import { internalAction, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { isSystemAccount } from "./systemAccount";

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
 * Internal, so no client can reach it. The previous blob is left in storage:
 * it is a few KB, and nothing here can prove no message still points at it.
 */
export const set = internalAction({
  args: {
    username: v.string(),
    imageBase64: v.string(),
    contentType: v.string(),
    target: v.optional(v.union(v.literal("account"), v.literal("room"))),
  },
  returns: v.object({ storageId: v.id("_storage"), rooms: v.number() }),
  handler: async (ctx, args): Promise<{ storageId: any; rooms: number }> => {
    const bytes = Uint8Array.from(atob(args.imageBase64), (c) =>
      c.charCodeAt(0),
    );
    const storageId = await ctx.storage.store(
      new Blob([bytes], { type: args.contentType }),
    );
    const rooms: number = await ctx.runMutation(internal.systemAvatars.apply, {
      username: args.username,
      storageId,
      target: args.target,
    });
    return { storageId, rooms };
  },
});

/**
 * The write half of [set]. Refuses a human account: this must never be a way
 * to change a person's picture.
 */
export const apply = internalMutation({
  args: {
    username: v.string(),
    storageId: v.id("_storage"),
    target: v.optional(v.union(v.literal("account"), v.literal("room"))),
  },
  returns: v.number(),
  handler: async (ctx, { username, storageId, target }) => {
    const account = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (!account || !isSystemAccount(account)) {
      throw new Error("NOT_A_SYSTEM_ACCOUNT");
    }
    const forRoom = target === "room";
    const previous = account.avatarStorageId;
    if (!forRoom) {
      await ctx.db.patch(account._id, { avatarStorageId: storageId });
    }

    // Only the stamped rooms this account owns. Its friendships point into
    // the same rooms, so there is nothing else carrying its face.
    let rooms = 0;
    const memberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", account._id))
      .collect();
    for (const m of memberships) {
      if (m.role !== "owner") continue;
      const room = await ctx.db.get(m.roomId);
      if (!room?.system) continue;
      // A new bot face only reaches a room still wearing the old one (or none),
      // so it never overwrites a picture set for the room itself.
      if (
        !forRoom &&
        room.avatarStorageId &&
        room.avatarStorageId !== previous
      ) {
        continue;
      }
      await ctx.db.patch(room._id, { avatarStorageId: storageId });
      rooms++;
    }
    return rooms;
  },
});
