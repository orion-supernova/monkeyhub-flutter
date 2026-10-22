/**
 * The room posting policy: what a room's MEMBERS may put into it.
 *
 * ── The problem ────────────────────────────────────────────────────────────
 *
 * Some rooms are not conversations. `MonkeyHub Logs` is a feed the app writes
 * problem reports into, and the people in it are there to READ. Future system
 * rooms (an AI agent room, a support room, an announcements channel) will each
 * want something in between: text and photos but no games, replies but no
 * calls. "Is this a system room" is a yes/no, and these answers are a table.
 *
 * ── The shape ──────────────────────────────────────────────────────────────
 *
 * A room carries an optional `rooms.postingPolicy`: the NAME of a preset in
 * [POSTING_PRESETS] below. A preset name rather than a stored object, for the
 * same reason `rooms.system` is a slug: the table lives in code on both sides
 * (`lib/models/room_posting_policy.dart` mirrors it), so changing what a preset
 * means is one deploy, not a backfill of every row that carries it.
 *
 * Resolution, in [postingPresetOf]:
 *
 *   1. `rooms.postingPolicy`, when set and known.
 *   2. Otherwise a system room (`rooms.system` set) is `readOnly`. This is what
 *      keeps a system room created by some path nobody has written yet safe
 *      before anybody remembers to stamp it, and what makes the logs room
 *      read-only even before its backfill runs.
 *   3. Otherwise `open`, which is exactly today's behaviour. Every ordinary
 *      room carries no field and changes not at all.
 *
 * An unknown preset name (impossible through the validator, but a rolled-back
 * deploy can leave one behind) resolves to `readOnly`: the failure mode of a
 * policy this code predates is a room nobody can post in, never a room
 * anybody can post anything in.
 *
 * ── Who it binds ───────────────────────────────────────────────────────────
 *
 * Members. A system account (`systemAccount.isSystemAccount`) is never bound by
 * it, and neither is any internal mutation that writes rows directly
 * (`problemReports.submit` inserts its messages itself and never reaches a
 * guard at all). The bypass is decided by WHO is writing, from the `users` row,
 * never from an argument.
 *
 * ── Where it is enforced ───────────────────────────────────────────────────
 *
 * One function, [assertRoomAllows], called from every public path that adds
 * member content to a room:
 *
 *   messages.guardOutgoing   send, scheduled send (stage AND release),
 *                            forwardToRoom, live-location updates, and every
 *                            `sendCore` caller (polls, games, challenges)
 *   messages.sendCore        the post-downgrade re-check and replies
 *   messages.editMessage     editing your own text
 *   reactions.addReaction
 *   pins.pin
 *   interactions.respond / addItem
 *   calls.initiate / groupCalls.start
 *
 * Imports only `systemAccount`, which imports nothing, so any module may use it
 * without an import cycle.
 */
import { v } from "convex/values";
import { isSystemAccount, isSystemRoom } from "./systemAccount";

/** Thrown by [assertRoomAllows]. One code for every refusal: the client's
 * answer to all of them is the same quiet "you can't post here". */
export const ERR_ROOM_POSTING_RESTRICTED = "ROOM_POSTING_RESTRICTED";

/**
 * The kinds of content a member can post, coarser than message `type`.
 *
 * Coarser on purpose: a policy says "photos", not "image and album image and
 * camera image", and `url` vs `text` is wire history, not a distinction anyone
 * would grant separately. [postKindOf] is the one mapping from type to kind.
 */
export const POST_KINDS = [
  "text", // text, url
  "image",
  "video", // video, videoNote
  "voice", // audio
  "file",
  "sticker", // sticker, gif
  "location", // location, liveLocation
  "poll",
  "checklist",
  "event",
  "game", // game, gameMove, challenge
  "system", // `type: "system"` notices
  "other", // any type this table has not been taught
] as const;
export type PostKind = (typeof POST_KINDS)[number];

/** Non-message acts a policy can grant or withhold. */
export type RoomAction =
  | "reply"
  | "react"
  | "forwardIn"
  | "call"
  | "interact" // poll votes, checklist ticks and items, event RSVPs
  | "pin";

export interface PostingPolicy {
  /** `"all"` grants every kind, including ones not invented yet. */
  kinds: "all" | ReadonlySet<PostKind>;
  replies: boolean;
  reactions: boolean;
  forwardsIn: boolean;
  calls: boolean;
  interactions: boolean;
  pins: boolean;
}

const OPEN: PostingPolicy = {
  kinds: "all",
  replies: true,
  reactions: true,
  forwardsIn: true,
  calls: true,
  interactions: true,
  pins: true,
};

const READ_ONLY: PostingPolicy = {
  kinds: new Set<PostKind>(),
  replies: false,
  reactions: false,
  forwardsIn: false,
  calls: false,
  interactions: false,
  pins: false,
};

/**
 * The named presets. Mirrored in `lib/models/room_posting_policy.dart`; a
 * change here is a change there.
 *
 *   open      every room that is not special. Today's behaviour, untouched.
 *   readOnly  a feed: members read, the app writes. `MonkeyHub Logs`.
 *   agent     a conversation with a bot: words and pictures, replies and
 *             reactions, nothing that needs a second human (calls, games) and
 *             nothing the bot cannot read (voice, video, files, location).
 */
export const POSTING_PRESETS = {
  open: OPEN,
  readOnly: READ_ONLY,
  agent: {
    kinds: new Set<PostKind>(["text", "image"]),
    replies: true,
    reactions: true,
    forwardsIn: true,
    calls: false,
    interactions: true,
    pins: true,
  } satisfies PostingPolicy,
} as const;
export type PostingPreset = keyof typeof POSTING_PRESETS;

/** The schema validator for `rooms.postingPolicy`. Adding a preset is adding a
 * literal here and an entry above. */
export const postingPresetValidator = v.union(
  v.literal("open"),
  v.literal("readOnly"),
  v.literal("agent"),
);

/** The preset the logs room is stamped with. */
export const LOG_ROOM_POSTING_PRESET: PostingPreset = "readOnly";

/** Which preset governs [room]. See the resolution order in the header. */
export function postingPresetOf(
  room: { postingPolicy?: string; system?: string } | null | undefined,
): PostingPreset {
  const stored = room?.postingPolicy;
  if (typeof stored === "string" && stored.length > 0) {
    return Object.prototype.hasOwnProperty.call(POSTING_PRESETS, stored)
      ? (stored as PostingPreset)
      : "readOnly";
  }
  return isSystemRoom(room ?? null) ? "readOnly" : "open";
}

export function postingPolicyOf(
  room: { postingPolicy?: string; system?: string } | null | undefined,
): PostingPolicy {
  return POSTING_PRESETS[postingPresetOf(room)];
}

/** The one mapping from a message `type` to the [PostKind] a policy grants. */
export function postKindOf(type: string | undefined | null): PostKind {
  switch (type ?? "text") {
    case "text":
    case "url":
      return "text";
    case "image":
      return "image";
    case "video":
    case "videoNote":
      return "video";
    case "audio":
      return "voice";
    case "file":
      return "file";
    case "gif":
    case "sticker":
      return "sticker";
    case "location":
    case "liveLocation":
      return "location";
    case "poll":
      return "poll";
    case "checklist":
      return "checklist";
    case "event":
      return "event";
    case "game":
    case "gameMove":
    case "challenge":
      return "game";
    case "system":
      return "system";
    default:
      return "other";
  }
}

/** What one write wants: the kinds of content it adds, and the acts it does. */
export interface RoomWrite {
  kinds?: readonly PostKind[];
  actions?: readonly RoomAction[];
}

function actionAllowed(policy: PostingPolicy, action: RoomAction): boolean {
  switch (action) {
    case "reply":
      return policy.replies;
    case "react":
      return policy.reactions;
    case "forwardIn":
      return policy.forwardsIn;
    case "call":
      return policy.calls;
    case "interact":
      return policy.interactions;
    case "pin":
      return policy.pins;
  }
}

/** Pure: whether [policy] grants everything [write] asks for. */
export function policyAllows(policy: PostingPolicy, write: RoomWrite): boolean {
  for (const kind of write.kinds ?? []) {
    if (policy.kinds !== "all" && !policy.kinds.has(kind)) return false;
  }
  for (const action of write.actions ?? []) {
    if (!actionAllowed(policy, action)) return false;
  }
  return true;
}

/**
 * THE guard. Throws [ERR_ROOM_POSTING_RESTRICTED] unless [room]'s policy grants
 * [write] to [userId], or [userId] is a system account.
 *
 * The sender's row is read only when the policy refuses, so an ordinary room
 * (preset `open`, which refuses nothing) costs this zero reads. Pass [sender]
 * when it is already in hand to skip even that one.
 *
 * A tombstoned room (`deletingAt`) is `ROOM_NOT_FOUND`. A missing room is not
 * this function's refusal to make: every caller already
 * has its own `ROOM_NOT_FOUND` / membership answer, and a null here resolves to
 * `open` so that answer is the one the client sees.
 */
export async function assertRoomAllows(
  ctx: any,
  room:
    | { postingPolicy?: string; system?: string; deletingAt?: number }
    | null
    | undefined,
  userId: any,
  write: RoomWrite,
  sender?: { passwordHash?: string } | null,
): Promise<void> {
  // A room being deleted takes nothing new (send, schedule, forward all pass
  // here). The row is already in hand, so this costs no read. Inline rather
  // than `deletionCore.isTombstoned`: this file imports nothing on purpose.
  if (room?.deletingAt !== undefined) throw new Error("ROOM_NOT_FOUND");
  if (policyAllows(postingPolicyOf(room), write)) return;
  const who = sender !== undefined ? sender : userId ? await ctx.db.get(userId) : null;
  if (isSystemAccount(who)) return;
  throw new Error(ERR_ROOM_POSTING_RESTRICTED);
}

/** [assertRoomAllows] for callers holding only the room id. */
export async function assertRoomAllowsById(
  ctx: any,
  roomId: any,
  userId: any,
  write: RoomWrite,
): Promise<void> {
  await assertRoomAllows(ctx, await ctx.db.get(roomId), userId, write);
}
