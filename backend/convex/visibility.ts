import { effectiveStatus } from "./presence";
import { childrenOf } from "./childGuard";
// Imports nothing itself, so this cannot cycle — see the note at the top of
// `systemAccount.ts` on why that module exists.
import { isSystemAccount } from "./systemAccount";

/**
 * Per-field privacy, resolved once per query and applied at EVERY read site.
 *
 * This exists because the setting used to be enforced in exactly one place —
 * `users.getProfile` — while a dozen other queries handed the same three
 * fields out raw. Setting "avatar: nobody" blanked your profile page and
 * nothing else: your face still appeared in the room member sheet, the typing
 * indicator, the friends list, Discover, the ringer, the group-call grid and
 * the feed. A privacy control that only covers one of thirteen surfaces is
 * worse than none, because it tells the user they're covered.
 *
 * The rule is now: any query that returns another user's `avatarStorageId`,
 * `status` or `lastSeen` builds a lens and passes the row through it. There is
 * no second implementation of the level check to drift out of sync.
 *
 * Levels, exactly as `users.setVisibility` stores them:
 *   "public"  → anyone
 *   "friends" → accepted friendships only
 *   "nobody"  → the subject alone
 *
 * Two viewers are never subject to it: the subject themselves, and a guardian
 * looking at their own child. That's how "everything on for their parents"
 * coexists with a locked-down child account — the child's map stays
 * restrictive and guardians simply aren't bound by it.
 */

/** The identity fields this module owns. Feed keys live in feed.ts. */
export type VisField = "avatar" | "status" | "lastSeen" | "seen";

/**
 * Level used when the stored map has no entry for a field.
 *
 * These are NOT uniform, and the difference is deliberate — which is exactly
 * why they belong in one table instead of being re-decided per call site:
 *
 *   avatar / status / lastSeen → "public". What `users.getProfile` has always
 *     done. Defaulting these closed would blank the avatar of every account
 *     that has never opened the visibility screen, which is most of them.
 *
 *   seen (read receipts) → "nobody". What `messages.getReadState` has always
 *     done, and the stricter default is right: a read receipt is a claim about
 *     someone's behaviour, not their identity, and it should be opted into.
 *
 * Note these are also NOT the client model's defaults — `ChatUser`'s
 * `ProfileVisibility` fails closed to "nobody" across the board. The server's
 * reading is the one that decides what actually leaves the database, so the
 * server's is the one spelled out here.
 */
const DEFAULT_LEVEL: Record<VisField, string> = {
  avatar: "public",
  status: "public",
  lastSeen: "public",
  seen: "nobody",
};

/**
 * Fields a guardian sees on their own child regardless of the child's setting.
 *
 * Scoped to exactly what the supervised-account screen promises the child —
 * "They can always see your picture, when you're online and when you were last
 * around" — and no more. Read receipts are deliberately absent: nobody was
 * told a parent would see those, so the bypass does not quietly reach them.
 */
const GUARDIAN_BYPASS: ReadonlySet<VisField> = new Set<VisField>([
  "avatar",
  "status",
  "lastSeen",
]);

export type PrivacyLens = {
  /** null for an unauthenticated/omitted viewer — sees public fields only. */
  readonly viewerId: string | null;
  isSelf(subjectId: any): boolean;
  isFriend(subjectId: any): boolean;
  /** True when the viewer supervises this subject. */
  isGuardian(subjectId: any): boolean;
  /** Pass the whole `users` ROW — the level is read off `row.visibility`. */
  canSee(subject: any, field: VisField): boolean;
  /**
   * The three identity fields, redacted. Hidden fields come back `undefined`
   * rather than nulled or zeroed: the client renders the gradient-initials
   * fallback for a missing avatar and no status dot for a missing status, so
   * "hidden" and "not set" land on the same, already-correct UI.
   *
   * `now` has no default — see `presence.effectiveStatus`, which this calls
   * into for the `status` field. Pass one `Date.now()` computed at the top of
   * the calling handler so every subject resolved in the same query is
   * judged against the same instant.
   */
  identity(subject: any, now: number): {
    avatarStorageId?: any;
    status?: string;
    lastSeen?: number;
  };
};

/**
 * Builds a lens for [viewerUserId].
 *
 * Costs three index scans, ONCE, no matter how many subjects are then tested —
 * which is the reason this is a lens and not a `canSee(ctx, viewer, subject)`
 * helper. A 50-member room would have meant 100 pair lookups per render of the
 * member sheet, and that cost is exactly what tempts the next author to skip
 * the check.
 *
 * Pass `undefined` for anonymous callers; they get the public-only view.
 */
export async function lensFor(
  ctx: any,
  viewerUserId: any
): Promise<PrivacyLens> {
  const viewerId = viewerUserId ? viewerUserId.toString() : null;
  const friends = new Set<string>();
  const wards = new Set<string>();

  if (viewerUserId) {
    // Both directions. An accepted friendship writes two directed rows, so
    // `by_user` alone would do — but a half-written pair (a crash between the
    // two inserts) would silently read as "not friends" on one side only, and
    // scanning both makes the lens agree with itself regardless of direction.
    const outgoing = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q: any) => q.eq("userId", viewerUserId))
      .collect();
    for (const f of outgoing) {
      if (f.status === "accepted") friends.add(f.friendId.toString());
    }
    const incoming = await ctx.db
      .query("friendships")
      .withIndex("by_friend", (q: any) => q.eq("friendId", viewerUserId))
      .collect();
    for (const f of incoming) {
      if (f.status === "accepted") friends.add(f.userId.toString());
    }

    for (const childId of await childrenOf(ctx, viewerUserId)) {
      wards.add(childId.toString());
    }
  }

  function key(id: any): string {
    return id?.toString() ?? "";
  }

  const lens: PrivacyLens = {
    viewerId,
    isSelf: (id) => viewerId !== null && key(id) === viewerId,
    isFriend: (id) => friends.has(key(id)),
    isGuardian: (id) => wards.has(key(id)),
    canSee(subject, field) {
      const id = subject?._id;
      if (lens.isSelf(id)) return true;
      if (lens.isGuardian(id) && GUARDIAN_BYPASS.has(field)) return true;
      const level = subject?.visibility?.[field] ?? DEFAULT_LEVEL[field];
      if (level === "public") return true;
      if (level === "friends") return lens.isFriend(id);
      return false; // "nobody"
    },
    identity(subject, now) {
      return {
        // `undefined`, not the raw id — Convex ships whatever the handler
        // returns, so omitting the key IS the redaction.
        avatarStorageId: lens.canSee(subject, "avatar")
          ? subject?.avatarStorageId
          : undefined,
        // Staleness-corrected on the way out, so no caller has to remember to
        // do it and none can forget. See presence.ts.
        status: lens.canSee(subject, "status")
          ? effectiveStatus(subject?.status, subject?.lastSeen, now)
          : undefined,
        lastSeen: lens.canSee(subject, "lastSeen")
          ? subject?.lastSeen
          : undefined,
      };
    },
  };

  return lens;
}

/**
 * The `visibility.seen` snapshot a new `roomMembers` row should be inserted
 * with, so `messages:getReadState` never has to fall back to `users`.
 *
 * A one-time read at membership-creation time, not a query — cheap, and
 * every one of the half-dozen `roomMembers` insert sites across the codebase
 * needs the exact same value, which is the duplicated-read-path trap this
 * file's own header comment warns about. `updateVisibility` keeps existing
 * rows in sync when the setting later changes; this only handles the
 * membership's first write.
 */
export async function seenVisibilityOf(ctx: any, userId: any): Promise<string | undefined> {
  const user = await ctx.db.get(userId);
  return user?.visibility?.seen;
}

/**
 * The fields of a `users` row any other user may see, already redacted.
 *
 * Spreading a user document is a data leak — a row carries `passwordHash`,
 * `recoveryKeyHash`, the push routing tokens, `birthYear`, and the
 * `visibility` / `childPolicy` blocks that are self-or-guardian only. With no
 * `returns:` validator on a Convex handler, the shape of this object IS the
 * access-control boundary, so add a field here only after asking whether every
 * stranger who can address a friend request to you should have it.
 */
export function publicUserView(lens: PrivacyLens, user: any, now: number) {
  return {
    _id: user._id,
    username: user.username,
    name: user.name,
    // No `email`. It used to be here, and it failed the test above: a stranger
    // who can address a friend request to you should not learn your address.
    // `users.getProfile` serves it to self and guardians only.
    ...lens.identity(user, now),
    // Passes the test above trivially: it is not a fact ABOUT anyone, it is the
    // statement that this row is the app rather than a person. Only ever true
    // for a row `problemReports.ensureLogAccount` wrote, so it discloses
    // nothing a human account could be embarrassed by, and it is what lets the
    // client stop offering to call, befriend or profile something that will
    // never answer. Omitted rather than `false` for the 99.99% case — the wire
    // shape stays exactly as it was for every real user.
    ...(isSystemAccount(user) ? { isSystem: true } : {}),
  };
}
