# Friend requests: answer, ignore, delete

What each answer to an incoming request does, and what the sender sees. Code:
`backend/convex/friends.ts`, `lib/widgets/request_cards.dart`,
`lib/screens/discover_screen.dart` (inbox), `lib/screens/discover_lists.dart`
(`IgnoredRequestsScreen`).

## The three answers

| Action | Row | Sender sees | Can they ask again? | Can you change your mind? |
| --- | --- | --- | --- | --- |
| Approve | `status: accepted` | a DM opens, they're friends | n/a | remove friend |
| Ignore | stays `pending`, `ignoredAt` set | still "waiting", no push, nothing different | no: the pending row blocks re-sends (`ALREADY_FRIENDS_OR_PENDING` / `REQUEST_ALREADY_PENDING`) | yes: Approve or Move back any time |
| Decline / Delete | row and its messages deleted | request disappears from their sent list, profile shows "Add" again. No push. | yes, up to 3 per pair per week (`freqpair:` bucket) | no: you send them a request instead |

Decisions:

- **Ignore is the safe default for "not now / not you".** It is the only option
  that both hides the request and stops repeat requests. The sender is never told.
- **Ignore is recipient-only state.** `listOutgoingDirectRequests` never returns
  `ignoredAt`; test pins that the outgoing row has no `ignored` key.
- **Ignored requests leave the badge.** `friendContribution` returns 0 when
  `ignoredAt` is set and `ignoredAt` is in `FRIEND_PENDING_FIELDS`, so the
  `friendships` hook moves `userBadgeCounts` on ignore/restore (R8, R9).
- **Delete from the Ignored list asks first** (confirm sheet). Decline in the
  inbox stays one tap, as before.
- **Ignored requests still count as pending** everywhere that decides
  relationship state: `ChatRepository.incomingRequestFrom` (profile button) and
  the request draft screen both look in the ignored list too, so ignoring an
  open request is not mistaken for an answer.

## UI

- Inbox card: **Approve** full width, then **Ignore | Decline**. Three in one row
  broke "Approve" mid-word at phone width (rendered and checked).
- Ignoring moves the card at once (optimistic, reverted on failure) and shows a
  toast "Moved to Ignored. They won't be told." with **Undo**.
- Under the inbox, while any exist: one grouped row **Ignored · N** that opens
  the Ignored requests page. The page shows the same card with **Approve**,
  **Move back | Delete**, and pops itself when the last one leaves.
- Discover's Incoming segment count, the chat list's Requests folder and the app
  badge all read `incomingRequests`, which excludes ignored ones.

## Cost table

| Action | Reads | Writes | Re-runs | Idle |
| --- | --- | --- | --- | --- |
| Ignore / Move back | 1 (`by_pair`) + hook: 1 (`userBadgeCounts`) | 1 patch + 1 counter bump | recipient's incoming list (screen changes, R5 ok); sender's outgoing list once (same result, it reads the row) | 0 |
| Ignore again (no-op) | 1 | 0 | none | 0 |
| Delete | as decline today | | | 0 |

No new table, no new index, no scheduled work. One optional field on
`friendships`, which is bounded by its parent request (deleted with it).
