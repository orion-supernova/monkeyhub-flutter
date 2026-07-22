/**
 * Child-account rules, in one place.
 *
 * Every enforcement site across the backend (rooms, messages, friends, users,
 * calls, auth) imports from here rather than re-deriving "is this allowed?"
 * locally — so tightening a rule is a single edit, and there is exactly one
 * definition of what "family" means.
 *
 * Plain helpers, not Convex functions: callers pass their own `ctx`.
 */

// ─────────────────────────────── constants ───────────────────────────────

export const ACCOUNT_CHILD = "child";
export const ACCOUNT_ADULT = "adult";

/** Supervision stages for a pending `friendships` row. */
export const STAGE_SENDER_GUARDIAN = "awaitingSenderGuardian";
export const STAGE_RECIPIENT_GUARDIAN = "awaitingRecipientGuardian";
export const STAGE_RECIPIENT = "awaitingRecipient";

/**
 * A brand-new child account starts locked down: no public rooms, no room
 * creation. Calls, media, and asking-to-add stay on because the whole point
 * of the account is talking to family — a guardian can tighten any of them.
 */
export const DEFAULT_CHILD_POLICY = {
  publicRoomsEnabled: false,
  callsEnabled: true,
  mediaEnabled: true,
  canRequestContacts: true,
  canCreateRooms: false,
};

// Error codes. Kept as constants so the Flutter client's string matching and
// the backend can't drift apart.
export const ERR_APPROVAL_REQUIRED = "CHILD_APPROVAL_REQUIRED";
export const ERR_NOT_ALLOWED = "CHILD_NOT_ALLOWED";
export const ERR_MUST_PAIR = "CHILD_MUST_PAIR";
export const ERR_NOT_GUARDIAN = "NOT_A_GUARDIAN";
export const ERR_CODE_INVALID = "PAIRING_CODE_INVALID";
export const ERR_CODE_EXPIRED = "PAIRING_CODE_EXPIRED";

// ──────────────────────────────── accounts ────────────────────────────────

export async function getAccount(ctx: any, userId: any) {
  const user = await ctx.db.get(userId);
  if (!user) return null;
  return {
    accountType: user.accountType ?? ACCOUNT_ADULT,
    childPolicy: user.childPolicy ?? DEFAULT_CHILD_POLICY,
  };
}

export async function isChild(ctx: any, userId: any): Promise<boolean> {
  const acct = await getAccount(ctx, userId);
  return acct?.accountType === ACCOUNT_CHILD;
}

/** The child's policy, or null when the user is an adult / missing. */
export async function childPolicyOf(ctx: any, userId: any) {
  const acct = await getAccount(ctx, userId);
  if (!acct || acct.accountType !== ACCOUNT_CHILD) return null;
  return acct.childPolicy;
}

// ─────────────────────────────── guardianship ───────────────────────────────

/** userIds of everyone who supervises [childId]. */
export async function guardiansOf(ctx: any, childId: any): Promise<any[]> {
  const rows = await ctx.db
    .query("guardianships")
    .withIndex("by_child", (q: any) => q.eq("childId", childId))
    .collect();
  return rows.map((r: any) => r.guardianId);
}

/** childIds supervised by [guardianId]. */
export async function childrenOf(ctx: any, guardianId: any): Promise<any[]> {
  const rows = await ctx.db
    .query("guardianships")
    .withIndex("by_guardian", (q: any) => q.eq("guardianId", guardianId))
    .collect();
  return rows.map((r: any) => r.childId);
}

export async function isGuardianOf(
  ctx: any,
  guardianId: any,
  childId: any,
): Promise<boolean> {
  const row = await ctx.db
    .query("guardianships")
    .withIndex("by_pair", (q: any) =>
      q.eq("guardianId", guardianId).eq("childId", childId),
    )
    .first();
  return !!row;
}

export async function assertGuardian(ctx: any, guardianId: any, childId: any) {
  if (!(await isGuardianOf(ctx, guardianId, childId))) {
    throw new Error(ERR_NOT_GUARDIAN);
  }
}

/**
 * Everyone a child can always reach with no approval: their guardians, and
 * their siblings (anyone sharing a guardian). Returned as a Set of id strings
 * so callers can test membership cheaply.
 */
export async function familyOf(ctx: any, childId: any): Promise<Set<string>> {
  const out = new Set<string>();
  const guardians = await guardiansOf(ctx, childId);
  for (const g of guardians) {
    out.add(g.toString());
    for (const sibling of await childrenOf(ctx, g)) {
      const s = sibling.toString();
      if (s !== childId.toString()) out.add(s);
    }
  }
  return out;
}

// ──────────────────────────── the relay chain ────────────────────────────

/**
 * Where a brand-new contact request from [senderId] to [recipientId] enters
 * the chain. `undefined` means "no supervision" — adult to adult, straight
 * into the recipient's requests list, exactly as before this feature existed.
 *
 * The sender's guardian always goes first: nothing leaves a child's family
 * before their own guardian has seen it.
 */
export async function initialStageFor(
  ctx: any,
  senderId: any,
  recipientId: any,
): Promise<string | undefined> {
  if (await isChild(ctx, senderId)) return STAGE_SENDER_GUARDIAN;
  if (await isChild(ctx, recipientId)) return STAGE_RECIPIENT_GUARDIAN;
  return undefined;
}

/** True when the recipient is allowed to see this row at all. */
export function isReleasedToRecipient(stage: string | undefined): boolean {
  return stage === undefined || stage === STAGE_RECIPIENT;
}

// ──────────────────────────────── reach ────────────────────────────────

/**
 * Can [childId] talk to [otherUserId]? Family always; anyone else only once
 * a friendship has been accepted — and a friendship can only reach "accepted"
 * by clearing the guardian relay, so this single check covers both.
 */
export async function childMayReach(
  ctx: any,
  childId: any,
  otherUserId: any,
): Promise<boolean> {
  const family = await familyOf(ctx, childId);
  if (family.has(otherUserId.toString())) return true;

  const forward = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) =>
      q.eq("userId", childId).eq("friendId", otherUserId),
    )
    .first();
  if (forward?.status === "accepted") return true;

  const reverse = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) =>
      q.eq("userId", otherUserId).eq("friendId", childId),
    )
    .first();
  return reverse?.status === "accepted";
}

/**
 * Can [childId] be in / post to [roomId]?
 *
 *   - A DM: the other member must be reachable.
 *   - A room whose other members are ALL family: always fine, so a parent can
 *     spin up a family group room without an approval round-trip.
 *   - Anything else: needs an approved "joinRoom" grant.
 *
 * Safe to call before the child has joined — "other members" is simply every
 * current member.
 */
export async function childMayUseRoom(
  ctx: any,
  childId: any,
  roomId: any,
): Promise<boolean> {
  const members = await ctx.db
    .query("roomMembers")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  const others = members
    .map((m: any) => m.userId.toString())
    .filter((id: string) => id !== childId.toString());

  const family = await familyOf(ctx, childId);

  const room = await ctx.db.get(roomId);
  if (room?.name?.startsWith("dm:")) {
    // A DM with nobody else in it yet is the child's own half-built room.
    if (others.length === 0) return true;
    return childMayReach(ctx, childId, others[0]);
  }

  // Family-only room — no approval needed.
  if (others.length > 0 && others.every((id: string) => family.has(id))) {
    return true;
  }

  return hasRoomGrant(ctx, childId, roomId);
}

/** An approved, un-revoked "joinRoom" grant for this exact room. */
export async function hasRoomGrant(
  ctx: any,
  childId: any,
  roomId: any,
): Promise<boolean> {
  const rows = await ctx.db
    .query("approvalRequests")
    .withIndex("by_child_room", (q: any) =>
      q.eq("childId", childId).eq("targetRoomId", roomId),
    )
    .collect();
  return rows.some((r: any) => r.kind === "joinRoom" && r.status === "approved");
}

// ─────────────────────────────── assertions ───────────────────────────────

/**
 * Gate an outbound action by a possibly-child user. No-ops for adults, so
 * call sites read as a single line with no branching.
 */
export async function assertChildMayReach(
  ctx: any,
  userId: any,
  otherUserId: any,
) {
  if (!(await isChild(ctx, userId))) return;
  if (!(await childMayReach(ctx, userId, otherUserId))) {
    throw new Error(ERR_APPROVAL_REQUIRED);
  }
}

export async function assertChildMayUseRoom(ctx: any, userId: any, roomId: any) {
  if (!(await isChild(ctx, userId))) return;
  if (!(await childMayUseRoom(ctx, userId, roomId))) {
    throw new Error(ERR_APPROVAL_REQUIRED);
  }
}

/** Throws unless the child's policy has [flag] switched on. Adults pass. */
export async function assertChildPolicy(
  ctx: any,
  userId: any,
  flag: keyof typeof DEFAULT_CHILD_POLICY,
) {
  const policy = await childPolicyOf(ctx, userId);
  if (policy === null) return; // adult
  if (!policy[flag]) throw new Error(ERR_NOT_ALLOWED);
}
