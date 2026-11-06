import { presenceOf } from "./profileView";
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
 * By product decision (2026-10-07):
 *
 *   avatar → "public". A face is how a friend request, a Discover result or a
 *     stranger in a group is recognised at all; hiding it by default would
 *     turn all of those into initials.
 *
 *   status / lastSeen / seen → "friends". These used to be "public" for
 *     presence and "nobody" for read receipts, which meant a stranger saw when
 *     you were online while your own friends never got a second tick or a
 *     SEEN. Behaviour is for the people you added, and only them.
 *
 * A stored value always wins, so anyone who picked "public" or "nobody" keeps
 * exactly what they picked. Only accounts that never touched a field move.
 *
 * The client model (`ProfileVisibility` in chat_user.dart) reads an absent
 * field the same way, so the visibility screen shows what is really enforced.
 * Read the level through [levelOf], never `visibility?.x ?? "<literal>"` — a
 * literal at a call site is how the push paths ended up disagreeing with this
 * table about whose avatar was public.
 */
export const DEFAULT_LEVEL: Record<VisField, string> = {
  avatar: "public",
  status: "friends",
  lastSeen: "friends",
  seen: "friends",
};

/** The effective level of [field] on a `users` row, default applied. */
export function levelOf(subject: any, field: VisField): string {
  return subject?.visibility?.[field] ?? DEFAULT_LEVEL[field];
}

/**
 * Fields a guardian sees on their own child regardless of the child's setting.
 *
 * Scoped to exactly what the supervised-account screen promises the child —
 * "They can always see your picture, when you're online and when you were last
 * around" — and no more. Read receipts are deliberately absent: nobody was
 * told a parent would see those, so the bypass does not quietly reach them.
 */
export const GUARDIAN_BYPASS: ReadonlySet<VisField> = new Set<VisField>([
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
   * The avatar, redacted. Hidden comes back `undefined` rather than nulled:
   * the client renders the gradient-initials fallback for a missing avatar.
   * Status and lastSeen are NOT here any more (they live in the `presence`
   * table, not on `users`): see [presenceFields].
   */
  identity(subject: any): { avatarStorageId?: any };
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
      const level = levelOf(subject, field);
      if (level === "public") return true;
      if (level === "friends") return lens.isFriend(id);
      return false; // "nobody"
    },
    identity(subject) {
      return {
        // `undefined`, not the raw id — Convex ships whatever the handler
        // returns, so omitting the key IS the redaction.
        avatarStorageId: lens.canSee(subject, "avatar")
          ? subject?.avatarStorageId
          : undefined,
      };
    },
  };

  return lens;
}

/**
 * `status` / `lastSeen` of [subject] as the lens's viewer may see them, read
 * from the `presence` table (one point read; the sweep keeps a vanished client
 * honest, so no staleness window is applied here). The levels are the
 * subject's live `users.visibility` ones, same as every other lens check.
 * A subject with no presence row reads "offline" with no lastSeen.
 */
export async function presenceFields(
  ctx: any,
  lens: PrivacyLens,
  subject: any,
): Promise<{ status?: string; lastSeen?: number }> {
  const wantStatus = lens.canSee(subject, "status");
  const wantLastSeen = lens.canSee(subject, "lastSeen");
  if (!wantStatus && !wantLastSeen) return {};
  const row = await presenceOf(ctx, subject._id);
  return {
    status: wantStatus ? (row?.status ?? "offline") : undefined,
    lastSeen: wantLastSeen ? (row?.lastSeen ?? undefined) : undefined,
  };
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
export async function publicUserView(ctx: any, lens: PrivacyLens, user: any) {
  return {
    _id: user._id,
    username: user.username,
    name: user.name,
    // No `email`. It used to be here, and it failed the test above: a stranger
    // who can address a friend request to you should not learn your address.
    // `users.getProfile` serves it to self and guardians only.
    ...lens.identity(user),
    ...(await presenceFields(ctx, lens, user)),
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
