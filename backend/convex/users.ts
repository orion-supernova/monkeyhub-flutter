import { internalMutation } from "./_generated/server";
import { mutation, publicQuery, query } from "./functions";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { PRESENCE_WRITE_INTERVAL_MS } from "./presence";
import { COMPAT_OFFLINE_MS } from "./presenceCore";
import { attachFile, claimUpload } from "./files";
import { enqueueDeletion, getLiveUser, isTombstoned } from "./deletionCore";
import {
  SOCIAL_ONLY_PASSWORD_SENTINEL,
  normaliseUsername, assertNoCaseTwin,
} from "./socialAuth";
import {
  ACCOUNT_ADULT,
  ACCOUNT_CHILD,
  DEFAULT_CHILD_POLICY,
  ERR_MUST_PAIR,
  ERR_NOT_ALLOWED,
  STAGE_RECIPIENT_GUARDIAN,
  STAGE_SENDER_GUARDIAN,
  familyOf,
  isChild,
} from "./childGuard";
import { findDmRoomsBetween, wipeRoomCompletely } from "./roomCleanup";
import {
  ERR_DISPLAY_NAME_RESERVED,
  ERR_USERNAME_RESERVED,
  REPORT_INBOX_USERNAME,
  isReservedName,
  isStaffHandle,
  isSystemAccount,
} from "./systemAccount";
import { lensFor } from "./visibility";
import { searchNameOf } from "./userSearch";
import { assertCleanName, isObjectionableName } from "./contentFilter";
import { fileContentReport } from "./moderationCore";
import { isRetiredHandle } from "./retiredHandles";
import { consume } from "./rateLimit";
import { continueSweep, sweepArgs } from "./sweep";
import { touchSessions } from "./sessionCore";
import {
  noteBeat,
  setStatus as setPresenceStatus,
  syncLevels,
  type PresenceStatus,
} from "./presenceCore";
import { restampSeenPage } from "./receipts";

/**
 * Returns a user's profile, with per-field redaction based on the viewer's
 * relationship to the subject. Pass `viewerUserId` so the backend can apply
 * the subject's visibility rules. Callers omitting `viewerUserId` get the
 * public-only view (used for self-lookups via login response, etc.).
 *
 * The level check itself lives in visibility.ts and is shared with every other
 * query that returns someone's avatar or presence — this handler used to own
 * it, which is precisely why the setting only ever worked here.
 *
 * `friendRequests` doesn't affect the profile payload directly — it's
 * enforced at request-mutation time.
 */
// The one function in the codebase where `userId` names the person being
// looked AT rather than the person asking. `identityArg` moves the injected
// identity onto `viewerUserId` so the subject keeps coming from the client —
// without it the wrapper would overwrite `userId` with the caller and this
// query would only ever return your own profile.
export const getProfile = query({
  identityArg: "viewerUserId" as const,
  args: {
    userId: v.id("users"),
    // Still DECLARED so the client's existing payload validates — Convex
    // rejects arguments a function did not declare — but no longer TRUSTED:
    // `identityArg` above makes the wrapper overwrite it with the resolved
    // caller. Removing it outright broke every profile view in the app.
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { userId, viewerUserId }) => {
    const user = await ctx.db.get(userId);
    // A tombstoned account (being deleted) is gone as far as a viewer can tell.
    if (!user || isTombstoned(user)) return null;

    const lens = await lensFor(ctx, viewerUserId);
    const isSelf = lens.isSelf(userId);
    // Guardian bypass. This is how "everything enabled for their parents to
    // check" is delivered WITHOUT making the child public to the world: the
    // child's visibility map stays as restrictive as we like, and guardians
    // simply aren't subject to it. Strangers still see a redacted profile.
    const isGuardian = !isSelf && lens.isGuardian(userId);

    const vis = user.visibility ?? {};
    const identity = lens.identity(user, Date.now());

    // Whether a pending request between the viewer and this profile is parked
    // at the VIEWER'S OWN guardian hop — see the long note in
    // `searchUsersCore`, which computes the same flag for the same reason and
    // under the same "own guardian only" restriction.
    //
    // The profile screen cannot derive this for itself: it resolves friendship
    // from the repository's live request lists, and those are filtered
    // server-side to released rows only. So a child looking at the profile of
    // someone whose request their parent is still holding saw a clean SEND
    // REQUEST button, and tapping it failed with REQUEST_ALREADY_RECEIVED.
    let awaitingGuardian = false;
    if (viewerUserId && !isSelf) {
      const outgoing = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (q: any) =>
          q.eq("userId", viewerUserId).eq("friendId", userId),
        )
        .first();
      const incoming = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (q: any) =>
          q.eq("userId", userId).eq("friendId", viewerUserId),
        )
        .first();
      awaitingGuardian =
        (outgoing?.status === "pending" &&
          outgoing.stage === STAGE_SENDER_GUARDIAN) ||
        (incoming?.status === "pending" &&
          incoming.stage === STAGE_RECIPIENT_GUARDIAN);
    }

    return {
      _id: user._id,
      username: user.username,
      name: user.name,
      // Self-only data — never expose to other viewers.
      email: isSelf || isGuardian ? user.email : undefined,
      // Whether a recovery phrase is set. The HASH is NEVER returned: it IS
      // the reset credential, and handing it out would enable an offline
      // dictionary attack on the legacy freehand phrases, which are exactly
      // the low-entropy ones.
      //
      // Self only — deliberately NOT self-or-guardian, unlike email above.
      // Another adult's recovery status is none of a guardian's business, and
      // for a child it is meaningless: children have no phrase and no reset
      // path, so returning `false` there would drive a "set up your recovery
      // phrase" nag on every kid's phone, pointing at a screen that cannot
      // work for them. `undefined` reads as "unknown" on the client, which is
      // treated as do-not-prompt.
      //
      // Accounts created through Apple/Google are excluded for exactly the same
      // reason as children: they have no password either, and the recovery
      // phrase's only power is resetting one. Prompting them would open a gate
      // whose commit step (`auth.setRecoveryKey`) demands a password they do not
      // have. Their provider IS the recovery path.
      //
      // Note this un-excludes itself: if such a user later sets a real password
      // the sentinel is gone, and the phrase prompt becomes meaningful again.
      hasRecoveryKey:
        isSelf &&
        user.accountType !== ACCOUNT_CHILD &&
        user.passwordHash !== SOCIAL_ONLY_PASSWORD_SENTINEL
          ? user.recoveryKeyHash !== undefined
          : undefined,
      // Whether this account can be asked for a password at all. Self only, and
      // for the same reason as `hasRecoveryKey`: it describes a credential.
      //
      // The rename sheet is the caller. A password account is gated by typing
      // its password; an Apple/Google-only account has none to type and is
      // gated by re-running the provider sheet instead. The client cannot tell
      // those apart on its own — a linked provider does not imply the absence
      // of a password — so the answer has to come from here.
      hasPassword: isSelf
        ? user.passwordHash !== SOCIAL_ONLY_PASSWORD_SENTINEL
        : undefined,
      // Lets the rename row show the date the handle unlocks instead of
      // accepting a new one and refusing it after the user has typed it.
      usernameChangedAt: isSelf ? user.usernameChangedAt : undefined,
      ...identity,
      // Mirror the visibility map back so self-view UI can render it without
      // a separate fetch. Other viewers get an empty map — knowing someone's
      // settings is itself a privacy leak.
      visibility: isSelf || isGuardian ? vis : undefined,
      // Lets the client decide what to render without a second round trip:
      // hide Sign Out, lock the visibility screen, gate Discover.
      accountType: user.accountType ?? ACCOUNT_ADULT,
      childPolicy:
        (isSelf || isGuardian) && user.accountType === ACCOUNT_CHILD
          ? user.childPolicy ?? DEFAULT_CHILD_POLICY
          : undefined,
      // Hint to the viewer that fields were redacted, so the UI can show
      // a "limited view" pill instead of guessing.
      isRedacted: !isSelf && !isGuardian &&
        (!lens.canSee(user, "avatar") ||
          !lens.canSee(user, "status") ||
          !lens.canSee(user, "lastSeen")),
      acceptsFriendRequests: (vis.friendRequests ?? "public") === "public",
      awaitingGuardian,
    };
  },
});

/**
 * Sets the user's presence status. Called from the Flutter client whenever the
 * app's lifecycle changes (resume → "online", pause/inactive → "away",
 * detach → "offline"). Also stamps `lastSeen` so other clients can render
 * "last seen N minutes ago" based on the most recent transition.
 *
 * Note: this writes the top-level `status` field (the presence indicator),
 * not `visibility.status` (which controls whether other users can SEE this
 * field). Those are two separate concepts that happen to share a name.
 */
export const updateStatus = mutation({
  args: {
    userId: v.id("users"),
    status: v.string(),
  },
  handler: async (ctx, { userId, status }) => {
    const allowed = new Set(["online", "away", "offline"]);
    if (!allowed.has(status)) return; // ignore unknown values silently
    const user = await ctx.db.get(userId);
    if (!user) return; // user gone — nothing to update
    // Nothing changed and `lastSeen` is still fresh, so the write would only
    // move the timestamp — and every write to a `users` row recomputes each
    // subscription that read it. A lock/unlock cycle sends several transitions
    // that collapse to the same status; the client suppresses the obvious
    // repeats, this catches the rest (a second device, a resumed session).
    // See presence.ts for why the write rate matters here.
    const now = Date.now();
    if (
      user.status === status &&
      user.lastSeen != null &&
      now - user.lastSeen < PRESENCE_WRITE_INTERVAL_MS
    ) {
      return;
    }
    // A real status CHANGE is still written, but not without limit: flipping
    // online/away on a loop rewrote this row, and every subscription reading
    // it, on every call. Over the limit the flip is dropped, not refused.
    try {
      await consume(ctx, `presence:${userId}`, 20, 60 * 1000);
    } catch {
      return;
    }
    await ctx.db.patch(userId, {
      status,
      lastSeen: now,
    });
    // Old builds land in `presence` too (the users patch above is their
    // mirror, so the core must not write it again).
    await setPresenceStatus(ctx, userId, status as PresenceStatus, {
      now,
      mirror: false,
    });
  },
});

/**
 * Lightweight presence keepalive. The client calls this on an interval while
 * signed in so `lastSeen` stays fresh; readers use that timestamp to treat a
 * client that stopped heartbeating (closed tab / killed app) as offline. Only
 * stamps `lastSeen` — the online/away distinction stays owned by updateStatus.
 * Skips a user already marked offline (logged out) so a stray late heartbeat
 * can't resurrect them. See presence.ts.
 */
export const heartbeat = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Session idle expiry's "refreshed on use": at most one write a day per
    // session, an empty index probe otherwise. Before the early returns below,
    // which are about presence and say nothing about the session being used.
    await touchSessions(ctx, userId);
    // Old builds feed `presenceBeats` as well: no resurrect (a late beat from a
    // signed-out client must not bring anyone back) and no mirror (the users
    // throttle below is this path's mirror).
    await noteBeat(ctx, userId, { now: Date.now(), mirror: false });
    const user = await ctx.db.get(userId);
    if (!user || user.status === "offline") return;
    // Usually a pure read. Clients beat every 30s because the round-trip is
    // also their connectivity canary, but `lastSeen` only needs to stay fresher
    // than PRESENCE_OFFLINE_MS — and each write here recomputes every
    // subscription that read this row. See presence.ts.
    const now = Date.now();
    if (
      user.lastSeen != null &&
      now - user.lastSeen < PRESENCE_WRITE_INTERVAL_MS
    ) {
      return;
    }
    await ctx.db.patch(userId, { lastSeen: now });
  },
});

/**
 * Cron backstop: persist the offline demotion for anyone still marked
 * online/away whose last heartbeat is older than the offline window. Readers
 * already compute this on the fly via effectiveStatus; this keeps the STORED
 * value honest too (so any consumer that reads status directly is correct).
 * The lower bound (> 0) skips rows with no lastSeen at all (never heartbeated),
 * which would otherwise be swept the instant they appear.
 */
export const sweepStalePresence = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - COMPAT_OFFLINE_MS;
    // Bounded on purpose. This is a backstop, not a deadline — readers already
    // compute the right answer on the fly via effectiveStatus, so a backlog
    // costs nothing but a few extra ticks. An unbounded .collect() over a
    // growing users table is the opposite trade: it eventually exceeds the
    // read limit or the 1s mutation budget and then the sweep stops working
    // entirely, silently.
    //
    // Scanned per status rather than over `lastSeen` alone, and that is what
    // makes the bound above a page size instead of a permanent ceiling. The
    // old range took the 200 oldest-`lastSeen` rows in the whole table while
    // patching only `status`, so every row it demoted kept its ancient
    // timestamp and stayed in range. Once ~200 dormant accounts sat below the
    // cutoff the sweep re-read that same dead prefix every five minutes and
    // never reached anyone who had newly gone stale — it looked healthy and
    // did nothing. Ranging within a status means a patched row leaves the
    // range on the spot, so each tick sees only live work.
    //
    // The lower bound (> 0) skips rows with no lastSeen at all (never
    // heartbeated), which would otherwise be swept the instant they appear.
    for (const status of ["online", "away"] as const) {
      const stale = await ctx.db
        .query("users")
        .withIndex("by_status_lastSeen", (q) =>
          q.eq("status", status).gt("lastSeen", 0).lt("lastSeen", cutoff),
        )
        .take(200);
      for (const u of stale) {
        await ctx.db.patch(u._id, { status: "offline" });
      }
    }
  },
});

export const updateVisibility = mutation({
  args: {
    userId: v.id("users"),
    avatar: v.optional(v.string()),
    status: v.optional(v.string()),
    lastSeen: v.optional(v.string()),
    seen: v.optional(v.string()),
    friendRequests: v.optional(v.string()),
    feed: v.optional(v.string()),
    points: v.optional(v.string()),
    puzzle: v.optional(v.string()),
    pointsPast: v.optional(v.string()),
  },
  handler: async (
    ctx,
    {
      userId,
      avatar,
      status,
      lastSeen,
      seen,
      friendRequests,
      feed,
      points,
      puzzle,
      pointsPast,
    }
  ) => {
    const user = await getLiveUser(ctx, userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    // A child can't loosen or tighten their own visibility — the guardian
    // bypass in getProfile makes it moot for parents, and letting a child
    // set fields to "public" would expose them to everyone.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_NOT_ALLOWED);
    const valid = new Set(["public", "friends", "nobody"]);
    const reqValid = new Set(["public", "nobody"]);
    const feedValid = new Set(["friends", "nobody"]);
    function pick(level: string | undefined, allowed: Set<string>): string | undefined {
      if (level === undefined) return undefined;
      return allowed.has(level) ? level : undefined;
    }
    // Strip any legacy `bio` key from the stored visibility object before
    // merging — old records may still carry it and the new schema rejects it.
    const prev = { ...(user.visibility ?? {}) } as Record<string, unknown>;
    delete prev.bio;
    const next = {
      ...prev,
      ...(avatar !== undefined ? { avatar: pick(avatar, valid) } : {}),
      ...(status !== undefined ? { status: pick(status, valid) } : {}),
      ...(lastSeen !== undefined ? { lastSeen: pick(lastSeen, valid) } : {}),
      ...(seen !== undefined ? { seen: pick(seen, valid) } : {}),
      ...(friendRequests !== undefined
        ? { friendRequests: pick(friendRequests, reqValid) }
        : {}),
      // Feed keys are friends-or-nobody only. "public" is deliberately not
      // accepted: the board fans out over accepted friendships and nothing
      // else, so storing "public" would be a promise the reader cannot keep.
      // Note these three DEFAULT differently from the rest of this object —
      // see `visibilityOf` in feed.ts, which owns that decision.
      ...(feed !== undefined ? { feed: pick(feed, feedValid) } : {}),
      ...(points !== undefined ? { points: pick(points, feedValid) } : {}),
      ...(puzzle !== undefined ? { puzzle: pick(puzzle, feedValid) } : {}),
      ...(pointsPast !== undefined
        ? { pointsPast: pick(pointsPast, feedValid) }
        : {}),
    };
    await ctx.db.patch(userId, { visibility: next });
    if (status !== undefined || lastSeen !== undefined) {
      await syncLevels(ctx, userId, next as any);
    }

    // Keep `roomMembers.seenVisibility` — the denormalized copy
    // `messages:getReadState` / `getReceiptTimes` read instead of the full
    // `users` row, see schema.ts — in sync. It cannot be read from the owner's
    // row at read time: `users` also carries presence, so every member's
    // heartbeat would re-run those queries again (Phase 5 moves presence out,
    // and this can go then). So the fan-out stays, paged: the first page
    // inline, so a tightening takes effect for the first rooms at once, and
    // the rest chained through the scheduler. Each page stamps the user's
    // CURRENT level, so overlapping edits converge.
    if (seen !== undefined) {
      const next = await restampSeenPage(ctx, userId, null);
      if (next !== null) {
        await ctx.scheduler.runAfter(0, internal.receipts.restampSeenVisibility, {
          userId,
          cursor: next,
        });
      }
    }
  },
});

export const updateProfile = mutation({
  args: {
    userId: v.id("users"),
    name: v.string(),
    email: v.optional(v.string()),
  },
  handler: async (ctx, { userId, name, email }) => {
    const user = await getLiveUser(ctx, userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    // The display name is what renders on every chat bubble, friend request and
    // room list row, so this is the check that actually stops somebody passing
    // themselves off as an official account — and it has to be HERE, not only at
    // signup, or the rule is one profile edit away from meaningless.
    //
    // Not applied to a system account's own row: `problemReports` writes that
    // name with `ctx.db.insert`, and no session exists that could reach this
    // mutation as one anyway.
    if (isReservedName(name)) throw new Error(ERR_DISPLAY_NAME_RESERVED);
    assertCleanName(name);
    // An ABSENT email leaves the stored one alone; only an explicitly empty
    // string clears it. The old code treated both as "delete", which was
    // harmless only because the client always echoed the currently-loaded
    // value back. It no longer can: email is now stripped from friend lists
    // and room member lists, so a profile opened from one of those has
    // `email == null` until getProfile lands — and echoing that back would
    // have silently deleted the user's email on a name change.
    await ctx.db.patch(userId, {
      name: name.trim(),
      searchName: searchNameOf(user.username, name.trim()),
      ...(email !== undefined
        ? { email: email.trim().length > 0 ? email.trim() : undefined }
        : {}),
    });
  },
});

/**
 * Whether a handle could be claimed right now, for the typeahead under every
 * pick-a-username field.
 *
 * ## This is an account-enumeration oracle, and that was the trade
 *
 * `login_screen.dart` used to carry a comment refusing exactly this endpoint,
 * on the grounds that answering "is this name free?" answers "does this account
 * exist?" for anyone who cares to ask. That reasoning was correct and has not
 * stopped being correct. It was overruled deliberately: three of the four
 * screens that pick a handle previously had no feedback at all until submit,
 * and USERNAME_TAKEN-after-the-fact is a poor way to name yourself.
 *
 * So the mitigations are honest ones rather than a pretence that the hole is
 * closed. The client debounces, which cuts incidental traffic and does nothing
 * whatsoever to a script. Nothing here reveals anything the signup form did not
 * already reveal one attempt at a time — same two outcomes, same two reasons,
 * just faster. And it stays a QUERY: no writes, no scheduling, nothing an
 * attacker can make expensive.
 *
 * What it must never become is a lookup that returns anything ABOUT the
 * account. It answers one boolean and a reason for `false`; a caller learning
 * an id, a display name or an avatar from this would be a different and much
 * worse leak than the one knowingly accepted here.
 *
 * NEVER the authority. `auth.signup`, `family.createChildAccount`,
 * `socialAuth.createWithIdentity` and `users.applyUsernameChange` all re-check
 * on the write, in the same transaction, because a name can be claimed between
 * the answer and the tap.
 */
export const isUsernameAvailable = publicQuery({
  args: {
    username: v.string(),
    // Set on the rename sheet. Your CURRENT handle is obviously "taken" — by
    // you — and reporting that would leave the field looking broken the moment
    // it opens, since it opens prefilled with it.
    excludeUserId: v.optional(v.id("users")),
  },
  returns: v.object({
    available: v.boolean(),
    // "invalid" | "reserved" | "taken", absent when available. Mirrors the
    // three ways a write can refuse, so the label and the eventual error agree.
    reason: v.optional(v.string()),
  }),
  handler: async (ctx, { username, excludeUserId }) => {
    const next = username.trim();
    if (next.length === 0 || next.length > 32) {
      return { available: false, reason: "invalid" };
    }
    if (isReservedName(next) || (await isRetiredHandle(ctx, next))) {
      return { available: false, reason: "reserved" };
    }
    // A reason older builds do not know, which they read as "taken" — true
    // enough. See `contentFilter.isObjectionableName`.
    if (isObjectionableName(next)) {
      return { available: false, reason: "inappropriate" };
    }

    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", next))
      .first();
    if (existing && existing._id !== excludeUserId) {
      return { available: false, reason: "taken" };
    }
    return { available: true };
  },
});

/** A handle may be changed once every thirty days. */
export const USERNAME_COOLDOWN_MS = 30 * 24 * 60 * 60 * 1000;

/** Refused when the cooldown above has not elapsed. */
export const ERR_USERNAME_CHANGED_RECENTLY = "USERNAME_CHANGED_RECENTLY";

/**
 * Refused when the account being renamed is the one problem reports are
 * delivered to. See the guard below for why this is its own error.
 */
export const ERR_INBOX_HANDLE_LOCKED = "INBOX_HANDLE_LOCKED";

/**
 * Every rule governing a handle change, in one place.
 *
 * INTERNAL on purpose. The handle is a login credential — `auth.login` and
 * `auth.resetPasswordWithRecoveryKey` both look an account up by it — so
 * changing one has to be proved, and there are two different proofs depending
 * on how the account signs in. Rather than teach this function about both, it
 * takes an already-authorized rename and the two public entry points own the
 * gate: `auth.changeUsername` (password) and
 * `socialAuth.changeUsernameWithIdentity` (a fresh provider token). Both call
 * this, so a rule added here cannot be missed by one of them.
 *
 * The order of the checks is deliberate and is described at each step.
 */
export const applyUsernameChange = internalMutation({
  args: {
    userId: v.id("users"),
    username: v.string(),
  },
  returns: v.object({ username: v.string() }),
  handler: async (ctx, { userId, username }) => {
    const user = await getLiveUser(ctx, userId);
    if (!user) throw new Error("USER_NOT_FOUND");

    // Belt and braces: both callers refuse a child first, but this is the only
    // function that writes the field, so it is the one place the rule cannot be
    // routed around. A supervised account's handle is how a guardian finds them.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    // Shared with the social signup path rather than reimplemented, so a handle
    // accepted at rename is exactly one that would be accepted at creation.
    // Trim and a 32-char ceiling, and deliberately NO charset rule: existing
    // handles may legitimately contain spaces or non-Latin characters, and a
    // regex introduced here — and nowhere else — would lock those users out of
    // the name they already answer to.
    const next = normaliseUsername(username);
    if (next.toLowerCase() !== user.username?.toLowerCase()) {
      await assertNoCaseTwin(ctx, next);
    }

    // A no-op costs nothing and, more to the point, must not spend the thirty
    // days. Someone who opens the sheet, thinks better of it and saves the name
    // they already had should not be locked out of the real change.
    if (next === user.username) return { username: next };

    // The report inbox is resolved BY HANDLE (`problemReports.submit`), not by
    // id, so this account renaming itself would take the delivery address of
    // every problem report in the app with it — silently, and for everybody.
    // `isReservedName` does not cover this: the inbox handle is a person's
    // ordinary name and matches no brand substring, so it is protected only by
    // being occupied. This is what keeps it occupied.
    // Staff handles too: moderator rights follow the handle, so a renamed
    // moderator would leave their rights behind for whoever registers it next.
    if (
      user.username === REPORT_INBOX_USERNAME ||
      isStaffHandle(user.username ?? "")
    ) {
      throw new Error(ERR_INBOX_HANDLE_LOCKED);
    }

    // Before the collision test, for the reason `auth.signup` spells out: system
    // accounts are created lazily, so a reserved handle is simply FREE until the
    // first report is filed, and answering "taken" or "available" would make the
    // rule depend on whether that has happened yet.
    if (isReservedName(next) || (await isRetiredHandle(ctx, next))) {
      throw new Error(ERR_USERNAME_RESERVED);
    }
    assertCleanName(next);

    const changedAt = user.usernameChangedAt;
    if (
      changedAt !== undefined &&
      Date.now() - changedAt < USERNAME_COOLDOWN_MS
    ) {
      throw new Error(ERR_USERNAME_CHANGED_RECENTLY);
    }

    // Uniqueness is PROCEDURAL — Convex has no unique constraints, so this is
    // the same read-then-write as `auth.signup`, and safe for the same reason:
    // a mutation is one serializable transaction, so a racing claim aborts
    // rather than interleaving.
    //
    // Comparing `_id` rather than treating any hit as a collision is what makes
    // a CASE-ONLY change work. `by_username` is exact and case-sensitive, so
    // `bob` → `Bob` finds nothing and passes; the check matters for the
    // narrower case where the index somehow returns this very row.
    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", next))
      .first();
    if (existing && existing._id !== userId) throw new Error("USERNAME_TAKEN");

    await ctx.db.patch(userId, {
      username: next,
      searchName: searchNameOf(next, user.name),
      usernameChangedAt: Date.now(),
    });
    // Handed back so the caller can put the NORMALISED handle into the session
    // rather than the raw string the user typed — otherwise a trailing space
    // would live on in the keychain and in the settings header.
    return { username: next };
  },
});

/**
 * Points the user at a freshly uploaded avatar and hands the clean-up to an
 * `avatar` job.
 *
 * Convex bills for stored files, not for the rows referencing them, so dropping
 * the old id without deleting the blob leaks it permanently, and invisibly,
 * since `_storage` is a system table nothing in the app ever walks. But a user
 * with years of moments and reactions has thousands of denormalized copies of
 * the old id (`moments.authorAvatarStorageId`,
 * `momentReactions.userAvatarStorageId`), so this mutation only patches the
 * row. The job (`avatarSteps`) moves the copies, and deletes the old file as
 * its LAST step, only if it is no longer the current avatar: deleting it here
 * would leave every earlier post pointing at nothing until the job finished.
 */
export const updateAvatar = mutation({
  args: {
    userId: v.id("users"),
    storageId: v.id("_storage"),
  },
  handler: async (ctx, { userId, storageId }) => {
    const user = await getLiveUser(ctx, userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    // Before anything else: an id somebody else uploaded must not become this
    // avatar, or replacing it later would delete their file.
    await claimUpload(ctx, storageId, userId, "avatar");
    const previous = user.avatarStorageId;
    await ctx.db.patch(userId, { avatarStorageId: storageId });
    // The old file's ref is dropped by the avatar job, once its copies moved.
    await attachFile(ctx, storageId, {
      table: "users",
      id: userId.toString(),
      field: "avatarStorageId",
    });
    // Guard against re-submitting the id already stored: the job would find it
    // is still current and do nothing, but there is no point queueing it.
    if (previous && previous !== storageId) {
      // One job per change (`to` is a fresh upload), so a second change while
      // the first is running is not folded into it.
      await enqueueDeletion(ctx, {
        kind: "avatar",
        targetId: `${userId}:${storageId}`,
        args: { userId, from: previous, to: storageId },
      });
    }
  },
});

/** Search-index window read per query; the window is filtered down to `limit`. */
const SEARCH_CANDIDATES = 100;

/**
 * The one search behind both `users.searchUsers` and `friends.searchUsers`.
 *
 * These used to be two independent copies of the same `.collect()`-and-filter
 * over `users`, and had already drifted: only this one applied the blocking
 * filter and the child-safe reachability restriction, so a build calling the
 * other copy could surface a blocked account, or let a supervised child
 * enumerate strangers by fuzzy match — exactly the "one copy gets fixed and
 * the other quietly does not" trap a comment on this function used to warn
 * about while still doing nothing about it. There is now exactly one
 * implementation; `[limit]` is the only thing callers vary.
 *
 * Never reads the `users` table. An exact `by_username` point read comes first
 * (so the handle you were given always surfaces, first), then the
 * `search_users` index (token prefix match over "<handle> <name>", see
 * `userSearch.ts`), then the same filters as ever. A child reads its short
 * reachable list directly instead. The old match was a true substring; the
 * index matches word prefixes ("ann" finds "Anna", "x_anna" and "Hi Anna" but
 * "nna" no longer finds "Anna"), and results are ordered exact handle first,
 * then by relevance rather than by signup order.
 */
export async function searchUsersCore(
  ctx: any,
  currentUserId: any,
  rawQuery: string,
  limit: number
) {
  // Collect ids that should be hidden: anyone *I* have blocked OR who has
  // blocked *me* (in both directions — invisibility is symmetric).
  const blockedByMe = await ctx.db
    .query("blocks")
    .withIndex("by_user", (qb: any) => qb.eq("userId", currentUserId))
    .collect();
  const blockingMe = await ctx.db
    .query("blocks")
    .withIndex("by_blocked", (qb: any) => qb.eq("blockedUserId", currentUserId))
    .collect();
  const hidden = new Set<string>();
  for (const b of blockedByMe) hidden.add(b.blockedUserId.toString());
  for (const b of blockingMe) {
    if (b.blockedUserId.toString() === currentUserId.toString()) {
      hidden.add(b.userId.toString());
    }
  }

  // A child searching gets a nearly-closed world: their family and their
  // approved contacts match as they type, exactly like an adult's search.
  // Anyone else surfaces ONLY on a complete, exact username — so a child
  // can reach someone whose handle they were given in person, but can't
  // browse, guess, or enumerate their way to a stranger.
  let reachable: Set<string> | null = null;
  if (await isChild(ctx, currentUserId)) {
    reachable = await familyOf(ctx, currentUserId);
    const mine = await ctx.db
      .query("friendships")
      .withIndex("by_user", (qf: any) => qf.eq("userId", currentUserId))
      .collect();
    for (const f of mine) {
      if (f.status === "accepted") reachable.add(f.friendId.toString());
    }
    const theirs = await ctx.db
      .query("friendships")
      .withIndex("by_friend", (qf: any) => qf.eq("friendId", currentUserId))
      .collect();
    for (const f of theirs) {
      if (f.status === "accepted") reachable.add(f.userId.toString());
    }
  }

  const lens = await lensFor(ctx, currentUserId);
  const now = Date.now();
  const trimmed = rawQuery.trim();
  const needle = trimmed.toLowerCase();
  // Nothing typed matches nothing: the old scan answered an empty query with
  // the first rows of the table, which is an enumeration, not a search. The
  // app never sends one (the people tab shows nothing until you type).
  if (needle.length === 0) return [];

  // Candidates, in the order they will be shown. Exact handles first: they are
  // the one result a person who was told a handle in person is looking for, and
  // a child may only ever reach a stranger this way. `by_username` is
  // case-sensitive and handles may be mixed-case, so both spellings are read;
  // a stored "Bob" typed as "bob" also arrives through the search below and is
  // lifted by the `handle === needle` check.
  const found = new Map<string, any>();
  for (const handle of new Set([needle, trimmed])) {
    const exact = await ctx.db
      .query("users")
      .withIndex("by_username", (qu: any) => qu.eq("username", handle))
      .first();
    if (exact) found.set(exact._id.toString(), exact);
  }
  if (reachable === null) {
    // An adult: token/prefix search over "<handle> <name>", a bounded window of
    // the best matches. Oversampled because children, the viewer, blocked and
    // suspended accounts are dropped below. A row not yet backfilled with
    // `searchName` is findable by its exact handle only.
    const hits = await ctx.db
      .query("users")
      .withSearchIndex("search_users", (qs: any) =>
        qs.search("searchName", needle.slice(0, 64))
      )
      .take(SEARCH_CANDIDATES);
    for (const u of hits) found.set(u._id.toString(), u);
  } else {
    // A child: fuzzy only within people they already have, which is a short,
    // known list. Reading it directly beats searching the whole table and then
    // throwing every stranger away.
    for (const id of reachable) {
      if (found.has(id)) continue;
      const u = await ctx.db.get(id as any);
      if (u) found.set(id, u);
    }
  }

  const matched = [...found.values()].filter((u: any) => {
      if (u._id === currentUserId) return false;
      // Being deleted: the row lingers until its teardown finishes.
      if (isTombstoned(u)) return false;
      if (hidden.has(u._id.toString())) return false;
      // System accounts are not people and cannot be addressed — see
      // `systemAccount.ts`. Search is the main way one could be found at all,
      // so this filter is most of what "private" means for that row: it sends
      // no friend requests, joins no public rooms, and appears in no roster
      // except the single DM it writes to.
      if (isSystemAccount(u)) return false;
      // Banned accounts are unfindable for as long as the ban lasts. See
      // `moderation.suspendAccount`.
      if (u.suspendedAt !== undefined) return false;
      const handle = u.username.toLowerCase();
      const fuzzy =
        handle.includes(needle) ||
        (u.name ?? "").toLowerCase().includes(needle);
      if (reachable === null) {
        // An adult finds a child only by their exact handle, given to them
        // in person: browsing a substring must not list children to anyone.
        if (u.accountType === "child") {
          return handle === needle;
        }
        return fuzzy;
      }
      // Child: fuzzy within the people they already have, exact anywhere.
      if (reachable.has(u._id.toString())) return fuzzy;
      return handle === needle;
    });
  // Stable: exact handles first, everything else in relevance order.
  const isExact = (u: any) => u.username.toLowerCase() === needle;
  const filtered = [
    ...matched.filter(isExact),
    ...matched.filter((u: any) => !isExact(u)),
  ].slice(0, limit);

  return Promise.all(
    filtered.map(async (u: any) => {
      const outgoing = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (query: any) =>
          query.eq("userId", currentUserId).eq("friendId", u._id)
        )
        .first();
      const incoming = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (query: any) =>
          query.eq("userId", u._id).eq("friendId", currentUserId)
        )
        .first();

      let friendshipStatus = "none";
      let requestId = undefined;
      if (outgoing?.status === "accepted" || incoming?.status === "accepted") {
        friendshipStatus = "friend";
      } else if (outgoing?.status === "pending") {
        friendshipStatus = "outgoingPending";
        requestId = outgoing._id;
      } else if (incoming?.status === "pending") {
        friendshipStatus = "incomingPending";
        requestId = incoming._id;
      }

      // Is this row parked at the VIEWER'S OWN guardian hop?
      //
      // Narrowly the viewer's own, and that restriction is the whole design.
      // A row held at the OTHER end's guardian would tell an adult sender that
      // the person they asked for is a child, which nothing in this app is
      // allowed to reveal (see `RequestStage.senderLabel` on the client, which
      // deliberately collapses that case into a flat "waiting for them").
      //
      // Here it says something the viewer already knows about themselves, and
      // it fixes a live lie: a child searching for the exact handle of someone
      // who has asked to add them got an actionable APPROVE, because the
      // status above reads the row's existence and not its stage. Tapping it
      // called `approveDirectRequest`, which refuses anything a guardian has
      // not released, so the button could only ever fail. The row is already
      // visible on this surface; what was missing was the truth about it.
      const awaitingGuardian =
        (outgoing?.status === "pending" &&
          outgoing.stage === STAGE_SENDER_GUARDIAN) ||
        (incoming?.status === "pending" &&
          incoming.stage === STAGE_RECIPIENT_GUARDIAN);

      return {
        _id: u._id,
        username: u.username,
        name: u.name ?? u.username,
        // Discover is the surface a stranger reaches you through, so it is
        // the LAST place that may ignore the setting. Someone at "avatar:
        // friends" is searchable by handle and still faceless until they
        // accept you.
        ...lens.identity(u, now),
        friendshipStatus,
        requestId,
        awaitingGuardian,
      };
    })
  );
}

export const searchUsers = query({
  args: { query: v.string(), currentUserId: v.id("users") },
  handler: async (ctx, { query: q, currentUserId }) =>
    searchUsersCore(ctx, currentUserId, q, 20),
});

// ─────────────────────────────── Blocking ───────────────────────────────

export const blockUser = mutation({
  args: {
    userId: v.id("users"),
    targetUserId: v.id("users"),
    /**
     * When true, also wipes the shared DM room between the two users
     * (messages, reactions, media, the room itself, and both memberships).
     * Group rooms the two share are NOT touched — the blocker can leave
     * those manually. The target is never notified either way.
     */
    deleteDm: v.optional(v.boolean()),
  },
  handler: async (ctx, { userId, targetUserId, deleteDm }) =>
    await blockCore(ctx, userId, targetUserId, deleteDm === true),
});

/**
 * Deletes a friendship row, and with it the messages riding on a pending
 * request.
 *
 * `friendRequestMessages.requestId` points at the friendship row, so every
 * path that removes a pending row has to take them too or they are orphaned
 * for good: unfriend, reject, block, account deletion. One helper so no path
 * can forget. Only an unaccepted row can have any (accepting a request
 * migrates them into the DM and clears them), so an accepted row costs no extra
 * read.
 * The per-request cap on writes is 20, so `take(100)` is the whole set.
 */
export async function deleteFriendshipRow(ctx: any, friendship: any) {
  if (friendship.status !== "accepted") {
    await clearFriendRequestMessages(ctx, friendship._id);
  }
  await ctx.db.delete(friendship._id);
}

/** Deletes the messages riding on one request. Bounded by `by_request`. */
export async function clearFriendRequestMessages(ctx: any, requestId: any) {
  const messages = await ctx.db
    .query("friendRequestMessages")
    .withIndex("by_request", (q: any) => q.eq("requestId", requestId))
    .take(100);
  for (const m of messages) await ctx.db.delete(m._id);
}

/**
 * Everything `blockUser` does, as a plain function, so a report can block in
 * the same transaction it files in ("Also block this person" on the report
 * sheet) instead of the client making two calls that can half-succeed.
 */
export async function blockCore(
  ctx: any,
  userId: any,
  targetUserId: any,
  deleteDm: boolean,
) {
    if (userId.toString() === targetUserId.toString()) {
      throw new Error("CANT_BLOCK_SELF");
    }
    // A block on an account being deleted would dangle: the teardown's blocks
    // step may have run already.
    if (!(await getLiveUser(ctx, targetUserId))) throw new Error("USER_NOT_FOUND");
    // Idempotent: don't insert if a pair row already exists.
    const existing = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", userId).eq("blockedUserId", targetUserId)
      )
      .first();
    if (!existing) {
      await ctx.db.insert("blocks", {
        userId,
        blockedUserId: targetUserId,
        createdAt: Date.now(),
      });
    }

    // Tear down any existing friendship so the block is binding.
    // Point reads on the pair index, one per direction: the cost is the pair's
    // own rows, not everything either account has ever sent or received.
    const forward = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", userId).eq("friendId", targetUserId)
      )
      .collect();
    for (const f of forward) await deleteFriendshipRow(ctx, f);
    const reverse = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", targetUserId).eq("friendId", userId)
      )
      .collect();
    for (const f of reverse) await deleteFriendshipRow(ctx, f);

    if (deleteDm) {
      // A pair can hold more than one DM (regular + Chamber of Secrets), so
      // this wipes every one it finds — see `findDmRoomsBetween`.
      for (const roomId of await findDmRoomsBetween(ctx, userId, targetUserId)) {
        await wipeRoomCompletely(ctx, roomId);
      }
    }
}

export const unblockUser = mutation({
  args: { userId: v.id("users"), targetUserId: v.id("users") },
  handler: async (ctx, { userId, targetUserId }) => {
    const existing = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", userId).eq("blockedUserId", targetUserId)
      )
      .first();
    if (existing) {
      await ctx.db.delete(existing._id);
    }
  },
});

/**
 * Returns the user-profiles this account has blocked, including the
 * blocked person's username/name/avatar so the UI can render an unblock list.
 */
export const listBlocked = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("blocks")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    const out: Array<{
      _id: string;
      username: string;
      name: string;
      avatarStorageId?: string;
    }> = [];
    const lens = await lensFor(ctx, userId);
    for (const r of rows) {
      const u = await ctx.db.get(r.blockedUserId);
      if (!u) continue;
      out.push({
        _id: u._id.toString(),
        username: u.username,
        name: u.name ?? u.username,
        // Blocking someone does not earn you their face. The handle and name
        // identify the row well enough to unblock it, and a blocked person is
        // by definition not a friend — so "friends" and "nobody" both land on
        // the initials fallback here, which is the correct reading.
        avatarStorageId: lens.canSee(u, "avatar") ? u.avatarStorageId : undefined,
      });
    }
    return out;
  },
});

/**
 * True when EITHER user has blocked the other — used by clients before
 * showing message-send or friend-request UI. The backend should ALSO check
 * inside sendRequest/sendMessage; this is convenience.
 */
export const isBlocked = query({
  args: { userId: v.id("users"), otherUserId: v.id("users") },
  handler: async (ctx, { userId, otherUserId }) => {
    const a = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", userId).eq("blockedUserId", otherUserId)
      )
      .first();
    if (a) return true;
    const b = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", otherUserId).eq("blockedUserId", userId)
      )
      .first();
    return !!b;
  },
});

// ─────────────────────────────── Reporting ───────────────────────────────

/**
 * Files a content report. The `reports` row, then Monkey Reporter's card in
 * the moderation room with the reported message and the last few messages of
 * the conversation as evidence — what the report sheet tells the user will
 * happen. See `moderationCore.fileContentReport`.
 *
 * [alsoBlock] is the sheet's "Also block this person" box: the block is
 * written in this same mutation, so a report never lands without the block
 * the user asked for, or the other way round. Ignored for a room report,
 * which has no one person to block.
 *
 * The reported person is never told, and nothing here writes anywhere they
 * can read.
 */
export const report = mutation({
  // The caller IS the reporter. Without this the wrapper injects `userId`,
  // which this handler does not read, and `reporterId` stayed whatever the
  // client sent — so anyone could file reports in somebody else's name and
  // spend their rate limit. Same fix as `users.getProfile`'s `viewerUserId`.
  identityArg: "reporterId" as const,
  args: {
    reporterId: v.id("users"),
    targetType: v.string(), // "user" | "message" | "room"
    targetId: v.string(),
    reason: v.string(),
    note: v.optional(v.string()),
    alsoBlock: v.optional(v.boolean()),
  },
  returns: v.object({
    ok: v.boolean(),
    blocked: v.boolean(),
  }),
  handler: async (
    ctx,
    { reporterId, targetType, targetId, reason, note, alsoBlock },
  ) => {
    // A person's report carries the context of the caller's DM with them, if
    // any — the thing a moderator needs to judge a report made from a profile.
    let evidenceRoomId: any;
    if (targetType === "user") {
      const target = ctx.db.normalizeId("users", targetId);
      if (target) {
        evidenceRoomId = (await findDmRoomsBetween(ctx, reporterId, target))[0];
      }
    }
    const filed = await fileContentReport(ctx, {
      reporterId,
      targetType,
      targetId,
      reason,
      note,
      evidenceRoomId,
    });
    let blocked = false;
    if (alsoBlock === true && targetType !== "room" && filed.reportedUserId) {
      await blockCore(ctx, reporterId, filed.reportedUserId, false);
      blocked = true;
    }
    return { ok: true, blocked };
  },
});

/** How long a moderation report is kept. Stated in the privacy policy. */
export const REPORT_RETENTION_MS = 24 * 30 * 24 * 60 * 60 * 1000; // ~24 months

/** Rows per run of [gcExpiredReports]; a full page schedules the next. */
const REPORTS_GC_PAGE = 200;

/**
 * Deletes reports past the retention period.
 *
 * Unlike every other sweep in `crons.ts`, this one is not a garbage collector
 * cleaning up after a path that already tidies itself — it is the mechanism
 * that makes a published promise true. The privacy policy states a 24-month
 * retention period for reports, and a stated period with no job behind it is
 * just a longer way of saying "indefinitely".
 *
 * Deliberately unconditional on `status`. A resolved report and one nobody ever
 * looked at are the same thing to a data subject, and carving out the open ones
 * would quietly reintroduce indefinite retention for exactly the records most
 * likely to name a child.
 *
 * Batched at 200 like the other sweeps: the cron runs daily and the table is
 * small, so a backlog drains over a few days rather than risking the 1s
 * function limit on a box that is also serving live traffic.
 */
export const gcExpiredReports = internalMutation({
  args: sweepArgs,
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - REPORT_RETENTION_MS;
    const expired = await ctx.db
      .query("reports")
      .withIndex("by_createdAt", (q) => q.lt("createdAt", cutoff))
      .take(REPORTS_GC_PAGE);
    for (const r of expired) await ctx.db.delete(r._id);
    await continueSweep(
      ctx,
      internal.users.gcExpiredReports,
      expired.length === REPORTS_GC_PAGE,
      chain,
    );
  },
});
