/**
 * "Can we use this photo instead?" — the group's identity, proposed by people
 * who cannot change it.
 *
 * A group's name, description and picture are admin-only (see `rooms.ts`, and
 * `roomAdmin.ts` for why). That rule is right — the avatar is the most visible
 * thing about a group and the first thing a griefer reaches for — but on its
 * own it leaves the ordinary case with nowhere to go: a member who took the
 * photo everyone is in has to send it to the chat and ask somebody to set it,
 * which is a worse version of this feature implemented by hand, badly, every
 * time.
 *
 * So the refusal grows an answer. A member proposes; the room's admins are
 * told; any one of them approves or rejects; the proposer can take it back
 * before anyone rules. Nothing here can change the room by itself — approval
 * is what writes to `rooms`, and it runs the same validation the admin's own
 * edit would (see `applyChange`), so "approved" cannot smuggle past a rule
 * `rooms.updateRoom` enforces.
 *
 * Deliberately NOT merged into `roomJoinRequests`. Both are "a person asking
 * an admin for something", and that is where the similarity stops: a join
 * request is answered by a membership and is about somebody who cannot see the
 * room at all, while this is answered by a patch to the room document and
 * comes from somebody already inside it. Sharing a table would mean one row
 * shape where half the columns are null depending on a discriminator, and
 * every query would have to remember which half it was reading.
 *
 * ONE pending proposal per person per field, enforced by replacement in
 * `propose`. That is the whole flood control: a room of N members can queue at
 * most 3N suggestions, each attributable to somebody an admin can remove, and
 * picking a second photo replaces the first rather than queueing beside it —
 * which is what somebody who picked twice actually meant.
 */

import { assertCleanName, assertCleanText } from "./contentFilter";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { deleteStored } from "./files";
import { lensFor, publicUserView } from "./visibility";
import {
  assertAdministrableRoom,
  assertMember,
  isAdminRole,
  roleOf,
} from "./roomAdmin";

/** The three things about a group that a member can ask to change. */
export const FIELD_AVATAR = "avatar";
export const FIELD_NAME = "name";
export const FIELD_DESCRIPTION = "description";

const FIELDS = [FIELD_AVATAR, FIELD_NAME, FIELD_DESCRIPTION];

export const STATUS_PENDING = "pending";
export const STATUS_APPROVED = "approved";
export const STATUS_REJECTED = "rejected";

export const ERR_NOT_FOUND = "CHANGE_REQUEST_NOT_FOUND";
export const ERR_INVALID_FIELD = "CHANGE_REQUEST_INVALID_FIELD";
/** An avatar proposal with no file, or a text proposal with no text. */
export const ERR_MISSING_VALUE = "CHANGE_REQUEST_MISSING_VALUE";
/** Proposing exactly what the room already says. */
export const ERR_NO_CHANGE = "CHANGE_REQUEST_NO_CHANGE";
/** Withdrawing somebody else's. */
export const ERR_NOT_REQUESTER = "CHANGE_REQUEST_NOT_YOURS";

/**
 * Same ceiling `rooms.updateRoom` implies for a name, made explicit here
 * because this path accepts text from somebody the room has not trusted with
 * the field. A description long enough to be a denial-of-service on the review
 * sheet is not a suggestion.
 */
const NAME_MAX = 100;
const DESCRIPTION_MAX = 500;

// ─────────────────────────────── helpers ───────────────────────────────

function assertField(field: string) {
  if (!FIELDS.includes(field)) throw new Error(ERR_INVALID_FIELD);
}

/** This room's outstanding proposals, oldest first — the admin's work queue. */
async function pendingFor(ctx: any, roomId: any) {
  const rows = await ctx.db
    .query("roomChangeRequests")
    .withIndex("by_room_status", (q: any) =>
      q.eq("roomId", roomId).eq("status", STATUS_PENDING),
    )
    .collect();
  rows.sort((a: any, b: any) => a.createdAt - b.createdAt);
  return rows;
}

/**
 * Free the file a proposal was carrying.
 *
 * Called on every ending EXCEPT approval: a rejected, withdrawn or swept
 * avatar proposal is the last pointer to those bytes, and leaving it would
 * bill forever for a picture nobody chose. On approval the room document is
 * now the pointer, so deleting here would hand the group a broken avatar —
 * which is exactly the bug `rooms.updateRoomAvatar` guards against on its own
 * side with an id comparison.
 */
async function releaseProposal(ctx: any, row: any) {
  if (row?.field === FIELD_AVATAR && row.storageId) {
    await deleteStored(ctx, row.storageId);
  }
}

/**
 * Two other files sweep this table and do it INLINE rather than calling in
 * here: `roomAdmin.clearPendingFor` (somebody left, was removed, or was
 * admitted) and `roomCleanup.wipeRoomContents` (the room is going). Both
 * already sweep `roomInvitations` and `roomJoinRequests` the same way, and
 * both are imported BY this file's dependencies — a helper exported from here
 * would close an import cycle for four lines of query.
 *
 * What those two must not get wrong is the blob: a pending avatar proposal is
 * the last pointer to its file, so deleting the row without
 * `deleteStored(storageId)` bills forever for a picture nobody chose. Both
 * call sites say so at the sweep.
 */

/**
 * Write the proposed value onto the room.
 *
 * The ONE place a proposal can touch `rooms`, and it repeats the checks
 * `rooms.updateRoom` and `rooms.updateRoomAvatar` make rather than trusting
 * that they were true when the row was written. Both matter:
 *
 *  * A name that was free when it was suggested can be taken by the time an
 *    admin looks. Approving into a duplicate would break the `by_name` lookup
 *    every DM key and system room depends on.
 *  * The previous avatar has to be released here, exactly as
 *    `updateRoomAvatar` does, or approving a suggestion leaks the picture it
 *    replaced — the same file the admin's own edit would have freed.
 */
async function applyChange(ctx: any, room: any, row: any) {
  if (row.field === FIELD_AVATAR) {
    const previous = room.avatarStorageId;
    await ctx.db.patch(room._id, { avatarStorageId: row.storageId });
    if (previous && previous !== row.storageId) {
      await deleteStored(ctx, previous);
    }
    return;
  }
  if (row.field === FIELD_NAME) {
    const trimmed = (row.value ?? "").trim();
    if (!trimmed) throw new Error("ROOM_NAME_REQUIRED");
    if (trimmed !== room.name) {
      const clash = await ctx.db
        .query("rooms")
        .withIndex("by_name", (q: any) => q.eq("name", trimmed))
        .first();
      if (clash && clash._id.toString() !== room._id.toString()) {
        throw new Error("ROOM_EXISTS");
      }
    }
    await ctx.db.patch(room._id, { name: trimmed });
    return;
  }
  // Description. An empty string is a real proposal — "take the description
  // off" — and `rooms.updateRoom` spells that as `undefined`, so it is spelled
  // the same way here rather than stored as "".
  const text = (row.value ?? "").trim();
  await ctx.db.patch(room._id, { description: text.length > 0 ? text : undefined });
}

/** What the room says right now, for the field a proposal is about. */
function currentValue(room: any, field: string): string {
  if (field === FIELD_NAME) return room.name ?? "";
  if (field === FIELD_DESCRIPTION) return room.description ?? "";
  return room.avatarStorageId ? room.avatarStorageId.toString() : "";
}

/** Every admin of the room, for the "somebody suggested something" fan-out. */
async function adminIdsOf(ctx: any, roomId: any): Promise<string[]> {
  const rows = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  return rows
    .filter((m: any) => isAdminRole(m.role))
    .map((m: any) => m.userId.toString());
}

// ─────────────────────────────── mutations ───────────────────────────────

/**
 * Ask for the room to look different.
 *
 * **An admin's proposal applies immediately** and comes back as
 * `{ status: "applied" }`. That is not a shortcut around the queue, it is the
 * only correct answer to a real race: a member opens the picker, is promoted
 * while they are cropping, and taps save. Refusing there would strand a
 * finished upload behind an error about a permission they now have, and filing
 * a request for somebody to approve for themselves is worse. The client never
 * takes this path deliberately — it calls `rooms.updateRoom` /
 * `rooms.updateRoomAvatar` when `canEditRoom` is true — so "applied" is only
 * ever seen by the person who was promoted mid-edit.
 *
 * Proposing again on the same field REPLACES the outstanding one, freeing the
 * file the earlier suggestion was carrying. Somebody who picks a second photo
 * has changed their mind, not queued a second question.
 */
export const propose = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    field: v.string(), // "avatar" | "name" | "description"
    /** For "name" and "description". Empty clears the description. */
    value: v.optional(v.string()),
    /** For "avatar". Already uploaded — see `files.generateUploadUrl`. */
    storageId: v.optional(v.id("_storage")),
  },
  handler: async (ctx, { roomId, userId, field, value, storageId }) => {
    assertField(field);
    const room = await assertAdministrableRoom(ctx, roomId);
    const role = await assertMember(ctx, roomId, userId);

    // Shape first, rank second: a malformed proposal is malformed whoever
    // sent it, and validating after the admin short-circuit below would let an
    // admin write an empty name through a path that claims to check.
    let proposed: string;
    if (field === FIELD_AVATAR) {
      if (!storageId) throw new Error(ERR_MISSING_VALUE);
      proposed = storageId.toString();
    } else {
      const trimmed = (value ?? "").trim();
      if (field === FIELD_NAME && !trimmed) throw new Error(ERR_MISSING_VALUE);
      if (field === FIELD_NAME && trimmed.length > NAME_MAX) {
        throw new Error(ERR_MISSING_VALUE);
      }
      if (field === FIELD_DESCRIPTION && trimmed.length > DESCRIPTION_MAX) {
        throw new Error(ERR_MISSING_VALUE);
      }
      // Refused at proposal, so an admin is never asked to approve it.
      if (field === FIELD_NAME) assertCleanName(trimmed);
      if (field === FIELD_DESCRIPTION) assertCleanText(trimmed);
      proposed = trimmed;
    }

    // Suggesting what the room already says is a no-op an admin would have to
    // read and dismiss. Refused here rather than silently dropped, so the
    // client can say "that's already the name" instead of showing a pending
    // badge for something that will never visibly land.
    //
    // Not applied to an avatar: two uploads of the same picture are different
    // storage ids, so this can only ever compare equal when the client sends
    // back the id it was already showing, which it does not do.
    if (field !== FIELD_AVATAR && proposed === currentValue(room, field)) {
      throw new Error(ERR_NO_CHANGE);
    }

    const now = Date.now();

    // See the docstring: the promoted-mid-edit case.
    if (isAdminRole(role)) {
      await applyChange(ctx, room, { field, value: proposed, storageId });
      return { status: "applied" as const, requestId: null };
    }

    const mine = await ctx.db
      .query("roomChangeRequests")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .collect();
    for (const row of mine) {
      if (row.status !== STATUS_PENDING || row.field !== field) continue;
      await releaseProposal(ctx, row);
      await ctx.db.delete(row._id);
    }

    const requestId = await ctx.db.insert("roomChangeRequests", {
      roomId,
      userId,
      field,
      status: STATUS_PENDING,
      createdAt: now,
      ...(field === FIELD_AVATAR ? { storageId } : { value: proposed }),
    });

    const admins = await adminIdsOf(ctx, roomId);
    if (admins.length > 0) {
      const who = await ctx.db.get(userId);
      await ctx.scheduler.runAfter(
        0,
        internal.notifications.sendRoomChangePush,
        {
          userIds: admins,
          roomId,
          roomName: room.name,
          who: who?.name ?? who?.username ?? "Someone",
          field,
          // Spread rather than an explicit `undefined`: a scheduled action's
          // args are validated at FIRE time, minutes of wall clock after the
          // mutation that queued them returned successfully, so a shape
          // mistake here surfaces as a notification that silently never
          // arrives rather than as a failed call anybody can see.
          ...(field === FIELD_NAME ? { value: proposed } : {}),
        },
      );
    }
    return { status: "pending" as const, requestId };
  },
});

/**
 * Take a suggestion back before anybody has ruled on it.
 *
 * DELETED, not stamped "withdrawn". A join request is kept after a decision
 * because the row is the audit trail and the thing that stops somebody
 * re-queueing; neither applies here. Withdrawing means "forget I asked", and
 * leaving the row for admins to read later is the opposite of that. The file
 * goes with it, because nothing points at it any more.
 *
 * The requester only. An admin who wants it gone rejects it, which tells the
 * proposer what happened — a silent admin-side withdrawal would read to them
 * as the suggestion evaporating.
 */
export const withdraw = mutation({
  args: { requestId: v.id("roomChangeRequests"), userId: v.id("users") },
  handler: async (ctx, { requestId, userId }) => {
    const row = await ctx.db.get(requestId);
    if (!row || row.status !== STATUS_PENDING) throw new Error(ERR_NOT_FOUND);
    if (row.userId.toString() !== userId.toString()) {
      throw new Error(ERR_NOT_REQUESTER);
    }
    await releaseProposal(ctx, row);
    await ctx.db.delete(requestId);
  },
});

/**
 * Approve or reject one suggestion. Any admin may answer; the row records
 * which one did.
 *
 * Rows are kept after the decision rather than deleted — unlike a withdrawal,
 * somebody else's yes or no is a fact about the room worth being able to look
 * up, and the proposer's own screen reads the status back to explain why their
 * suggestion stopped being pending.
 *
 * A rejected avatar's file is released here. Approving hands the bytes to the
 * room, so only this branch is the last pointer.
 */
export const decide = mutation({
  args: {
    requestId: v.id("roomChangeRequests"),
    userId: v.id("users"), // the deciding admin
    approve: v.boolean(),
  },
  handler: async (ctx, { requestId, userId, approve }) => {
    const row = await ctx.db.get(requestId);
    if (!row || row.status !== STATUS_PENDING) throw new Error(ERR_NOT_FOUND);
    const room = await assertAdministrableRoom(ctx, row.roomId);
    // Rank, from the room the ROW names — never from an argument. Checked
    // against the live membership, so an admin demoted since the notification
    // landed is refused here rather than by the UI that has already stopped
    // drawing the button.
    const role = await roleOf(ctx, row.roomId, userId);
    if (role === null) throw new Error("NOT_A_MEMBER");
    if (!isAdminRole(role)) throw new Error("NOT_ADMIN");

    // The write BEFORE the status stamp, so a refusal (a name taken since the
    // suggestion) leaves the row pending for the admin to see again rather
    // than marking it approved against a room that never changed.
    if (approve) await applyChange(ctx, room, row);

    await ctx.db.patch(requestId, {
      status: approve ? STATUS_APPROVED : STATUS_REJECTED,
      decidedAt: Date.now(),
      decidedBy: userId,
    });
    if (!approve) await releaseProposal(ctx, row);

    await ctx.scheduler.runAfter(
      0,
      internal.notifications.sendRoomChangeDecidedPush,
      {
        userIds: [row.userId.toString()],
        roomName: room.name,
        roomId: row.roomId,
        field: row.field,
        approved: approve,
      },
    );
  },
});

// ─────────────────────────────── reads ───────────────────────────────

/**
 * The admin queue for one room.
 *
 * Admin-only; returns [] rather than throwing for anybody else, so a demoted
 * admin's open screen empties instead of erroring — the same posture
 * `roomInvites.listJoinRequests` takes, and for the same reason.
 *
 * Carries the room's CURRENT value beside the proposed one. An admin ruling on
 * "call it Trip 2026" needs to know what it is called now, and making the
 * sheet fetch the room separately would let the two disagree for a frame.
 */
export const listPending = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const role = await roleOf(ctx, roomId, userId);
    if (!isAdminRole(role)) return [];
    const room = await ctx.db.get(roomId);
    if (!room) return [];

    // Through the viewer's lens like every other roster in the app — a
    // suggestion is not a reason to hand an admin fields its author set to
    // "friends only".
    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const out = [];
    for (const row of await pendingFor(ctx, roomId)) {
      const user = await ctx.db.get(row.userId);
      if (!user) continue;
      out.push({
        requestId: row._id,
        field: row.field,
        value: row.value ?? null,
        // The storage id, NOT a resolved URL: the client draws room and user
        // pictures through `RemoteImage`, which caches bytes on disk and
        // decodes to the painted size. A URL here would opt the review sheet
        // out of both.
        storageId: row.storageId ?? null,
        createdAt: row.createdAt,
        currentValue:
          row.field === FIELD_AVATAR ? null : currentValue(room, row.field),
        currentStorageId:
          row.field === FIELD_AVATAR ? (room.avatarStorageId ?? null) : null,
        user: publicUserView(lens, user, now),
      });
    }
    return out;
  },
});

/**
 * "What have I got outstanding here?" — the proposer's own view, and the only
 * query about a suggestion a non-admin may run.
 *
 * Pending rows only. A decided suggestion is told to its author by push and by
 * the room visibly changing (or not); a row that lingered on their settings
 * screen afterwards would be a notice they have to dismiss for something that
 * has already happened.
 */
export const mine = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const rows = await ctx.db
      .query("roomChangeRequests")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .collect();
    return rows
      .filter((r: any) => r.status === STATUS_PENDING)
      .sort((a: any, b: any) => a.createdAt - b.createdAt)
      .map((r: any) => ({
        requestId: r._id,
        field: r.field,
        value: r.value ?? null,
        storageId: r.storageId ?? null,
        createdAt: r.createdAt,
      }));
  },
});
