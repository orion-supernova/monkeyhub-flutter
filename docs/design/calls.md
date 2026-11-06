# Calls: chat bubbles, Calls tab, call stats

Status: in progress (2026-11-06). Three phases, built in order, one contract.

1. **Call bubbles** in every room (DM and group): live while the call runs,
   then the same bubble settles into its final state.
2. **Calls tab**: a fifth home section, on by default, toggle in
   Settings › Navigation. Live-now strip, All / Missed pill, recent list,
   swipe-to-call, call details sheet, new-call button.
3. **Extras**: favourites row, talk-time header, quality timeline in details.

Huddles keep their centered `HuddleHistoryLine` (nobody called anybody). They
do get `callLog` rows for the people who joined, so they show in the tab.

## Backend cost budget (free Ampere box, assume millions of DAU)

| Event | Writes |
|---|---|
| Direct call starts | +1 message insert (and `calls.messageId` set on the insert) |
| Direct call answered | +1 message patch |
| Direct call ends (any terminal) | +1 message patch, +1 room patch, +2 `callLog` inserts |
| Ringing group call starts | +1 message insert |
| Ringing group call ends | +1 message patch, +1 room patch, +1 `callLog` per participant row (starter, joined, invited, missed, declined); bounded by the group-call invite cap |
| Huddle ends | +1 `callLog` per person who joined (the message is the existing `huddle:ended`) |
| Client quality report after a call | +1 `callLog` patch (own row), +0 or 1 message patch (only when it worsens `q`) |
| Opening the Calls tab | 1 paginated `callLog` query (50 rows) + 1 bounded summary query |

Nothing per heartbeat, per frame or per ICE candidate. `callLog` rows are never
patched except the one quality report, so subscribing to them is cheap (unlike
`calls`, which heartbeats every 15 s while active). Users who never call cost
zero.

## 1. The call message

`messages` row, `type: "system"`, `userId` = caller / group-call starter,
`createdAt` = the call's `startedAt`. Expiry follows the room exactly like the
huddle line (`expiresAt` from `messageLifetime` unless seen-clock,
`vanishUntil` from `vanishUntilFor`). Not inserted in a tombstoned room.

`content` = `call:` + compact JSON (one line, no spaces):

```
call:{"v":1,"k":"d","id":"<calls id>","t":"video","s":"ended","a":1730000000000,"e":1730000600000,"d":600000,"o":"macos","q":"fair"}
```

| key | meaning |
|---|---|
| `v` | format version, `1` |
| `k` | `"d"` direct (1:1 `calls`), `"g"` ringing group call (`groupCalls`, not huddles) |
| `id` | the `calls` / `groupCalls` id |
| `t` | `"audio"` or `"video"` |
| `s` | `"ringing"`, `"active"`, `"ended"`, `"missed"`, `"declined"`, `"cancelled"` |
| `a` | epoch ms the call was answered (direct: accept; group: first join by someone other than the starter). Absent until then |
| `e` | epoch ms it ended. Absent while live |
| `d` | ms talked: `e - a`. Only when it was answered |
| `n` | group only: everyone who joined at some point, starter included |
| `o` | direct only: platform of the callee device that answered (`userDevices.platform`, e.g. `ios`, `macos`, `android`, `windows`, `linux`, `web`) |
| `q` | worst quality either participant reported after the call: `"good"`, `"fair"`, `"poor"`. Absent until a report arrives |

Terminal status mapping, direct calls (`calls.status` → `s`):
`ended` with `acceptedAt` → `ended`; `ended` without `acceptedAt` (an `end`
during ringing) → `cancelled`; `missed` → `missed`; `rejected` → `declined`;
`cancelled` → `cancelled`; `failed` → `missed`. Room teardown
(`endLiveCallsInRoom`) does not touch the message (the room is going away).

Group calls: `ended` when anyone besides the starter joined, else `missed`.

The client reads the perspective itself (me = `message.userId` → outgoing):

| `s` | caller / starter sees | callee / invitee sees |
|---|---|---|
| ringing | Calling… | Incoming call (Join pill for groups) |
| active | live timer from `a` | live timer, Join pill for groups if not in it |
| ended | Outgoing call · 12:41 | Incoming call · 12:41 |
| missed | No answer | Missed call |
| cancelled | Cancelled | Missed call |
| declined | Declined | Declined |

`rooms.lastMessage` is set to the same `call:` content at the end (and
`lastMessageTime` / `lastMessageSenderId`, like the huddle line; a vanish room
gets `VANISH_PREVIEW` as everywhere else). `roomSubtitle` localizes it from
the viewer's side. Old builds show the raw code: acceptable while testers-only.

Live bubbles must never subscribe to `calls` or `groupCalls` rows. The message
itself carries `s`/`a`; the group Join pill reads the existing
`LiveCallsStore` (already subscribed app-wide).

## 2. `callLog` (one row per person per call, written once at the end)

```ts
callLog: defineTable({
  userId: v.id("users"),            // whose history this is
  roomId: v.id("rooms"),
  kind: v.union(v.literal("direct"), v.literal("group"), v.literal("huddle")),
  callId: v.optional(v.id("calls")),
  groupCallId: v.optional(v.id("groupCalls")),
  type: v.string(),                 // "audio" | "video"
  direction: v.union(v.literal("in"), v.literal("out")),
  // answered: I talked. missed: rang me, I never picked up (incl. caller
  // cancelled while ringing). unanswered: I called, nobody picked up.
  // declined: I declined, or they declined my call. cancelled: I called and
  // hung up before an answer.
  outcome: v.union(v.literal("answered"), v.literal("missed"),
    v.literal("unanswered"), v.literal("declined"), v.literal("cancelled")),
  peerId: v.optional(v.id("users")), // direct: the other person; group/huddle: the starter when it isn't me
  people: v.optional(v.number()),    // group/huddle: everyone who joined, me included
  startedAt: v.number(),             // ring started (huddle: huddle started)
  ringingAt: v.optional(v.number()), // direct: callee device ringer up
  answeredAt: v.optional(v.number()),// when I was connected (direct: accept; group/huddle: my joinedAt; starter: first other join)
  endedAt: v.number(),               // when it ended for me
  durationMs: v.number(),            // my time connected, 0 if never
  answeredOn: v.optional(v.string()),// direct: callee answering device platform
  handoffs: v.optional(v.array(v.object({ at: v.number(), platform: v.string() }))), // direct: moves between devices
  // Filled by the client's own report after the call (phase 3).
  quality: v.optional(v.object({
    worst: v.string(),               // "good" | "fair" | "poor"
    // One bucket per 10 s connected: 0 good, 1 fair, 2 poor. At most 360.
    samples: v.array(v.number()),
  })),
})
  .index("by_user_started", ["userId", "startedAt"])
  .index("by_user_outcome_started", ["userId", "outcome", "startedAt"])
  .index("by_call_user", ["callId", "userId"])
  .index("by_group_call_user", ["groupCallId", "userId"])
```

Handoffs: `calls` gains `handoffs?: {at, platform}[]` (capped at 20), appended
in `handoffCall`; copied to both `callLog` rows at the end. `calls` also gains
`messageId?: Id<"messages">`, `groupCalls` gains `messageId?` and
`firstJoinAt?` (first join by someone other than the starter; set once).

Account deletion removes the user's `callLog` rows (deletion plan step).
Room deletion leaves them (the tab shows "Deleted chat").

### API (`backend/convex/callLog.ts`, all authed via `functions.ts`)

- `list({ paginationOpts, filter: "all" | "missed" })`: newest first.
  Returns the rows as stored plus `_id`. No profile copies: the client resolves
  peers and rooms from what it already has (rooms store, user lookups).
- `summary({ since })`: `{ totalMs, calls, top: [{ peerId, ms, calls }] }` over
  `by_user_started >= since`, `take(1000)` bounded, top 8 by `ms`, direct
  calls only for `top`.
- `remove({ id })`: deletes one of my rows. `clear()`: deletes up to 500 of
  mine per call, returns `{ more }`.
- `reportQuality({ callId?, groupCallId?, samples })`: patches MY row's
  `quality` (worst = max sample), and for a direct / ringing group call
  patches the message's `q` only if it is worse than what is there. Samples
  capped at 360, values clamped 0..2. Rate-limited per user.

## 2b. Favourites (user-picked, 2026-11-06)

Favourites are people the user pins THEMSELVES. The app never fills the row;
"most called" is a different list (the talk-time sheet). The app may SUGGEST
one frequent contact (from `summary`, last 30 days: at least 3 direct calls or
20 minutes) with "Add to favourites" / "Not now". Not now snoozes that person
for 30 days, stored locally (no backend write).

`callFavorites { userId, peerId, addedAt }`, indexes `by_user_added`,
`by_user_peer`, `by_peer`; both ids cascade on account deletion. API in
`backend/convex/callFavorites.ts`: `list({})`, `add({peerId})`,
`remove({peerId})`, cap 24, writes only on add/remove.

## 3. Client

- `lib/models/call_history.dart`: pure Dart parser for the `call:` content
  (like `HuddleHistory`), plus the perspective table above.
- `lib/widgets/call_bubble.dart`: the bubble, sender-sided, inside the
  existing bubble chrome. Tap = call back with the same type (direct) or Join
  (group, while live). Consecutive missed calls from the same person collapse
  into one bubble with a ×N badge that springs open on tap.
- `lib/screens/calls/`: the tab. `HomeSection.calls` (SF Symbol `phone` /
  `phone.fill`), `SettingsStore` toggle `showCallsTab`, default true.
- Quality report: `CallStatsMonitor` snapshots are bucketed every 10 s by the
  device that is on the call and sent once via `reportQuality` when it ends.
  Local only until then.

Motion: jelly springs for real moments (bubble going live → settled, missed
wobble once on first view, talk-time ring fill, favourites pop-in), crisp
chrome everywhere else. Idle loops only while a call is live. Never animate a
`BackdropFilter`. No InkWell. Reuse `chrome_motion.dart`, the shared glass /
icon-button / press primitives, and the hold menu.
