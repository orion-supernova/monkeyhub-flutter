import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { isSystemAccount } from "./systemAccount";
import { attachFile, claimUpload, releaseFile } from "./files";
import { syncProfile } from "./profilesCore";

/**
 * Sets a system account's picture, or the picture of the system rooms it
 * owns, from an image passed in as base64.
 *
 * A mutation cannot create a blob, which is why `ensureSystemAccount` leaves
 * the avatar unset: the picture is deployment data, set once from a terminal
 * with the admin key:
 *
 *   npx convex run systemAvatars:set \
 *     '{"username":"monkeyhub_reporter","imageBase64":"…","contentType":"image/jpeg"}'
 *
 * `target` picks which face: "account" (the default) is the bot's own
 * picture, "room" is the picture of its room. A room that has never had its own
 * picture shows the bot's, so setting only the account is enough to start.
 *
 * Every face gets a blob of its own, stored from the same bytes: the account
 * and each room it owns hold one file each, so replacing or wiping one never
 * touches another's. The file a face stops wearing is released (see [apply]).
 *
 * Internal, so no client can reach it.
 */
export const set = internalAction({
  args: {
    username: v.string(),
    imageBase64: v.string(),
    contentType: v.string(),
    target: v.optional(v.union(v.literal("account"), v.literal("room"))),
  },
  returns: v.object({ storageId: v.union(v.id("_storage"), v.null()), rooms: v.number() }),
  handler: async (ctx, args): Promise<{ storageId: any; rooms: number }> => {
    const bytes = Uint8Array.from(atob(args.imageBase64), (c) =>
      c.charCodeAt(0),
    );
    const targets: { kind: "account" | "room"; id: string; previous: any }[] =
      await ctx.runQuery(internal.systemAvatars.targets, {
        username: args.username,
        target: args.target,
      });
    let accountFile: any = null;
    let rooms = 0;
    for (const t of targets) {
      const storageId = await ctx.storage.store(
        new Blob([bytes], { type: args.contentType }),
      );
      const applied: boolean = await ctx.runMutation(internal.systemAvatars.apply, {
        username: args.username,
        kind: t.kind,
        id: t.id,
        storageId,
        expectPrevious: t.previous ?? undefined,
      });
      if (!applied) {
        // The face changed under us; the blob is nobody's.
        await ctx.storage.delete(storageId);
        continue;
      }
      if (t.kind === "account") accountFile = storageId;
      else rooms++;
    }
    return { storageId: accountFile, rooms };
  },
});

/**
 * Whether [file] is the account's face: the same file, or (once every face owns
 * a blob of its own) a blob with the same bytes, which is what [set] stores for
 * each. A picture somebody chose for the room itself differs in content.
 */
async function wearsAccountFace(ctx: any, file: any, accountFile: any): Promise<boolean> {
  if (!accountFile) return false;
  if (file.toString() === accountFile.toString()) return true;
  const [a, b] = await Promise.all([ctx.db.system.get(file), ctx.db.system.get(accountFile)]);
  return !!a && !!b && a.sha256 === b.sha256;
}

/**
 * The faces a [set] reaches: the account (unless `target` is "room") and the
 * stamped system rooms it owns. A new bot face only reaches a room still
 * wearing the old one (or none), so it never overwrites a picture set for the
 * room itself; `previous` is what each wears now.
 */
export const targets = internalQuery({
  args: {
    username: v.string(),
    target: v.optional(v.union(v.literal("account"), v.literal("room"))),
  },
  handler: async (ctx, { username, target }) => {
    const account = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (!account || !isSystemAccount(account)) {
      throw new Error("NOT_A_SYSTEM_ACCOUNT");
    }
    const forRoom = target === "room";
    const out: { kind: "account" | "room"; id: string; previous: any }[] = [];
    if (!forRoom) {
      out.push({
        kind: "account",
        id: account._id.toString(),
        previous: account.avatarStorageId ?? null,
      });
    }
    // Only the stamped rooms this account owns. Its friendships point into
    // the same rooms, so there is nothing else carrying its face.
    const memberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", account._id))
      .collect();
    for (const m of memberships) {
      if (m.role !== "owner") continue;
      const room = await ctx.db.get(m.roomId);
      if (!room?.system) continue;
      if (
        !forRoom &&
        room.avatarStorageId &&
        !(await wearsAccountFace(ctx, room.avatarStorageId, account.avatarStorageId))
      ) {
        continue;
      }
      out.push({
        kind: "room",
        id: room._id.toString(),
        previous: room.avatarStorageId ?? null,
      });
    }
    return out;
  },
});

/**
 * The write half of [set], for one face. Refuses a human account: this must
 * never be a way to change a person's picture. `expectPrevious` is what the
 * face wore when [targets] looked; a face that has moved since is left alone
 * (false), so a concurrent change is never overwritten.
 *
 * The blob is claimed, attached to this face alone, and the file the face
 * stops wearing is released: it is the last use unless something still holds
 * a ref, which is exactly the account's old picture while a room still wears
 * it.
 */
export const apply = internalMutation({
  args: {
    username: v.string(),
    kind: v.union(v.literal("account"), v.literal("room")),
    id: v.string(),
    storageId: v.id("_storage"),
    expectPrevious: v.optional(v.id("_storage")),
  },
  returns: v.boolean(),
  handler: async (ctx, { username, kind, id, storageId, expectPrevious }) => {
    const account = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (!account || !isSystemAccount(account)) {
      throw new Error("NOT_A_SYSTEM_ACCOUNT");
    }
    const roomId = kind === "room" ? ctx.db.normalizeId("rooms", id) : null;
    const holderRow: any =
      kind === "account" ? account : roomId ? await ctx.db.get(roomId) : null;
    // A room must be a system room this account owns, never somebody's group.
    if (!holderRow) return false;
    if (kind === "room") {
      if (!holderRow.system) return false;
      const membership = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", holderRow._id).eq("userId", account._id),
        )
        .first();
      if (membership?.role !== "owner") return false;
    }
    const previous = holderRow.avatarStorageId;
    if (previous?.toString() !== expectPrevious?.toString()) return false;

    await claimUpload(ctx, storageId, undefined, "avatar");
    const holder = {
      table: kind === "account" ? "users" : "rooms",
      id: holderRow._id.toString(),
      field: "avatarStorageId",
    };
    await ctx.db.patch(holderRow._id, { avatarStorageId: storageId });
    if (kind === "account") await syncProfile(ctx, holderRow._id);
    await attachFile(ctx, storageId, holder);
    if (previous && previous !== storageId) {
      await releaseFile(ctx, previous, holder);
    }
    return true;
  },
});
