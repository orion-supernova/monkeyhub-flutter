# Phases 5 and 6 design: presence and profiles (2026-10-23)

**Phase 5 status (2026-10-23): Done in code, not deployed** (backend 5A to
5D, app 5E and 5F). One review; fixes applied: the compat mirror restores
`users.status` and the users-sourced window is 420 s (old builds no longer see
new-build users flicker offline); tombstoned and suspended users can't write
presence; a beat within 60 s of an explicit offline doesn't resurrect;
suspension continues past 100 sessions; one sign-in brings any account to the
50-session cap; the audit counts `overCap` and `sessions:trimOverCap` fixes
it; an earlier ban's sessions can't pass `allowSuspended`. W0 to W5 below are
operator steps after the deploy.

**Phase 6 status (2026-10-23): Done in code, not deployed** (backend 6A to
6E, app 6F to 6H). `profiles` is synced by every name, username, avatar and
visibility write (guarded by `profileWriters.test.ts`) and tombstoned on
deletion; `profiles:get` / `profiles:versions` apply avatar privacy with point
probes and never read `users`. Copies are still written (`PROFILE_COPIES` /
`profileCopyGate.copyFlags`) so old builds keep working; every server reader
already resolves the current name (`displayName` / `nameResolver`), pushes
build names at send time and skip deleted actors. The app resolves names and
faces through `ProfileCache` (per-user disk cache, `ProfileScope`), shows
"Deleted account" for tombstones in 12 languages. One review; fixes applied
(tombstones never fall back to a copied face or handle, a known profile's
avatar wins, failed refetches retry, fewer resubscribes while scrolling, a
departed group sender still gets a name, the board no longer reads the
viewer's `users` row, deleted accounts never surface `deleted:<id>`).

**Phase 6 runbook (operator):**
1. In the same deploy window as the Phase 6 backend: run
   `npx convex run profileMigrations:backfillProfiles '{}'` and check
   `profileMigrations:countMissingProfiles '{"numItems":10000}'` sums to 0.
   Until it finishes, readers fall back to `users` rows (correct, but they
   follow `users` churn).
2. Ship the app (profiles in the cache).
3. W3, once the minimum supported version is at or above that build: set
   `PROFILE_COPIES = false` in `profilesCore.ts`, deploy, then per table
   `npx convex run profileMigrations:stripCopies '{"table":"<t>"}'` for
   messages, messageInteractions, interactionResponses, moments,
   momentReactions, momentComments, momentCommentReactions, recordReactions,
   typingIndicators; check `profileMigrations:countCopies` sums to 0 each.
4. 6Z, after the strip: `users.updateAvatar` releases the old file directly;
   delete `deletionSteps/avatarSteps.ts`, the `avatar` deletion kind and plan,
   and the copy rules for `moments.authorAvatarStorageId` /
   `momentReactions.userAvatarStorageId`; a later deploy removes the copy
   fields from `schema.ts`. Not done yet on purpose: old builds still need the
   copies and the repoint job until then.

**Runbook for the `SESSION_TRUSTS_ROW` flip (W1):** run
`npx convex run sessions:auditLiveVsAccounts '{}'` (repeat with
`{"cursor":"<nextCursor>"}` until `isDone`, sum the counts). Fix: `missing` ->
`sessions:revokeOrphaned`; `suspended`/`tombstoned` -> re-run the suspension
or deletion; `overCap` -> `sessions:trimOverCap '{}'` (paged). Re-audit; flip
the constant in `sessionCore.ts` only when missing, tombstoned, suspended and
overCap are all 0. Then `npx convex run presenceMigrations:backfillPresence '{}'`
and check `presenceMigrations:countMissingPresence` sums to 0.
W4 strip: set `PRESENCE_COMPAT_MIRROR=off` first, then
`presenceMigrations:stripUsersPresence '{}'`, check
`countUsersWithPresenceFields` sums to 0.

Drafted by a planning agent against the code (backend and `lib/`), reviewed by
the orchestrator. **Decisions** at the end are binding. Supersedes the sketches
in `data-integrity-handoff.md` sections 5 and 6.

## 0. Corrections to the handoff sketch

1. One `presence` row refreshed every 90 s would still re-run every
   `forUsers` subscriber every 90 s. Split it: `presence` changes only on a
   status transition; `presenceBeats` takes the 90 s write and nothing
   subscribes to it (only the sweep reads it).
2. `groupCalls.roster` and `feed:board` don't return status or lastSeen;
   they re-run only because heartbeats churn `users`. The real readers:
   `users.getProfile`, `users.searchUsersCore`, `friends.listFriends`,
   `listPendingRequests`, `listIncomingDirectRequests`,
   `listOutgoingDirectRequests`, `roomInvitations.listIncoming`,
   `listForRoom`, `invitableFriends`, `roomChangeRequests.listPending`,
   `roomInvites.listJoinRequests`, `rooms.getMembers` (all through
   `visibility.ts` `lens.identity` / `publicUserView`), and
   `family.getFamilyContext` (raw `u.status` / `u.lastSeen`).
3. Dual-writing from the same endpoints keeps the fan-out. Split by endpoint:
   new builds call new endpoints that write `presence`/`presenceBeats` and
   mirror to `users` only slowly; old builds keep the old endpoints, which
   dual-write.
4. `startUserDeletion` revokes `sessions.by_user take(100)`, but revoked rows
   (kept 7 days) sit in that range and can crowd out live ones. The first
   transaction and `moderation.suspendAccount` must read the live-only
   `by_user_live_seen`.
5. A boolean on sessions isn't enough: `requireSession` must still tell
   `ACCOUNT_SUSPENDED` from `SESSION_REVOKED`, and `allowSuspended` compares
   `revokedAt >= suspendedAt`. Add `sessions.revokedReason`.
6. `avatarSteps.ts` can't just be deleted: its `deleteOld` step releases the
   old avatar file. It retires only after copies are stripped (6Z).
7. "New rows store only userId" must wait for old builds to be gone: they
   render the copies straight from the row, and several are required
   `v.string()`. Loosen to optional first; stop writing behind a constant.
8. Profile privacy depends on the viewer, so the version subscription
   carries a per-viewer `av` flag.
9. The scrubbed ghost keeps its users row, so `profiles` is tombstoned, not
   deleted.

## 1. Phase 5 backend

### Tables (`schema.ts`)

```
presence: userId, status ("online"|"away"|"offline"), lastSeen?: number,
          statusLevel?: string, lastSeenLevel?: string   // absent = DEFAULT_LEVEL "friends"
  .index("by_user", ["userId"])
presenceBeats: userId, beatAt: number, live: boolean
  .index("by_user", ["userId"])
  .index("by_live_beat", ["live","beatAt"])
sessions: + revokedReason?: "suspended" | "deleted" | "evicted"
```

`lastSeen` = when the user left the foreground; absent while online, set on
the move to away/offline, set to `beat.beatAt` when the sweep demotes. That is
what keeps the 90 s beat off `presence`. `PRESENCE_OFFLINE_MS` stays 180 s.
`REFERENCE_RULES`: `presence.userId` and `presenceBeats.userId` cascade via
`by_user`.

### Writes (shared logic in new `presenceCore.ts`: `noteBeat`, `setStatus`, `markOnline`, `markOffline`, `clearPresence`, `syncLevels`)

| Path | Writes |
|---|---|
| `presenceApi.beat({status})` (new, authed) | `touchSessions`; read beats row; if live, `now - beatAt < 90 s` and presence not offline: read only, return. Else patch `presenceBeats {beatAt, live: true}`; if presence absent/offline, resurrect it to the beat's status |
| `presenceApi.setStatus({status})` (new) | today's `updateStatus` semantics: `consume(presence:user, 20, 60 s)`, drop repeats, write `presence` only on change, `lastSeen = now` on away/offline, upsert the beat |
| `presenceApi.sweepStale` (internal, cron every 1 min) | `presenceBeats.by_live_beat eq(live,true).lt(beatAt, now-180 s) take(200)` via `continueSweep`; beat -> `live:false`, presence -> `{offline, lastSeen: beatAt}`. Required: queries don't re-run as time passes |
| `users.heartbeat` (old builds) | unchanged users throttle + `touchSessions`; also `presenceCore.noteBeat` (no resurrect) |
| `users.updateStatus` (old builds) | users patch + `presenceCore.setStatus` |
| sign-in / sign-out / pairing | `markOnline`/`markOffline` next to each existing users patch: `auth.ts` (~168, 225, 255, 326), `socialAuth.ts` (~665, 753/763, 876), `family.ts` (~170, 368, 433), `voipTokens.ts` (~604, guarded by `hasAnyLiveSession`), `moderation.suspendAccount` |
| `users.updateVisibility` | status/lastSeen level change also patches the two level fields on `presence` |
| `deletionCore.startUserDeletion` | `clearPresence` deletes both rows |
| system accounts | no row; absent reads as offline |

**Compat mirror** (new endpoints only, so old viewers stay right): mirror
`users {status, lastSeen}` on transitions; while live refresh `users.lastSeen`
at most every `COMPAT_MIRROR_MS = 300_000`; env `PRESENCE_COMPAT_MIRROR=off`
stops it without a redeploy. `lens.identity` / `effectiveStatus` take a
`windowMs`, `COMPAT_OFFLINE_MS = 420_000` on the users-sourced path. Today's
`users.sweepStalePresence` and its index stay for the window.

### `presenceApi.forUsers({ids})`

Cap 100 (over the cap throws `TOO_MANY_IDS`). Per id with point probes, never
`lensFor` (which scans all the viewer's friendships per re-run), ~400 reads
max: self visible; "public" visible; "friends" = `friendships.by_pair` both
directions, accepted; guardian bypass for status/lastSeen
(`guardianships.by_pair`, existing `GUARDIAN_BYPASS`); "nobody" hidden. Levels
come from the `presence` row; `users` is never read. Returns
`[{id, s?, ls?}]` (`s` only if status visible; `ls` only if visible and set).
Helper in new `visibilityPoint.ts: canSeeAs(ctx, viewerId, subjectId, level, field)`
(not in `presence.ts`: `visibility.ts` already imports `presence.ts`; hence the
module name `presenceApi.ts`).

### `requireSession` (`sessionCore.ts`)

- `SESSION_LIVE_CAP = 50`, asserted `<= FIRST_TX_SESSIONS` (100). In
  `mintSession`, before the insert: live sessions via `by_user_live_seen`
  (oldest `lastSeenAt` first, `take(2*CAP)`); revoke the excess with
  `revokedReason: "evicted"`.
- Reasons: `suspendAccount` writes `"suspended"`; deletion first transaction
  and the user plan's sessions step write `"deleted"`; both first-transaction
  reads switch to `by_user_live_seen take(FIRST_TX_SESSIONS)`.
- Revoked branch: `"suspended"` -> `ACCOUNT_SUSPENDED` (`allowSuspended`
  passes on this reason); `"deleted"` -> `SESSION_REVOKED`; no reason (legacy,
  sign-out) keeps today's owner lookup.
- Live branch: return `row.userId` without `users.get`, behind
  `SESSION_TRUSTS_ROW` (false at first). Stage A: deploy reasons, cap and
  live-index revokes; run new `sessions.auditLiveVsAccounts` (live sessions
  whose user is missing, `deletingAt` or `suspendedAt`; extend
  `countOrphaned`/`revokeOrphaned`) and require 0. Stage B: flip to true.
  Then rename/avatar writes stop re-running a user's own screens.

### Readers and the window

Day one, no reader changes. At cutover, `status`/`lastSeen` leave
`visibility.identity`, `publicUserView`, `users.getProfile` (and its
`isRedacted`), and `family.getFamilyContext` reads `presence` for the child.

| Stage | State |
|---|---|
| W0 | deploy; old endpoints dual-write; new endpoints live; mirror on; `SESSION_TRUSTS_ROW=false` |
| W1 | audit = 0, flip `SESSION_TRUSTS_ROW`; run `backfillPresence` |
| W2 | app release using the new endpoints |
| W3 | min version >= first new build: `PRESENCE_COMPAT_MIRROR=off`; users writes removed from `heartbeat`/`updateStatus` (thin stubs); readers stripped |
| W4 | `stripUsersPresence` (~50 rows per tick every 5 s) |
| W5 | remove schema fields, `users.by_status_lastSeen`, `users.sweepStalePresence` and its cron |

## 2. Phase 5 app

**`lib/data/presence_store.dart`** (`ChangeNotifier` singleton, shaped like
`RecordsStore`, injected subscribe fn for tests):
- `PresenceLease lease(Iterable<String> ids)` / `release()`, refcounted.
  `PresenceDot` leases in `initState`, releases in `dispose`; lazy lists make
  that "people on screen". Text displays lease directly.
- Additions coalesce 250 ms; removals wait 3 s; a shrink resubscribes only if
  the stale set exceeds the cap.
- Key = sorted joined ids (max 100, most recently leased first); same key =
  no-op; else cancel and subscribe `presenceApi:forUsers` via
  `ConvexBackend.subscribe` (`SubscriptionRegistry` rebinds on reconnect).
- One `ValueNotifier<PresenceInfo?>` per id; only changed ids notify.
- Unsubscribed ids keep their value 2 min, then unknown (no dot). Never
  persisted.
- "function not found" (old server): legacy mode, `UserAvatar` falls back to
  `user.status`. `clear()` from `ChatRepository.detach`.

**App wiring:** new `lib/backend/presence_api.dart`; `lib/app.dart` `_beat`
and `_sendStatus` use it (`_beat` sends `online|away`), old calls only as the
not-found fallback; `chat_repository.dart` `_roomMemberSignature` drops
status/lastSeen.

**Widgets:** `lib/widgets/user_avatar.dart`: replace `_statusColor` /
`_withStatus` with a `PresenceDot` (keep the `Stack` whenever `showStatus`, so
a change doesn't remount the image). Inherit through `UserAvatar`:
friend_request_draft, approvals, child_policy, search, family, room_info,
room screens; room_invite_friends_sheet, room_member_actions_sheet,
request_cards, room_change_requests_sheet, moment_rail, chat_list_row,
discover_rows, room_join_requests_sheet, mention_picker,
interaction_respondents_sheet, share_target_sheet, moment_comments_sheet,
people_picker. Direct leases: `room_screen.dart` header (~8216,
`dmUser.status`), `profile_screen.dart:_relationLine` (~1419),
`family_screen.dart:_presence` (~171), `models/mention.dart:_presenceRank`.

## 3. Phase 6 backend

```
profiles: userId, name (users.name ?? username), username, avatarStorageId?,
          avatarLevel?, deleted?: boolean, isSystem?: boolean, updatedAt: number
  .index("by_user", ["userId"])
```
Rules: `profiles.avatarStorageId` file/`copy`; `profiles.userId` history.

**`profilesCore.syncProfile(ctx, userId)`**: build the desired row from users,
patch only on a difference, `updatedAt = max(prev+1, now)`. Called from
`users.updateProfile`, `applyUsernameChange`, `updateAvatar` (same
transaction), `updateVisibility`, signup (`auth.ts`), `socialAuth`
createWithIdentity, `family` createChildAccount, `systemRooms` ensure and its
two repair patches. `deletionCore.startUserDeletion` calls `tombstoneProfile`
(`{deleted: true, name: "", username: "", avatarStorageId: undefined}`). A
static test (style of `fileCallSites.test.ts`) fails if a `users` write sets
name/username/avatarStorageId/visibility without `syncProfile` in the same
function.

**Copies stop being written** behind `PROFILE_COPIES` (true until W3):
`messages.senderName`, `replyToPreview.senderName`;
`moments.authorName/authorUsername/authorAvatarStorageId`;
`momentReactions.userName/userUsername/userAvatarStorageId/userAvatarLevel`;
`momentComments.userName/replyToName`; `momentCommentReactions.userName`;
`recordReactions.userName`; `interactionResponses.userName`; interaction
`respondents[].name`; `typingIndicators.userName/avatarStorageId/avatarVisibility`.
Kept: `mentions[].username`, call/push payloads (snapshots), game names
(`matches.seats[].name`, `seatRequest.name`, `gameChallenges.name`),
`roomMembers.seenVisibility`. Deploy 1 loosens the required ones to optional
(`moments.authorName`, `authorUsername`, `momentComments.userName`,
`interactionResponses.userName`, `replyToPreview.senderName`, the
`respondents[].name` validator).

Server readers that need a name switch to `profilesCore.nameOf(ctx, id)` (point
read, safe in subscriptions since profiles rarely change): `socialPush.ts`
(~704, 900, 1037; pushes build the snapshot at send time), `notifications.ts`
(~721), `deletions.ts` (~271, moderation excerpt), `feed.ts` (~151-178),
`momentComments.ts` (~232, 263, 361), `interactions.ts` (~243, 968),
`records.ts` (~196, 258), `typing.ts` (`typistOf`, labels). `sendCore`
already resolves the sender name at send time.

**`profiles:versions({ids})`** (subscribed, <=100): `[{id, u, av}]`, `av` =
viewer may see the avatar and one exists (same `canSeeAs`). **`profiles:get({ids})`**
(one-shot, <=100): `{id, name, username, avatarStorageId? (only if av),
deleted?, isSystem?, updatedAt}`; missing row = null, client falls back to the
copy. Versions re-run on profile or friendship changes, so an `av` flip
refetches just that id.

**Migrations** (`profileMigrations.ts`): `backfillProfiles` (paged,
idempotent), `stripCopies` per table after W3 with `PROFILE_COPIES=false`,
count helpers to 0, throttled ticks; then a deploy removes the fields.

**6Z, after the strip:** `users.updateAvatar` calls `releaseFile(previous)`
directly; remove `deletionSteps/avatarSteps.ts`, the `avatar` kind and plan,
and the two copy rules.

## 4. Phase 6 app

**`lib/data/profile_cache.dart`**: disk `<documents>/cache/<userId>/profiles.json`
(`id -> {n, un, a, u, d}` + schema version; per signed-in user since avatars
are viewer-dependent; 600 ms debounced writes; LRU 2000; web in-memory only;
separate from `cache_store.dart`). Loaded in `ChatRepository._attach` alongside
rooms and friends. Unknown ids batch through a 50 ms coalescer into
`profiles:get` (`cv.query`, chunks of 100, in-flight dedupe, 60 s negative
cache). Active set = ids touched in the last 60 s, max 100, subscribed to
`profiles:versions` with the PresenceStore debounce/dedupe; a changed `u` or
`av` refetches. API: `peek`, `nameFor(id, {fallback})`, `avatarFor`,
`usernameFor`, `isDeleted`. `ProfileScope` (`InheritedNotifier`);
`context.profileName(userId, fallback: copy)` returns the localized "Deleted
account" for tombstones (new key in every `.arb`; `arb_parity_test`
enforces it). No profile -> the copy; both empty -> neutral placeholder.

**Call sites** (resolve by userId, copy as fallback): chat:
`models/chat_message.dart` (resolved getter from `senderId`),
`widgets/message_bubble.dart` (~477, 1055), `reply_indicator.dart`
(`preview.senderName` ~370, 558, 953, 1095, 1289, 1515, 1675),
`thread_overlay.dart` (~1195, 1239, 1270, 1582), `pinned_banner.dart`,
`pinned_list_sheet.dart`, `location_bubble.dart`, `game_move_bubble.dart`,
`composer_reply_card.dart`, `chat_row_action_menu.dart`,
`screens/media_pager_screen.dart`, `room_content_screen.dart`,
`room_screen.dart` (~6281-6292), `interaction_bubble.dart`,
`interaction_respondents_sheet.dart`, `typing_indicator.dart`. Moments:
`models/moment.dart`, `models/moment_comment.dart`, `moment_rail.dart`,
`moment_activity.dart`, `screens/feed/moment_viewer.dart`,
`moment_comments_sheet.dart`, `points_board.dart`, `moment_reactions.dart`,
`reaction_details_sheet.dart`. Synthetic `ChatUser`s built from copies
overlay cache values first.

## 5. Packages

Shared files (`schema.ts`, `crons.ts`, `referenceRules.ts`): small exact
edits, in package order. Scoped tests only; never `dart format`; no InkWell;
Flutter tests use fake time.

**Phase 5:**
- **5A core:** `schema.ts` (presence tables, `revokedReason`), `presence.ts`,
  new `presenceCore.ts`, new `visibilityPoint.ts`, rules. Tests:
  `presenceCore.test.ts`, `visibilityPoint.test.ts`.
- **5B endpoints/writers** (after 5A): new `presenceApi.ts`, `users.ts`
  (heartbeat, updateStatus, updateVisibility), `auth.ts`, `socialAuth.ts`,
  `family.ts`, `voipTokens.ts`, `crons.ts`. Tests: `presenceApi.test.ts`
  (cap, privacy matrix, sweep, no writes on a fresh beat, rate limit, both
  endpoint generations land in `presence`); extend `signedOutDevice.test.ts`.
- **5C sessions** (after 5A): `sessionCore.ts`, `sessions.ts`,
  `moderation.ts`, `deletionCore.ts` (first transaction),
  `deletionSteps/userSteps.ts` (sessions step). Tests: `sessionCap.test.ts`.
- **5D backfill** (after 5A): new `presenceMigrations.ts`.
- **5E app store/api** (parallel): `lib/data/presence_store.dart`,
  `lib/backend/presence_api.dart`, `test/presence_store_test.dart`.
- **5F app widgets** (after 5E): `user_avatar.dart`, `app.dart`,
  `chat_repository.dart`, `room_screen.dart`, `profile_screen.dart`,
  `family_screen.dart`, `models/mention.dart`; tests
  `user_avatar_presence_test.dart`, update `presence_lifecycle_test.dart`.
- **5G strip** (W3 to W5, after the min version rises).

**Phase 6** (after Phase 5 is merged): **6A** `schema.ts` (profiles, loosen
copies), `profilesCore.ts`, `profiles.ts`, rules; **6B** writers (`users.ts`,
`auth.ts`, `socialAuth.ts`, `family.ts`, `systemRooms.ts`, `deletionCore.ts`);
**6C** copies set 1 (`messages.ts`, `interactions.ts`, `typing.ts`,
`notifications.ts`, `deletions.ts`); **6D** copies set 2 (`feed.ts`,
`momentComments.ts`, `records.ts`, `socialPush.ts`); **6E**
`profileMigrations.ts`; **6F** app cache + l10n; **6G** chat widgets; **6H**
moment widgets; **6Z** retire the avatar job after the strip.

## 6. Load math (200 friends, ~60 online, ~20 own subscriptions)

| Stage | Re-runs per 90 s heartbeat |
|---|---|
| Today | ~20 own + 60 `listFriends` + 18 `feed:board` + ~2 rosters = **~100** (and each `listFriends` re-run reads ~600 docs: ~36,000 reads per heartbeat) |
| Window, new build | ~30 (users row mirrored every 5 min) + ~3 `forUsers` per status transition |
| End state | **0** per beat; ~3 `forUsers` re-runs per transition (~10 a day) |

Fleet at 1M online: ~1.2M re-runs/s today; end state ~11k beat writes/s that
invalidate nothing plus ~350 re-runs/s.

## Decisions (orchestrator, 2026-10-23)

1. The two-table split, endpoint-split dual-write, compat mirror, session
   cap 50 with `revokedReason`, and `SESSION_TRUSTS_ROW` staging, as designed.
2. Game names (`matches.seats[].name`, `seatRequest.name`,
   `gameChallenges.name`) stay as snapshots: a finished game is a record of
   who played under what name, like a scoreboard.
3. Multi-device online/away flapping keeps today's behaviour; per-session
   status is deferred (not worth the writes now).
4. The window ends when the store-driven minimum supported version reaches
   the first build with presence and profiles (handoff 7.3 question 1).
   Stages W3+ and 6Z are operator steps for after that, documented here;
   nothing in them runs automatically.
5. App changes ship in one release per phase: Phase 5 app (5E, 5F) and Phase
   6 app (6F to 6H), each after its backend is deployed.
