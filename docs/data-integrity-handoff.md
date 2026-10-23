# Data integrity work: handoff (2026-10-22)

Read this first if you are a new session continuing the data-integrity work.
It is self-contained: what is done, what is deployed (nothing yet), how it was
run, and a ready-to-build design for every remaining step.

Source documents (all in `docs/`):
- `data-integrity-and-scale-plan-2026-10-22.md`: the plan. Sections 1 to 5
  are the audit; section 6 the phases with a status note per phase; section 7
  decisions (several decided 2026-10-22).
- `data-integrity-phase2-design.md`: the deletion engine (built).
- `data-integrity-phase3-design.md`: file references (built, see status).
- This file: state, rollout, and the remaining designs.

## 1. State

| Phase | State | Commits (branch `dev`) |
|---|---|---|
| 0 security/privacy/data-loss fixes | Done in code | `73878c15` |
| 1 reference rules + guard + weekly integrity scan | Done in code | `2e847111` |
| 2 batched deletion engine | Done in code | `c7d48262`, `bed88907` |
| 3 file references | Done in code; rollout runbook in the plan's Phase 3 status | see `git log` ("phase 3") |
| 4 cleanups keep up | Done in code: A crons + sessions, B retention, C receipts table, D point reads + search index, E room counts, G moderator removal of moments/comments | see `git log` ("phase 4") |
| 5 presence | Done in code (backend + app); runbook in the Phase 5 status of `data-integrity-phase5-6-design.md` | see `git log` ("phase 5") |
| 6 profiles | Done in code (backend + app); runbook and 6Z in the Phase 6 status of `data-integrity-phase5-6-design.md` | see `git log` ("phase 6") |

**Nothing is deployed.** Everything is committed on `dev` only, not pushed.
Verify with `git log --oneline origin/dev..dev`.

## 2. How this work was run (keep doing it this way)

- The user's standing rules live in Claude memory (MEMORY.md). The ones that
  bite here: never `dart format`; never run `flutter build`; run only touched
  test files (the backend suite is fine to run once per phase, ~1 min); commit
  verified work without asking, but **never push or deploy without asking**;
  confirm the checkout is in sync before deploying (a second laptop also
  pushes); Convex is self-hosted (never `--prod`); no em dashes in
  user-facing text; design for millions of DAU.
- Orchestration: one planning agent drafts a design against the code; the
  orchestrator reviews it and writes the decisions into a design doc; Sonnet
  workers implement packages with **disjoint file ownership** (shared files
  like `schema.ts` and `crons.ts` take small exact edits only); an
  independent reviewer reads the combined diff; fixes; full suite +
  `npm run typecheck` (backend, must be 0) + `flutter analyze` if Dart
  changed; commit with explicit paths (never `git add <dir>` while a worker
  is still writing); update the plan's status note.
- Checks: `cd backend && npx vitest run` (all green at every commit so far)
  and `npm run typecheck`.
- `graphify update .` after code changes (the project CLAUDE.md asks for
  it); keep `graphify-out/` out of feature commits.

## 3. Rollout runbook (when the user says to deploy)

Deploy order matters. Do these in order, asking the user before step 1.

1. **Sync check.** `git fetch && git status -sb`; make sure `dev` contains the
   remote's work; read `backend/.env.local` for the deployment (self-hosted,
   VPS is primary; see memory "Primary backend is the VPS").
2. **Backend deploy** via the repo's `deploy.sh` (it gates on the typecheck;
   it owns the version number, never edit `version:` by hand). New indexes
   build on deploy; that includes many added in Phases 0 to 4.
3. **Phase 0 item 14:** `npx convex run sessions:revokeOrphaned` (1 row).
4. **Phase 2:** nothing to run. The shims `auth.purgeMessagesLater` and
   `roomCleanup.wipeMessagesLater` finish jobs scheduled before the deploy;
   delete them one release later. After the first clean weekly integrity run
   (`npx convex run integrity:latest`, or start one with
   `integrity:start`), retire `gcOrphanedRoomMemberships` and its cron.
5. **Phase 3:** follow the numbered runbook in the plan's Phase 3 status
   note exactly (backfill, verify, report, mark, enable reaper, enforce,
   lift epoch). Nothing irreversible runs without a human step.
5b. **Phase 4 backfills** (each pages itself, safe to re-run; run right
   after the deploy, before the new app ships):
   - `npx convex run userSearch:backfillSearchName '{}'`: until it finishes,
     existing users are findable by exact handle only.
   - `npx convex run roomCounts:backfill '{}'`: until then the room cap
     falls back to the old bounded count (correct, just slower).
   - `npx convex run receipts:moveLogs '{}'`: re-run until it logs
     `moved: 0`. A later deploy removes `roomMembers.readLog` /
     `deliveredLog` from the schema.
6. **App release** only after the backend is live: the new app sends
   `deviceSecret` on sign-in, which an old backend rejects.
7. Optional app follow-up from Phase 4A: send `roomIds` to
   `groupCalls.liveInMyRooms` (`lib/backend/group_call_api.dart`,
   `live_calls_store.dart`) for a smaller subscription footprint.

## 4. Remaining Phase 4 (designed, ready to build)

Decisions already made (plan section 7): games' moves and boards kept 90
days, daily results 1 year then yearly totals; receipts move to their own
table; decided requests kept 90 days; sessions 90 days idle (built).

Use the existing helpers: `backend/convex/sweep.ts` (`sweepArgs`,
`continueSweep`, `MAX_SWEEP_CHAIN`) for every retention sweep, and
`deletionCore.ts` `pageAfter`/`cursorOf` for tie-safe cursors. Deleting a
parent with children (a message, a match) goes through the engine
(`removeMessageBounded`, `eraseMatch`, `enqueueDeletion`), never a raw
delete. File-bearing rows release through `releaseRowFiles` (Phase 3).

### 4B. Retention sweeps (new `retention.ts` + crons)

| Table | Rule | Index needed | Notes |
|---|---|---|---|
| `roomBans` | delete when `until < now` | `by_until` (exists, Phase 1) | `until` is required, bound both ends |
| `typingIndicators` | delete on stop (`clearTyping` today only zeroes a timestamp) and rows idle > 1 day | `by_updated` or similar | delete on leave is already done (Phase 2) |
| `momentViews` | delete views of moments expired > 7 days | `by_moment_viewer` + moments `by_expires` | page moments by expiry, delete their views |
| `matches` + `matchMoves` + `matchHidden` + `matchPresence` | finished > 90 days: erase the match (keep the chat result card, which is a message) | `matches.by_status_finished` | use `eraseMatch(ctx, id, {skipBubbles: true})`; the card message stays |
| `gameResults`, `puzzleResults` | rows > 1 year: fold into a new `gameResultYears` (userId, game, year, counts/wins/best/streak fields matching what readers show), then delete | by user+day or by day | first grep every reader of these tables (streaks, stats, `records`, `games.standings`) and make them read `gameResultYears` for older years; verify streak math still holds across the boundary |
| `scheduledMessages` failed | failed > 30 days: delete, releasing files | `by_status_updated` | via `releaseRowFiles` |
| decided `roomInvitations`, `roomJoinRequests`, `roomChangeRequests` | decided > 90 days | `by_status_decided` per table | never delete pending rows |
| `approvalRequests` | decided **denied/revoked** > 90 days only | | approved rows are live permissions: never delete |
| rotated `roomInvites` | revoked/expired > 90 days | | `roomJoinRequests.inviteId` is setNull on these |
| `pairingCodes`, `releaseCodes` | expired or consumed > 1 day | `by_expires` | |
| problem-report log room messages | > 90 days (the report rows already go at 90) | messages `by_room_time` on that room | delete via `removeMessageBounded` |
| `integrityRuns` + `integrityCounts` | runs > 8 weeks | `by_started` | delete counts first |

Tests per sweep: backlog > 1 page drains in one firing (fake timers), kept
rows survive, the boundary is exact. Update `REFERENCE_RULES` `today` notes
that mention retention (scheduled messages, `momentViews`).

### 4C. Read receipts out of `roomMembers` (decided: own table)

Today `roomMembers.readLog` / `deliveredLog` (200 entries each) make a
membership row ~17 KB, rewritten on every receipt; `getReadState` reads every
member row (~17 MB for 1,000 members per run) and every receipt re-runs it
for the whole room.

- New `receiptLogs` table: `{roomId, userId, kind: "read"|"delivered",
  entries: [...same shape as today]}`, index `by_room_user_kind`, and
  `by_room_kind` if `getReceiptTimes` needs a room-wide read.
- `roomMembers` keeps only the scalar watermarks (`lastReadAt`, delivered
  equivalents) that `getReadState` needs; check exactly which fields it
  reads.
- `getReceiptTimes` ("seen by" for one message) reads `receiptLogs` for that
  room; it is the only reader of the logs.
- Writers (`markRoomRead`, `advanceDelivered` in `messages.ts`, and wherever
  logs are trimmed) write the log row instead of the membership row.
- Migration: deploy dual-read (prefer `receiptLogs`, fall back to the member
  row), backfill with a paged job moving logs out, then stop writing the old
  fields and strip them (deploy, migrate, deploy). Old app builds keep
  working because query shapes don't change.
- Also: `users.updateVisibility` rewrites every membership row to copy
  `seenVisibility`. Move that read to the user's row (or Phase 5 presence)
  and stop the fan-out write.

### 4D. Point reads instead of scans

- `users.blockCore`: loads all friendships of both users; use
  `friendships.by_pair` point reads (check the index name).
- `roomCleanup.findDmRoomsBetween`: scans all memberships on every report;
  DM names are deterministic (`dm:<key>:<idA>:<idB>`), so point-read
  `rooms.by_name`.
- `messages.ts` album lookup (send path, ~"albumId"): unscoped by room;
  add `messages.by_room_album ["roomId","albumId"]` with a limit.
- `roomInvites.activeInviteFor` / `listForRoom`: load every invite ever;
  bound with an index on status and a `take`.
- `typing.getTypingForUser`: session-long subscription over every typing row
  in every room of the user; scope it to the open room (client passes the
  room id; keep the old shape working).
- `searchUsers` (`users.searchUsersCore`, also behind `friends.searchUsers`):
  loads the whole `users` table per keystroke. Add a Convex search index
  (`searchIndex("search_username", {searchField: "username"})` and one on
  name, or a combined normalized field), query with `take(20)`, and keep the
  tombstone filter. Check the app's expectations for prefix vs fuzzy match.

### 4E. Room-cap counting

`addMembership` checks `MAX_ROOMS_PER_USER` by reading up to 500
`roomMembers` rows (~8 MB for a power user before 4C). Add a small
`userRoomCounts` table (`userId`, `count`; NOT a field on `users`, which
would churn every subscriber), maintained in `addMembership` /
`removeMembership` and every direct insert (the two documented
`systemRooms.ts` inserts and the deletion engine's membership step), with a
one-time paged backfill. The cap check becomes one point read.

### 4F. Packages and order

4B, 4D, 4E can run in parallel (disjoint files). 4C touches `messages.ts`
and `roomMembers`; run it alone or after 4D's `messages.ts` change. One
independent review at the end.

## 5. Phase 5: presence (designed, not started)

**Goal:** heartbeats stop re-running other people's screens. Today every
authenticated call reads the caller's own `users` row (`requireSession` in
`sessionCore.ts`), and `users.status`/`lastSeen` live on that row, so a
heartbeat write re-runs every query of that user on every device, plus every
list that reads their row (friends, members, feed). At 1M online users that
is ~2M query re-runs a second.

1. **`presence` table:** `userId`, `status`, `lastSeen`, plus the visibility
   levels for status and last seen (so privacy checks don't read `users`);
   index `by_user`.
2. **Writes:** `users.heartbeat` and `users.updateStatus` write only
   `presence`. During the switch they ALSO keep writing `users` (throttled as
   today, `presence.ts` throttles to 90 s) so old builds keep working. Note
   Phase 4A made `heartbeat` also refresh sessions once a day; keep that.
3. **New query** `presence:forUsers({ids})`, capped at ~100 ids, applying
   `visibility.ts` rules. The app subscribes for people on screen: chat
   header, visible chat-list rows, the open member sheet, the profile.
4. **`requireSession` stops reading `users`:** move "deleted" (Phase 2
   `deletingAt`) and "suspended" onto the session rows. Deletion and
   suspension already revoke sessions; set a flag on live sessions at the
   same time. Mind Phase 2's dependency: the first deletion transaction
   revokes up to 100 sessions and relies on `requireSession` checking
   `deletingAt` for the rest; once that check moves to sessions, cap live
   sessions per user in `mintSession` (for example 50, revoking the oldest)
   so the first transaction can revoke all of them.
5. **Readers:** every query that reads `status`/`lastSeen` from `users`
   (`users.getProfile`, `rooms.getMembers`, `groupCalls.roster`, `feed:board`)
   reads `presence` instead, or drops the field for the new app, which uses
   `presence:forUsers`.
6. **App release:** new `PresenceStore` on the Dart side subscribing to
   `presence:forUsers` for visible ids (dedupe subscriptions; see memory
   "Performance bar": rooms/roomMembers churn, dedup every Convex
   subscription).
7. **Cleanup:** once old builds are below the minimum supported version,
   stop writing presence fields to `users`, then strip them (deploy, migrate,
   deploy).

Also note: Phase 0 made `feed:board` read each reactor's live `users` row for
their photo setting; once heartbeats stop writing `users`, that cost goes
away with no change to the board.

## 6. Phase 6: profiles (designed, not started; needs Phase 5 first)

1. **`profiles` read model:** `userId`, `name`, `username`,
   `avatarStorageId`, avatar visibility, `updatedAt`; written only when one
   of those changes (rename, photo, visibility), so subscribers almost never
   refresh. Holds a Phase 3 file ref? No: the user row holds the avatar ref;
   the profile is a copy (`fileHold: "copy"`).
2. **`profiles:get({ids})`** in batches, privacy applied. The app caches by
   `userId` + `updatedAt` on the device so a cold start shows faces at once.
3. **New rows store only `userId`:** messages (`senderName`,
   `replyToPreview.senderName`), moments (`authorName`, `authorUsername`,
   `authorAvatarStorageId`), reactions, comments, comment reactions, record
   reactions, game seats, typing rows, interaction respondents. The full
   list of copies is plan section 3. Readers resolve through the profile
   cache. `mentions[].username` stays (it matches typed text); call push
   payloads stay (snapshots).
4. **Delete the sync code:** the avatar-repoint job (`deletionSteps/avatarSteps.ts`,
   enqueued from `users.updateAvatar`) and any rename sync. A rename or new
   photo is one write.
5. **Migration:** batched job strips old copies (deploy, migrate, deploy),
   only after old builds are below the minimum version.
6. **Open decision (plan section 7):** old posts after a rename show the
   name at posting time or the current name? With profiles the current name
   is free; keeping the old one means storing it on purpose. Ask the user
   before building step 3.

## 7. Decisions and questions

The user delegated these on 2026-10-23 ("decide what's best for a
production-ready app; make the 24 GB Ampere VPS last"). Decided by the
orchestrator with the big apps as reference. **The user may overrule any of
them; that is the only place questions live (7.3).**

### 7.1 Product decisions (made)

| Question | Decision | Reference |
|---|---|---|
| Old posts after a rename | **Current name** everywhere (messages, moments, reactions, comments). Phase 6 makes it free. | WhatsApp, Telegram, Signal, Slack, Instagram, Discord all show the current profile name on old content |
| DMs after one side deletes their account | **Keep the DM** for the other person, shown as "Deleted account" (no photo, no profile link), read-only | WhatsApp, Telegram ("Deleted Account"), Signal |
| Moderator "remove" for reported moments and comments | **Add it** (Phase 4G): App Store guideline 1.2 requires a way to remove objectionable UGC and act on reports within 24 h | Instagram/Facebook takedown, Slack admin delete |
| Personal stickers | Anyone may forward (user decided 2026-10-22) | Telegram, WhatsApp |
| Session lifetime, game history, receipts, old requests | As decided 2026-10-22 (plan section 7) | |
| Presence privacy | Keep today's visibility rules; presence is sent only for people on screen; "last seen" is an exact time only to those allowed to see it | Telegram (on-screen, throttled), WhatsApp |
| Presence freshness | Heartbeat stays at the current 90 s throttle; status flips to offline when the heartbeat stops (TTL), not by a client write | WhatsApp, Slack |
| Profile cache on the device | Profiles cached by `userId` + `updatedAt`, refreshed when a subscribed `updatedAt` changes | Slack, Discord |

### 7.2 Infrastructure stance (made)

One Oracle Ampere A1 (24 GB) runs self-hosted Convex. Every design choice
favours fewer re-runs and smaller rows over convenience:
- Hot rows (`users`, `roomMembers`, `rooms`) are written only when what
  subscribers display changes. Heartbeats go to `presence`, receipts to
  `receiptLogs`, counts to `userRoomCounts`.
- Subscriptions are scoped to what is on screen (typing per open room,
  presence for visible ids, group calls per room).
- Every cleanup pages and reschedules; nothing reads a whole table.

### 7.3 Questions for the user (answered 2026-10-23)

1. **Minimum app version for the cutovers.** Answer: **the next release is
   the minimum (a force update).** When it is approved in the stores, set
   `minSupported` to that version on every platform's `appReleases` row;
   from then on old builds are cut off, and the cutover steps (Phase 5
   W3-W5, Phase 6 W3 strip and 6Z, dropping the Phase 2 shims and the old
   schema fields) can run. That cleanup is the one step left for later.
2. **Deploy timing.** Answer: deploy everything once **every known small
   follow-up (section 8) is fixed**, so that nothing is left in this plan
   except the cutover and deleting the compat code. Backend first, then the
   app (runbook, section 3).

## 8. Known small follow-ups (not in any phase): all fixed 2026-10-23

Every item below is fixed in code with tests (uncommitted until reviewed,
then committed on `dev`). Nothing is left in this plan except the cutover
after the forced minimum version (7.3) and deleting the compat code.

| Item | Fix |
|---|---|
| `roomInvitations.respond` deleted then threw, so the delete rolled back | Deletes the stale invite and returns `{status: "gone"}`; the app shows "invitation gone" |
| Login screen suspended delete: no retry, no success message | Error with "Try again", green success banner; also offered after a refused password or Apple/Google sign-in |
| A long-suspended user could no longer delete (revoked session GC'd) | `auth.deleteSuspendedAccount` (password, same lockout as login) and `socialAuth.deleteSuspendedAccount` (provider token): one-shot delete with proof, suspended accounts only, no children |
| A banned password-only user could sign up again | Bans also record hashed `device:` (per-install `deviceSecret`) and `email:` keys; sign-up refuses them, sign-in is unchanged, unban removes them. Limit: a reinstall gets a new device secret |
| Purging an account deleted the reported content | Reports snapshot the content at report time (`reports.evidence`) and hold their own file refs (`evidenceMediaStorageId`, `evidencePosterStorageId`), released when the report expires (24 months). Staff read it with `moderation.reportEvidence`. View-once media is never kept. Reports filed before this change fall back to the card |
| `matchPresence` kept on a plain room leave | Removed on leave, kick and deletion (`leaveMatchesInRoom`) |
| `matches.watchers` frozen on finish | `finishMatch` clears `watchers` and `watching` |
| Dead `rooms.createdBy` after a creator who had left deletes their account | Deletion step `createdRooms` (index `by_created_by`) re-points it to the owner seat; rooms with no owner keep the id (field is required) |
| Heartbeat refreshed every session of the account | `functions.ts` records the calling session; `touchSessions` refreshes only it. Visible change, accepted: a device that is never opened for 90 days idles out (and stops getting pushes) even while the account is active elsewhere; opening the app, or answering a call, heartbeats. Signal and WhatsApp expire idle linked devices the same way |
| Phase 5F: roster status not refreshed on a legacy server | The roster dedup includes status/last seen only when the presence API is missing |
| Optional: `roomIds` for `groupCalls.liveInMyRooms` | Already shipped in Phase 5 (sorted-ids key, no resubscribe on reorder) |
| Four stale Flutter tests | Tests updated to the current UI (link underlines allow-listed, bell-slash mute glyph, Terms consent before username submit); no code regressions |
| Flaky `room_scroll_rebuild_test` | Waits for the subscription and render instead of a fixed 100 ms sleep |
| Stale `today` notes in `referenceRules.ts` | Verified and rewritten (stickers, moderation card, scheduled mentions/replies, expression favourites) |

Accepted by design, unchanged: poll respondent ids until the next write,
`sessions.userId` until GC, `problemReports.messageId` (expires
2026-11-06), a deleted personal sticker in a reply preview (privacy), a
scheduled reply whose parent was deleted goes out as a plain message.

Operator steps still open after deploy, all documented: Phase 0 item 14,
Phase 3 file-ref rollout, Phase 4 backfills, Phase 5 W1
(`SESSION_TRUSTS_ROW`), Phase 6 backfill. After the forced minimum version
is live: Phase 5 W3-W5, Phase 6 W3 strip and 6Z, the Phase 2 shims
(`auth.purgeMessagesLater`, `roomCleanup.wipeMessagesLater`), retiring
`gcOrphanedRoomMemberships`, and dropping `roomMembers.readLog` /
`deliveredLog`.
