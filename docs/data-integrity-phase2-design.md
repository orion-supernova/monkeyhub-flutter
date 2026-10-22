# Phase 2 design: lifecycle engine for deletes (2026-10-22)

Companion to `data-integrity-and-scale-plan-2026-10-22.md` (Phase 2). Drafted
by a planning agent against the code, then reviewed; the **Decisions** section
at the end overrides anything above it.

## 0. Principles

- **Only `users` and `rooms` get a tombstone** (`deletingAt`). Their ids are
  referenced everywhere and must keep resolving until the end. Messages,
  moments and matches are deleted at once; their children are swept by a job
  keyed by the dead id (children are only ever read through the parent).
- **Order inside a teardown:** close the gates (access, membership, sessions,
  invites), then the data, then the parent row. A write racing the tombstone is
  caught because data steps re-query until the range is empty.
- **Jobs are independent.** A user or room job doesn't wait for the overflow
  jobs it enqueues.
- **No time budget.** `Date.now()` is frozen inside a mutation; budgets count
  reads and writes.
- **No cursor for index-equality steps:** `eq(field, id).take(n)` re-queried
  each time; deleted or nulled rows leave the range, so it's idempotent. Only
  `via` steps and rows that stay in range (reply-preview patches) keep a
  paginate cursor.
- **`eq(undefined)` guard:** never run a step with an empty `targetId`
  (`eq(path, undefined)` matches every unset row).

## 1. Data model

```ts
deletions: defineTable({
  kind: v.union(v.literal("user"), v.literal("room"), v.literal("message"),
                v.literal("moment"), v.literal("match"), v.literal("avatar"),
                v.literal("comment")),
  targetId: v.string(),            // the parent may already be gone
  state: v.union(v.literal("running"), v.literal("done"), v.literal("failed")),
  stepId: v.string(),
  cursor: v.union(v.string(), v.null()),
  args: v.optional(v.record(v.string(), v.any())),
  reason: v.optional(v.string()),  // self | guardian | lastMember | blockDm | cutoff | owner
  createdAt: v.number(),
  lastProgressAt: v.number(),
  finishedAt: v.optional(v.number()),
  restarts: v.number(),            // cron re-drives; also the chain "generation"
  attempts: v.number(),            // consecutive failures, reset on success
  lastError: v.optional(v.string()),   // <=200 chars, ids only
  pages: v.number(),
  writes: v.number(),
})
 .index("by_target", ["kind", "targetId"])
 .index("by_state_progress", ["state", "lastProgressAt"])
 .index("by_state_finished", ["state", "finishedAt"])
```

`args`: user `{avatarStorageId?, suspended?}`; room `{avatarStorageId?,
system?}`; message `{deletedStorageIds?: string[]}`; match `{skipBubbles?}`;
avatar `{userId, from, to}`.

Tombstones: `users.deletingAt`, `rooms.deletingAt` (optional numbers, no index).
New index `roomMembers.by_room_role ["roomId","role"]` for owner re-seating.

### First (user-facing) transaction, bounded

`startUserDeletion` / `startRoomDeletion` in `deletionCore.ts`. If a running
job exists for `[kind, targetId]`, return it (double tap is idempotent).

- **Room (~3 writes):** patch `deletingAt: now`, `name: "deleted:" + roomId`,
  `isPrivate: true`, `passwordHash: undefined`; insert the job; schedule
  `step`. The rename hides it from every `by_name` lookup and `listPublic`,
  lets the same DM pair be re-created, and drops it out of
  `findDmRoomsBetween`. No reads added anywhere.
- **User:** `retireIfStaff(username)` first; scrub the row (`deletingAt`,
  `username: "deleted:" + id`, `name/email/recoveryKeyHash/lastSeen`
  undefined, `passwordHash: ""`, `status: "offline"`, `avatarStorageId`
  undefined with the old id kept in `args`; `suspendedAt` untouched); revoke up
  to 100 live sessions (the first step does the rest; safe because
  `requireSession` checks `deletingAt`); delete `socialIdentities`
  (`take(20)`); write `bannedIdentities` if suspended (as today); schedule
  `revokeAppleGrant` by value (as today); insert job; schedule `step`.
  `LAST_GUARDIAN` stays in `auth.deleteAccount`, before this transaction.

From then on: the user's calls throw `SESSION_REVOKED`; others see a scrubbed
ghost until the social step runs, and explicit filters hide it at once
(section 2). A room vanishes from lists and lookups immediately, sends are
refused, and the first step removes access/membership rows and ends calls.

## 2. Read side: never add a read, check a field on a row already held

Helpers in `deletionCore.ts`: `isTombstoned(row)`, `getLiveRoom(ctx, id)`,
`getLiveUser(ctx, id)` (null when tombstoned).

**Sessions:** `sessionCore.requireSession` (both the revoked branch, before the
suspended test, and the live path) throws `SESSION_REVOKED` on `deletingAt`;
`mintSession` refuses the same (covers password, social, QR, pairing).

**R1, membership-driven lists** (room row already read): `rooms.listUserRooms`,
`rooms.listShared`, `badges.badgeTotalFor`, `systemRooms.findSystemRoom`,
`family.previewContactRemoval`, `family.grantableRooms`.

**R2, gates:** `roomPolicy.assertRoomAllows` / `assertRoomAllowsById` throw
`ROOM_NOT_FOUND` on a tombstone (covers send, schedule, forward);
`roomAdmin.getRoomOrThrow`; `roomAdmin.addMembership` refuses;
`rooms.join/updateRoom/updatePassword/updateRoomAvatar/deleteRoom` (second
delete is a no-op); `rooms.getRoom`, `rooms.getMemberIds`; individual swaps:
`messages.editMessage`, `messages.forwardToRoom` (source), `messages.markRoomRead`,
`messages.advanceDelivered`, `groupCalls.start/roster/pendingInviteForUser`.

**R3, request/invite flows** (rows deleted in the first step; swap for the
window): `roomInvitations.respond/advance/listIncoming`,
`roomInvites.preview/decideJoinRequest`, `roomChangeRequests.listPending`,
`family.listGuardianQueue/requestApproval/decideApproval/listMyApprovals/grantRoomToChild/listChildGrants`,
`challenges.forMessages/roomResults`.

**R4, must keep seeing it (leave alone):** `moderationCore.collectEvidence/fileContentReport/fileFilterHit`,
`moderation.suspendAccount/act/gcExpiredEvidence`, `matches._pushPlan`,
`notifications._reactionPushPlan`, `push._loadAlertTargets`,
`childGuard.childMayUseRoom`.

**U1, user row in hand, filter `deletingAt`:** `friends.listFriends`, friend
request lists, `rooms.getMembers`, `groupCalls.roster`, `feed:board`,
`momentComments.list`, `users.listBlocked`, family queues, `games.standings`,
`records.board`, `challenges.roomResults`, `calls.activeCallForUser`,
`groupCalls.pendingInviteForUser`.

**U2, return null:** `users.getProfile`, `auth.whoami`,
`users.searchUsersCore`, `friends.searchUsers`.

**U3, mutation entry points taking another user's id** (swap to `getLiveUser`
at each USER_NOT_FOUND guard): friends (5, incl. sendRequest, acceptRequest,
getOrCreateDM), family (5), users (4), roomInvitations (2), feed (2),
moderation (4), games (1), puzzle (1), `calls.initiate`.

## 3. Engine

Files: `deletionCore.ts` (imports only `_generated`; `enqueueDeletion`,
`startUserDeletion`, `startRoomDeletion`, `isTombstoned`, `getLiveRoom`,
`getLiveUser`, `class Budget`, `tuning`, `deleteCapped`); `deletions.ts`
(`step`, `stepInner`, `redrive`, `prune`, `retry`, `summary`);
`deletionPlans.ts` (`planFor(kind)`, generic step builder);
`deletionSteps/{roomSteps,userSteps,messageSteps,momentSteps,matchSteps,avatarSteps,commentSteps}.ts`.

```ts
type StepResult = { done: boolean; cursor?: string | null };
interface Step { id: string; tier: number; claims?: string[];
  run(ctx, job, b: Budget): Promise<StepResult>; }
export const tuning = { maxWrites: 1500, maxReads: 6000, pageRows: 100, inlineCap: 25 };
```

Tests shrink `tuning` to force multiple pages. Handlers check `b.spent()`
between rows; one row's worst case is bounded by `inlineCap`.

**`planFor(kind)`** = the kind's custom steps + a generic step for every
`REFERENCE_RULES` entry targeting the kind's table with rule `cascade` or
`setNull` that no custom step claims (tier 50), sorted by tier then key.
Generic: `eq(firstField, targetId).take(...)` then delete or patch
`{[path]: undefined}`; top-level paths only; a per-step `seen` set; re-`get`
when an earlier row can delete a later one. `via`, arrays, file, history,
softRef, ephemeral, restrict are never generic: custom claim or a
`PLAN_EXEMPT` entry with a reason.

**Coverage test** (`deletionPlans.test.ts`): fails if a cascade/setNull/restrict
rule targeting a plan kind is neither generic, claimed nor exempt, or if a
claimed/exempt key isn't in `REFERENCE_RULES`.

**`step` driver** (`internalMutation {jobId, gen}`): load job; return unless
running and `restarts === gen`; `try { runMutation(stepInner) }`; on catch
(sub-transaction rolled back) patch `attempts+1`, `lastError`, reschedule with
`2^attempts` s backoff while `attempts < 5`, else leave it for the cron.
**`stepInner`**: loop steps while budget remains (empty tables cost one probe,
so tiny steps share a transaction); persist `stepId/cursor/lastProgressAt/
pages/writes/attempts:0` in the same transaction; unknown step id (deploy
changed the plan) restarts at step 0, safe since every step is idempotent;
finish = final step, `done`, `finishedAt`; else `runAfter(0, step, {gen})`.
Test hook: `testHooks.beforeStep`. Fallback if convex-test doesn't roll back a
caught nested `runMutation`: `step` becomes an `internalAction` around
`stepInner` + a `noteFailure` mutation. **Verify this first.**

**Parent last:** room final step releases the avatar (skipped for system
rooms) then deletes the room; user final step deletes the stored avatar then
the user. Both skip a missing row.

**Re-drive:** `deletions.redrive` every 5 min: running jobs with
`lastProgressAt < now - 10 min` (`take(50)`): at `restarts >= 6` mark failed and
alert (see Decisions), else `restarts+1`, reset `attempts`, reschedule with the
new generation. `prune` daily drops `done` rows older than 30 days. `retry`
resets a failed job. `summary` counts by state and lists failed rows.

### Room plan (`roomSteps.ts`)

| tier | step | what |
|---|---|---|
| 0 | gates | `endGroupCallsInRoom`, `endLiveCallsInRoom`; roomInvites, roomInvitations, roomJoinRequests; roomChangeRequests (release photo files); approvalRequests.targetRoomId (delete pending, null decided) |
| 1 | access, members | roomAccess, then roomMembers (page <= 100) |
| 2 | typing, matches | typingIndicators; matches in pages of 25 (erase matchHidden/matchPresence, delete row, enqueue a `match` job with `skipBubbles` on move overflow) |
| 3 | small tables | pins, bookmarks, interactions + responses, speakerColors, gameChallenges, viewOnceViews, roomBans, scheduledMessages (dropJob + file release), friendships.roomId setNull |
| 4 | messages | `by_room_time` take 100; per message: reactions while budget, `releaseMessageBlobs`, delete. No per-message fanout (siblings swept by room) |

### User plan (`userSteps.ts`)

| tier | step | what |
|---|---|---|
| 0 | sessions | revoke the rest |
| 0 | social | friendships both ways via `deleteFriendshipRow`; blocks both; guardianships both; userDevices; groupCallParticipants; friendRequestMessages.by_user |
| 1 | memberships | page <= 20; per row: delete, revoke access, `leaveMatchesInRoom`, `removeUserFromRoomGroupCall`, `purgeScheduledForRoomUser`; emptiness via `take(1)`; empty room -> `startRoomDeletion`; else `memberCount - 1`; owner leaving -> re-seat via `by_room_role`; `createdBy === userId` -> re-point to owner |
| 2 | messages | `by_user` page, `removeMessageImmediate` per row (re-`get` first) |
| 3 | own rows | reactions, pins, bookmarks, interactionResponses, viewOnceViews, speakerColors (both), scheduledMessages (paged), gameChallenges, matchPresence, matches.turnUserId, typingIndicators, roomBans, uploadUsage, uploads (setNull) |
| 4 | requests | roomInvitations (both), roomJoinRequests (user deleted, decidedBy nulled), roomInvites (creator; then null roomJoinRequests.by_invite), roomChangeRequests (own pending w/ file release, decider nulled), approvalRequests (child/target cascade, decider nulled), pairing/release codes, deviceLoginRequests.by_approver, problemReports/reports (null reporter), calls both sides + signals, groupCallSignals.toUserId |
| 5 | feed | momentReactions, momentViews, momentCommentReactions, momentComments.by_user (via `deleteCommentCore`, overflow -> `comment` job), moments (10 per run via `deleteMomentCore`) |
| 6 | expressions | `purgeUserExpressions`, gameResults, puzzleResults, gameRecords + recordReactions |

### Children-only kinds

- **Moments:** `deleteMomentCore(ctx, m, cap)` in new `momentCleanup.ts`
  (shared with `feed.remove`): delete row; `releaseMomentFiles` (media and
  poster each checked against both `by_media` and `by_poster`); capped
  deletes of reactions, views, comment reactions, comments; overflow ->
  one `moment` job (generic cascades, comment reactions before comments).
- **Comments:** `deleteCommentCore` caps the reply subtree inline; overflow
  -> one `comment` job.
- **Matches:** `eraseMatch` capped; moves overflow -> `match` job paging
  `matchMoves.by_match_seq` (100), removing bubbles via
  `removeMessageImmediate` unless `skipBubbles`.

## 4. Message delete split

`removeMessageAndFanout(ctx, msg, id)` keeps name and signature (callers
unchanged) and wraps `removeMessageImmediate`, enqueueing a `message` job on
overflow, then the existing push revoke (skipped for gameMove).

Immediate (same transaction, capped at `inlineCap` per table, ~150 writes /
~300 reads worst case regardless of popularity, so self-destruct can't fail):
delete row; repair room preview (only if it was the newest); 
`releaseMessageBlobs` returns the ids it actually deleted; interaction body
deleted, answers capped; match split; challenge (already `first()`);
`matchMoves.by_message` null `messageId` (take 5); capped reactions, pins,
bookmarks, viewOnceViews; first 25 `by_replyTo` previews -> `__DELETED__`,
stripping `replyToPreview.mediaStorageId` only if in `deletedStorageIds`.

Batched (`message` job): generic cascades by messageId (reactions, pins,
bookmarks, viewOnceViews, interactionResponses) and a cursor-paged `replies`
step that never re-patches.

## 5. Caller migration

| Caller | Change |
|---|---|
| `auth.deleteAccount` | guardian check, then `startUserDeletion(reason: "self")` |
| `auth.purgeAccount` (family.deleteChildAccount) | body -> `startUserDeletion(reason: "guardian")` |
| `auth.purgeUser` | deleted; content moves to `userSteps.ts` |
| `auth.purgeMessagesLater`, `roomCleanup.wipeMessagesLater` | thin shims for one release (scheduled jobs reference them by name), then delete |
| `roomCleanup.wipeRoomCompletely` | alias of `startRoomDeletion`; callers unchanged |
| `wipeRoomContents`, `wipeMessagesBatch`, `wipeRoomRows` | deleted, moved to `roomSteps.ts` |
| `gcOrphanedRoomMemberships` (+ list fn, cron) | retire after one clean integrity run and old chains drained |
| `removeMessageAndFanout` callers | unchanged |
| `feed.remove` | `deleteMomentCore` |
| `users.repointAvatarCopies` | deleted; `updateAvatar` patches the user then enqueues an `avatar` job; the old file is deleted only in the job's last step, only if not the current avatar |
| `roomAdmin.removeMembership` | `take(1)` emptiness, `ensureOwner` only if the leaver was owner, delete the leaver's typing row |

Existing tests asserting state right after a delete need a drain helper
(`deletionTestUtils.ts`, using the fake-timer pattern from `viewOnce.test.ts`
/ `calls.test.ts`).

## 6. The 31 `today` entries

Fixed in Phase 2: approvalRequests.targetRoomId, friendships.roomId,
matchMoves.messageId, matchPresence.userId,
messages.replyToPreview.mediaStorageId, moments.mediaStorageId,
moments.posterStorageId, roomBans.roomId, roomBans.userId,
roomJoinRequests.inviteId, rooms.avatarStorageId (system rooms),
rooms.createdBy, typingIndicators.avatarStorageId, uploads.userId,
uploadUsage.userId.

Stale text, verify and drop: roomChangeRequests.storageId (fixed in Phase 0),
sessions.userId (by design).

Out of scope: messageInteractions respondents (accepted), matches.watchers
(Phase 4, optional in WP-B), messages.moderationCard.reportId (unverified,
retention), sticker copies (Phase 3), momentViews.momentId (Phase 4),
problemReports.messageId (expires 2026-11-06), scheduledMessages
file/mentions/reply (Phase 4 / product).

## 7. Work packages

- **WP-A, engine core (first, alone):** schema (`deletions`, tombstones,
  `roomMembers.by_room_role`), `deletionCore.ts`, `deletions.ts`,
  `deletionPlans.ts`, step stubs, crons, `deletionTestUtils.ts`, tests:
  multi-page generic cascade/setNull with parent last; throw + re-drive +
  give-up; re-run is a no-op, double enqueue makes one job, stale generation
  exits; tombstone + `getLive*`; coverage test.
- **WP-B, messages/moments/comments/matches/avatar:** `messages.ts`,
  `interactionCore.ts`, `matchCore.ts`, `files.ts`, `feed.ts`,
  `momentComments.ts` (`deleteCommentCore`), `momentCleanup.ts`, `users.ts`
  (`updateAvatar`, delete `repointAvatarCopies`, plus the 4 U3 swaps and U2
  `getProfile`/`searchUsersCore`), the R2 swaps in `messages.ts`, the U1/U3
  sites in `feed.ts`, step files for its kinds.
- **WP-C, room and user plans + caller migration:** `roomCleanup.ts`,
  `roomAdmin.ts`, `auth.ts`, `expressions.ts`, `recordBook.ts`,
  `speakerColors.ts`, `scheduledMessages.ts` (incl. the `schedule` R2 swap),
  `roomSteps.ts`, `userSteps.ts`.
- **WP-D, read side + retirements:** `sessionCore.ts`, `roomPolicy.ts`,
  `rooms.ts`, `roomInvitations.ts`, `roomInvites.ts`, `roomChangeRequests.ts`,
  `groupCalls.ts`, `badges.ts`, `systemRooms.ts`, `challenges.ts`,
  `friends.ts`, `family.ts`, `games.ts`, `puzzle.ts`, `moderation.ts`,
  `calls.ts`, `records.ts`, `referenceRules.ts` (all `today` edits, at the
  end), retirement of `gcOrphanedRoomMemberships` (last, after C).

## Decisions (orchestrator, 2026-10-22)

1. Owner re-seating uses the new `roomMembers.by_room_role` index (keeps
   "longest-standing member"); no 300-member cap.
2. No "accept the rare case": a huge comment reply subtree overflows into a
   `comment` job like everything else.
3. A job marked failed must reach a human: besides `console.error`, post an
   ids-only notice where staff already get alerts (find the existing staff /
   moderation / problem-report alert path and reuse it; don't invent a new
   channel). Retrying is `internal.deletions.retry`.
4. DMs after account deletion keep today's behaviour (the other person keeps
   the DM) until the user decides plan section 7.
5. File ownership as listed in section 7 is binding; anything outside a
   package's list goes back to the orchestrator. Only WP-A edits `schema.ts`
   and `crons.ts`; later index needs are requested.
