import { internalMutation, internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import {
  ERR_APPROVAL_REQUIRED,
  ERR_NOT_ALLOWED,
  LOCATION_POLICY_FLAG,
  childMayUseRoom,
  childPolicyOf,
  childPolicyOfUser,
} from "./childGuard";
import { deleteStored, releaseMessageBlobs } from "./files";
import { forkInteraction, purgeInteraction } from "./interactionCore";
import { lensFor } from "./visibility";

// ── Delivery-receipt tuning ─────────────────────────────────────────────────

/**
 * Largest room that still reports delivery — the second tick's fan-out cap.
 *
 * Sized to cover real group chats and nothing beyond them. Past this, a
 * `roomMembers` patch re-runs `getReadState` for every member, so the write
 * gets steadily more expensive while the thing it claims ("at least one other
 * device has this") gets steadily less informative, until in a public room of
 * hundreds it is true the instant a message is sent and worth nothing.
 *
 * Rooms above the line simply stay on one tick; nothing else about them
 * changes. Mirrored client-side in `ChatRepository.kDeliveryMemberLimit` so the
 * call is skipped before the round trip — keep the two in step.
 */
const DELIVERY_MEMBER_LIMIT = 50;

// ── View-once tuning ────────────────────────────────────────────────────────

/** Burn an armed photo this long after it was sent, opened or not. */
const VIEW_ONCE_DEADLINE_MS = 14 * 24 * 60 * 60 * 1000;

/**
 * How long a download ticket stays valid. This is also the retry window: a
 * client whose fetch dies on bad cellular asks `openViewOnce` again and gets
 * the SAME nonce back, because re-minting would be indistinguishable from a
 * second view. Long enough for a multi-megabyte photo on a bad connection.
 */
const VIEW_ONCE_NONCE_TTL_MS = 120_000;

/**
 * Delay between "the last recipient opened it" and deleting the blob. Must
 * exceed the nonce TTL, or we would delete the file out from under the very
 * download that triggered the burn.
 */
const VIEW_ONCE_BURN_GRACE_MS = VIEW_ONCE_NONCE_TTL_MS + 30_000;

// ── Live-location tuning ────────────────────────────────────────────────────

/**
 * The durations a live share may be started for, in milliseconds.
 *
 * A closed set rather than a free number, and validated server-side rather
 * than only offered client-side: `liveExpiresAt` is the entire safety property
 * of this feature, so "how long am I visible for" must not be something a
 * client can set to a year by sending a bigger integer.
 *
 * 15 min / 1 h / 8 h is the set the large messengers converged on, and the
 * reasoning behind it is sound — meeting someone now, an outing, a day out —
 * so it is copied rather than re-derived. Mirrored client-side in
 * `LiveShareDuration` (lib/models/location_share.dart); keep the two in step.
 */
const LIVE_SHARE_DURATIONS_MS = [
  15 * 60 * 1000,
  60 * 60 * 1000,
  8 * 60 * 60 * 1000,
];

/**
 * Smallest gap between two accepted position updates on one share.
 *
 * A rate limit rather than a smoothing filter. The client already throttles to
 * one publish per 10 s (`LiveLocationPublisher`), so in normal operation this
 * never fires; it exists because `updateLiveLocation` is a public mutation and
 * a client in a retry loop — or one that simply has a bug — must not be able
 * to rewrite one row hundreds of times a second on the box crons.ts:6-13
 * describes. Deliberately below the client's own interval so clock skew
 * between the two cannot silently drop legitimate updates.
 */
const LIVE_UPDATE_MIN_INTERVAL_MS = 5_000;

/**
 * Row budget for the "starting a share ends your previous one" scan in `send`,
 * and for the repair sweep. Both range over the currently-live bucket, whose
 * size is the number of shares running across the whole deployment right now —
 * a set measured in tens. The cap is a guarantee about the read set rather
 * than a claim about the data: nothing breaks if it is hit, because every
 * share also carries its own `runAt`.
 */
const LIVE_SHARE_SUPERSEDE_SCAN_LIMIT = 100;

/**
 * Strips a view-once message down to what a client is allowed to hold.
 *
 * This is the whole feature. `files:getFileUrl` is a public query, and on a
 * self-hosted deployment `ctx.storage.getUrl` returns an unsigned URL with no
 * expiry (see the comment in lib/media/file_url_cache.dart). So the storage id
 * IS the picture: any client that learns one can fetch the bytes forever,
 * without ever calling `openViewOnce`. Every read path therefore has to remove
 * it — and remove it unconditionally, including for the sender, so no branch
 * can leak it by being forgotten.
 *
 * `viewOnceOpened` costs one indexed lookup, and only for armed messages, so
 * ordinary rooms pay nothing. Scoping it to the viewer's OWN ledger rows is
 * also what keeps this safe in a subscribed query: inserting a row refires
 * that viewer's `list` (which is how opening on web greys the bubble out on
 * their phone) and nobody else's.
 */
export async function sanitizeViewOnce(ctx: any, msg: any, viewerUserId: any) {
  if (msg?.viewOnce !== true) return msg;
  // `posterStorageId` is here in depth, not as the guard. `send` never writes
  // one on an armed message in the first place — which it has to be, because
  // this is a list of field names rather than a rule, and because
  // `files:getFileUrl` refuses a view-once blob by looking it up in `by_media`,
  // an index keyed on `mediaStorageId` alone. A poster that reached storage
  // would be fetchable by anyone who learned its id, forever.
  const {
    mediaStorageId: _id,
    mediaWidth: _w,
    mediaHeight: _h,
    posterStorageId: _p,
    ...rest
  } = msg;
  let opened = false;
  if (viewerUserId) {
    const row = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message_user", (q: any) =>
        q.eq("messageId", msg._id).eq("userId", viewerUserId)
      )
      .first();
    opened = row !== null;
  }
  return { ...rest, viewOnceOpened: opened };
}

/**
 * The reactions on one message, for the transcript queries.
 *
 * Reads `reactions.by_message` only when `msg.hasReactions` is `true`. Any
 * other row costs nothing — and "nobody reacted" is the common case by a wide
 * margin, which is the whole point: `list` is re-run for every viewer of a
 * room on every message sent into it, and it used to spend a hundred index
 * reads per run finding nothing. See the field comment in schema.ts.
 *
 * Reactivity is preserved, not bypassed: `addReaction` patches the message
 * row it reacts to, and every caller here holds that row in its read set, so
 * the first reaction on a message re-fires the query and the read happens.
 */
export async function reactionsFor(
  ctx: any,
  msg: any
): Promise<Doc<"reactions">[]> {
  if (msg.hasReactions !== true) return [];
  return await ctx.db
    .query("reactions")
    .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
    .collect();
}

// ── Shared-content indexing ─────────────────────────────────────────────────

/**
 * URL detection, for `messages.hasLink`.
 *
 * This is a deliberate port of `UrlDetector._pattern` in
 * lib/services/link_preview_service.dart, and the two must stay identical:
 * the LINKS tab decides *which rows to read* from this one and then decides
 * *what to render* with the Dart one, so a disagreement shows up as a page of
 * results that renders empty rather than as an error.
 * `url_detector_parity_test.dart` reads both literals and compares them.
 *
 * Only ever asked a yes/no question, so the client's extra trailing-punctuation
 * trim is irrelevant here — it can only shorten a match, never remove one.
 * The `i` flag is not decoration: the Dart side is `caseSensitive: false`, and
 * without it a message reading `HTTP://EXAMPLE.COM` would be linkified in its
 * bubble and yet never appear in the LINKS tab, because this is what decides
 * whether the row is in the index at all.
 */
export const LINK_PATTERN = /https?:\/\/[^\s<>"]+/i;

/**
 * Which shared-content tab a message belongs in, or undefined for none.
 *
 * The `hasBlob` argument is load-bearing and easy to mistake for a formality:
 * `messages:send` accepts `type: "image"` with no `mediaStorageId`, and
 * `ChatRepository` posts exactly that when its retained-bytes cap refuses an
 * upload. Bucketing one puts a tile in the grid that can never load and can
 * never be dismissed.
 *
 * Armed messages get no bucket at all, which is what keeps a view-once photo
 * out of the browser structurally — `eq()` cannot match an absent field — as
 * opposed to by a filter somebody has to remember to write on every read path.
 */
export function galleryBucketFor(
  type: string,
  hasBlob: boolean,
  viewOnce: boolean
): string | undefined {
  if (!hasBlob || viewOnce) return undefined;
  switch (type) {
    case "image":
    case "video":
    // A circular video note is a video for browsing purposes. It gets no tab of
    // its own: one note in a room is a message, and a MEDIA tab that split them
    // out would be a tab that is empty for almost everybody.
    case "videoNote":
      return "media";
    case "audio":
      return "voice";
    case "file":
      return "file";
    default:
      return undefined;
  }
}

/**
 * Whether [url] is one of KLIPY's, and so allowed on a GIF or sticker row.
 *
 * The whole reason `mediaUrl` can exist safely. Every client loads that URL
 * the moment the message scrolls into view, so without this check a sender
 * could put any address they liked in front of every member of a room — a
 * tracking pixel that logs who read the message and from where. Restricting it
 * to KLIPY's published network allowlist (`klipy.com` and its subdomains)
 * means the only party that learns anything is the one the viewer's own app
 * already talks to while browsing GIFs.
 *
 * HTTPS only, and capped in length because it is copied into reply previews
 * and forwards.
 */
export function isKlipyUrl(url: unknown): url is string {
  if (typeof url !== "string" || url.length === 0 || url.length > 2048) {
    return false;
  }
  try {
    const u = new URL(url);
    return (
      u.protocol === "https:" &&
      (u.hostname === "klipy.com" || u.hostname.endsWith(".klipy.com"))
    );
  } catch (_) {
    return false;
  }
}

/**
 * The GIF/sticker fields a send is allowed to write, or null to downgrade it.
 *
 * The client only ever NAMES the picture: a KLIPY URL, or a sticker id. What
 * lands on the row is decided here — the sticker's blob, format and size come
 * off its own `stickers` row, never from the caller, so nobody can send "a
 * sticker" that is really an arbitrary storage id.
 *
 * `mediaSource` on the result is also a permission: "pack" (an official pack)
 * is text-shaped for the child guard, while "klipy" and "personal" (a photo
 * somebody cut out) are pictures and need the media grant. See
 * [permissionsFor].
 *
 * Null rather than a throw for the reason the location block in `sendCore`
 * gives: a refused send strands a retry-forever bubble that no retry can fix.
 * The message goes out as text instead, which still says something.
 */
export async function expressionFieldsFor(
  ctx: any,
  type: string,
  a: {
    mediaSource?: string;
    mediaUrl?: string;
    mediaPreviewUrl?: string;
    mediaRef?: string;
    stickerId?: any;
    mediaWidth?: number;
    mediaHeight?: number;
  }
): Promise<Record<string, any> | null> {
  const size = (n: unknown) =>
    typeof n === "number" && Number.isFinite(n) && n > 0 && n < 10_000
      ? Math.round(n)
      : undefined;
  const klipy = () => {
    if (a.mediaSource !== "klipy" || !isKlipyUrl(a.mediaUrl)) return null;
    return {
      mediaSource: "klipy",
      mediaUrl: a.mediaUrl,
      // Dropped rather than refusing the send: it is only a thumbnail.
      mediaPreviewUrl: isKlipyUrl(a.mediaPreviewUrl) ? a.mediaPreviewUrl : undefined,
      mediaRef:
        typeof a.mediaRef === "string" && a.mediaRef.length <= 200
          ? a.mediaRef
          : undefined,
      mediaWidth: size(a.mediaWidth),
      mediaHeight: size(a.mediaHeight),
    };
  };

  if (type === "gif") return klipy();
  if (type !== "sticker") return null;

  if (a.stickerId === undefined) {
    const k = klipy();
    return k ? { ...k, stickerFormat: "image" } : null;
  }
  const sticker = await ctx.db.get(a.stickerId);
  if (!sticker || sticker.deletedAt !== undefined) return null;
  const pack = await ctx.db.get(sticker.packId);
  if (!pack) return null;
  return {
    mediaSource: pack.kind === "official" ? "pack" : "personal",
    stickerId: sticker._id,
    stickerStorageId: sticker.storageId,
    stickerFormat: sticker.format,
    mediaWidth: sticker.width,
    mediaHeight: sticker.height,
    // Not a column: `sendCore` takes it as the fallback alt text and strips
    // it before the insert.
    alt: sticker.emoji,
  };
}

/**
 * Which guarded capabilities a write actually uses.
 *
 * Two independent booleans, not one type string, and the difference is a
 * security boundary rather than a refactor. `guardOutgoing` used to branch on
 * the type, which left two holes:
 *
 *  * A mixed forward batch collapses to ONE type string, so a selection of nine
 *    photos and one location was described as "a location" — and a child with
 *    location allowed and media forbidden could forward the photos.
 *  * `send` accepts a `mediaStorageId` on any type at all, so a `location`
 *    message carrying a blob took the location branch and never met the media
 *    gate. The blob is fetchable via `files:getFileUrl` even though nothing
 *    renders it.
 *
 * Keyed on [hasBlob] rather than on the type for exactly that second reason: an
 * attachment is an attachment whatever the message calls itself.
 */
/**
 * The types that need no grant beyond being able to write in the room at all.
 *
 * `text` was the whole set until polls arrived, and adding to it IS a
 * permission change, so it is stated here rather than buried in an expression.
 *
 * The three interactive kinds join it because a poll, a checklist and an event
 * are words — a prompt and some labels the sender typed, carrying no blob and
 * no coordinates. Gating them behind the MEDIA grant would mean a child who may
 * say "pizza or curry?" may not ask it as a poll, which is not a distinction
 * the guardian switch is about: that switch is about pictures and video leaving
 * the device. See `childGuard.ts`.
 *
 * Note what this does NOT relax. `system` stays outside the set, exactly where
 * the pre-existing `!== "text"` put it — extending a text-shaped exemption is
 * not the place to quietly change an unrelated type's posture.
 */
const TEXT_SHAPED_TYPES = new Set(["text", "poll", "checklist", "event"]);

export function permissionsFor(
  type: string,
  hasBlob: boolean,
  mediaSource?: string
) {
  const location = type === "location" || type === "liveLocation";
  // A sticker from one of OUR packs is art the app shipped, as harmless as the
  // emoji it stands for, so it needs no grant beyond writing at all. A KLIPY
  // GIF or sticker, or a personal sticker cut out of somebody's photo, is a
  // picture from outside and falls through to the media gate below.
  if (type === "sticker" && mediaSource === "pack" && !hasBlob) {
    return { location: false, media: false };
  }
  return {
    location,
    // A location message is not media, but a location message with a file
    // attached to it needs both — see above. And an interactive message with a
    // blob somehow attached needs the media grant like anything else would:
    // `hasBlob` leads for the reason it always has, that an attachment is an
    // attachment whatever the message calls itself.
    media: hasBlob || (!location && !TEXT_SHAPED_TYPES.has(type)),
  };
}

/**
 * Everything that must be true before a message may be written into a room,
 * plus the three values that fall out of checking it.
 *
 * Extracted so `send` and `forwardToRoom` cannot disagree about who may write
 * where — the same reasoning as `removeMessageAndFanout` two functions down,
 * and a sharper case, because every check in here is a security check. A
 * forward that grew its own copy of the DM block rule would be a way to reach
 * someone who blocked you.
 *
 * Returns the lazy `roster` rather than a resolved list because `send` needs it
 * again afterwards (view-once recipient counts, mention resolution) and most
 * sends never need it at all.
 *
 * [needs] is only consulted by the child policy: which of the two guarded
 * capabilities this write actually uses. A SET rather than a type string,
 * because the two are independent and a batch can want both — see
 * [permissionsFor] for the argument, and for the two holes the type-string
 * version had.
 */
export async function guardOutgoing(
  ctx: any,
  roomId: any,
  userId: any,
  needs: { media: boolean; location: boolean },
  senderName?: string
) {
  // Membership, the sender and the room, together.
  //
  // These three are mutually independent — no one of them decides whether
  // another is needed — and they used to be three awaits in a row, with the
  // user read happening TWICE (once inside `childPolicyOf`, once for the
  // display name) and the room read after that. Four serial index hits where
  // one round of three does. On a warm backend that is noise; on one whose
  // working set has been paged out it is four disk waits instead of one, and
  // it lands on the ack the sender is watching a clock icon for.
  const [membership, senderUser, room] = await Promise.all([
    ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .first(),
    ctx.db.get(userId),
    ctx.db.get(roomId),
  ]);
  if (!membership) throw new Error("NOT_A_MEMBER");

  // The room's roster, fetched at most once and only if something actually
  // needs it. Three separate branches want it — the DM block check, the armed
  // view-once recipient count, and mention resolution — and before this they
  // each ran their own identical `by_room` collect. Lazy so an ordinary text
  // send into a group room still reads nothing extra.
  let rosterCache: any[] | null = null;
  const roster = async () =>
    (rosterCache ??= await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
      .collect());

  // Child guard. Membership alone isn't enough: a grant can be revoked while
  // the child is still sitting in the room, and the room's members can change
  // after approval. Re-checked on every send so revocation is immediate rather
  // than "until they close the screen".
  const policy = childPolicyOfUser(senderUser);
  if (policy !== null) {
    // Hand over the roster and the room we already hold. Without them this
    // ran its own unbounded `roomMembers` collect and its own `rooms` get —
    // so a child sending into a big room paid for the roster twice.
    if (
      !(await childMayUseRoom(ctx, userId, roomId, {
        members: await roster(),
        room,
      }))
    ) {
      throw new Error(ERR_APPROVAL_REQUIRED);
    }
    // Two independent gates, checked independently. They were an if/else-if
    // over a type string and that was wrong twice: a batch containing a photo
    // AND a location was described by whichever branch came first, so one
    // permission let the other through; and a `location`-typed message carrying
    // a blob took the location branch and skipped the media gate entirely.
    // Both disappear once the caller says what it NEEDS instead of what it is.
    //
    // `?? false` on the location flag rather than `?? true`: a child account
    // created before that flag existed has a stored policy object without it,
    // and the safe reading of a missing answer here is no. See
    // LOCATION_POLICY_FLAG in childGuard.ts for why it is a second switch.
    if (needs.location && !(policy[LOCATION_POLICY_FLAG] ?? false)) {
      throw new Error(ERR_NOT_ALLOWED);
    }
    if (needs.media && !policy.mediaEnabled) {
      throw new Error(ERR_NOT_ALLOWED);
    }
  }

  // Typed `string` up front rather than inferred from the optional argument,
  // so callers destructuring this get a name they can pass straight to the
  // push action without re-proving it is present.
  // Read off the document fetched above rather than fetching it again.
  let resolvedSenderName: string = senderName ?? "";
  if (!resolvedSenderName) {
    resolvedSenderName =
      senderUser?.name ?? senderUser?.username ?? "Unknown";
  }

  // DM block enforcement.
  //
  // Group rooms allow blocks to be one-way (the blocker hides the blockee
  // client-side). For DMs we hard-stop sends in either direction so the block
  // is absolute. The error is intentionally generic — never reveal to the
  // sender that they're the one being blocked.
  if (room?.name?.startsWith("dm:")) {
    const otherMember = await roster();
    const otherId = otherMember.find(
      (m: any) => m.userId.toString() !== userId.toString()
    )?.userId;
    if (otherId) {
      // Both directions at once. Neither answer gates the other — the pair of
      // throws below is what distinguishes them — so serializing these was two
      // index hits of latency for one hit of information.
      const [iBlockedThem, theyBlockedMe] = await Promise.all([
        ctx.db
          .query("blocks")
          .withIndex("by_pair", (q: any) =>
            q.eq("userId", userId).eq("blockedUserId", otherId)
          )
          .first(),
        ctx.db
          .query("blocks")
          .withIndex("by_pair", (q: any) =>
            q.eq("userId", otherId).eq("blockedUserId", userId)
          )
          .first(),
      ]);
      if (iBlockedThem) throw new Error("UNBLOCK_FIRST");
      if (theyBlockedMe) throw new Error("MESSAGE_FAILED");
    }
  }

  // Chamber of Secrets. Derived from the TARGET room, which is what makes
  // forwarding out of an ephemeral room into a permanent one a laundering
  // path — `forwardToRoom` refuses that at the source instead.
  const expiresAt = room?.messageLifetime
    ? Date.now() + room.messageLifetime * 1000
    : undefined;

  return { room, roster, resolvedSenderName, expiresAt };
}

/**
 * The one line a room card shows for its newest message.
 *
 * Also the push body (`notifications.sendMessagePush` is handed this exact
 * string), which is why the text case runs through `maskSpoilers`: a
 * spoiler is a promise that the words stay hidden until touched, and a
 * lock-screen banner or a chat-list row is the one place the reader never
 * touched anything. Masked HERE rather than in `notifications` so the room
 * card, the push and every repair path agree by construction.
 *
 * Shared by `send` and by the preview repair in `removeMessageAndFanout`,
 * which each spelled it out before — and had already drifted: the repair had
 * no armed-photo case, so deleting the newest message re-labelled a view-once
 * photo as a plain `[image]`. The same `removeMessageAndFanout` reasoning
 * applies, one function up.
 *
 * A document is the one attachment whose preview is not a category. `[file]`
 * would make every document on the room list identical, so the name is used
 * where there is one — it is already the thing the sender chose to say.
 */
export function roomPreviewFor(msg: {
  type?: string;
  content?: string;
  fileName?: string;
  viewOnce?: boolean;
  formatting?: FormattingSpan[];
}): string {
  const type = msg.type ?? "text";
  // Masked BEFORE the slice: span offsets index the whole `content`.
  if (type === "text") {
    return maskSpoilers(msg.content ?? "", msg.formatting).slice(0, 100);
  }
  if (msg.viewOnce === true) return "[photo]";
  if (type === "file") {
    const name = (msg.fileName ?? "").slice(0, 100);
    return name.length > 0 ? name : "[file]";
  }
  // Spelled out rather than left to the fallback below, which would render
  // the wire name verbatim and put the literal "[liveLocation]" on a room
  // card. Coordinates are deliberately NOT in the preview: a room list is
  // visible on a lock screen, over a shoulder, and in a screenshot of the
  // chats tab, and none of those are places somebody agreed to be located.
  if (type === "location") return "[location]";
  if (type === "liveLocation") return "[live location]";
  // Spelled out rather than falling through to `[videoNote]`, which is a
  // camelCase identifier leaking onto the chat list where every other preview
  // is a word.
  if (type === "videoNote") return "[video note]";
  // The three interactive kinds preview as their own prompt, which is why
  // `interactions:create` puts the question in `content` at all — see the
  // `messageInteractions` schema header. A room card saying "pizza or curry?"
  // is the useful thing; "[poll]" is the label of a thing.
  //
  // Prefixed rather than bare so a chat list still distinguishes a poll from
  // somebody typing the same words, and prefixed with a WORD rather than an
  // emoji because this string is also read by `notifications` (which adds its
  // own glyph) and by screen readers.
  if (type === "poll" || type === "checklist" || type === "event") {
    const prompt = (msg.content ?? "").slice(0, 100);
    return prompt.length > 0 ? `[${type}] ${prompt}` : `[${type}]`;
  }
  // A GIF says what it is, not its title — "[GIF] Hello" would read as though
  // the sender had typed "Hello". A sticker's `content` is the emoji it stands
  // for, which is exactly what a room card should show beside the word.
  if (type === "gif") return "[GIF]";
  if (type === "sticker") {
    // Only an emoji rides along. A pack sticker's `content` is the emoji it
    // stands for; a KLIPY sticker's is its title ("Whatever Nevermind"),
    // which on a room card would read as typed text — and a 16-character cut
    // of it read as a broken one.
    const alt = (msg.content ?? "").trim();
    const isEmoji = alt.length > 0 && alt.length <= 16 && !/[\p{L}\p{N}]/u.test(alt);
    return isEmoji ? `[sticker] ${alt}` : "[sticker]";
  }
  return `[${type}]`;
}

/**
 * Ends a live share: freezes the last position, stamps `liveEndedAt`, and
 * takes the row out of the sweep index.
 *
 * One function for all three ways a share can end — the sharer stopping it,
 * the scheduled expiry firing, and the repair sweep catching one whose
 * schedule was lost — because the three must produce an identical row. A
 * separately-written stop path that forgot to unset `liveShareLive` would
 * leave the message in the sweep bucket forever, re-examined every six hours
 * and never leaving.
 *
 * Idempotent: a row that is already ended has no `liveShareLive`, so the
 * second caller returns without writing. That matters because the scheduled
 * expiry and the sweep genuinely do race on a share the user stopped a second
 * before its deadline.
 *
 * [endedAt] is the moment the share is *recorded* as having stopped. The
 * scheduler passes the deadline rather than "now" so a job that runs three
 * minutes late doesn't claim the share ran three minutes longer than it did.
 *
 * The coordinates are left alone on purpose. Every fix on this row was already
 * delivered to this room while the share was running, so clearing them
 * discloses nothing and costs the transcript its record of where the person
 * was when it ended — which is exactly what a static share would have left.
 */
async function endLiveShare(ctx: any, msg: any, endedAt: number) {
  if (msg?.liveShareLive !== true) return false;
  await ctx.db.patch(msg._id, {
    liveEndedAt: endedAt,
    liveShareLive: undefined,
  });
  return true;
}

/**
 * Resolve @-mentions for a message body. The client sends ids; everything
 * else is decided here, because the client is not in a position to be trusted
 * about who may be pinged.
 *
 * Extracted so `send` and `editMessage` cannot disagree about who may be
 * named — the same reasoning as `guardOutgoing` above. An edit that resolved
 * mentions under looser rules than the send would be a way to ping people the
 * original message was not allowed to.
 *
 * Five guards, each closing something different:
 *
 *  * The cap is applied BEFORE any `ctx.db.get`, so a hostile client can't
 *    buy an unbounded read set (or an unbounded push fan-out) by sending a
 *    huge array. Truncating silently rather than throwing is deliberate —
 *    the client caps too, and a disagreement must never fail a send the
 *    user has already made.
 *  * De-duplication, because the array answers "who", not "how many".
 *  * The sender's own id is dropped: `unreadForRoom` already skips your own
 *    messages, so a self-mention could only ever be dead weight.
 *  * Membership, which IS the authorization model here — without it any
 *    client could ping any account on the deployment.
 *  * The handle must actually appear in `content`. Otherwise "hi" could
 *    notify twenty people, and the text would disagree with the badge.
 */
async function resolveMentions(
  ctx: any,
  content: string,
  userId: any,
  roster: () => Promise<any[]>,
  room: any,
  mentionedUserIds: any[] | undefined,
  mentionsEveryone: boolean | undefined
): Promise<{
  resolvedMentions: Array<{ userId: any; username: string }> | undefined;
  everyone: boolean;
}> {
  const MAX_MENTIONS = 20;
  let resolvedMentions:
    | Array<{ userId: any; username: string }>
    | undefined;
  if (mentionedUserIds && mentionedUserIds.length > 0) {
    const wanted = [
      ...new Set(mentionedUserIds.slice(0, MAX_MENTIONS).map(String)),
    ].filter((id) => id !== userId.toString());
    if (wanted.length > 0) {
      const memberIds = new Set(
        (await roster()).map((m: any) => m.userId.toString())
      );
      const out: Array<{ userId: any; username: string }> = [];
      for (const id of wanted) {
        if (!memberIds.has(id)) continue;
        const u = await ctx.db.get(id as any);
        const handle = (u as any)?.username;
        if (!handle) continue;
        if (!content.includes(`@${handle}`)) continue;
        out.push({ userId: (u as any)._id, username: handle });
      }
      // Never store an empty array — the field is meant to be sparse.
      if (out.length > 0) resolvedMentions = out;
    }
  }
  // `@everyone` is only meaningful where there is a crowd to address, and a
  // DM already has the other person's full attention.
  const everyone =
    mentionsEveryone === true &&
    !room?.name?.startsWith("dm:") &&
    content.includes("@everyone");
  return { resolvedMentions, everyone };
}

/** The formatting span types a message may carry. A closed set validated
 * server-side: an unrecognized type is dropped rather than stored, so a
 * hostile or future client cannot park arbitrary strings on a row every
 * member subscribes to. Must match `FormattingType` in the Dart model. */
const FORMATTING_TYPES = new Set([
  "bold",
  "italic",
  "strikethrough",
  "underline",
  "spoiler",
  "link",
  "code",
]);

/** Most formatting spans one message may carry. A guarantee about the row's
 * size (the row is re-sent to every member on every reaction change), not an
 * expectation about real use — the composer can't produce anywhere near this
 * many. Truncating silently rather than throwing, for the same reason the
 * mention cap does: the client caps too, and a disagreement must never fail
 * a send the user has already made. */
const MAX_FORMATTING_ENTITIES = 50;

/** One stored formatting span — the `messages.formatting` element shape. */
export type FormattingSpan = {
  start: number;
  end: number;
  type: string;
  url?: string;
};

/**
 * What stands in for spoiler text anywhere the reader has not touched it —
 * the push body, the room card, a reply quote.
 *
 * A fixed run rather than one block per character: the length of a spoiler
 * is part of what it hides ("▒▒▒" next to a question about a name is an
 * answer). Five is wide enough to read as a redaction at a glance, and the
 * glyph is the same one Telegram's chat list uses, so nobody has to learn it.
 * Not a word like "Spoiler": every other placeholder this string sits beside
 * is language-neutral because the backend has no locale to speak in.
 */
export const SPOILER_MASK = "▒▒▒▒▒";

/**
 * `content` with every spoiler span replaced by [SPOILER_MASK].
 *
 * Overlapping and touching spoiler spans collapse into one mask — the
 * composer can produce them (toggle, retype, toggle) and two masks side by
 * side would describe a boundary the sender never drew. Offsets are the
 * stored UTF-16 code units, which is exactly what `slice` takes, so this is
 * safe to run on the raw row; anything malformed is clamped rather than
 * thrown on, because a preview must never fail a send.
 */
export function maskSpoilers(
  content: string,
  formatting?: FormattingSpan[] | null
): string {
  if (!formatting || formatting.length === 0) return content;
  const spans = formatting
    .filter((f) => f.type === "spoiler")
    .map((f) => ({
      start: Math.max(0, Math.min(content.length, Math.floor(f.start))),
      end: Math.max(0, Math.min(content.length, Math.floor(f.end))),
    }))
    .filter((f) => f.start < f.end)
    .sort((a, b) => a.start - b.start);
  if (spans.length === 0) return content;
  let out = "";
  let cursor = 0;
  let open: { start: number; end: number } | null = null;
  const flush = () => {
    if (!open) return;
    out += content.slice(cursor, open.start) + SPOILER_MASK;
    cursor = open.end;
    open = null;
  };
  for (const s of spans) {
    if (open && s.start <= open.end) {
      open.end = Math.max(open.end, s.end);
      continue;
    }
    flush();
    open = { start: s.start, end: s.end };
  }
  flush();
  return out + content.slice(cursor);
}

/**
 * Validate client-supplied formatting spans against the content they claim
 * to describe. Returns `undefined` when nothing survives — the field is
 * sparse, never `[]`.
 *
 * Every span must lie inside the string (`0 <= start < end <= length`,
 * integers only — a fractional or out-of-range offset would make clients
 * substring past the end of the text) and a link span must carry a URL the
 * same `LINK_PATTERN` the linkifier trusts would accept. Overlaps are NOT
 * rejected: bold-inside-italic is legitimate nesting and the renderer folds
 * styles per character range.
 */
function sanitizeFormatting(
  content: string,
  raw?: Array<{ start: number; end: number; type: string; url?: string }>
): Array<{ start: number; end: number; type: string; url?: string }> | undefined {
  if (!raw || raw.length === 0) return undefined;
  const out = raw
    .filter((f) => FORMATTING_TYPES.has(f.type))
    .filter(
      (f) =>
        Number.isInteger(f.start) &&
        Number.isInteger(f.end) &&
        f.start >= 0 &&
        f.start < f.end &&
        f.end <= content.length
    )
    .filter(
      (f) =>
        f.type !== "link" ||
        (typeof f.url === "string" && LINK_PATTERN.test(f.url))
    )
    .slice(0, MAX_FORMATTING_ENTITIES)
    .map((f) => ({
      start: f.start,
      end: f.end,
      type: f.type,
      ...(f.type === "link" ? { url: f.url } : {}),
    }));
  return out.length > 0 ? out : undefined;
}

/** The wire shape of one formatting span, shared by `send` and `editMessage`
 * so the two cannot drift. */
const formattingArg = v.optional(
  v.array(
    v.object({
      start: v.number(),
      end: v.number(),
      type: v.string(),
      url: v.optional(v.string()),
    })
  )
);

/**
 * Everything `messages:send` does, as a plain function.
 *
 * Split out so `scheduledMessages:release` can post a staged message through
 * the exact same path a hand-typed one takes — the membership and child-guard
 * checks, the reply-preview snapshot, mention resolution, the Chamber-of-
 * Secrets `expiresAt` schedule, the `rooms.lastMessage` patch and the push.
 *
 * A shared core rather than a second implementation, following the precedent
 * this file already sets three times over: `guardOutgoing` (shared with
 * `forwardToRoom`), `roomPreviewFor` (see its header — it exists precisely
 * because two copies of the preview logic had already drifted) and
 * `endLiveShare`. A scheduled send that re-derived any of this would be a
 * second place for the child guard to be forgotten, which is the one kind of
 * drift this file cannot afford.
 *
 * `ctx` is a mutation context in both cases, so nothing here changes: the
 * insert, the three `scheduler` calls and the room patch all run in the same
 * transaction as the caller.
 */
export const send = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    type: v.optional(v.string()),          // "text" | "image" | "video" | "videoNote" | "audio" | "url" | "system"
    mediaStorageId: v.optional(v.id("_storage")),
    // Pixel size of the attachment, so a receiver can lay the bubble out at the
    // picture's real ratio before decoding it. See the schema comment.
    mediaWidth: v.optional(v.number()),
    mediaHeight: v.optional(v.number()),
    // Documents. Convex storage keeps no name, type or extension for a blob,
    // so these are the only record of what the attachment actually is. See the
    // schema comment.
    fileName: v.optional(v.string()),
    fileSize: v.optional(v.number()),
    mimeType: v.optional(v.string()),
    // Playing time of an audio or video attachment, when the sender measured
    // it, so a shared-content row can show a duration without decoding.
    mediaDurationMs: v.optional(v.number()),
    // A poster frame for a video, uploaded as a second blob. Refused on an
    // armed send — see the schema comment.
    posterStorageId: v.optional(v.id("_storage")),
    senderName: v.optional(v.string()),
    replyToId: v.optional(v.id("messages")),
    // Burn-after-reading. Armed by the sender in the pre-send editor; see the
    // schema comment on `messages.viewOnce`.
    viewOnce: v.optional(v.boolean()),
    // Idempotency key. Optional so older clients keep working — they just get
    // the old at-least-once behaviour. See the schema comment on
    // `messages.clientId`.
    clientId: v.optional(v.string()),
    // @-mentions. The client says WHO it meant; this mutation decides what they
    // are called and whether they may be named at all. See `resolveMentions`.
    mentionedUserIds: v.optional(v.array(v.id("users"))),
    mentionsEveryone: v.optional(v.boolean()),
    // Location, on `type: "location"` and `type: "liveLocation"`. Range-checked
    // below rather than trusted: a NaN or a longitude of 4000 would render as a
    // bubble pointing at nowhere that nobody could delete except its sender.
    latitude: v.optional(v.number()),
    longitude: v.optional(v.number()),
    locationAccuracyM: v.optional(v.number()),
    // How long a live share should run for, in milliseconds. Only consulted on
    // `type: "liveLocation"`, and only accepted if it is one of
    // `LIVE_SHARE_DURATIONS_MS` — see the note there on why this is a closed
    // set validated here and not just a client-side picker.
    liveDurationMs: v.optional(v.number()),
    // Rich-text spans over `content`. Validated by `sanitizeFormatting` —
    // the client says where the runs are, this mutation decides whether they
    // fit the text at all.
    formatting: formattingArg,
    // GIFs and stickers, on `type: "gif"` and `type: "sticker"`. The caller
    // names the picture; `expressionFieldsFor` decides what is written. See
    // the schema comment on `messages.mediaSource`.
    mediaSource: v.optional(v.string()),
    mediaUrl: v.optional(v.string()),
    mediaPreviewUrl: v.optional(v.string()),
    mediaRef: v.optional(v.string()),
    stickerId: v.optional(v.id("stickers")),
  },
  handler: async (ctx, args) => await sendCore(ctx, args),
});

/**
 * Everything `send` does, as a plain function.
 *
 * Split out so `scheduledMessages:release` can post a staged message down the
 * exact path a hand-typed one takes: the membership and child-guard checks,
 * the DM-block check, the reply-preview snapshot, mention resolution and
 * formatting sanitation, the Chamber-of-Secrets `expiresAt` schedule, the
 * `rooms.lastMessage` patch and the push fan-out.
 *
 * A shared core rather than a second implementation, following the precedent
 * this file already sets three times: `guardOutgoing` (shared with
 * `forwardToRoom`), `roomPreviewFor` — read its header, it exists precisely
 * because two copies of the preview logic had already drifted — and
 * `endLiveShare`. A scheduled send that re-derived any of this would be a
 * second place for the child guard to be forgotten, and the guard is the one
 * thing in here that must never be forgotten twice.
 *
 * `ctx` is a mutation context either way, so nothing about the body changes:
 * the insert, the `scheduler` calls and the room patch all commit in the same
 * transaction as whoever called this.
 */
export async function sendCore(ctx: any, { roomId, userId, content, type, mediaStorageId, mediaWidth, mediaHeight, fileName, fileSize, mimeType, mediaDurationMs, posterStorageId, senderName, replyToId, viewOnce, clientId, mentionedUserIds, mentionsEveryone, latitude, longitude, locationAccuracyM, liveDurationMs, formatting, mediaSource, mediaUrl, mediaPreviewUrl, mediaRef, stickerId }: any) {
  // Idempotency, checked before anything else has a chance to happen twice.
  //
  // Everything below this line has side effects that must not be repeated:
  // a second row, a second `rooms.lastMessage` bump, a second push, a second
  // pair of view-once burn schedules. Returning the original id makes a retry
  // indistinguishable from the send having succeeded the first time, which is
  // exactly what the caller believes when it retries.
  if (clientId !== undefined) {
    const existing = await ctx.db
      .query("messages")
      .withIndex("by_room_user_client", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId).eq("clientId", clientId)
      )
      .first();
    if (existing) return existing._id;
  }

  // `let`, because the location block below downgrades a malformed
  // `location`/`liveLocation` send rather than refusing it. Everything that
  // reads this after that point — the insert, the gallery bucket, the room
  // preview, the push body — must see the type actually written.
  let msgType = type ?? "text";

  // GIFs and stickers, resolved BEFORE the guard because what they resolve to
  // is part of what the guard checks — an official pack sticker needs no media
  // grant, a KLIPY GIF does. A GIF or sticker never carries an uploaded blob
  // of its own, so `mediaStorageId` is dropped outright rather than trusted;
  // that also keeps these rows out of the gallery and away from every
  // view-once path below. One that does not resolve goes out as text.
  let expressionFields: Record<string, any> = {};
  if (msgType === "gif" || msgType === "sticker") {
    const resolved = await expressionFieldsFor(ctx, msgType, {
      mediaSource,
      mediaUrl,
      mediaPreviewUrl,
      mediaRef,
      stickerId,
      mediaWidth,
      mediaHeight,
    });
    mediaStorageId = undefined;
    posterStorageId = undefined;
    if (resolved) {
      const { alt, ...fields } = resolved;
      expressionFields = fields;
      mediaWidth = resolved.mediaWidth;
      mediaHeight = resolved.mediaHeight;
      // `content` is the alt text: the GIF's title, or the emoji a sticker
      // stands for. It is also what an app too old to know these types shows
      // instead, so it is never left empty.
      content = (content ?? "").trim().slice(0, 200);
      if (content.length === 0) {
        content = alt ?? (msgType === "gif" ? "GIF" : "🙂");
      }
      formatting = undefined;
    } else {
      msgType = "text";
    }
  }

  // Membership, the child guard, DM blocks, the sender's display name and the
  // room's message lifetime — all of it, in the order it has always run. See
  // `guardOutgoing`, which `forwardToRoom` shares so the two cannot disagree
  // about who may write where.
  const { room, roster, resolvedSenderName, expiresAt } = await guardOutgoing(
    ctx,
    roomId,
    userId,
    // `mediaStorageId !== undefined` and not the type: a blob attached to a
    // `location`-typed send is still an attachment, and used to skip the media
    // gate by taking the location branch. See `permissionsFor`.
    permissionsFor(
      msgType,
      mediaStorageId !== undefined,
      expressionFields.mediaSource
    ),
    senderName
  );

  // Build a denormalized snapshot of the parent at send time. Survives the
  // parent's later deletion so the inline reply tether keeps rendering. We
  // intentionally drop both replyToId AND replyToPreview together if the
  // parent isn't reachable from the same room — never store a dangling id.
  let replyToPreview: {
    senderId: any;
    senderName: string;
    contentPreview: string;
    type: string;
    mediaStorageId?: any;
    mediaUrl?: string;
    stickerStorageId?: any;
    stickerFormat?: string;
  } | undefined;
  let resolvedReplyToId: any | undefined;
  // Thread root, derived from the *resolved* parent. Computing it from the
  // raw `replyToId` arg would let a cross-room parent produce a message
  // that belongs to a thread but has no tether — it'd render in the thread
  // with nothing above it. Written only alongside replyToId/replyToPreview.
  let resolvedRootId: any | undefined;
  if (replyToId) {
    const parent = await ctx.db.get(replyToId);
    if (parent && parent.roomId.toString() === roomId.toString()) {
      const parentContent = parent.content ?? "";
      // Quoting a view-once photo must not re-publish it. The preview is a
      // permanent, un-burnable copy of the parent, so carrying the parent's
      // `mediaStorageId` here would hand every reader the storage id the
      // read path works so hard to withhold — and would keep the blob
      // looking referenced to `files.gcOrphanedFiles` after the burn.
      // Sentinel mirrors the "__DELETED__" one used by the fanout below.
      const parentIsViewOnce = parent.viewOnce === true;
      replyToPreview = {
        senderId: parent.userId,
        senderName: parent.senderName ?? "unknown",
        // Spoilers masked: the quote is a permanent copy shown above the
        // reply, untouched and un-revealable, so the hidden words would
        // otherwise sit in the open on every reply to them.
        contentPreview: parentIsViewOnce
          ? "__VIEW_ONCE__"
          : maskSpoilers(parentContent, parent.formatting).slice(0, 140),
        type: parent.type ?? "text",
        mediaStorageId: parentIsViewOnce ? undefined : parent.mediaStorageId,
        // A quoted GIF or sticker has no `mediaStorageId`, so it brings its own
        // thumbnail: KLIPY's small rendition, or the pack sticker itself.
        mediaUrl: parent.mediaPreviewUrl ?? parent.mediaUrl,
        stickerStorageId: parent.stickerStorageId,
        stickerFormat: parent.stickerFormat,
      };
      resolvedReplyToId = replyToId;
      resolvedRootId = parent.rootId ?? parent._id;
    }
  }

  // View-once bookkeeping, done once here rather than once per open. The
  // roster walk is O(members), but only on an armed send.
  const armed = viewOnce === true && mediaStorageId !== undefined;
  let viewOnceFields: Record<string, any> = {};
  if (armed) {
    const recipients = (await roster()).filter(
      (m: any) => m.userId.toString() !== userId.toString()
    ).length;
    viewOnceFields = {
      viewOnce: true,
      viewOnceLive: true,
      viewOnceRecipients: recipients,
      viewOnceViewCount: 0,
      viewOnceDeadline: Date.now() + VIEW_ONCE_DEADLINE_MS,
    };
  }

  // ── Location ────────────────────────────────────────────────────────────
  //
  // Validated here rather than believed, for two different reasons that both
  // end in the same code. A malformed pair (NaN, a longitude of 4000, a
  // latitude the client computed from an uninitialised variable) produces a
  // bubble that points at nowhere and cannot be repaired, only deleted. And
  // an out-of-set `liveDurationMs` is the whole safety property of the
  // feature: `liveExpiresAt` is what makes a share stop, so a client able to
  // name its own deadline is a client able to share its position forever.
  //
  // A location-typed message whose coordinates don't survive this is
  // downgraded to `text` rather than refused. Refusing would strand a
  // retry-forever bubble in the sender's pending list for a message no retry
  // can fix — the same reasoning as the child-gate branch in
  // `ChatRepository._postMessage`.
  const wantsLocation = msgType === "location" || msgType === "liveLocation";
  const validCoords =
    wantsLocation &&
    typeof latitude === "number" &&
    typeof longitude === "number" &&
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
  if (wantsLocation && !validCoords) msgType = "text";

  let locationFields: Record<string, any> = {};
  if (validCoords) {
    locationFields = {
      latitude,
      longitude,
      // Dropped rather than clamped when it is nonsense. The bubble draws no
      // ring when this is absent, which is the honest rendering of "the
      // device did not say how sure it was".
      locationAccuracyM:
        typeof locationAccuracyM === "number" &&
        Number.isFinite(locationAccuracyM) &&
        locationAccuracyM > 0
          ? Math.min(locationAccuracyM, 100_000)
          : undefined,
    };
  }

  // Live shares: the deadline, and the flag that puts the row in the sweep's
  // bucket. A `liveLocation` send whose duration is refused becomes an
  // ordinary static `location` — the position the sender chose to share is
  // still shared, it simply does not move. Silently downgrading beats
  // throwing for the reason above, and beats accepting an unbounded share by
  // a much wider margin.
  let liveFields: Record<string, any> = {};
  if (msgType === "liveLocation") {
    if (
      typeof liveDurationMs === "number" &&
      LIVE_SHARE_DURATIONS_MS.includes(liveDurationMs) &&
      // Refused in a Chamber of Secrets room, where `expiresAt` is set. Two
      // self-destruct clocks on one row is a promise the app cannot keep: a
      // 60-second room lifetime deletes an 8-hour share after a minute, and
      // the sharer is told nothing — their publisher simply starts getting
      // "gone" back. Downgraded to a static pin, which the room's own
      // lifetime then governs, exactly as it governs every other message
      // there. The client hides the live options in such a room, so reaching
      // this is a stale screen rather than the normal path.
      expiresAt === undefined
    ) {
      liveFields = {
        liveExpiresAt: Date.now() + liveDurationMs,
        liveUpdatedAt: Date.now(),
        liveShareLive: true,
      };
    } else {
      msgType = "location";
    }
  }

  // Resolve @-mentions — see `resolveMentions` for the five guards and why
  // it is shared with `editMessage`.
  const { resolvedMentions, everyone } = await resolveMentions(
    ctx,
    content,
    userId,
    roster,
    room,
    mentionedUserIds,
    mentionsEveryone
  );

  // Formatting spans, clamped to the text they describe. Dropped entirely
  // on an armed send for the reason the caption's `hasLink` is below: a
  // sealed photo's caption is content the row must not describe before it
  // is opened, and span offsets are a partial description (they say where
  // the interesting parts are).
  const fmt = armed ? undefined : sanitizeFormatting(content, formatting);

  const messageId = await ctx.db.insert("messages", {
    roomId,
    userId,
    content,
    createdAt: Date.now(),
    type: msgType,
    mediaStorageId,
    // Deliberately dropped on an armed send. The sealed tile is a fixed size,
    // so the picture's true aspect ratio buys the receiver nothing and is one
    // more thing leaking out of a message whose whole point is to leak
    // nothing until it's opened.
    mediaWidth: armed ? undefined : mediaWidth,
    mediaHeight: armed ? undefined : mediaHeight,
    // Dropped on an armed send for the same reason, and for one more: a
    // filename is content. No UI can arm a document today, so this is
    // defence in depth rather than a live case — but it is the sort of
    // thing that stops being true quietly.
    fileName: armed ? undefined : fileName,
    fileSize: armed ? undefined : fileSize,
    mimeType: armed ? undefined : mimeType,
    mediaDurationMs: armed ? undefined : mediaDurationMs,
    // THE guard, not a redundancy. `sanitizeViewOnce` lists this field too,
    // but that is a hardcoded list on the read path; the poster must never
    // reach storage in the first place, because `files:getFileUrl` refuses a
    // view-once blob via `by_media` — an index that cannot see this id.
    posterStorageId: armed ? undefined : posterStorageId,
    // Which shared-content tab this belongs in, or nothing. Passing
    // `mediaStorageId !== undefined` rather than `msgType` alone is what
    // keeps a failed upload out of the grid — see `galleryBucketFor`.
    galleryBucket: galleryBucketFor(
      msgType,
      mediaStorageId !== undefined,
      armed
    ),
    // Left absent rather than written `false`, so the LINKS index holds only
    // rows that belong in it. Armed messages are excluded for the same
    // reason they get no bucket: a sealed photo's caption is not shared
    // content anybody may browse. A `formatting` link entity counts too —
    // "check this out" carrying a URL belongs in the LINKS tab exactly as
    // much as the bare URL would have.
    ...(!armed &&
    (LINK_PATTERN.test(content) || (fmt?.some((f) => f.type === "link") ?? false))
      ? { hasLink: true }
      : {}),
    ...(fmt ? { formatting: fmt } : {}),
    senderName: resolvedSenderName,
    expiresAt,
    // Stored so the retry that arrives after this one commits can find it.
    clientId,
    ...expressionFields,
    ...viewOnceFields,
    ...locationFields,
    ...liveFields,
    ...(replyToPreview
      ? { replyToId: resolvedReplyToId, replyToPreview, rootId: resolvedRootId }
      : {}),
    ...(resolvedMentions ? { mentions: resolvedMentions } : {}),
    ...(everyone ? { mentionsEveryone: true } : {}),
  });

  // Schedule server-side deletion for self-destructing messages
  if (expiresAt !== undefined) {
    await ctx.scheduler.runAt(
      new Date(expiresAt),
      internal.messages.expireMessage,
      { messageId }
    );
  }

  // Hard deadline for an armed photo nobody ever opens. The per-message
  // schedule is the primary mechanism — `gcExpiredViewOnce` is only a repair
  // sweep for anything the scheduler dropped.
  if (armed) {
    await ctx.scheduler.runAfter(
      VIEW_ONCE_DEADLINE_MS,
      internal.messages.burnViewOnce,
      { messageId }
    );
    // A room with exactly one member has no recipients at all, so the
    // "everyone has seen it" condition is already true on arrival. Without
    // this the blob would idle for the full deadline.
    if ((viewOnceFields.viewOnceRecipients ?? 0) === 0) {
      await ctx.scheduler.runAfter(
        VIEW_ONCE_BURN_GRACE_MS,
        internal.messages.burnViewOnce,
        { messageId }
      );
    }
  }

  // The share's own deadline. THE mechanism, not a backstop: nothing else
  // stops a live share, because the client that started it may be force-quit,
  // out of battery, or in a tunnel when its time is up. `gcExpiredLiveShares`
  // exists only for the case where this schedule is lost.
  if (liveFields.liveExpiresAt !== undefined) {
    await ctx.scheduler.runAt(
      new Date(liveFields.liveExpiresAt),
      internal.messages.expireLiveLocation,
      { messageId }
    );

    // Starting a share supersedes the sender's previous one in this room.
    // Two live bubbles in one transcript is a UI nobody can read — which of
    // them is you? — and only one of them can be fed anyway, because the
    // client runs a single publisher. Ending the old one here rather than
    // client-side means it also happens when the new share is started from a
    // second device.
    //
    // Bounded by `.take()` and scoped to the currently-live bucket, which is
    // the whole deployment's concurrent shares rather than this room's
    // history — a set measured in tens, not in messages. The cap is a
    // guarantee about the read set, not an expectation about the data: if it
    // is ever hit, the extra share still expires on its own schedule.
    const otherLive = await ctx.db
      .query("messages")
      .withIndex("by_liveLocation_live_expiry", (q: any) =>
        q.eq("liveShareLive", true)
      )
      .take(LIVE_SHARE_SUPERSEDE_SCAN_LIMIT);
    for (const other of otherLive) {
      if (other._id === messageId) continue;
      if (other.roomId.toString() !== roomId.toString()) continue;
      if (other.userId.toString() !== userId.toString()) continue;
      await endLiveShare(ctx, other, Date.now());
    }
  }

  // Update room's last message preview
  // `fmt`, not the raw arg: a spoiler span the sanitizer refused is not on
  // the row, so it must not mask the preview either.
  const preview = roomPreviewFor({
    type: msgType,
    content,
    fileName,
    viewOnce: armed,
    formatting: fmt,
  });
  await ctx.db.patch(roomId, {
    lastMessage: preview,
    lastMessageTime: Date.now(),
  });

  // Fire push notifications in background (non-blocking)
  await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
    roomId,
    messageId,
    senderId: userId,
    senderName: resolvedSenderName,
    content: preview,
    type: msgType,
    // Post-validation, so nobody gets a "mentioned you" banner for a mention
    // that was rejected above and isn't on the stored row.
    mentionedUserIds: resolvedMentions?.map((m) => m.userId),
    mentionsEveryone: everyone ? true : undefined,
  });

  return messageId;
}

// ── Live location ───────────────────────────────────────────────────────────
//
// Three mutations and a sweep, and the split between them is the whole design:
//
//   updateLiveLocation  the sharer's device, every ~10-90 s while it moves
//   stopLiveLocation    the sharer, explicitly, at any time
//   expireLiveLocation  the scheduler, at the deadline — THE authority
//   gcExpiredLiveShares a six-hourly repair pass for lost schedules
//
// No mutation anywhere can extend a share. Ending one early is a user action;
// ending one on time is not. That asymmetry is deliberate: a "keep sharing"
// call would turn a time-boxed disclosure into an indefinite one held open by
// whatever software happened to keep calling it, which is precisely the shape
// this feature exists to avoid. Sharing for longer means starting a new share,
// which is a new message the recipients can see arrive.

/**
 * Moves a running live share to a new position.
 *
 * Sender-only, and checked against the row rather than against room
 * membership: a room member who could write coordinates onto somebody else's
 * share would be able to say where that person is, in their name, to everyone
 * watching. There is no legitimate case for it, so there is no branch for it.
 *
 * Returns `{ ok }` rather than throwing on a share that has ended. This is
 * called by a background timer against a deadline the server owns, so "the
 * share you are feeding is over" is an ordinary, expected outcome — the client
 * reads a false and shuts its publisher down. Throwing would put an error in
 * the log for the system working correctly.
 *
 * ## It re-runs `guardOutgoing`, and that is the point
 *
 * This is a write into a room, hours after the write that created it, and the
 * `send` path's comment about the child guard applies with far more force here:
 * "a grant can be revoked while the child is still sitting in the room". A
 * version that checked only the sender's id would mean that for up to eight
 * hours after a share starts:
 *
 *  * a guardian switching location sharing off does not stop it — the one
 *    revocation this feature most needs to honour;
 *  * leaving or being removed from the room does not stop it, so a position
 *    keeps arriving in a room the sharer is no longer in;
 *  * a DM block does not stop it.
 *
 * So the same guard runs on every update, and a refusal ENDS the share rather
 * than merely declining the write. Ending it is what makes the bubble read as
 * finished for everybody, instead of silently going stale while the row still
 * claims to be live.
 *
 * The cost is the guard's handful of indexed reads per update — bounded by
 * `LIVE_UPDATE_MIN_INTERVAL_MS` — which is the price of the checks meaning
 * anything at all after the first second.
 */
export const updateLiveLocation = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    latitude: v.number(),
    longitude: v.number(),
    locationAccuracyM: v.optional(v.number()),
  },
  handler: async (
    ctx,
    { messageId, userId, latitude, longitude, locationAccuracyM }
  ) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return { ok: false, reason: "gone" as const };
    if (msg.userId.toString() !== userId.toString()) {
      return { ok: false, reason: "not_yours" as const };
    }
    if (msg.liveShareLive !== true) {
      return { ok: false, reason: "ended" as const };
    }

    const now = Date.now();

    // The deadline is enforced on read as well as by the scheduler. A job that
    // has not fired yet — the box was busy, the deployment restarted — must not
    // be a window in which the share keeps accepting positions past its time.
    // Ending it here rather than merely refusing the write means the very first
    // late update also cleans the row up.
    if (typeof msg.liveExpiresAt === "number" && msg.liveExpiresAt <= now) {
      await endLiveShare(ctx, msg, msg.liveExpiresAt);
      return { ok: false, reason: "ended" as const };
    }

    // Rate limit. See LIVE_UPDATE_MIN_INTERVAL_MS — the client throttles well
    // below this, so a caller tripping it is a caller that is malfunctioning.
    // Reported as success: the share is fine, this particular fix was simply
    // not worth a write, and telling the publisher otherwise would make it
    // retry and trip it again.
    if (
      typeof msg.liveUpdatedAt === "number" &&
      now - msg.liveUpdatedAt < LIVE_UPDATE_MIN_INTERVAL_MS
    ) {
      return { ok: true, throttled: true };
    }

    // May this person still write into this room, right now? See the header —
    // membership, the child policy and the DM block can all change during a
    // share, and none of them is honoured by a check that ran hours ago.
    //
    // `senderName` is passed so the guard skips its `users` read: this row
    // already carries the name that was resolved at send time, and a live share
    // is not the place to discover a rename.
    try {
      await guardOutgoing(
        ctx,
        msg.roomId,
        userId,
        { media: false, location: true },
        msg.senderName ?? "unknown"
      );
    } catch (_) {
      // Ended, not merely refused. A share whose permission has gone must stop
      // being a live share on everyone's screen, not sit there going quietly
      // stale while the row still says it is running.
      await endLiveShare(ctx, msg, now);
      return { ok: false, reason: "revoked" as const };
    }

    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      return { ok: false, reason: "bad_position" as const };
    }

    await ctx.db.patch(messageId, {
      latitude,
      longitude,
      locationAccuracyM:
        typeof locationAccuracyM === "number" &&
        Number.isFinite(locationAccuracyM) &&
        locationAccuracyM > 0
          ? Math.min(locationAccuracyM, 100_000)
          : undefined,
      liveUpdatedAt: now,
    });

    // Deliberately no `rooms.lastMessage` bump and no push. A live share moving
    // is not a new message: re-sorting the chat list to the top every ninety
    // seconds for eight hours would make one share look like a conversation,
    // and a banner per fix would be unusable. The transcript updates because
    // `messages:list` is subscribed to this row, which is the entire reason the
    // position lives on the message instead of in a side table.
    return { ok: true, throttled: false };
  },
});

/**
 * Ends a live share early, at the sharer's request.
 *
 * Sender-only for the same reason `updateLiveLocation` is, mirrored: a room
 * member who could stop somebody else's share could silently cut off a person
 * who is relying on being followed home.
 */
export const stopLiveLocation = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return { ok: false, reason: "gone" as const };
    // Returned, not thrown, matching `updateLiveLocation` beside it. Both are
    // the same question — "is this yours?" — and answering it two different
    // ways means every reader has to check which is which. A caller that
    // genuinely cannot stop somebody else's share does not need a stack trace.
    if (msg.userId.toString() !== userId.toString()) {
      return { ok: false, reason: "not_yours" as const };
    }
    // Not an error. The share may have hit its deadline in the second between
    // the user seeing the button and pressing it, and "it already stopped" is
    // the outcome they asked for.
    await endLiveShare(ctx, msg, Date.now());
    return { ok: true };
  },
});

/**
 * The scheduled end of a live share. Registered by `send` at the moment the
 * share is created, which is what makes the deadline hold when the sharer's
 * device does not: force-quit, out of battery, in a tunnel, or simply
 * uninstalled.
 *
 * Stamps `liveEndedAt` with the deadline rather than with `Date.now()`, so a
 * job that runs late does not record the share as having run longer than it
 * was allowed to.
 */
export const expireLiveLocation = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const msg = await ctx.db.get(messageId);
    // Already deleted, already stopped, or superseded. All three are ordinary.
    if (!msg) return;
    await endLiveShare(ctx, msg, msg.liveExpiresAt ?? Date.now());
  },
});

/**
 * Repair sweep for shares whose per-message schedule was lost.
 *
 * A backstop, exactly like `gcExpiredViewOnce` — and the one whose absence
 * would matter most, because the failure it repairs is "a position keeps being
 * broadcast after the person said stop". Runs six-hourly rather than by the
 * minute for the cost reason crons.ts:6-13 gives; the per-message `runAt` is
 * what makes that acceptable, since anything this sweep finds is already a
 * scheduler failure rather than the normal path.
 *
 * Scans `by_liveLocation_live_expiry` as `eq(true).lt(now)`, so it reads only
 * shares that are both running and overdue — see the index comment for why
 * ranging on the deadline alone would walk the whole table.
 */
export const gcExpiredLiveShares = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    // Ranged on the flag alone, then filtered in JS, rather than
    // `.lt("liveExpiresAt", now)` in the index. The narrower scan looks better
    // and has a hole: Convex sorts `undefined` ahead of every number, so a row
    // that somehow acquired `liveShareLive: true` WITHOUT a deadline is
    // excluded by the `lt` — invisible to the one sweep whose whole job is
    // catching rows that got away, while sitting permanently at the head of the
    // bucket. `send` writes all three live fields together so it should not
    // happen; this is the backstop, and a backstop with a blind spot is not
    // one. The bucket only ever holds shares that are currently running, so the
    // wider scan is the same order of magnitude either way.
    const live = await ctx.db
      .query("messages")
      .withIndex("by_liveLocation_live_expiry", (q) =>
        q.eq("liveShareLive", true)
      )
      .take(LIVE_SHARE_SUPERSEDE_SCAN_LIMIT);
    let ended = 0;
    for (const msg of live) {
      // A missing deadline reads as overdue. It cannot be honoured, and a live
      // share with no end is the one state this feature must never have.
      const deadline = msg.liveExpiresAt ?? 0;
      if (deadline > now) continue;
      if (await endLiveShare(ctx, msg, msg.liveExpiresAt ?? now)) ended++;
    }
    return { scanned: live.length, ended };
  },
});

/**
 * Everything that has to happen when a message stops existing, whether the
 * user deleted it or it self-destructed. Both paths ran verbatim copies of
 * this before; they had already drifted (neither repaired the room preview).
 *
 * Ordering matters: this must run BEFORE `ctx.db.delete(messageId)`, because
 * it reads the message's siblings to re-derive the room preview.
 */
async function removeMessageAndFanout(ctx: any, msg: any, messageId: any) {
  // Reactions.
  const reactions = await ctx.db
    .query("reactions")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const r of reactions) await ctx.db.delete(r._id);

  // Pins. Room state, but it points at this message — a pin outliving its
  // message is a banner entry that can be neither opened nor cleared. Being
  // here rather than in `deleteMessage` is what makes a pinned message in a
  // Chamber of Secrets room clean itself up when it self-destructs.
  const pins = await ctx.db
    .query("pinnedMessages")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const p of pins) await ctx.db.delete(p._id);

  // Bookmarks. Personal rather than room state, but with the same defect if
  // left behind: `bookmarks:listForRoom` would drop the dangling row on read
  // and the reader would be left with a saved message that silently isn't
  // there, and no way to clear it — `bookmarks:unsave` can't find a row for a
  // message it can no longer load. Here rather than in `deleteMessage` for the
  // reason the pins above are: this is also the path a Chamber of Secrets
  // message takes when it self-destructs, and a saved message expiring out from
  // under its reader is the ordinary case, not the exotic one.
  const bookmarks = await ctx.db
    .query("messageBookmarks")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const b of bookmarks) await ctx.db.delete(b._id);

  // Media, and the video poster that rides with it. Via `releaseMessageBlobs`
  // rather than a bare `deleteStored` because forwarding re-references a file
  // instead of copying it, so this message may not be the last one pointing at
  // its bytes. That helper is also what tolerates a file some other path
  // already removed — a throw here would abort the fanout below half-done,
  // leaving children tethered to a deleted parent.
  //
  // Not used on the two view-once burn paths: an armed message can be neither
  // forwarded nor given a poster, so there is nothing there to share.
  await releaseMessageBlobs(ctx, msg);

  // View-once ledger. Also runs for messages that were never armed, where the
  // scan is a single empty index range.
  await purgeViewOnceViews(ctx, messageId);

  // The poll/checklist/event body and every answer to it. Here rather than in
  // `deleteMessage` for the reason the pins and bookmarks above are: this is
  // also the path a Chamber of Secrets message takes when it self-destructs,
  // and a poll outliving the message that posed the question would be a row
  // nothing renders and nothing can reach. Unconditional, like the line above
  // it — only three message types find anything.
  await purgeInteraction(ctx, messageId);

  // Mark every child reply's denormalized preview as deleted so their inline
  // tether keeps rendering ("message removed") instead of pointing at a
  // vanished parent.
  const children = await ctx.db
    .query("messages")
    .withIndex("by_replyTo", (q: any) => q.eq("replyToId", messageId))
    .collect();
  for (const child of children) {
    const existing = child.replyToPreview;
    if (!existing) continue;
    // Drop the copied `mediaStorageId` too. It's a snapshot of the parent's id
    // (see `send`), and the file it named was just deleted — leaving it set
    // points the preview at a blob that no longer exists, and makes the file
    // look referenced to `files.gcOrphanedFiles`.
    const { mediaStorageId: _stale, ...rest } = existing;
    await ctx.db.patch(child._id, {
      replyToPreview: { ...rest, contentPreview: "__DELETED__" },
    });
  }

  await ctx.db.delete(messageId);

  // Repair the room's last-message preview. Only when the removed message was
  // actually the newest — a mid-history delete would otherwise re-write the
  // room doc and needlessly invalidate every member's listUserRooms
  // subscription. Previously nothing did this at all, so deleting the newest
  // message left its text on the room card forever.
  const room = await ctx.db.get(msg.roomId);
  if (room && room.lastMessageTime === msg.createdAt) {
    const newest = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q: any) => q.eq("roomId", msg.roomId))
      .order("desc")
      .first();
    await ctx.db.patch(msg.roomId, {
      lastMessage: newest ? roomPreviewFor(newest) : undefined,
      lastMessageTime: newest ? newest.createdAt : undefined,
    });
  }

  // Ask devices that already showed this message to take it back down. See
  // notifications.revokeMessagePushes for what that can and cannot reach.
  await ctx.scheduler.runAfter(0, internal.notifications.revokeMessagePushes, {
    messageId,
    roomId: msg.roomId,
    senderId: msg.userId,
  });
}

export const deleteMessage = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Sender only. This is delete-for-everyone — the row leaves the other
    // person's transcript, their gallery and their notification shade — so it
    // is scoped to what the caller themselves said.
    //
    // Room owners used to be allowed here too, and that was worse than it
    // looked: `roomMembers.role` is set at join time and there is no
    // promote/demote mutation anywhere, so in a DM it silently meant "whoever
    // opened the conversation may delete the other person's messages". A
    // moderator's remove-this-post is a different feature with a different
    // audit story, not a side effect of having tapped NEW CHAT first.
    if (msg.userId.toString() !== userId.toString()) {
      throw new Error("NOT_AUTHORIZED");
    }

    await removeMessageAndFanout(ctx, msg, messageId);
  },
});

/** How long after sending a message its author may still edit it.
 *
 * Enforced HERE, against this server's clock, and nowhere else. The client
 * hides its Edit row from the same window (via `messages.now`, skew-corrected)
 * but that is presentation — a device whose clock runs fast could otherwise
 * offer an edit this mutation must then be trusted to refuse. */
const EDIT_WINDOW_MS = 15 * 60 * 1000;

export const editMessage = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    content: v.string(),
    // Re-declared rather than inherited from the original row: an edit that
    // deletes an `@bob` must drop bob's mention, and one that adds it must
    // pass the same five guards a send does. See `resolveMentions`.
    mentionedUserIds: v.optional(v.array(v.id("users"))),
    mentionsEveryone: v.optional(v.boolean()),
    formatting: formattingArg,
  },
  // "OK", or an error-code string for the one refusal the UI can genuinely
  // race into: the window closing between the menu opening and the send.
  // Everything else throws, because nothing the client renders can reach it —
  // the same split `pins.pinMessage` draws between a full room and a missing
  // one.
  returns: v.string(),
  handler: async (
    ctx,
    { messageId, userId, content, mentionedUserIds, mentionsEveryone, formatting }
  ) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Sender only — the same scope as `deleteMessage` above, for the same
    // reason: rewriting what somebody said is a strictly stronger power than
    // removing it, so it gets no wider an audience.
    if (msg.userId.toString() !== userId.toString()) {
      throw new Error("NOT_AUTHORIZED");
    }

    // Text only. A caption edit is a different feature (it has to reconcile
    // with the gallery and the sealed-tile rules), and a view-once message is
    // sealed content whose whole contract is that it never changes after
    // arming. `url` is grandfathered wire vocabulary for a text message that
    // is mostly a link — same renderer, same rules.
    const msgType = msg.type ?? "text";
    if (msgType !== "text" && msgType !== "url") throw new Error("NOT_AUTHORIZED");
    if (msg.viewOnce === true) throw new Error("NOT_AUTHORIZED");

    // The composer refuses an empty send, so an empty edit can only be a bug
    // or a forged call. "Edit to nothing" is deleteMessage with extra steps,
    // and it should be spelled that way.
    if (content.trim().length === 0) throw new Error("EMPTY_CONTENT");

    if (Date.now() - msg.createdAt > EDIT_WINDOW_MS) {
      return "EDIT_WINDOW_EXPIRED";
    }

    const room = await ctx.db.get(msg.roomId);
    // Lazy for the same reason `guardOutgoing`'s is: most edits carry no
    // mentions, and those must not pay for a roster collect.
    let rosterCache: any[] | null = null;
    const roster = async () =>
      (rosterCache ??= await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", msg.roomId))
        .collect());
    const { resolvedMentions, everyone } = await resolveMentions(
      ctx,
      content,
      userId,
      roster,
      room,
      mentionedUserIds,
      mentionsEveryone
    );

    const fmt = sanitizeFormatting(content, formatting);
    const hasLink =
      LINK_PATTERN.test(content) ||
      (fmt?.some((f) => f.type === "link") ?? false);

    // `undefined` on a patch REMOVES the field (the `backfillRoomContent`
    // idiom), which is exactly right for every sparse field here: an edit
    // that deletes the last URL must take the row out of the LINKS index,
    // not leave it there with `hasLink: false` matching nothing.
    await ctx.db.patch(messageId, {
      content,
      edited: true,
      editedAt: Date.now(),
      mentions: resolvedMentions,
      mentionsEveryone: everyone ? true : undefined,
      hasLink: hasLink ? true : undefined,
      formatting: fmt,
    });

    // Repair the room card, but only when this message is what it shows —
    // the `removeMessageAndFanout` guard. A mid-history edit re-writing the
    // room doc would needlessly invalidate every member's listUserRooms
    // subscription. `lastMessageTime` is left alone: an edit must not float
    // the room to the top of anybody's chat list.
    if (room && room.lastMessageTime === msg.createdAt) {
      await ctx.db.patch(msg.roomId, {
        lastMessage: roomPreviewFor({
          type: msgType,
          content,
          fileName: msg.fileName,
          viewOnce: msg.viewOnce,
          formatting: fmt,
        }),
      });
    }

    // Deliberately NO push. A typo fix must not re-ring anyone's phone. The
    // shade may keep showing the pre-edit text until it is next dismissed —
    // if that ever matters, `notifications.revokeMessagePushes` plus a fresh
    // alert on the same collapse id is the machinery to replace a banner
    // in place. Consequence accepted alongside: a mention ADDED by an edit
    // never notifies its target.
    //
    // Children's `replyToPreview` snapshots are also left frozen on purpose:
    // a reply quoted what was actually said at the time, and rewriting the
    // quote under it would change what the reply meant.
    return "OK";
  },
});

/** The server's clock, for the client's edit-window gate.
 *
 * The `feed.serverNow` pattern as its own query: the client computes a skew
 * offset once per session and uses it to decide whether to OFFER the Edit
 * row. The mutation above re-checks with its own `Date.now()` either way —
 * this exists so a device that is minutes wrong doesn't render a menu item
 * the server will only ever refuse. */
export const now = query({
  args: {},
  returns: v.number(),
  handler: async () => Date.now(),
});

/** Most messages one forward may carry. See `forwardToRoom`. */
const MAX_FORWARD_MESSAGES = 10;

/** Most messages one bulk delete may remove. See `deleteMany`. */
const MAX_DELETE_MESSAGES = 25;

/**
 * Re-sends [messageIds] into ONE other room.
 *
 * One target room per call, with the client fanning out, rather than a single
 * mutation taking a list of rooms. A Convex mutation is one transaction, so a
 * multi-room version would be all-or-nothing: one blocked DM among five targets
 * would roll back the four that were fine. Per-room also keeps OCC contention
 * scoped to the room being written, lets the UI say *which* target failed, and
 * makes `clientIds` a per-room idempotency key rather than a global one.
 *
 * Deliberately not built on `messages:send`. Calling it via `ctx.runMutation`
 * would run in this same transaction anyway — no isolation, no separate limit
 * budget — while re-reading the roster, re-patching `rooms.lastMessage` and
 * scheduling a push once per message. Instead the guard both paths must agree
 * on is shared (`guardOutgoing`) and the rest is done once for the batch.
 *
 * What is deliberately NOT carried over:
 *  - mentions, so forwarding does not ping people in a room they were never
 *    named in;
 *  - `replyToId`/`replyToPreview`, since the parent is not in this room;
 *  - `viewOnce`, which is refused outright — the client does not even hold an
 *    armed message's storage id, so a "forward" of one would be an empty row.
 *
 * The blob itself is shared rather than copied — a mutation cannot read storage
 * bytes anyway, and re-uploading would double the storage for an identical
 * file. That is what makes `files.releaseMessageBlobs` necessary: before this,
 * every teardown path deleted a message's media unconditionally, which was
 * correct only while exactly one message could ever name a given blob.
 */
export const forwardToRoom = mutation({
  args: {
    sourceRoomId: v.id("rooms"),
    targetRoomId: v.id("rooms"),
    userId: v.id("users"),
    messageIds: v.array(v.id("messages")),
    // One idempotency key per message, same order. The forwarded rows carry
    // them exactly as an original send carries its optimistic bubble's id, so
    // a retry after a dropped ack collapses onto the same rows.
    clientIds: v.optional(v.array(v.string())),
  },
  handler: async (
    ctx,
    { sourceRoomId, targetRoomId, userId, messageIds, clientIds }
  ) => {
    if (messageIds.length === 0) return { forwarded: 0, refused: 0 };
    if (messageIds.length > MAX_FORWARD_MESSAGES) {
      throw new Error("TOO_MANY_MESSAGES");
    }
    // Not an error worth its own code — the UI has no way to offer it — but
    // writing a room's own messages back into it would look like a bug.
    if (sourceRoomId.toString() === targetRoomId.toString()) {
      throw new Error("SAME_ROOM");
    }

    // The caller must be in the room they are forwarding OUT of, or this is a
    // way to read any message whose id you can guess into a room you control.
    const sourceMembership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", sourceRoomId).eq("userId", userId)
      )
      .first();
    if (!sourceMembership) throw new Error("NOT_A_MEMBER");

    // Forwarding OUT of a Chamber of Secrets room is refused entirely.
    // `guardOutgoing` derives `expiresAt` from the TARGET room, so a message
    // written to self-destruct in an hour would land in an ordinary room as a
    // permanent one — the sender's expiry silently laundered away by a reader.
    const sourceRoom = await ctx.db.get(sourceRoomId);
    if (sourceRoom?.messageLifetime) throw new Error("SOURCE_IS_EPHEMERAL");

    const sources = await Promise.all(messageIds.map((id) => ctx.db.get(id)));

    // The child media policy is checked against the strongest type in the
    // batch: a child who may not send media may not forward it either, and
    // checking only the first would let one text message carry nine photos.
    //
    // A location anywhere in the batch makes the WHOLE batch a location as far
    // as the guard is concerned, and outranks media — the two gates are
    // separate switches (see LOCATION_POLICY_FLAG) and only one type string can
    // be passed, so the batch has to be described by the permission it most
    // needs. The alternative, checking media and letting a location through on
    // a media grant, is the exact conflation that flag exists to undo.
    // Unioned across the batch rather than collapsed to one type, because a
    // batch genuinely can need both permissions and describing it with one
    // string means the one that wins lets the other through — nine photos
    // forwarded on the strength of a single location in the selection. See
    // `permissionsFor`.
    const batchNeeds = sources.reduce(
      (acc, m) => {
        if (!m) return acc;
        const p = permissionsFor(
          m.type ?? "text",
          m.mediaStorageId !== undefined,
          m.mediaSource
        );
        return { media: acc.media || p.media, location: acc.location || p.location };
      },
      { media: false, location: false }
    );

    const { resolvedSenderName, expiresAt } = await guardOutgoing(
      ctx,
      targetRoomId,
      userId,
      batchNeeds
    );

    let forwarded = 0;
    let refused = 0;
    let newest: {
      type?: string;
      content?: string;
      fileName?: string;
      formatting?: FormattingSpan[];
    } | null = null;
    let newestId: any = null;

    for (let i = 0; i < sources.length; i++) {
      const msg = sources[i];
      // Skipped rather than thrown, so one expired message in a selection does
      // not roll back the nine the user could legitimately forward.
      if (!msg) {
        refused++;
        continue;
      }
      // Server-derived, never taken from args — the caller says which room it
      // is forwarding from, and every message has to actually be from there.
      if (msg.roomId.toString() !== sourceRoomId.toString()) {
        refused++;
        continue;
      }
      if (msg.viewOnce === true) {
        refused++;
        continue;
      }
      // A live share is refused for the same structural reason a view-once
      // photo is: the copy would be a second row claiming to track a person,
      // with no publisher feeding it and no relationship to the original's
      // deadline. It would freeze at whatever position the sharer happened to
      // be at when somebody else pressed forward — a stale position presented
      // as a live one, in a room the sharer never agreed to be in.
      //
      // A STATIC location forwards fine and does below: it is a fixed pair of
      // numbers the sender already published, which is exactly what forwarding
      // any other message copies.
      if ((msg.type ?? "") === "liveLocation") {
        refused++;
        continue;
      }

      const clientId = clientIds?.[i];
      if (clientId !== undefined) {
        const existing = await ctx.db
          .query("messages")
          .withIndex("by_room_user_client", (q) =>
            q
              .eq("roomId", targetRoomId)
              .eq("userId", userId)
              .eq("clientId", clientId)
          )
          .first();
        if (existing) {
          forwarded++;
          continue;
        }
      }

      const msgType = msg.type ?? "text";
      const newId = await ctx.db.insert("messages", {
        roomId: targetRoomId,
        userId,
        content: msg.content ?? "",
        createdAt: Date.now(),
        type: msgType,
        mediaStorageId: msg.mediaStorageId,
        mediaWidth: msg.mediaWidth,
        mediaHeight: msg.mediaHeight,
        fileName: msg.fileName,
        fileSize: msg.fileSize,
        mimeType: msg.mimeType,
        mediaDurationMs: msg.mediaDurationMs,
        posterStorageId: msg.posterStorageId,
        // Recomputed rather than copied. The source's bucket was decided
        // against the source's own storage id and armed flag, and a copy would
        // be a second place for that decision to live.
        galleryBucket: galleryBucketFor(
          msgType,
          msg.mediaStorageId !== undefined,
          false
        ),
        ...(LINK_PATTERN.test(msg.content ?? "") ? { hasLink: true } : {}),
        // Carried, or a forwarded location would arrive as a `location`-typed
        // message with no coordinates — a bubble that renders nothing and can
        // only be deleted. Copied rather than re-derived because unlike the
        // gallery bucket above there is nothing to re-derive: a static share is
        // exactly these two numbers. No live fields are copied, which is
        // structural rather than an omission — the refusal above means a
        // forwarded row can never be a live share.
        latitude: msg.latitude,
        longitude: msg.longitude,
        locationAccuracyM: msg.locationAccuracyM,
        // A GIF or sticker is these fields and nothing else — without them the
        // copy is a `gif` row with no picture. Copied, not re-resolved: the
        // original was validated when it was sent, and a personal sticker its
        // owner has since deleted must still forward as what was said.
        mediaSource: msg.mediaSource,
        mediaUrl: msg.mediaUrl,
        mediaPreviewUrl: msg.mediaPreviewUrl,
        mediaRef: msg.mediaRef,
        stickerId: msg.stickerId,
        stickerStorageId: msg.stickerStorageId,
        stickerFormat: msg.stickerFormat,
        senderName: resolvedSenderName,
        expiresAt,
        ...(clientId !== undefined ? { clientId } : {}),
      });

      // A poll, checklist or event forwards as a FRESH one: same question,
      // same options, no answers. Called unconditionally because the lookup is
      // an empty index range for every other type — the same posture as
      // `purgeInteraction` on the teardown path. See `forkInteraction` for why
      // the tallies deliberately do not travel.
      await forkInteraction(ctx, msg._id, newId, targetRoomId, userId);

      if (expiresAt !== undefined) {
        await ctx.scheduler.runAt(
          new Date(expiresAt),
          internal.messages.expireMessage,
          { messageId: newId }
        );
      }

      forwarded++;
      newest = {
        type: msgType,
        content: msg.content,
        fileName: msg.fileName,
        // Carried so a forwarded spoiler is masked on the target's room card
        // and in its push, the same as the original was.
        formatting: msg.formatting,
      };
      newestId = newId;
    }

    // Once for the batch, not once per message: N patches to one room document
    // all land in the same write set, so only the last would matter anyway —
    // but every one of them contends with concurrent sends into that room.
    if (forwarded > 0 && newest !== null) {
      const preview = roomPreviewFor(newest);
      await ctx.db.patch(targetRoomId, {
        lastMessage: preview,
        lastMessageTime: Date.now(),
      });

      // One push for the batch as well. Ten banners for one tap on FORWARD is
      // a notification bug, not a notification.
      await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
        roomId: targetRoomId,
        messageId: newestId,
        senderId: userId,
        senderName: resolvedSenderName,
        content: forwarded === 1 ? preview : `${forwarded} forwarded messages`,
        // Forced to "text" for a batch so the notification renders the count
        // sentence rather than replacing it with a "📷 Image" label.
        type: forwarded === 1 ? (newest.type ?? "text") : "text",
      });
    }

    return { forwarded, refused };
  },
});

/**
 * Deletes up to [MAX_DELETE_MESSAGES] messages the caller is entitled to.
 *
 * Per-message authorization SKIPS rather than throws, and that is the whole
 * design. A selection made in a gallery can still reach this holding something
 * that isn't the caller's — a message whose sender changed under a stale
 * screen, or simply a client that got it wrong; throwing on the first one would
 * roll back the deletions they were entitled to and leave the UI unable to say
 * which of the twenty was the problem. The `{deleted, refused}` return is what
 * the caller reports.
 *
 * The client is expected to have filtered the selection already — the DELETE
 * action only appears when every selected message is the caller's own — so a
 * non-zero `refused` means the two disagreed, which is exactly when a silent
 * partial success would be worst.
 *
 * Same rule as `deleteMessage`: sender, and only the sender. This is
 * delete-for-everyone, not delete-for-me, so it is scoped to what the caller
 * said themselves — see the note there on why owning the room does not extend
 * it.
 */
export const deleteMany = mutation({
  args: {
    userId: v.id("users"),
    messageIds: v.array(v.id("messages")),
  },
  handler: async (ctx, { userId, messageIds }) => {
    if (messageIds.length === 0) return { deleted: 0, refused: 0 };
    if (messageIds.length > MAX_DELETE_MESSAGES) {
      throw new Error("TOO_MANY_MESSAGES");
    }

    let deleted = 0;
    let refused = 0;

    for (const messageId of messageIds) {
      const msg = await ctx.db.get(messageId);
      // Already gone — an expired ephemeral message, or someone else's delete
      // landing first. Not a refusal: the caller wanted it gone and it is.
      if (!msg) continue;

      if (msg.userId.toString() !== userId.toString()) {
        refused++;
        continue;
      }

      await removeMessageAndFanout(ctx, msg, messageId);
      deleted++;
    }

    return { deleted, refused };
  },
});

export const list = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    limit: v.optional(v.number()),
    // Optional so already-shipped clients keep working. Without it a
    // view-once message still comes back stripped — the viewer just can't be
    // told whether they personally opened it.
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, limit, viewerUserId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(limit ?? 100);

    // Do NOT read `users` here. Convex reactivity tracks every doc read, so
    // including `ctx.db.get(msg.userId)` made this subscription re-fire on
    // every user.status flip (online/away/offline) for any author in the
    // list — which then triggered markRoomRead, which patched roomMembers,
    // which refired four other subscriptions. The denormalized
    // `msg.senderName` is set at write time in `messages:send` so the
    // client already has the display name.
    //
    // Reactions come through `reactionsFor`, which reads the `reactions`
    // table only for rows flagged as having any. This query is what every
    // viewer of a room holds open, and it re-runs for each of them on every
    // send, edit, reaction and delete in the window — so its per-run cost is
    // very nearly the app's receive latency. It used to be one indexed read
    // per message returned; it is now one range scan plus a read per message
    // somebody actually reacted to.
    const enriched = await Promise.all(
      msgs.map(async (msg) => {
        const reactions = await reactionsFor(ctx, msg);
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );
    return enriched.reverse();
  },
});

export const listBefore = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    beforeTimestamp: v.number(),
    limit: v.optional(v.number()),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, beforeTimestamp, limit, viewerUserId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).lt("createdAt", beforeTimestamp)
      )
      .order("desc")
      .take(limit ?? 30);

    // Mirrors the no-user-doc-read pattern from `list` above — see comment
    // there for why we never enrich with users in a reactive query.
    const enriched = await Promise.all(
      msgs.map(async (msg) => {
        const reactions = await reactionsFor(ctx, msg);
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );
    return enriched.reverse(); // chronological order
  },
});

// Ascending counterpart to `listBefore`. Only used to walk *back down* toward
// the present after a jump into old history — the newest end of the room is
// owned by the live `list` subscription, so nothing subscribes to this.
export const listAfter = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    afterTimestamp: v.number(),
    limit: v.optional(v.number()),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, afterTimestamp, limit, viewerUserId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).gt("createdAt", afterTimestamp)
      )
      .order("asc")
      .take(limit ?? 30);

    // Mirrors the no-user-doc-read pattern from `list` above.
    return await Promise.all(
      msgs.map(async (msg) => {
        const reactions = await reactionsFor(ctx, msg);
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );
  },
});

// A window of history centred on one message, so tapping a reply tether can
// land on a parent that was posted long before anything the client holds —
// without paging the whole gap 40 messages at a time.
//
// Returns the anchor plus `before` older and `after` newer messages,
// chronological, with a flag per side saying whether history continues there.
// `found: false` means the message is gone (deleted) or not in this room.
//
// Messages sharing the anchor's exact `createdAt` fall outside both range
// scans; at millisecond precision that's vanishingly rare, and the client
// dedupes by id anyway.
export const listAround = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    messageId: v.id("messages"),
    before: v.optional(v.number()),
    after: v.optional(v.number()),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, messageId, before, after, viewerUserId }) => {
    const anchor = await ctx.db.get(messageId);
    if (!anchor || anchor.roomId.toString() !== roomId.toString()) {
      return {
        messages: [],
        hasMoreOlder: true,
        hasMoreNewer: true,
        found: false,
      };
    }

    const backCap = Math.min(before ?? 25, 100);
    const fwdCap = Math.min(after ?? 25, 100);

    const older = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).lt("createdAt", anchor.createdAt)
      )
      .order("desc")
      .take(backCap);
    const newer = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).gt("createdAt", anchor.createdAt)
      )
      .order("asc")
      .take(fwdCap);

    const collected = [...older.reverse(), anchor, ...newer];

    // Reactions only. Do NOT read `users` here — same reason as `list`.
    const enriched = await Promise.all(
      collected.map(async (msg) => {
        const reactions = await reactionsFor(ctx, msg);
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );

    return {
      messages: enriched,
      hasMoreOlder: older.length === backCap,
      hasMoreNewer: newer.length === fwdCap,
      found: true,
    };
  },
});

// MARK: - Chamber of Secrets: scheduled self-destruction

export const expireMessage = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return; // Already deleted (e.g. manually deleted before expiry)

    await removeMessageAndFanout(ctx, msg, messageId);
  },
});

// Paged thread read. Supersedes `getThread` below, which is kept only for
// already-shipped clients.
//
// A thread is `{root} ∪ {m : m.rootId === rootId}` — see the `rootId` comment
// in schema.ts for why the tree is flattened this way. Because `by_root_time`
// is time-ordered, a page is a plain range scan and page N+1 is always a
// prefix-extension of page N: newly-loaded messages can only ever appear
// above what's already on screen, never in the middle of it.
//
// Walks *older*, mirroring `listBefore`: pass the oldest `createdAt` you hold
// as `beforeTimestamp`. The newest end is owned by the room's live
// subscription on the client, so there is deliberately no "load newer".
//
// The root itself carries no `rootId`, so it isn't in the index scan — it's
// unshifted once the scan runs dry (a reply's createdAt always postdates its
// parent's, so the root is unconditionally the head of the thread).
export const getThreadPage = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    rootId: v.id("messages"),
    viewerUserId: v.id("users"),
    beforeTimestamp: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, rootId, viewerUserId, beforeTimestamp, limit }) => {
    // `getThread` has no authorization at all — any messageId reads a thread.
    // Checking here is safe precisely because this query is only ever fetched
    // one-shot, never subscribed: reading `roomMembers` from a live query
    // would make it refire on every `markRoomRead` patch (see the comment on
    // `list` about why reactive queries must stay off shared docs).
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", viewerUserId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    const cap = Math.min(limit ?? 25, 100);

    let q = ctx.db
      .query("messages")
      .withIndex("by_root_time", (ix) =>
        beforeTimestamp === undefined
          ? ix.eq("rootId", rootId)
          : ix.eq("rootId", rootId).lt("createdAt", beforeTimestamp)
      );

    const descendants = await q.order("desc").take(cap);
    const hasMore = descendants.length === cap;
    const collected = descendants.reverse(); // chronological

    // Scan ran dry — prepend the root, unless the caller already has it.
    if (!hasMore) {
      const root = await ctx.db.get(rootId);
      if (
        root &&
        root.roomId.toString() === roomId.toString() &&
        (beforeTimestamp === undefined || root.createdAt < beforeTimestamp)
      ) {
        collected.unshift(root);
      }
    }

    // Reactions only. Do NOT read `users` here — same reason as `list`.
    const enriched = await Promise.all(
      collected.map(async (msg) => {
        const reactions = await reactionsFor(ctx, msg);
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );

    return { messages: enriched, hasMore };
  },
});

// DEPRECATED — superseded by `getThreadPage`. Retained so app versions
// already in the wild keep working; delete once they've aged out.
//
// Returns the entire conversational thread containing [messageId]: walks up
// to the root via replyToId, then BFS down through the by_replyTo index to
// collect every descendant. Result is sorted chronologically (oldest first)
// and enriched the same way `list` enriches its rows. Capped at 50 messages
// to keep the round-trip bounded; branching threads still work but only the
// first 50 BFS-collected rows come back.
export const getThread = query({
  args: {
    messageId: v.id("messages"),
    maxTotal: v.optional(v.number()),
  },
  handler: async (ctx, { messageId, maxTotal }) => {
    const cap = Math.min(maxTotal ?? 50, 100);

    // 1. Walk up to the root. Bounded by 20 hops + cycle-guard set.
    // Typed, so `ctx.db.get(rootId)` below resolves to a message. As `any` it
    // fell back to the union of every table's document type, where
    // `replyToId` does not exist — on the two lines that walk the chain by it.
    let rootId: Id<"messages"> = messageId;
    const seenUp = new Set<string>();
    for (let i = 0; i < 20; i++) {
      const key = rootId.toString();
      if (seenUp.has(key)) break;
      seenUp.add(key);
      const m = await ctx.db.get(rootId);
      if (!m || !m.replyToId) break;
      rootId = m.replyToId;
    }

    // 2. BFS down from the root through the by_replyTo index.
    // Both typed, for the same reason `rootId` above is: `ctx.db.get(id)` on an
    // `any` resolves to the union of every table's document, so `m.userId` was
    // not an `Id<"users">` and the `db.get` in the enrichment below could not
    // find `name` or `username` on what it returned.
    const collected: Doc<"messages">[] = [];
    const seenDown = new Set<string>();
    const queue: Id<"messages">[] = [rootId];
    while (queue.length > 0 && collected.length < cap) {
      const id = queue.shift();
      // `shift()` is typed `T | undefined` regardless of the length check in
      // the loop condition, and the next line dereferences it. The guard is
      // free and turns an impossible-today crash into a `break` if the loop
      // condition is ever loosened.
      if (id === undefined) break;
      const key = id.toString();
      if (seenDown.has(key)) continue;
      seenDown.add(key);
      const m = await ctx.db.get(id);
      if (!m) continue;
      collected.push(m);
      const kids = await ctx.db
        .query("messages")
        .withIndex("by_replyTo", (q) => q.eq("replyToId", id))
        .collect();
      for (const k of kids) queue.push(k._id);
    }

    // 3. Enrich + sort chronologically.
    //
    // Sanitized with no viewer: this function takes no user id and does no
    // authorization at all, so it must never be the one path that hands out a
    // view-once storage id. Clients old enough to still call this simply can't
    // open view-once photos, which is the correct failure direction.
    const enriched = await Promise.all(
      collected.map(async (m) => {
        const user = await ctx.db.get(m.userId);
        const reactions = await reactionsFor(ctx, m);
        const safe = await sanitizeViewOnce(ctx, m, undefined);
        return {
          ...safe,
          username: user?.username ?? "unknown",
          name: user?.name ?? user?.username ?? "unknown",
          reactions,
        };
      })
    );
    enriched.sort((a, b) => a.createdAt - b.createdAt);
    return enriched;
  },
});

// ─────────────────────────────── View-once photos ────────────────────────────

/** Drops every ledger row for one message. Shared by all three delete paths. */
export async function purgeViewOnceViews(ctx: any, messageId: any) {
  const rows = await ctx.db
    .query("viewOnceViews")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const r of rows) await ctx.db.delete(r._id);
}

/**
 * A 32-hex-character ticket. `crypto.getRandomValues` is available in Convex's
 * runtime; `Math.random` would not be acceptable here, since guessing a nonce
 * is guessing a photo.
 */
function mintNonce(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Hands out a download ticket for a view-once photo, spending the caller's one
 * view in the same breath.
 *
 * The view is recorded at GRANT time rather than when the picture is dismissed.
 * That ordering is the whole security property: a client that crashes, force
 * quits, or simply lies about having closed the image has still spent its view,
 * because it could not have obtained the ticket otherwise.
 *
 * Returns one of:
 *   { nonce, expiresInMs } — go fetch it
 *   { alreadyViewed: true } — spent, and past the retry window
 *   { gone: true }          — burned, expired, deleted, or never armed
 */
export const openViewOnce = mutation({
  args: { messageId: v.id("messages"), userId: v.id("users") },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return { gone: true };

    // Membership, and the child guard on top of it. `send` re-checks the child
    // policy on every call because a guardian can revoke a grant while the
    // child is still sitting in the room; opening media has to be re-checked
    // for exactly the same reason, or revocation would only take effect for
    // photos that haven't been sent yet.
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    const policy = await childPolicyOf(ctx, userId);
    if (policy !== null) {
      if (!(await childMayUseRoom(ctx, userId, msg.roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
      if (!policy.mediaEnabled) throw new Error(ERR_NOT_ALLOWED);
    }

    if (msg.viewOnce !== true || !msg.mediaStorageId) return { gone: true };

    // The sender gets no reopen path, and this is a security decision rather
    // than a UX one. There is no authentication here — `userId` is a plain
    // argument — and a message's sender id is visible to everyone who receives
    // it. A "the sender may always look again" branch is therefore an oracle
    // any recipient can drive: pass the sender's id, get unlimited views.
    if (msg.userId.toString() === userId.toString()) return { gone: true };

    const now = Date.now();
    const existing = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message_user", (q) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .first();

    if (existing) {
      // Same ticket, not a fresh one. Re-minting would be indistinguishable
      // from granting a second view; handing back the still-live ticket is
      // just letting the first download finish over a bad connection.
      if (
        existing.grantNonce &&
        existing.grantExpiresAt &&
        now < existing.grantExpiresAt
      ) {
        return {
          nonce: existing.grantNonce,
          expiresInMs: existing.grantExpiresAt - now,
        };
      }
      return { alreadyViewed: true };
    }

    // Somebody who joined after the photo was sent may still open it, but must
    // not be able to satisfy the burn condition on the real recipients' behalf.
    const countsToward = membership.joinedAt <= msg.createdAt;

    const nonce = mintNonce();
    await ctx.db.insert("viewOnceViews", {
      messageId,
      roomId: msg.roomId,
      userId,
      viewedAt: now,
      countsToward,
      grantNonce: nonce,
      grantExpiresAt: now + VIEW_ONCE_NONCE_TTL_MS,
    });

    if (countsToward) {
      const seen = (msg.viewOnceViewCount ?? 0) + 1;
      await ctx.db.patch(messageId, { viewOnceViewCount: seen });
      if (seen >= (msg.viewOnceRecipients ?? 0)) {
        // Everyone has had their look. Wait out the grace period before
        // deleting, or we would pull the file out from under the download this
        // very grant just authorized.
        await ctx.scheduler.runAfter(
          VIEW_ONCE_BURN_GRACE_MS,
          internal.messages.burnViewOnce,
          { messageId }
        );
      }
    }

    return { nonce, expiresInMs: VIEW_ONCE_NONCE_TTL_MS };
  },
});

/**
 * Validates a download ticket and reports which blob to stream. Internal, and
 * called only by the `/viewOnce` HTTP action — the storage id it returns must
 * never reach a client.
 */
export const resolveViewOnceGrant = internalQuery({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    nonce: v.string(),
  },
  handler: async (ctx, { messageId, userId, nonce }) => {
    const row = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message_user", (q) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .first();
    if (!row || row.grantNonce !== nonce) return null;
    if (!row.grantExpiresAt || Date.now() >= row.grantExpiresAt) return null;

    const msg = await ctx.db.get(messageId);
    if (!msg || msg.viewOnce !== true || !msg.mediaStorageId) return null;
    return { storageId: msg.mediaStorageId };
  },
});

/**
 * Deletes the blob and leaves the message behind as a ghost.
 *
 * Idempotent, and deliberately so: it is reachable from the per-message
 * deadline schedule, from the "everyone has seen it" schedule, and from the
 * repair sweep, and any two of those can land on the same message.
 */
export const burnViewOnce = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg || msg.viewOnce !== true || !msg.mediaStorageId) return;

    await deleteStored(ctx, msg.mediaStorageId);
    // The ROW SURVIVES. Clearing these fields is what flips every client to the
    // greyed ghost bubble, reactively, without deleting anyone's transcript.
    await ctx.db.patch(messageId, {
      mediaStorageId: undefined,
      mediaWidth: undefined,
      mediaHeight: undefined,
      viewOnceBurnedAt: Date.now(),
      viewOnceDeadline: undefined,
      // Drops the row out of the sweep's index bucket entirely — see the
      // `viewOnceLive` comment in schema.ts.
      viewOnceLive: undefined,
    });
    // Tickets outlive their usefulness the moment the file is gone.
    const rows = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .collect();
    for (const r of rows) {
      if (r.grantNonce !== undefined) {
        await ctx.db.patch(r._id, {
          grantNonce: undefined,
          grantExpiresAt: undefined,
        });
      }
    }
  },
});

/**
 * Repair sweep for armed photos past their deadline. The per-message
 * `runAfter` scheduled in `send` is the primary mechanism — this only catches
 * what the scheduler dropped (a restart mid-flight, a backfilled row), which is
 * why six hours is frequent enough.
 *
 * The index leads with `viewOnce` on purpose: Convex has no sparse indexes and
 * sorts `undefined` ahead of every number, so ranging on the deadline alone
 * would walk every message in the deployment.
 */
export const gcExpiredViewOnce = internalMutation({
  args: {},
  handler: async (ctx) => {
    const SWEEP_LIMIT = 200;
    const due = await ctx.db
      .query("messages")
      .withIndex("by_viewOnce_live_deadline", (q) =>
        q.eq("viewOnceLive", true).lt("viewOnceDeadline", Date.now())
      )
      .take(SWEEP_LIMIT);

    let burned = 0;
    for (const msg of due) {
      await deleteStored(ctx, msg.mediaStorageId);
      await ctx.db.patch(msg._id, {
        mediaStorageId: undefined,
        mediaWidth: undefined,
        mediaHeight: undefined,
        viewOnceBurnedAt: Date.now(),
        viewOnceDeadline: undefined,
        viewOnceLive: undefined,
      });
      burned++;
    }
    return { scanned: due.length, burned };
  },
});

/**
 * Recomputes the recipient snapshot for a room's live view-once photos.
 *
 * Called when membership changes. Without it, someone leaving a room without
 * opening a photo pins that blob until its 14-day deadline, even though every
 * remaining recipient has already seen it. Bounded by design: only armed,
 * unburned messages in one room.
 */
export const recountViewOnceRecipients = internalMutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    const roster = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .collect();
    const memberIds = new Set(roster.map((m) => m.userId.toString()));

    const recent = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(200);

    for (const msg of recent) {
      if (msg.viewOnce !== true || !msg.mediaStorageId) continue;
      const recipients = roster.filter(
        (m) => m.userId.toString() !== msg.userId.toString()
      ).length;
      // Only count views from people who are still here — a departed member's
      // row would otherwise keep inflating the tally.
      const rows = await ctx.db
        .query("viewOnceViews")
        .withIndex("by_message", (q) => q.eq("messageId", msg._id))
        .collect();
      const seen = rows.filter(
        (r) => r.countsToward && memberIds.has(r.userId.toString())
      ).length;

      if (
        recipients !== msg.viewOnceRecipients ||
        seen !== msg.viewOnceViewCount
      ) {
        await ctx.db.patch(msg._id, {
          viewOnceRecipients: recipients,
          viewOnceViewCount: seen,
        });
      }
      if (seen >= recipients) {
        await ctx.scheduler.runAfter(
          VIEW_ONCE_BURN_GRACE_MS,
          internal.messages.burnViewOnce,
          { messageId: msg._id }
        );
      }
    }
  },
});

// ──────────────────────── Delivery + read receipts ───────────────────────────

/**
 * Mark a room as "read up to now" for the given user. Persisted on the
 * roomMembers row so the relationship is O(rooms × members) rather than
 * O(messages × members).
 *
 * Advances `lastDeliveredAt` in the same patch: you cannot read a message your
 * device does not have, so a read cursor ahead of the delivery cursor would be
 * a state the UI has no honest tick for. Doing it here rather than leaving it
 * to `markRoomDelivered` also means a recipient running a build too old to know
 * that mutation exists still moves the sender from one tick to two the moment
 * they open the room.
 *
 * Idempotent — calling repeatedly only updates the timestamps.
 */
export const markRoomRead = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    // `createdAt` of the newest message the client has on screen. When given
    // it is both the guard's bar and the cursor written, and the room
    // document is not read at all — see below for why that is the point.
    upTo: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, userId, upTo }) => {
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .first();
    if (!membership) return; // not a member, silently no-op

    // Nothing new to mark. The same guard `markRoomDelivered` carries, for the
    // same reason and with more to gain: patching a `roomMembers` row re-fires
    // `getReadState` for every member of the room and `listUserRooms` for this
    // one, so a patch that moves the cursor past nothing is not free — it is a
    // rebuild of several subscriptions that say exactly what they said before.
    //
    // This is the room-entry case, and it is the common one: opening a room
    // you have already read used to cost the same fan-out as reading a fresh
    // message in it, plus a scheduled `dismissAndSync`. Re-entering a quiet
    // room now costs one indexed read.
    //
    // Skipping the dismiss along with the patch is correct rather than merely
    // cheap: the cursor being at or past the newest message means an earlier
    // `markRoomRead` already ran and already scheduled one. The reading device
    // clears its own notifications locally either way (see `ChatRepository`),
    // so nothing is left showing on the device in the user's hand.
    //
    // `upTo` is the client saying WHICH message it read, so the bar comes from
    // the argument and the room document stays out of this transaction. That
    // is an OCC fix, not a saved read: `send` patches the room on every
    // message, and a `markRoomRead` that had read the room while a send was
    // committing was thrown away and re-run from the top — in a fast two-way
    // chat, where each arrival triggers exactly this call while the reply is
    // already on its way, a good share of them. The server logs showed it as
    // "Documents read from or written to the rooms table changed while this
    // mutation was being run". Writing the message's own timestamp instead of
    // `Date.now()` keeps every comparison as it was: unread is
    // `createdAt > lastReadAt` (badges.ts) and SEEN is `lastReadAt >=
    // createdAt` (room_screen.dart), and the newest message satisfies both.
    // Clients from before the argument existed send none and take the room
    // read as before.
    let newest: number;
    if (upTo !== undefined) {
      newest = upTo;
    } else {
      const room = await ctx.db.get(roomId);
      newest = room?.lastMessageTime ?? 0;
    }
    if ((membership.lastReadAt ?? 0) >= newest) return;

    // The cursor is the message's timestamp, but WHEN it was read is now —
    // stamped separately so the receipts screen has a real read time rather
    // than echoing the sent time. The delivery stamp moves only if this read
    // is also what delivered it; an earlier delivery keeps its own time.
    const clock = Date.now();
    const cursor = upTo ?? clock;
    const deliveredBefore = membership.lastDeliveredAt ?? 0;
    await ctx.db.patch(membership._id, {
      lastReadAt: cursor,
      lastReadClock: clock,
      lastDeliveredAt: Math.max(deliveredBefore, cursor),
      ...(cursor > deliveredBefore ? { lastDeliveredClock: clock } : {}),
    });

    // Reading the room retires its outstanding notifications. The device that
    // did the reading also clears them locally (it doesn't need a round trip);
    // this covers the user's *other* devices and corrects the badge everywhere.
    //
    // No id list: every platform sweeps this case by thread/group id (the
    // roomId), which is what `dismissAndSync` carries. The old code passed the
    // ids it had just read out of `pushReceipts`, but that table only ever
    // existed to hold OneSignal notification ids for cancellation, and the
    // client never used the list for the whole-room case.
    await ctx.scheduler.runAfter(0, internal.notifications.dismissAndSync, {
      userIds: [userId],
      roomId,
    });
  },
});

/**
 * Mark a room as "delivered up to now" for the given user — the second tick.
 *
 * Called by a recipient's client when it learns the room has moved but the
 * user has not opened it: the message is on the device, and that is all this
 * claims. Not called per message. The client fires it at most once per room
 * per burst of new traffic, and the guard below drops even that when the
 * cursor is already past the room's newest message, so a chatty or looping
 * client cannot turn this into a write per message.
 *
 * That guard matters beyond write volume: patching a roomMembers row re-fires
 * `getReadState` for every member of the room and `listUserRooms` for this
 * one, so a no-op patch is not free — it is a rebuild of the sender's receipt
 * stream that says nothing new.
 */
export const markRoomDelivered = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .first();
    if (!membership) return; // not a member, silently no-op

    const room = await ctx.db.get(roomId);

    // Above this many members the receipt stops being worth its fan-out: one
    // patch re-runs `getReadState` for every member, so the cost climbs with
    // room size exactly as the signal loses meaning ("someone's device has it"
    // is trivially true the moment a large room is posted to). The client
    // carries the same threshold and skips the call — this copy is what makes
    // it hold for an old or misbehaving one, and it is free because the room
    // is already loaded. One knob, two places, deliberately: see
    // `ChatRepository.kDeliveryMemberLimit`.
    if ((room?.memberCount ?? 0) > DELIVERY_MEMBER_LIMIT) return;

    const newest = room?.lastMessageTime ?? 0;
    const cursor = membership.lastDeliveredAt ?? 0;
    // Everything this room has is already behind the cursor — there is nothing
    // to tell anyone.
    if (cursor >= newest) return;

    const clock = Date.now();
    await ctx.db.patch(membership._id, {
      lastDeliveredAt: clock,
      lastDeliveredClock: clock,
    });
  },
});

/**
 * Returns each member's delivery and read cursors for a room, each filtered by
 * the visibility control that actually describes it.
 *
 * `lastReadAt` — gated on the reader's `seen` level, which is what the
 * visibility screen calls SEND READ RECEIPTS:
 *
 *   reader.visibility.seen = "public"  → visible to anyone
 *   reader.visibility.seen = "friends" → visible only to the reader's friends
 *   reader.visibility.seen = "nobody"  → hidden (the default for missing/unset)
 *
 * `lastDeliveredAt` — gated on `seen` as well, by product decision. Both ticks
 * past the first are therefore one opt-in: a user who has not turned on SEND
 * READ RECEIPTS reports neither delivery nor reads, and senders see a single
 * tick for them forever.
 *
 * This is the strict reading, chosen over gating delivery on `lastSeen`. The
 * `lastSeen` variant would have lit the second tick by default (that control
 * defaults to visible) at the cost of making a second, weaker promise about the
 * same underlying fact — and of putting delivery inside visibility.ts's
 * GUARDIAN_BYPASS, where a guardian would read a child's delivery cursor
 * whatever the child had set. Under `seen`, which is deliberately NOT in that
 * set, both cursors stay the child's to withhold.
 *
 * The cost is real and worth stating plainly: `seen` defaults to "nobody", so
 * out of the box every message in the app sits on one tick until the recipient
 * opts in. That is the intended default, not an oversight — do not "fix" it by
 * loosening the gate here.
 *
 * Either cursor comes back `null` when the viewer may not have it, rather than
 * 0: the shape still distinguishes "withheld" from "behind everything", which
 * matters if the two gates ever diverge again. A row with neither is omitted
 * entirely, so the client can fold over what it is given without a second
 * filter.
 *
 * The viewer's own row is always returned in full.
 */
export const getReadState = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    viewerUserId: v.id("users"),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .collect();

    // One lens for the whole room instead of a friendship pair-lookup per
    // member, and — more importantly — the same level check every other
    // surface uses. This handler used to carry its own copy of it, which is
    // how the app ended up with two subtly different readings of the same
    // stored value. The privacy-first default for `seen` (missing ⇒ "nobody")
    // now lives in visibility.ts's DEFAULT_LEVEL table, unchanged.
    const lens = await lensFor(ctx, viewerUserId);
    const out: Array<{
      userId: any;
      lastReadAt: number | null;
      lastDeliveredAt: number | null;
      readClock: number | null;
      deliveredClock: number | null;
    }> = [];
    for (const m of members) {
      if (lens.isSelf(m.userId)) {
        out.push({
          userId: m.userId,
          lastReadAt: m.lastReadAt ?? 0,
          lastDeliveredAt: m.lastDeliveredAt ?? 0,
          readClock: m.lastReadClock ?? null,
          deliveredClock: m.lastDeliveredClock ?? null,
        });
        continue;
      }
      // Built from the row's own denormalized `seenVisibility`, never
      // `ctx.db.get(m.userId)` — this query used to read every other
      // member's full `users` document just for this one near-static field,
      // which subscribed it to their `status`/`lastSeen` too and refired it
      // on every presence heartbeat in the room. See schema.ts's
      // `roomMembers.seenVisibility` comment. Still routed through the one
      // real `canSee` check so the gate can't drift from every other surface.
      const subject = { _id: m.userId, visibility: { seen: m.seenVisibility } };
      const shares = lens.canSee(subject, "seen");
      const read = shares ? (m.lastReadAt ?? 0) : null;
      const delivered = shares ? (m.lastDeliveredAt ?? 0) : null;
      if (read === null && delivered === null) continue;
      out.push({
        userId: m.userId,
        lastReadAt: read,
        lastDeliveredAt: delivered,
        // Same gate as the cursors they stamp.
        readClock: shares ? (m.lastReadClock ?? null) : null,
        deliveredClock: shares ? (m.lastDeliveredClock ?? null) : null,
      });
    }
    return out;
  },
});

