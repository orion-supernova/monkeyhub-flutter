import { internalMutation, mutation, query } from "./_generated/server";
import { v } from "convex/values";
import {
  effectiveStatus,
  PRESENCE_OFFLINE_MS,
  PRESENCE_WRITE_INTERVAL_MS,
} from "./presence";
import { deleteStored } from "./files";
import { SOCIAL_ONLY_PASSWORD_SENTINEL } from "./socialAuth";
import {
  ACCOUNT_ADULT,
  ACCOUNT_CHILD,
  DEFAULT_CHILD_POLICY,
  ERR_NOT_ALLOWED,
  familyOf,
  isChild,
  isGuardianOf,
} from "./childGuard";
import { findDmRoomsBetween, wipeRoomCompletely } from "./roomCleanup";

/**
 * Returns a user's profile, with per-field redaction based on the viewer's
 * relationship to the subject. Pass `viewerUserId` so the backend can apply
 * the subject's visibility rules. Callers omitting `viewerUserId` get the
 * public-only view (used for self-lookups via login response, etc.).
 *
 * Visibility values per field:
 *   "public"  → anyone sees it
 *   "friends" → only accepted friends see it (and the user themselves)
 *   "nobody"  → only the user themselves sees it
 *
 * `friendRequests` doesn't affect the profile payload directly — it's
 * enforced at request-mutation time.
 */
export const getProfile = query({
  args: {
    userId: v.id("users"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { userId, viewerUserId }) => {
    const user = await ctx.db.get(userId);
    if (!user) return null;

    const isSelf =
      viewerUserId !== undefined && viewerUserId.toString() === userId.toString();

    // Guardian bypass. This is how "everything enabled for their parents to
    // check" is delivered WITHOUT making the child public to the world: the
    // child's visibility map stays as restrictive as we like, and guardians
    // simply aren't subject to it. Strangers still see a redacted profile.
    const isGuardian =
      viewerUserId !== undefined &&
      !isSelf &&
      (await isGuardianOf(ctx, viewerUserId, userId));

    // Friends check.
    let isFriend = false;
    if (viewerUserId && !isSelf) {
      const a = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (q) =>
          q.eq("userId", viewerUserId).eq("friendId", userId)
        )
        .first();
      const b = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (q) =>
          q.eq("userId", userId).eq("friendId", viewerUserId)
        )
        .first();
      isFriend = a?.status === "accepted" || b?.status === "accepted";
    }

    function canSee(level: string | undefined): boolean {
      if (isSelf || isGuardian) return true;
      const v = level ?? "public";
      if (v === "public") return true;
      if (v === "friends") return isFriend;
      return false; // "nobody"
    }

    const vis = user.visibility ?? {};
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
      avatarStorageId: canSee(vis.avatar) ? user.avatarStorageId : undefined,
      status: canSee(vis.status)
        ? effectiveStatus(user.status, user.lastSeen)
        : undefined,
      lastSeen: canSee(vis.lastSeen) ? user.lastSeen : undefined,
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
        (!canSee(vis.avatar) ||
          !canSee(vis.status) ||
          !canSee(vis.lastSeen)),
      acceptsFriendRequests: (vis.friendRequests ?? "public") === "public",
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
    await ctx.db.patch(userId, {
      status,
      lastSeen: now,
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
    const cutoff = Date.now() - PRESENCE_OFFLINE_MS;
    // Bounded on purpose. This is a backstop, not a deadline — readers already
    // compute the right answer on the fly via effectiveStatus, so a backlog
    // costs nothing but a few extra ticks. An unbounded .collect() over a
    // growing users table is the opposite trade: it eventually exceeds the
    // read limit or the 1s mutation budget and then the sweep stops working
    // entirely, silently.
    const stale = await ctx.db
      .query("users")
      .withIndex("by_lastSeen", (q) => q.gt("lastSeen", 0).lt("lastSeen", cutoff))
      .take(200);
    for (const u of stale) {
      if (u.status !== "offline") {
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
  },
  handler: async (
    ctx,
    { userId, avatar, status, lastSeen, seen, friendRequests }
  ) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    // A child can't loosen or tighten their own visibility — the guardian
    // bypass in getProfile makes it moot for parents, and letting a child
    // set fields to "public" would expose them to everyone.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_NOT_ALLOWED);
    const valid = new Set(["public", "friends", "nobody"]);
    const reqValid = new Set(["public", "nobody"]);
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
    };
    await ctx.db.patch(userId, { visibility: next });
  },
});

export const updateProfile = mutation({
  args: {
    userId: v.id("users"),
    name: v.string(),
    email: v.optional(v.string()),
  },
  handler: async (ctx, { userId, name, email }) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    // An ABSENT email leaves the stored one alone; only an explicitly empty
    // string clears it. The old code treated both as "delete", which was
    // harmless only because the client always echoed the currently-loaded
    // value back. It no longer can: email is now stripped from friend lists
    // and room member lists, so a profile opened from one of those has
    // `email == null` until getProfile lands — and echoing that back would
    // have silently deleted the user's email on a name change.
    await ctx.db.patch(userId, {
      name: name.trim(),
      ...(email !== undefined
        ? { email: email.trim().length > 0 ? email.trim() : undefined }
        : {}),
    });
  },
});

/**
 * Points the user at a freshly uploaded avatar and frees the one it replaces.
 *
 * Convex bills for stored files, not for the rows referencing them, so dropping
 * the old id without deleting the blob leaks it permanently — and invisibly,
 * since `_storage` is a system table nothing in the app ever walks. Every
 * avatar change used to cost another copy forever.
 */
export const updateAvatar = mutation({
  args: {
    userId: v.id("users"),
    storageId: v.id("_storage"),
  },
  handler: async (ctx, { userId, storageId }) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    const previous = user.avatarStorageId;
    await ctx.db.patch(userId, { avatarStorageId: storageId });
    // Guard against re-submitting the id already stored: that would delete the
    // file the row now points at and leave the user with a broken avatar.
    if (previous && previous !== storageId) {
      await deleteStored(ctx, previous);
    }
  },
});

export const searchUsers = query({
  args: { query: v.string(), currentUserId: v.id("users") },
  handler: async (ctx, { query: q, currentUserId }) => {
    // Collect ids that should be hidden: anyone *I* have blocked OR who has
    // blocked *me* (in both directions — invisibility is symmetric).
    const blockedByMe = await ctx.db
      .query("blocks")
      .withIndex("by_user", (qb) => qb.eq("userId", currentUserId))
      .collect();
    const blockingMe = await ctx.db
      .query("blocks")
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
        .withIndex("by_user", (qf) => qf.eq("userId", currentUserId))
        .collect();
      for (const f of mine) {
        if (f.status === "accepted") reachable.add(f.friendId.toString());
      }
      const theirs = await ctx.db
        .query("friendships")
        .withIndex("by_friend", (qf) => qf.eq("friendId", currentUserId))
        .collect();
      for (const f of theirs) {
        if (f.status === "accepted") reachable.add(f.userId.toString());
      }
    }

    const needle = q.trim().toLowerCase();
    const users = await ctx.db.query("users").collect();
    const filtered = users
      .filter((u) => {
        if (u._id === currentUserId) return false;
        if (hidden.has(u._id.toString())) return false;
        const handle = u.username.toLowerCase();
        const fuzzy =
          handle.includes(needle) ||
          (u.name ?? "").toLowerCase().includes(needle);
        if (reachable === null) return fuzzy; // adult — unchanged
        // Child: fuzzy within the people they already have, exact anywhere.
        if (reachable.has(u._id.toString())) return fuzzy;
        return needle.length > 0 && handle === needle;
      })
      .slice(0, 20);

    const enriched = await Promise.all(
      filtered.map(async (u) => {
        const outgoing = await ctx.db
          .query("friendships")
          .withIndex("by_pair", (query) =>
            query.eq("userId", currentUserId).eq("friendId", u._id)
          )
          .first();
        const incoming = await ctx.db
          .query("friendships")
          .withIndex("by_pair", (query) =>
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

        return {
          _id: u._id,
          username: u.username,
          name: u.name ?? u.username,
          status: effectiveStatus(u.status, u.lastSeen),
          avatarStorageId: u.avatarStorageId,
          friendshipStatus,
          requestId,
        };
      })
    );

    return enriched;
  },
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
  handler: async (ctx, { userId, targetUserId, deleteDm }) => {
    if (userId.toString() === targetUserId.toString()) {
      throw new Error("CANT_BLOCK_SELF");
    }
    // Idempotent: don't insert if a pair row already exists.
    const existing = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
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
    const friendships = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    for (const f of friendships) {
      if (f.friendId.toString() === targetUserId.toString()) {
        await ctx.db.delete(f._id);
      }
    }
    const reverse = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q) => q.eq("userId", targetUserId))
      .collect();
    for (const f of reverse) {
      if (f.friendId.toString() === userId.toString()) {
        await ctx.db.delete(f._id);
      }
    }

    if (deleteDm) {
      // A pair can hold more than one DM (regular + Chamber of Secrets), so
      // this wipes every one it finds — see `findDmRoomsBetween`.
      for (const roomId of await findDmRoomsBetween(ctx, userId, targetUserId)) {
        await wipeRoomCompletely(ctx, roomId);
      }
    }
  },
});

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
    for (const r of rows) {
      const u = await ctx.db.get(r.blockedUserId);
      if (!u) continue;
      out.push({
        _id: u._id.toString(),
        username: u.username,
        name: u.name ?? u.username,
        avatarStorageId: u.avatarStorageId,
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

export const report = mutation({
  args: {
    reporterId: v.id("users"),
    targetType: v.string(), // "user" | "message" | "room"
    targetId: v.string(),
    reason: v.string(),
    note: v.optional(v.string()),
  },
  handler: async (ctx, { reporterId, targetType, targetId, reason, note }) => {
    if (!["user", "message", "room"].includes(targetType)) {
      throw new Error("INVALID_TARGET_TYPE");
    }
    await ctx.db.insert("reports", {
      reporterId,
      targetType,
      targetId,
      reason,
      note: note && note.length > 0 ? note : undefined,
      createdAt: Date.now(),
      status: "open",
    });
  },
});

/** How long a moderation report is kept. Stated in the privacy policy. */
export const REPORT_RETENTION_MS = 24 * 30 * 24 * 60 * 60 * 1000; // ~24 months

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
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - REPORT_RETENTION_MS;
    const expired = await ctx.db
      .query("reports")
      .withIndex("by_createdAt", (q) => q.lt("createdAt", cutoff))
      .take(200);
    for (const r of expired) await ctx.db.delete(r._id);
  },
});
