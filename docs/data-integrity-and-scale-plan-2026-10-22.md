# Data integrity and scale plan (2026-10-22)

**Status:** Phase 0 is **Done in code** (2026-10-22, uncommitted, not
deployed; see the Phase 0 status note). Later phases are not implemented
except where a line says **Done**. Built from a live scan of every reference in the production
database and five code audits (accounts, rooms, messages, feed/games/calls/
stickers, files/copies/crons), with every high-severity claim re-checked by
hand against the code.

**Most urgent, from the audits:**
- Deleting a child's **only** guardian strands the child account for good.
- A co-guardian deleting their account **silently revokes the child's
  approved contacts and rooms**.
- A child's phone handed back by a guardian **stays signed in** as the child.
- Someone who hides their photo still shows their face on old moment
  reactions.
- A user kicked from a room **stays in its group call**.
- The daily unused-file cleanup **hasn't run** since `messages` passed 4,000
  rows.
- Account, room and message deletion all load whole histories in one
  transaction, so they fail for heavy users and big rooms. Apple requires
  working account deletion.
- Every heartbeat re-runs every screen of that user and their friends; at 1
  million users online, that's about 2 million query re-runs a second.

**Design target:** millions of daily active users, users with 100k+
messages and reactions, rooms with 1,000 members (the current cap). "It's a
small invite-only app" is not a reason to accept a design.

## Why this exists

Convex has no foreign keys. In Postgres every reference would carry a rule
(`ON DELETE CASCADE`, `SET NULL`, `RESTRICT`) and the database would enforce
it. Here every rule is code someone has to remember to write, and when they
forget, nothing fails: rows quietly point at things that no longer exist.

This plan:
1. gives every reference in the schema an explicit rule,
2. makes every cleanup and sync path safe for heavy users and big rooms,
3. separates profiles (name, username, photo) from presence (online status,
   last seen), the way WhatsApp, Telegram, Slack and Discord do, and
4. adds a guard so a new table can't silently skip these rules.

It extends `ACCOUNT_LIFECYCLE_AUDIT.md` (2026-07-23), which covered account
deletion only.

---

## 1. What the live database shows

Measured on the VPS deployment, 2026-10-22. Every `v.id` reference in the
schema (163 across 64 tables) was checked for a target that no longer exists.

| Reference | Dangling | What it is |
|---|---|---|
| `sessions.userId -> users` | 1 | A login session for a deleted account, from before the 2026-08-29 fix. Can't be used (see 2.1); just needs deleting |
| `roomChangeRequests.storageId -> _storage` | 1 | A rejected room-photo request; the photo was deleted, the row kept |
| `problemReports.messageId -> messages` | 7 | Test reports from launch day (2026-08-08) whose messages were removed by hand; deleted automatically on 2026-11-06 (see 2.3) |
| `typingIndicators.avatarStorageId -> _storage` | 2 | Copies of an old photo. **Not** self-healing (see 2.2): typing rows outlive membership and only refresh when that person types in that room |
| All 14 references on `messages` | 0 | Clean |
| Everything else | 0 | Clean |

Row counts are small today (23 users, 4,903 messages, 911 stored files),
which is exactly why now is the time to set the rules.

### Already fixed today (**Done**, deployed to the VPS)

- **Photo changes left broken copies.** `users.updateAvatar` deleted the old
  file but moments and moment reactions kept pointing at it. It now moves
  those copies (`repointAvatarCopies`). This still runs in one request, which
  breaks for heavy users: see Phase 2.
- **A device stuck on a bad cached image** (zeynepoz could not see goksu's
  photo) was fixed by re-keying goksu's avatar file once, and in the app by
  `RemoteImage` dropping a copy that fails to decode and fetching it again.
  The app half ships with the next build.
- The 2 broken moment copies left over from goksu's earlier photo were
  repaired.

---

## 2. Reference rules, table by table

Filled from the five audits. Each table lists the references that are
wrong today and the rule each should have; references not listed are
handled correctly (CASCADE) or are short-lived.

### 2.1 Users and accounts

Audited 2026-10-22. Re-checked by hand: the missing last-guardian check
(`auth.ts:850`), approvals deleted by decider (`auth.ts:903`),
`releaseDevice` not revoking sessions (`family.ts:406`), and sessions having
no expiry (`sessionCore.ts`).

**One deletion path.** The only `ctx.db.delete(userId)` is at the end of
`purgeUser` (`auth.ts:510`), reached from `auth.deleteAccount` (self) and
`family.deleteChildAccount` (guardian). Moderation only suspends. Of the 82
references to `users`, about 55 are handled correctly (CASCADE). The rest:

| Reference | Today | Should be |
|---|---|---|
| `guardianships` (deleting a child's **only** guardian) | Deleted with no check; the child can never be paired, released or deleted again | RESTRICT: refuse while this user is any child's only guardian |
| `approvalRequests.decidedByGuardianId` | Deletes every row the deleted guardian decided, **which are the child's live permissions** (approved contacts, approved rooms). A co-guardian deleting their account silently revokes them. | SET NULL |
| `roomJoinRequests.decidedBy`, `roomChangeRequests.decidedBy` | Deletes other people's request history | SET NULL |
| `sessions` after a guardian releases a child's phone | `releaseDevice` removes the device row but **the session stays valid forever**; the handed-back phone is still signed in as the child | Revoke the device's sessions |
| `sessions` in general | Live sessions never expire and `lastSeenAt` is never updated after sign-in (41 live, oldest 2026-08-25) | Idle expiry (for example 90 days), refreshed on use |
| `friendRequestMessages.requestId` | Orphaned on 4 paths: unfriend, reject, block, account deletion (the other person's messages on the request) | CASCADE via one helper |
| `roomBans.userId` | Never deleted (see 2.2) | CASCADE |
| `uploadUsage.userId` | Never deleted | CASCADE |
| `uploads.userId` | Dangles for files that outlive the user (a room photo they set) | SET NULL |
| `users.suspendedBy` | Dangles if the moderator is deleted; never read | KEEP-AS-HISTORY |
| `reports.reportedUserId`, `reports.actionedBy` | Kept | KEEP-AS-HISTORY (24-month retention) |
| `messages.mentions[]`, `replyToPreview.senderId`, `scheduledMessages.mentionedUserIds[]`, `momentComments.replyToUserId`, `matches.watchers[]`, `matchPresence.userId` | Dead IDs in other people's rows | KEEP for snapshots that carry a name; strip or SET NULL for the rest |

**The live orphan session** (section 1) predates the fix of 2026-08-29
(commit `bd7afce5`), which added session revocation to account deletion.
**It can't be used:** `requireSession` refuses any session whose user is
gone (`sessionCore.ts:177`). It just needs deleting; the existing
`sessions.revokeOrphaned` was never run.

**Other account bugs:**
- Signing into account B on a phone doesn't revoke a session account A left
  on the server for that phone (when A's sign-out never reached the server).
- After a guardian is unlinked, the pairing codes they made stay redeemable
  for their 5-minute life, and redeeming doesn't re-check that the creator is
  still a guardian.
- **Suspended users can't delete their own account:** `requireSession` throws
  `ACCOUNT_SUSPENDED` before `deleteAccount` runs. This is a data-deletion
  rights gap.
- `acceptRequest` (`friends.ts:284`) inserts the reverse friendship without
  checking for a duplicate.

**Scale:** apart from messages, `purgeUser` deletes everything in **one
transaction**: memberships and every member of every room, reactions, views,
moments with their children, one game result per day forever, calls and
their signals. A heavy user's deletion will throw, and Apple requires
working account deletion (guideline 5.1.1(v)). The users row is also deleted
first, so if a later message batch fails, the rest are orphaned for good.

**Fix pattern:** same as rooms. Mark the account deleted and revoke its
sessions immediately. Then a scheduled teardown with a cursor per table,
and delete the users row last.

**`ACCOUNT_LIFECYCLE_AUDIT.md` is out of date.** All its line numbers have
moved. It lists 17 tables (the code now covers about 55), and several of its
statements are no longer true: no rate limiting, client-supplied user IDs,
owner logic, "a child always has a guardian". Replace it with this document
once Phase 1 lands.

### 2.2 Rooms and membership

Audited 2026-10-22. Key claims re-checked by hand: the `receiptLog.ts:32`
cap, `roomBans` never being deleted, `gcOrphanedRoomMemberships` taking
50,000 rows in one mutation, and `family.ts:962` revoking by hand.

**Every room deletion goes through `wipeRoomCompletely`
(`roomCleanup.ts:203`).** Its callers are `rooms.deleteRoom`, the last member
leaving (`roomAdmin.ts:279`), account deletion when the user was the last
member (`auth.ts:538`), block with "delete DM" (`users.ts:920`), a guardian
cutting off a contact (`family.ts:1136`), and the daily orphan cron
(`roomCleanup.ts:300`).

**Handled correctly (CASCADE):** messages (in batches of 300), reactions,
view-once views, message files (reference-counted), roomMembers, roomAccess,
pins, bookmarks, polls and their answers, speaker colors, matches with their
moves, presence and hidden rows, game challenges, typing rows, invite links,
invitations, join requests, change requests, scheduled messages, and the
room photo.

**Not handled:**

| Reference | Today | Should be |
|---|---|---|
| `roomBans.roomId`, `roomBans.userId` | Never deleted, by anything: not room deletion, not account deletion, not ban expiry. There is no `by_user` index. | CASCADE on both; delete expired bans with a cron |
| `calls.roomId`, `groupCalls.roomId` | A live call in a deleted room carries on; only finished calls get swept | End live calls as part of room deletion |
| `friendships.roomId` | Keeps pointing at a deleted DM (20 rows set, 0 dead today) | SET NULL, or drop the field |
| `approvalRequests.targetRoomId` | A pending "join room" approval for a deleted room can't be approved and sits in the guardian's queue | Delete pending ones; SET NULL on decided ones |
| `roomJoinRequests.inviteId` | Dangles after the link's creator deletes their account | SET NULL |
| `roomChangeRequests.storageId` | **The live orphan.** A rejected request keeps its row as an audit record (on purpose), but its photo file gets deleted. Approved rows will do the same the next time the room photo changes. | SET NULL whenever the file is released; only pending rows hold a file |
| `roomJoinRequests.decidedBy`, `roomChangeRequests.decidedBy` | Account deletion deletes the whole row, erasing someone else's request history | SET NULL |
| `rooms.createdBy` | Re-pointed only when nobody holds the owner role (0 dangling today) | Always re-point if it is the deleted user |
| `reports.roomId` | Kept | KEEP-AS-HISTORY (24-month moderation retention); readers must handle a missing room |
| `typingIndicators` | Not deleted on leave or kick; the avatar copy dangles indefinitely if the user never types there again. **Correction:** section 1 called these self-healing, which is wrong. | Delete on leave; read the photo from `profiles` |
| DM rooms after account deletion | The other person keeps a one-member DM whose name contains the dead user's ID | Decision needed (section 7) |

**Bugs, ranked:**
1. **High: room deletion is batched for messages only.** About 15 other
   tables load their whole history in one transaction (`roomCleanup.ts:90-193`),
   including every game ever played with all its moves. A busy room can't be
   deleted, so its last member can't leave either.
2. **High: no safety net if a message batch fails.** One failed
   `wipeMessagesLater` step stops the chain for good. The memberships are
   already gone by then, so the orphan cron never finds those messages again.
3. **High: the orphan cron itself breaks at scale.** It loads up to 50,000
   membership rows in one mutation (`roomCleanup.ts:304`). Past ~16k rows it
   will fail every day.
4. **High: account deletion can't finish for heavy users.** For every room
   it loads all members and may wipe the room, all in one transaction
   (`auth.ts:518-562`).
5. **Medium: guardian "revoke approval" has its own leave logic**
   (`family.ts:962-976`) instead of `removeMembership`. It skips deleting an
   emptied room, reassigning the owner, and cleaning up bookmarks, colors and
   pending requests. The matching approve path skips the room-size caps.
6. **Medium: the room and member caps can be bypassed.** `MAX_ROOMS_PER_USER`
   (500) is checked only in `addMembership`, but 7 other places insert
   memberships directly (`rooms.ts`, `friends.ts`, `family.ts`). Every
   "bounded at 500/1000" argument depends on those caps holding.
7. **Medium: read receipts are heavy.** Each log is capped at 200 entries,
   but a membership row reaches ~17 KB and is rewritten on every receipt.
   `getReadState` reads every member row, so a 1,000-member room reads about
   17 MB per run, and every receipt re-runs it for everyone in the room.
8. **Medium: `roomBans` grows forever** (see table).
9. **Low:** the dangling references in the table above, and live calls
   continuing in a deleted room.

**Other unbounded loads:** `blockCore` (`users.ts:897`) loads all
friendships of both users instead of two point reads. `findDmRoomsBetween`
(`roomCleanup.ts:349`) scans all memberships on every report. The DM name is
deterministic, so point reads on `by_name` would do. `updateVisibility`
(`users.ts:380`) rewrites every membership row, including the 17 KB logs.
`activeInviteFor` and `listForRoom` load every invite ever made.
`getTypingForUser` (`typing.ts:137`) is a session-long subscription over
every typing row in every room the user is in.

**Fix pattern for room deletion:** mark the room as being deleted and hide
it right away. Record that in a `roomDeletions` table, run one scheduled job
per table in chunks sized by write budget, and delete the `rooms` row last. A
cron re-drives anything that stalled, so a failed step can never orphan rows
again, and the current orphan cron becomes unnecessary.

### 2.3 Messages and everything attached to them

Audited 2026-10-22. Re-checked by hand: `interactions.ts:165` reading a
nonexistent `displayName`, and `removeMembership` not touching scheduled
messages.

**One delete path.** Every message delete (delete, bulk delete, self-destruct,
moderator removal, evidence expiry, game takeback, account deletion) goes
through `removeMessageAndFanout` (`messages.ts:1997`). There is no separate
"unsend". It correctly cascades reactions, pins, bookmarks, view-once
records, polls and their answers, game challenges, and games with their move
bubbles. Media files are reference-counted, so a forwarded copy keeps the
file alive. Room deletion sweeps the same tables by room instead.

| Reference | Today | Should be |
|---|---|---|
| `messages.replyToId`, `messages.rootId` | Keep the dead ID; the reply preview shows "deleted" | KEEP (documented soft reference); readers already handle it |
| `replyToPreview.mediaStorageId` | Removed when the parent is deleted, **even if a forward keeps the file alive** | Remove only when the file is actually gone |
| `replyToPreview.stickerStorageId` | Never removed | SET NULL when the sticker file is deleted |
| `messages.stickerId/stickerStorageId` | Break when a personal sticker's owner deletes their account (see 2.4) | Decision in section 7 |
| `matchMoves.messageId` | Dangles if a player deletes their own move bubble | SET NULL (as takeback already does), or don't allow deleting move bubbles |
| `scheduledMessages` after **leaving or being removed from a room** | Not cancelled. At send time it fails as "not a member" and the row, with its photo, is **kept forever** | Cancel on leave; delete failed rows after N days |
| `scheduledMessages.replyToId` | If the parent is deleted before sending, it goes out as a plain message without telling the sender | Tell the sender |
| `reports.messageId`, `reports.cardMessageId` | Kept | KEEP-AS-HISTORY (moderation evidence) |
| `moderationCard.hasMessage` | Never updated after the reported message is deleted, so the card offers "Remove" for a message that's already gone | Update on delete |
| `problemReports.messageId` | Never read by anything | Drop the field |
| Album reactions | Stored on the album's first photo; deleting that one photo deletes reactions for the whole album | Move them to the next photo, or key them by album |
| Burned view-once | The file is deleted but the **caption is kept** | Clear the caption too |

**The 7 live problem-report orphans** are test reports filed 2 to 8 minutes
after the feature shipped on 2026-08-08. Their messages were removed one by
one from a room that still exists, almost certainly a manual dashboard
cleanup (dashboard deletes don't cascade). No current code path can do it.
The 90-day retention deletes these rows on **2026-11-06**; no action needed.

**Bugs:**
1. **High:** the unused-file cleanup is off (see 2.4).
2. **High (scale):** deleting one message loads all its reactions, pins,
   bookmarks, replies, view-once records and poll answers in one transaction.
   A popular message in a big room can't be deleted. If it's a self-destructing
   message, **the self-destruct fails and the promise is broken.** Bulk
   delete does 25 of these at once; account deletion does 200.
3. **Medium:** scheduled messages survive leaving a room (table above).
4. **Medium:** poll answers always show the username, never the display name
   (`interactions.ts:165` reads `user.displayName`, which doesn't exist).
5. **Low:** the deprecated `getThread` returns an empty thread when an
   ancestor was deleted.
6. **Low:** the album send path loads every message with that album ID,
   unscoped by room (`messages.ts:1387`).

**Copies:** `messages.senderName` and `replyToPreview.senderName` are never
updated on rename, so old bubbles show the old name forever. The message
list deliberately never reads `users`, which is right for performance; with
profiles (Phase 6) it can show current names without that cost.
`mentions[].username` stays frozen on purpose: it matches the text the
sender typed.

### 2.4 Feed, games, calls and stickers

Audited 2026-10-22. Re-checked by hand: the reaction privacy leak
(`feed.ts:162`) and the file cleanup cap (`files.ts:382`).

**Moments are kept forever on purpose.** `expiresAt` only decides what shows
on friends' boards; the author keeps an archive. Deleting a moment (or an
account) does cascade to reactions, views, comments, comment reactions and
files. What is wrong:

| Reference | Today | Should be |
|---|---|---|
| `momentReactions.userAvatarLevel` | **Privacy leak.** A copy of the reactor's photo-visibility setting, taken when they reacted, and never updated. Someone who sets their photo to "nobody" still shows their face on every old reaction. | Read the live setting (as comments already do) |
| `momentReactions` (blocked users) | Board reactors don't filter blocked users; comments do (`momentComments.ts:170`) | Filter blocks |
| `momentViews` of expired moments | Kept forever; nothing reads them | Delete after the moment expires |
| Personal stickers | Anyone can send someone else's personal sticker taken from a message. When the owner deletes their account, the sticker files are deleted, and every message, forward, reply preview, comment and recents list that used it breaks. | Only the owner can send their personal stickers, or show a "sticker unavailable" placeholder |
| Soft-deleted personal stickers | The file is kept forever, even with no references, and soft-deleted rows don't count toward the 120 limit, so the table grows without bound | Delete the file when nothing references it |
| `userExpressions` recents/favorites | Other people's lists keep dead stickers; the server never checks that a sticker exists or matches its file | Filter on read |
| Group call after leaving or being kicked from a room | **The user stays in the call** and keeps sending and receiving | Remove them from the call on leave |
| Calls in a deleted room | Keep running | End them as part of room deletion |
| `matches`, `matchMoves`, `matchHidden`, `matchPresence` | Never expire; party games log a move per tick | Delete finished games after N days, or keep a summary |
| `matchPresence` | Not removed when a player leaves; there is no `by_user` index | Delete on leave |
| `matches.watchers` | Frozen on finish | Clear on finish |
| `matchMoves.messageId` | Dangles if a move bubble is deleted by hand | SET NULL |
| `gameResults`, `puzzleResults` | One row per user per day per game, forever (about 1,800 a year per active user) | Retention policy, or yearly roll-ups |
| Shared files | One uploaded file can back a message, a moment, an avatar and a sticker at once, and each delete path checks only its own table. The current app always uploads fresh, so this hasn't happened yet. | Reference count on the `uploads` ledger |

**Call cleanup can't keep up at scale.** Signal sweeps clear 200 rows every 2
to 5 minutes. A single call sends dozens of connection signals.
`gcStaleGroupParticipants` looks only at the 50 oldest calls, so past 50
live calls, stale ones are never reaped. `liveInMyRooms` takes the first 100
active group calls **worldwide**, so past 100 concurrent calls a user's own
room call silently disappears, and every join anywhere refreshes every
user's subscription.

**Also confirmed:** the daily unused-file cleanup (`gcOrphanedFiles`) gives
up when any table has more than 4,000 rows (`MAX_SCAN`). `messages` has
4,903, so **it currently skips every day**. It also doesn't know about
sticker and avatar copies.

**Scale:** `repointAvatarCopies` (shipped today) rewrites every moment and
reaction a user ever made in one request, and each rewrite refreshes every
friend's feed. Room deletion erases every game the room ever had, with all
moves, in its first transaction.

### 2.5 Files (`_storage`)

Audited 2026-10-22. Re-checked by hand: the `MAX_SCAN` cap in
`files.ts:382`.

**How it works today.** The `uploads` table records each file's **owner**,
not how many rows use it. Before deleting a file, only two places check for
other users of it: messages (`by_media`, `files.ts:417`) and moments
(`feed.ts:750`). Everything else deletes the file outright when its own row
goes.

| File field | Today | Should be |
|---|---|---|
| `users.avatarStorageId` | Old file deleted on change; copies moved (shipped today) | Owned by the row; copies go away with profiles |
| `rooms.avatarStorageId` | Owned by the row. **System rooms share the system account's avatar file**, so re-avatarring or wiping one deletes the account's avatar. `systemAvatars.apply` never frees the old file (leak). | Each row gets its own file, or a reference count |
| `messages.mediaStorageId`, `posterStorageId` | Counted across messages only; the poster check reuses the media lookup | One reference count across all tables |
| `messages.stickerStorageId`, `momentComments.stickerStorageId`, `replyToPreview.stickerStorageId` | Break when a personal sticker's owner deletes their account | Tombstone the sticker and keep the file (the soft delete already does this) |
| `stickers.storageId` | Soft delete keeps the file; account deletion hard-deletes it, which breaks the soft-delete promise | Always tombstone |
| `moments.posterStorageId` | `feed.remove` checks the poster against the **media** index, so a shared poster gets deleted while another moment uses it | Reference count |
| `scheduledMessages.mediaStorageId` | Failed rows keep their file forever | Delete failed rows after N days |
| `roomChangeRequests.storageId` | The live orphan (see 2.2) | SET NULL on release |
| `uploads.userId` | Dangles for files that outlive their owner | KEEP-AS-HISTORY |
| `uploadUsage.userId` | Never deleted | CASCADE |

**Cross-table sharing is allowed.** `claimUpload` lets the same owner claim
a file again (`files.ts:90-94`), so one file can back a message, an avatar, a
moment and a sticker at once. Any single delete then destroys it for all of
them. Today's app always uploads fresh, so it hasn't happened yet.

**The unused-file cleanup is dead.** `gcOrphanedFiles` builds one set of
every referenced file by scanning each table, and gives up if any table has
more than 4,000 rows. `messages` has 4,903, so it has deleted nothing since
then. This design can't work at scale whatever the cap: it has to read the
whole database.

**Fix:** turn the `uploads` ledger into a real reference count (or one
back-pointer row per use). Every attach increments it, every release
decrements it, and the file is deleted at zero. Unused-file cleanup then
becomes "ledger rows at zero, or files with no ledger row past the grace
period". That's an index range, not a full scan.

### 2.6 References stored as plain strings

| Reference | Today | Rule |
|---|---|---|
| `reports.targetId` (room, user, message, moment, comment) | Kept; resolved with a fallback | KEEP-AS-HISTORY. There is no moderator takedown for a reported moment or comment; check against App Review's user-generated content rules. |
| `messages.albumId` | Group key; the album lookup is unscoped and loads every match | Index on `[roomId, albumId]` with a limit |
| DM room names (`dm:<key>:<idA>:<idB>`, `dm:self:<id>`) | Contain user IDs; survive account deletion | Decision in section 7 |
| `rateBuckets.key`, `authAttempts.key` (`upload:<userId>` and similar) | Expire, but cleanup only does 500 and 800 rows a day | Self-rescheduling cleanup |
| Device IDs on calls and signals | Short-lived, swept after 24 hours | KEEP |
| `matches.state`, `matchMoves.move` | Seat indexes, not IDs | n/a |

---

## 3. Copied data

Every field that duplicates data from another row, whether it is kept in
sync, and what users see when it is stale.

Rename and display-name changes patch only the `users` row; **no copy of a
name or username is ever updated.** Photo changes now move two copies (see
section 1).

| Copy | From | Kept in sync? | Becomes |
|---|---|---|---|
| `messages.senderName` | name | Never | userId + profile |
| `messages.replyToPreview.senderName` | parent's `senderName` (a copy of a copy) | Never | userId + profile |
| `messages.mentions[].username` | handle | Never, on purpose | **Keep**: it matches the typed text |
| `interactionResponses.userName`, `messageInteractions…respondents[].name` | `user.displayName`, **which doesn't exist**, so always the handle | Never | userId + profile |
| `moments.authorName`, `authorUsername` | users | Never | userId + profile |
| `moments.authorAvatarStorageId` | users | Moved on photo change (unbounded) | userId + profile |
| `momentReactions.userName`, `userUsername`, `userAvatarStorageId` | users | Names never; photo moved | userId + profile |
| `momentReactions.userAvatarLevel` | visibility setting | **Never: privacy leak** | Read the live setting |
| `momentComments.userName`, `replyToName` | users | Reader already uses the live name; copy is a deleted-account fallback | userId + profile |
| `momentCommentReactions.userName`, `recordReactions.userName` | users | Never | userId + profile |
| `gameChallenges.name`, `matches.seats[].name`, `seatRequest.name` | users | Never | userId + profile, or keep as a snapshot for finished games |
| `typingIndicators.userName`, `avatarStorageId`, `avatarVisibility` | users | Only while typing; rows never deleted | userId + profile |
| `roomMembers.seenVisibility` | visibility setting | Yes, by rewriting every membership row (unbounded) | Read from presence/visibility |
| Call invite payload (`callerName`, avatar) | users | Snapshot | **Keep**: it's a push payload |
| `rooms.memberCount` | count of members | Increment/decrement only; 0 drift today. Every join or leave rewrites the room row, refreshing every member's room list | Keep, but route every membership change through one helper |
| `rooms.lastMessage*` | newest message | Repaired on delete and edit | Keep |
| `moments.commentCount` | count of comments | Yes | Keep |

**A note on why copies exist:** the comment at `users.ts:646` says the feed
never reads `users`. It does: `feed:board` reads every friend's row for
their visibility settings (`feed.ts:303`). So today the copies cost
staleness and save nothing. Profiles fix both.

---

## 4. Profiles and presence

### The problem

`users.status` and `users.lastSeen` sit on the same row as name, username
and photo. Every heartbeat write re-runs every query that reads that row
(room lists, friend lists, request lists) for everyone connected to that
person. `presence.ts` already throttles writes to every 90 seconds to cope.
This coupling is also why posts copy names and photos instead of storing a
user ID.

### How the big apps do it

| App | Approach |
|---|---|
| WhatsApp | Presence held in server memory, sent only while a chat is open; "last seen" fetched once on open |
| Telegram | Pushed only to contacts who are online, throttled; often a vague "last seen recently" |
| Slack | Clients subscribe to presence for the specific people shown (a few hundred max) |
| Discord | Lazy member lists; presence only for visible members |
| Meta | Dedicated in-memory presence service, batched updates to active viewers only |

Shared principles: presence lives apart from the profile; you receive it only
for people on screen; only transitions are sent; it is short-lived and
expires on its own.

### Target design

1. **`profiles` read model.** Name, username, photo. Posts, reactions and
   messages store only the user ID. The app looks up profiles in batches and
   caches them on the device. A rename or a new photo is one write.
2. **`presence` table.** One row per user: status, last seen. Heartbeats write
   only here and invalidate nothing else.
3. **On-screen subscriptions.** `presence:forUsers(ids)`, capped at about 100
   IDs, subscribed for the people currently visible. Convex re-runs it only
   when one of those rows changes.
4. **Privacy stays server-side.** The visibility check in `visibility.ts`
   still decides who sees status and last seen.

### What reads `users` today

**Every authenticated call reads the caller's own row**
(`requireSession`, `sessionCore.ts:177`) to check that the account still
exists and isn't suspended. So **each heartbeat write re-runs every screen
that user has open, on every device**, before counting anyone else. Fix:
keep "deleted" and "suspended" on the session rows (deletion and suspension
already revoke sessions), and stop reading `users` there.

Queries that read other people's rows:

| Kind | Queries | Rows per call |
|---|---|---|
| Need status or last seen | `users.getProfile`, `rooms.getMembers`, `groupCalls.roster`, `feed:board` | 1 to 1,000 |
| Need only name, handle, photo and visibility | `friends.listFriends`, the friend-request lists, `games.standings`, `records.board`, `feed.moment`, `feed.archive`, `momentComments.list`, `calls.activeCallForUser`, `groupCalls.pendingInviteForUser`, `challenges.roomResults`, room invitation, join and change request lists, `users.listBlocked`, the family queues, `auth.whoami`, `terms.status`, `rooms.listPublic` | 1 to "all friends" |
| Whole table | `users.searchUsers` / `friends.searchUsers` (`users.ts:746`): every user, on every keystroke | **all users** |

**Fan-out per heartbeat, worked example** (from the storage audit): a user
with 200 friends, 30% online with the feed open, causes about 200 query
re-runs per heartbeat write. At 1 million users online, that is about 11,000
writes a second and **about 2 million query re-runs a second**. With
presence split out, a heartbeat re-runs only the `presence:forUsers`
subscriptions that are showing that person right now.

**Dead code to delete:** `auth.updateStatus` (`auth.ts:1060`) is a second
public status write with no throttle. The app uses `users.updateStatus`, but
the old one is still callable and lets anyone hammer their own user row.

### Infrastructure

The backend runs on one Oracle Ampere A1 (24 GB) with one self-hosted Convex
instance. That is fine for now; no single server holds millions of daily
users, so that move happens regardless. This redesign makes the current box
last much longer (heartbeats stop re-running other people's lists), and makes
the later move cheap: presence becomes one module that can be swapped for an
in-memory service.

---

## 5. Things that grow forever

### Tables with no cleanup

| Table | Growth | Proposal |
|---|---|---|
| `roomBans` | Every kick, forever | Delete on expiry, room deletion, account deletion |
| `typingIndicators` | One row per person per room they ever typed in; `clearTyping` only zeroes a timestamp | Delete on stop and on leave |
| `momentViews` | Every view, forever, even after the moment expires | Delete after the moment expires |
| `gameResults`, `puzzleResults` | One row per user per game per day | Retention decision (section 7) |
| `matches`, `matchMoves`, `matchHidden`, `matchPresence` | Every game and every move, forever | Delete finished games after N days |
| `scheduledMessages` (failed) | Forever, with their files | Delete after N days |
| Decided `roomInvitations`, `roomJoinRequests`, `roomChangeRequests`, `approvalRequests`; rotated `roomInvites` | Forever | Keep for N days, except the ones that are live permissions (approvals) |
| `pairingCodes`, `releaseCodes` | Expired and consumed codes stay | Delete expired |
| `sessions` | Live sessions never expire | Idle expiry (section 7) |
| Problem-report log room | Its messages and files are never deleted, though the report rows are (90 days) | Same 90 days |
| Unconsumed `callSignals` of ended calls | The sweep only looks at consumed ones | Delete with the call |

### Cleanups that can't keep up

None of these reschedules itself, so at scale each backlog grows forever:

| Cleanup | Capacity |
|---|---|
| `gcRateBuckets` | 500 rows a day |
| `gcAuthAttempts` | 800 a day |
| `gcRevokedSessions` | 800 a day |
| `gcExpiredReports`, problem reports | 200 a day |
| `gcTerminalCalls` | 250 an hour |
| `gcTerminalGroupCalls` | 50 an hour |
| `gcConsumedSignals` | 200 every 2 minutes, a few thousand calls' worth a day |
| `gcStaleGroupParticipants` | Looks at the same 50 oldest calls every minute; past 50 live calls, the rest are never reaped |
| `gcOrphanedFiles` | Not running at all (section 2.5) |
| `gcOrphanedRoomMemberships` | Loads up to 50,000 rows in one go; fails past ~16k |

**Fix pattern:** each cleanup takes a page, and if the page was full,
schedules itself again immediately (`runAfter(0)`), ranging on an index
rather than a fixed "first N".

### Rows that are too big

- `roomMembers.readLog` / `deliveredLog`: capped at 200 entries each, but the
  row reaches ~17 KB, is rewritten on every receipt, and `getReadState` reads
  every member row of the room (~17 MB for 1,000 members per run).

### Whole-history work in one request

Each of these loads a user's or room's entire history in one transaction
and fails once that history is big:

- account deletion (`purgeUser`), apart from messages
- room deletion (`wipeRoomRows`), apart from messages
- deleting one message (all reactions, pins, bookmarks, replies, view-once
  records, poll answers)
- deleting a game card (every move, each a full message delete)
- `repointAvatarCopies` (shipped today)
- `updateVisibility` (every membership row)
- `blockCore` (all friendships of both users, instead of two point reads)
- `findDmRoomsBetween` (all memberships, on every report)
- `getTypingForUser` (every typing row in every room the user is in, as a
  session-long subscription)
- `liveInMyRooms` (first 100 active group calls **worldwide**; past that a
  user's own room call silently disappears)
- `searchUsers` (the whole `users` table)
- personal sticker create and purge (all stickers, including soft-deleted)

---

## 6. Phases

Each phase ships on its own, backend first. Phases 0 and 1 are small fixes
with no app release. Phases 2 to 4 are the structural work. Phases 5 and 6
need an app release and a data migration.

### Phase 0: security, privacy and data-loss bugs (backend only, days)

Each item is small and independent, with a test.

1. **Sole guardian deletion:** `deleteAccount` refuses while the user is any
   child's only guardian (`LAST_GUARDIAN`).
2. **Co-guardian deletion revokes a child's permissions:** SET NULL on
   `approvalRequests.decidedByGuardianId`, `roomJoinRequests.decidedBy`,
   `roomChangeRequests.decidedBy` instead of deleting the rows.
3. **Released child phone stays signed in:** `releaseDevice` revokes the
   device's sessions. Pairing-code redemption re-checks that the creator is
   still a guardian.
4. **Reaction faces ignore privacy:** the board reads the reactor's live
   photo visibility (as comments already do), and filters blocked users.
5. **Kicked users stay in group calls:** `removeMembership` removes the user
   from the room's live group call. Room deletion ends live calls.
6. **Guardian revoke has its own leave logic:** `family.ts` uses
   `addMembership` / `removeMembership`. Every other direct membership insert
   (7 sites) goes through `addMembership`, so the room caps actually hold.
7. **Personal stickers:** account deletion tombstones stickers instead of
   deleting their files (pending the decision in section 7).
8. **Scheduled messages survive leaving a room:** cancel them on leave.
9. **Poll names:** `interactions.ts:165` uses `user.name ?? user.username`.
10. **Burned view-once keeps its caption:** clear it.
11. **Room-photo request keeps a dead file:** clear `storageId` on reject and
    on replacement.
12. **Shared moment poster deleted:** `feed.remove` checks the poster against
    the poster index (folded into Phase 3 if that lands first).
13. **Dead code:** delete `auth.updateStatus`.
14. **Live data cleanup:** run `sessions.revokeOrphaned` once (1 row). The 7
    problem-report orphans expire on their own on 2026-11-06.
15. **Suspended users can't delete their account:** `deleteAccount` accepts
    a suspended session (moved here from Phase 2.7; it's a data-deletion
    rights gap, not a scale problem).
16. **Ghost sessions on a shared device:** if account A's sign-out never
    reached the server (offline, failed request, app reinstalled, local
    session cleared after an error), A's server session stays valid forever
    even after B signs in on that phone. The app no longer holds A's token,
    but it is a live credential nobody can see. Signing in on a device now
    revokes every other account's live session on that device
    (`sessions.by_device`).
17. **Duplicate friendship on accept:** `acceptRequest` checks for an
    existing reverse row before inserting.
18. **Friend-request messages orphaned:** one helper deletes a request's
    `friendRequestMessages`, called from unfriend, reject, block and account
    deletion.

19. **Device proof.** Found in review of item 16: `deviceId` is not a
    secret (peers see it in call rosters), so anyone could claim someone
    else's and evict their session. Each install now also holds a random
    `deviceSecret`, sent only on sign-in and stored hashed on the session;
    cross-account eviction needs a matching secret. Needs an app release;
    old builds keep today's behaviour.
20. **Ban escape through deletion.** Also from review: once item 15 let a
    suspended user delete their account, the purge removed the ban with it,
    so they could sign up again with the same Apple or Google ID. Deleting a
    suspended account now leaves a hashed ban record that sign-up checks.

Known gap in item 15: revoked sessions are garbage-collected after a while,
so a long-suspended user can no longer delete from the app; staff deletes
for them.

Items 15 to 20 were added on review: each is small, real and independent of
the redesign, so they don't belong behind Phases 1 and 2.

**Phase 0 status (2026-10-22): Done in code, not deployed.** Items 1 to 13
and 15 to 20 are implemented with tests (`accountIntegrity`, `roomIntegrity`,
`contentIntegrity`); the whole backend suite passes (762 tests) and the
typecheck is clean. An independent review of the first pass found six
problems, all fixed (items 19 and 20 came from it). Item 14 is a live-data
run and waits for the deploy. Shipping order:
1. Deploy the backend first. It adds indexes (`moments.by_poster`,
   `calls.by_room_status`, `sessions.by_device`, `rooms.by_avatar`,
   `roomChangeRequests.by_storage`) and the `bannedIdentities` table.
2. Then the app release. It sends `deviceSecret` on sign-in, which an old
   backend would reject. It also stops the sign-out on a `LAST_GUARDIAN`
   refusal and lets a suspended user delete their account from the login
   screen.

Known limits, left for later phases:
- A banned user with a password account can still sign up again under a
  new username (only Apple/Google identities are matched).
- Purging an account deletes the reported messages and moments, so those
  reports keep only the moderation card's excerpt.
- Forwarded personal stickers of a deleted account show a broken tile;
  the app should draw "unavailable".
- On the login screen's suspended delete: no retry after a failure, and no
  success message.

### Phase 1: one rule per reference, enforced by a test

1. A `REFERENCE_RULES` table in code: every `v.id` path in the schema mapped
   to `cascade`, `setNull`, `restrict`, `history` or `ephemeral`, with the
   index the cleanup uses. Section 2 of this document is its first draft.
2. **The guard:** a test walks the schema (the same way the audit's orphan
   checker did) and fails if any `v.id` field has no rule, or a `cascade` or
   `setNull` rule has no index on that field. A new table can no longer
   silently skip cleanup.
3. Add the missing indexes the rules need: `roomBans.by_user`,
   `roomBans.by_until`, `matchPresence.by_user`, `approvalRequests.by_room`,
   `friendships.by_room`, sticker referrer indexes, and so on.
4. A read-only **integrity check** (the orphan scan from section 1, paged)
   as an internal query, run weekly. It reports counts per reference, so
   drift is seen within a week instead of by users.
5. Replace `ACCOUNT_LIFECYCLE_AUDIT.md` with a pointer to this document.

**Phase 1 status (2026-10-22): Done in code** (commit `2e847111`, not
deployed). Items 4 and 5: `integrity.ts` scans every reference weekly
(Sunday 04:30 UTC) in 200-row pages, keeps one small counter row per table
(`integrityCounts`), resumes a stalled run hourly (3 tries, then failed
with a warning), and splits expected dead ids (history/softRef) from
violations; read the result with `internal.integrity.latest`.
`ACCOUNT_LIFECYCLE_AUDIT.md` is now a pointer here.
`backend/convex/schemaRefs.ts` walks the schema (163 reference paths across
56 tables; the other 8 tables hold none). `backend/convex/referenceRules.ts`
gives each path a rule: cascade 95, setNull 14, history 16, softRef 12,
file 19, ephemeral 6, restrict 1. `referenceRules.test.ts` fails when a path
has no rule, a rule names a path that's gone, or a cascade/setNull rule has
no matching index; the message says what to add. Seven indexes were added for
the rules: `approvalRequests.by_target_room`, `friendships.by_room`,
`matchMoves.by_message`, `matchPresence.by_user`, `roomBans.by_user`,
`roomBans.by_until`, `roomJoinRequests.by_invite`. Decided on the way:
`uploads.userId` is SET NULL (the ledger keeps no dead person's id);
`rooms.createdBy` is history (the owner role is what matters, not the
creator); calls and group-call references are ephemeral (Phase 0 ends live
calls, the crons sweep the rest).

**The Phase 2 worklist is the code, not this document:** every entry in
`REFERENCE_RULES` that carries a `today` field is a place where current
cleanup differs from the rule (31 entries on 2026-10-22, 2 still
`unverified`). Phase 2 is done when no `today` remains except the ones kept
on purpose (sticker files, decided in Phase 0).

### Phase 2: a lifecycle engine for deletes (backend only)

**Detailed design:** `docs/data-integrity-phase2-design.md` (reviewed
2026-10-22; its Decisions section is binding). Built in four packages: A
(engine core) first, then B (messages, moments, comments, matches, avatar
copies), C (room and user teardown, caller migration) and D (read side,
retirements) in parallel.

One mechanism for every parent with a big history: users, rooms, messages,
moments, games.

1. **Tombstone first.** Deleting a user or room sets `deletingAt`, revokes
   sessions or hides the room, and records a row in a `deletions` table
   (`kind`, `id`, `table cursor`). From that moment every read treats it as
   gone.
2. **Batched sweeps.** One scheduled job per child table walks the rule
   table from Phase 1, deleting or clearing in pages sized by a write budget
   (for example 500 writes), and schedules itself again until the page comes
   back short.
3. **Parent row last.** The `users` or `rooms` row is deleted only when every
   child table reports done. Until then the IDs still resolve, so nothing
   dangles mid-way.
4. **Re-driven by a cron.** A cron picks up any `deletions` row with no
   progress for 10 minutes and restarts its next step. A failed batch can
   never orphan rows again, which retires `gcOrphanedRoomMemberships`.
5. Message delete keeps its immediate part (the row disappears, preview and
   room summary repaired in the same transaction) and moves the children
   (reactions, view-once records, poll answers, bookmarks) to the same batch
   engine. Self-destruct can no longer fail on a popular message.
6. `repointAvatarCopies` moves to the engine as a stopgap until Phase 6
   removes it.
7. (Moved to Phase 0, item 15.)

### Phase 3: files with real reference counts

1. The `uploads` ledger gains a `refs` count (or one row per use). Every
   attach (`claimUpload` and the share paths: forward, evidence, sticker
   send, reply preview) increments it; every release decrements it; the file
   is deleted at zero.
2. A second claim of an already-attached file is rejected unless it comes
   through an explicit share path.
3. Unused-file cleanup becomes an index range over the ledger: zero refs,
   or files with no ledger row past the grace period. No full-database scan,
   no `MAX_SCAN`.
4. A backfill gives existing files their count, using the paged integrity
   check from Phase 1.
5. System rooms get their own avatar file; `systemAvatars.apply` frees the
   old one.

### Phase 4: every cleanup keeps up

1. Every cron in section 5 reschedules itself while pages come back full,
   and ranges on an index (no fixed "first 50").
2. Retention sweeps for the tables in section 5, with the periods decided in
   section 7. Also old `integrityRuns` and their `integrityCounts` (about 100
   small rows a week).
3. `typingIndicators` rows are deleted on stop and on leave.
4. Read receipts: the 200-entry logs move to their own `receiptLogs` table,
   read only by `getReceiptTimes`. Membership rows shrink from ~17 KB to a
   few hundred bytes.
5. Point reads instead of scans: `blockCore` (`by_pair`), `findDmRoomsBetween`
   (DM names are deterministic), album lookup (`[roomId, albumId]`),
   `liveInMyRooms` (per room, not worldwide), invite lookups.
6. `searchUsers` moves to a Convex search index on username and name.
7. **Room-cap counting.** `addMembership` checks `MAX_ROOMS_PER_USER` by
   reading up to 500 `roomMembers` rows. At ~17 KB a row (before item 4)
   that is ~8 MB per join for a power user, twice when a DM is created, close
   to Convex's 16 MiB read limit. Keep a per-user room count in its own
   small table (not on `users`, which would churn every subscriber),
   maintained by `addMembership`/`removeMembership` and backfilled once.

### Phase 5: presence (backend, then an app release)

1. A `presence` table: `userId`, `status`, `lastSeen`, plus the visibility
   levels for status and last seen, so the privacy check doesn't need
   `users`.
2. `users.heartbeat` and `users.updateStatus` write **only** to `presence`.
   During the switch they also keep writing `users` (throttled as today), so
   old app builds keep working.
3. New query `presence:forUsers(ids)`, capped at about 100 IDs, applying the
   visibility check. The app subscribes for the people on screen: chat
   header, visible chat-list rows, the open member sheet, the profile.
4. `requireSession` stops reading `users`: "deleted" and "suspended" move to
   the session rows.
   Phase 0 item 4 made `feed:board` read each reactor's live `users` row for
   their photo setting, so today a reactor's heartbeat also re-runs the
   boards they appear on. Once heartbeats stop writing `users`, that cost
   disappears with no change to the board.
5. Once the release is out and old builds are below the minimum supported
   version, stop writing presence fields to `users`, then migrate them off
   (deploy, migrate, deploy).

### Phase 6: profiles (backend, then an app release)

1. A `profiles` read model: `userId`, `name`, `username`, `avatarStorageId`,
   avatar visibility, `updatedAt`. Written only when one of those changes, so
   subscribers almost never refresh.
2. `profiles:get(ids)` in batches, with privacy applied. The app keeps a
   device cache keyed by user ID and `updatedAt`, so a cold start shows faces
   at once.
3. New rows (messages, moments, reactions, comments, games) store only
   `userId`. Readers that today use a copied name or photo resolve it
   through the profile cache.
4. `repointAvatarCopies` and every rename sync are deleted. A rename or a
   new photo is one write.
5. Old copies are stripped by a batched migration (deploy, migrate, deploy).
   Fields kept on purpose: `mentions[].username`, call push payloads, and
   whatever section 7 decides about names on old posts.

### Order and dependencies

Phase 0 first, in any order. Phase 1 before 2 (the engine walks the rule
table). Phases 3 and 4 can run alongside 2. Phase 5 before 6: presence gives
the biggest load win, and profiles depend on `users` no longer churning.
Each phase is deployed to the VPS first; the home server must be reachable
or explicitly skipped.

---

## 7. Decisions for you

- **Old posts after a rename:** show the name at posting time (history) or the
  current name? With profiles (Phase 6) the current name is free; keeping the
  old one means storing it on purpose.
- **DMs after one side deletes their account:** today the other person keeps
  the DM with their own messages in it. Keep it (like WhatsApp: the chat stays,
  shown as "Deleted account"), or delete it?
- **Session lifetime:** sessions never expire today. Proposal: expire after
  90 days without use (WhatsApp/Telegram keep linked devices for weeks to
  months of inactivity).
- **Personal stickers:** owner-only to send, or anyone can forward them and
  they show a placeholder after the owner deletes their account? (Phase 0
  already settled the deletion half on privacy grounds: stickers are cut
  from people's own photos, so their files go with the account and the
  tombstoned row shows as "unavailable" wherever someone else kept it.)
- **Game history:** how long to keep finished games and daily results.
- **Read receipts history:** the 200-entry receipt logs exist so receipts
  can be shown per message. Move them to their own table (keeps the feature,
  fixes the cost), or drop per-message history for big rooms?
- **Moderator takedown for moments and comments:** reports on them can be
  filed but there is no "remove" action. Worth adding before App Review
  looks at user-generated content.
- **Old decided requests** (invitations, join and change requests): how long
  to keep them as history.
