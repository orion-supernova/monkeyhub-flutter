# C1 + C4 (server): read cursors out of `roomMembers`, exact unread without scans

Design for handbook items C1 and C4 (`docs/backend/backend-handbook.html`).
Drafted 2026-11-06 against the code after wave 1 (`d2961c37`), reviewed and
amended by the orchestrator (amendments marked **[amended]**).

## Goals (budgets)

- Chat list (`rooms:listUserRooms`) re-runs exactly once per incoming message
  per recipient; about 2 docs per room per run; no message scans for unread.
- A delivery report re-runs nothing but the room's read-state / seen-by views.
- `rooms:getMembers` re-runs only on roster changes.
- No per-member write per message: rooms can have 1,000 members.
- Every number is true: unread counts are exact, or a capped exact fallback.

## Decision

Per-room message **sequence numbers** plus **gap rows** for deleted messages.
`unread = room.lastSeq - state.readSeq - gaps(readSeq, lastSeq] - ownNotGap`.

Rejected: a per-member unread counter bumped on send (N writes per message);
"room message count minus member read count" (wrong after deletes, not
repairable); timestamp cursors with a capped scan (today's cost).

Read state is split in two tables because the chat list must not read the
row that delivery reports write.

## 1. Data model

**`roomUserState`** (private to the member; read by the chat list, badges,
push mute checks, send):
- `roomId`, `userId`
- `readSeq: number`, `readAt?: number` (today's `lastReadAt`: unread anchor,
  push "already read" check)
- `ownRuns?: {from: number, to: number}[]` (own message seqs above `readSeq`,
  consecutive sends coalesce; at most 8)
- `ownOverflow?: true` **[amended]** set instead of jumping `readSeq` when an
  9th run would be needed; while set, unread uses the capped exact scan.
  Cleared when `markRoomRead` moves `readSeq` past the runs.
- `archived: boolean` (always set, indexable), `archivedAt?`, `isPinned?`,
  `pinnedAt?`, `muteNotifications?`, `muteBadges?`, `mutedUntil?`
- `dmPeerId?: Id<"users">`, `vanishShareReads?` (only if it lives per member)
- indexes: `by_user_archived [userId, archived]`, `by_room_user [roomId, userId]`

**`roomReceipts`** (public cursors; read only by read-state / seen-by and vanish):
- `roomId`, `userId`, `lastReadAt?`, `lastDeliveredAt?`, `readClock?`,
  `deliveredClock?`, `vanishSeenAt` (initialised to `joinedAt`),
  `seenVisibility?`
- indexes: `by_room_user [roomId, userId]`, `by_user [userId]`

**`messageGaps`** (one ~50 B row per deleted message):
- `roomId`, `seq`, `at` (deleted message's `createdAt`); index `by_room_seq`

Fields on existing tables: `messages.seq?: number` (no index; R13),
`rooms.lastSeq?: number`.

`roomMembers` keeps `roomId, userId, joinedAt, role` (legacy fields stay in
the schema until the D1 cutover).

### Sequence assignment (in `dbHooks.ts`)

- On a `messages` insert: read the room; if `room.lastSeq !== undefined`, set
  `seq = lastSeq + 1` on the message and patch `rooms.lastSeq`. New rooms get
  `lastSeq: 0` from a `rooms` insert hook. `lastSeq` undefined = unmigrated
  room, legacy path.
- **[amended] Order invariant:** `seq` order must match `createdAt` order.
  Audit every `messages` insert site (send, forward, scheduled, system, game
  cards, design samples, problem reports, imports). If any inserts a
  `createdAt` earlier than the room's newest message, either give it the
  next seq anyway and make `markRoomRead`'s seq resolution tolerate it (the
  newest message with `createdAt <= upTo` by `by_room_time` must still give a
  seq >= every message at or before `upTo`), or fix the insert. Add a test.
- Sender bookkeeping in the same hook: read the sender's `roomUserState`; if
  `readSeq == seq - 1`, set `readSeq = seq`; else append to `ownRuns`
  (coalescing); if a 9th run would be needed, set `ownOverflow: true`
  **[amended]** (never move `readSeq` past unread messages). The sender's
  `readAt` and `roomReceipts` are NOT touched (seen-by must stay honest).
- On a `messages` delete: if the room is live, the message has a `seq`, and
  it is younger than `GAP_HORIZON` (180 days), insert a `messageGaps` row.
  Room teardown and old messages insert nothing.

### Unread (new `unread.ts`, `roomUnread(ctx, room, state)`)

1. `R = lastSeq - readSeq`; `R <= 0` gives 0 with no further reads.
2. If `ownOverflow`, or the cursor (`readAt ?? joinedAt`) is older than
   `GAP_HORIZON`: the capped message scan (today's `unreadForRoom`, max 100).
3. Else read `messageGaps` in `(readSeq, lastSeq]` with `take(100)`; 100 or
   more gives the capped scan; otherwise `count = R - gaps - ownNotGap`,
   `capped = count > 99`.
4. `hasMention`: when `count > 0`, one probe of `mentionInbox` (`by_user_room`,
   `createdAt > readAt`).

## 2. Paths that change

Write paths:
- **send** (`sendCore`): bookkeeping is in the hook.
- **markRoomRead**: read `roomReceipts` (early return when already read);
  resolve `readSeq` from the newest message with `createdAt <= upTo`
  (`by_room_time`, desc, first), never the room doc; patch `roomUserState`
  (`readSeq`, `readAt`, trimmed `ownRuns`, clear `ownOverflow` when past);
  patch `roomReceipts` and write the wave-1 `receiptMoves` rows. Keep the
  wave-1 dismiss debounce (`readDismiss.ts`), `noteEngaged`, rate limit.
- **markRoomDelivered / markDeliveredByPush / advanceDelivered**: read and
  write `roomReceipts` only (plus the move row). No `roomUserState`, no room.
- **pin / archive / mute** (`patchOwnMembership` and setters): patch
  `roomUserState`.
- **message delete**: hook.
- **join** (`roomAdmin.addMembership`, `systemRooms.ts` direct inserts):
  insert both rows in the same transaction; `dmPeerId` for DMs parsed from
  the room name (`dm:regular:<a>:<b>`, legacy `dm:<a>:<b>`, `dm:self:<id>` =
  none) with `normalizeId`, on both members' rows.
- **leave / kick** (`removeMembership`): delete both rows and the member's
  `receiptMoves` (wave-1 follow-up).
- **deletion engine**: user `memberships` step deletes the user's
  `roomUserState`/`roomReceipts`; room `members` step claims all three new
  tables; `messageGaps` cascade with the room; reference rules for all.
- **seenVisibility re-stamp** (`receipts.ts`): patch `roomReceipts`.
- **vanish**: `vanishCore`/`vanish.ts` read/patch `roomReceipts`.
- **typing** legacy branches: use `roomAccess`/`canReadRoom`, not a
  `roomMembers.by_user` scan.
- **push**: mute and `readAt` from `roomUserState`; `getMemberIds` reads
  `roomUserState` by room for mute.
- Grep `lastReadAt|lastDeliveredAt|isPinned|mute|vanishSeenAt|seenVisibility`
  across `convex/` and move every remaining reader.

Read paths:
- **getReadState**: `roomReceipts` by room (same output shape).
- **getReceiptTimes**: receipts + `receiptMoves`.
- **badges** (`badgeTotalFor`'s isolated unread part, `unreadBadgePart`):
  iterate `roomUserState` by user, skip live `muteBadges`, `roomUnread` per
  room (2 docs, no scans).

## 3. `listUserRooms`

Per run: `roomUserState` by user (legacy: also `roomMembers` without a state
row, until the backfill marker), the room doc, `roomUnread`. No DM member
scan, no `...rest` spread. Payload = exactly the fields `ChatRoom.fromJson`
reads: `_id, name, description, createdBy, createdAt, isPrivate, memberCount,
lastMessage, lastMessageTime, lastMessageSenderId, hasPassword, type,
messageLifetime, messageClock, avatarStorageId, system, postingPolicy,
vanishMode, vanishAfterSeen, lastReadAt, unreadCount, unreadCapped,
hasMention, isPinned, pinnedAt, isArchived, archivedAt, muteNotifications,
muteBadges, mutedUntil, participantIds` (verify against the client before
trimming; keep anything it reads).

Compatibility (app 1.3.137+): `lastDeliveredAt` returns `null` (reading it
would re-run the list on every delivery; old clients then send at most one
no-op delivery mutation per room with unread). `participantIds` for a DM is
`[viewer, dmPeerId]`. New optional arg `scope: "active" | "archived"`
(absent = all, as old clients expect) and `rooms:archivedCount`.

## 4. Archived rooms

Server supports `scope` and `archivedCount`. The app adopts it only where the
files are not being edited by other work (see the brief).

## 5. Rollout

1. Deploy backend (dual-mode: new path when `room.lastSeq` and the state row
   exist, else legacy; writers write only the new tables when the state row
   exists).
2. Backfill (paged, marker pattern): seq per room (final page re-reads the
   newest rows to catch concurrent sends), then state + receipts rows per
   membership (`readSeq` = seq of newest message at or before `lastReadAt`),
   then the marker. Shadow-compare old vs new unread for every membership.
3. App release. 4. Cutover after it is the minimum version (D1).

## 6. Expected cost

| Action | Before | After |
|---|---|---|
| List run, 15 rooms | ~60 docs + scans, ~200 ms | ~30 docs, no scans |
| Incoming message | 2-3 list runs per recipient | 1 |
| Send | ~14 reads, ~4 writes | +2 reads, +1 write |
| markRoomRead | 11 reads, 3.7 writes | ~3 reads, 2 writes + move rows |
| Delivery report | re-runs list, read state, members, typing | re-runs read state only |
| Pin / archive / mute | re-runs room-wide queries | own list only |
| getMembers | re-runs on every receipt | roster changes only |

## 7. Tests

Unread exactness vs the old scan (sends, deletes of read/unread, vanish and
expiry, view-once burns, own interleavings, `ownOverflow`, 99+ cap, 100-gap
fallback, stale-cursor fallback); seq on every insert site and the order
invariant; gaps; re-run isolation (delivery touches only receipts, pin
leaves read state alone); join/leave/kick/account deletion lifecycle; old
client payload; backfill idempotence and concurrent-send safety; mentions.
