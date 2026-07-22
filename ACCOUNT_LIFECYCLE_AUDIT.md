# Account Lifecycle Audit — MonkeyHub

**Scope:** how an account is torn down, how supervision is created and ended, and
how a supervised handset is handed back. Covers `auth.purgeUser`, the
`guardianships` invariants, and the release-code mechanism.

**Status:** all three landed and are deployed to `https://termio-api.walhallaa.com`.
Backend behaviour is verified live against a seeded fixture (§6). The Flutter
screens are **written and analyzer-clean but not yet exercised on a device** —
§7 is the checklist for that.

**TL;DR:**
- **Deleting an account used to leak.** `purgeUser` cleaned 5 tables out of ~15.
  Every photo, video and voice note a user ever sent stayed in Convex storage
  **forever**, and a room whose creator was deleted became **permanently
  unadministerable** because `rooms.createdBy` gates `NOT_OWNER`. Both fixed.
- **Unlinking the last guardian orphaned the child account permanently.** Every
  family mutation is gated on `assertGuardian`, *including `addGuardian`* — so
  nobody could re-adopt, re-pair, or even delete it, and the child can't rescue
  themselves. Now refused server-side.
- **A child can now be signed out**, but only against a grown-up's credential:
  a six-digit release code, or a guardian's own password (the one-phone case).
- Release codes live in **their own table** so they can never be redeemed as
  sign-in codes. This is the single most important invariant in the feature.

---

## 1. The teardown map

Convex has no foreign keys and no cascade deletes, so every table that can point
at a user has to be named by hand. This is that list. **If you add a table with
a `v.id("users")` field, it belongs here** — the failure is silent.

`purgeUser` — `backend/convex/auth.ts:162`. Two entry points, same body:

```
auth.deleteAccount (public)      auth.ts:100   ← adult self-delete, profile_screen
  └─ refuses child accounts (:103)
auth.purgeAccount (internal)     auth.ts:113   ← called by family.deleteChildAccount
  └─ family.deleteChildAccount   family.ts:1283
```

| Table | Field(s) | Handling |
|---|---|---|
| `roomMembers` | `userId` | deleted; room recounted or wiped |
| `rooms` | `createdBy` | **reassigned** if the room survives (§2) |
| `messages` | `userId` | deleted, with media + reactions |
| `reactions` | `userId` | deleted — **both** on own and others' messages |
| `friendships` | `userId`, `friendId` | deleted, both directions |
| `friendRequestMessages` | `userId` | deleted |
| `blocks` | `userId`, `blockedUserId` | deleted, both directions |
| `guardianships` | `guardianId`, `childId` | deleted, both roles |
| `pairingCodes` | `childId`, `createdByGuardianId` | deleted, both roles |
| `releaseCodes` | `childId`, `createdByGuardianId` | deleted, both roles |
| `approvalRequests` | `childId`, `targetUserId`, `decidedByGuardianId` | deleted, all three |
| `calls` | `callerId`, `calleeId` | deleted, plus their signals |
| `callSignals` | `fromUserId`, `toUserId` | deleted, both directions |
| `userDevices` | `userId` | deleted — else pushes chase a dead account |
| `typingIndicators` | `userId` | deleted |
| `reports` | `reporterId` | **tombstoned, not deleted** (§3) |
| `_storage` | avatars, message media | `ctx.storage.delete` per file |

Two helpers carry the weight:

- **`deleteStored`** (`auth.ts:121`) — tolerates a file that's already gone. A
  purge that throws halfway is far worse than a leaked file.
- **`deleteRows`** (`auth.ts:136`) — dedupes by id. Most tables above are queried
  from two directions at once, those can return the same row twice, and a second
  `ctx.db.delete` on one id **throws**. The dedupe is load-bearing, not defensive.

Room teardown reuses **`wipeRoomCompletely`** (`backend/convex/roomCleanup.ts:21`),
shared with the block and "take back" flows. That reuse is where the media
deletion comes from — the old hand-rolled loop in `purgeUser` never touched
storage.

## 2. Why `rooms.createdBy` gets reassigned

`rooms.ts` throws `NOT_OWNER` when `room.createdBy !== userId`. If the creator is
deleted while other members remain, that pointer dangles and **nobody can ever
administer the room again** — it can't be renamed or deleted, by anyone, forever.

So when a room survives its creator, `purgeUser` hands `createdBy` to the
**earliest-`joinedAt` surviving member** and patches their `roomMembers.role` to
`"owner"` so both notions of ownership agree. When no members remain, the room is
wiped outright instead.

## 3. Why reports are tombstoned

A report is a moderation record. If deleting your account deleted your reports,
anyone could erase their own report trail on the way out. So the row survives and
`reporterId` is set to `undefined` — hence `reports.reporterId` is
`v.optional(v.id("users"))` in the schema. Nothing reads it back today
(`users.ts` only inserts), so this is safe.

## 4. Guardianship invariants

### 4a. A child account always has ≥ 1 guardian

`unlinkChild` (`family.ts:1219`) counts `guardianships.by_child` and throws
`ERR_LAST_GUARDIAN` (`childGuard.ts:48`) rather than removing the last one.

This is not cosmetic. Everything below is gated on `assertGuardian`
(`childGuard.ts:109`), which can never pass again once the last row is gone:

| Would be dead | Consequence |
|---|---|
| `addGuardian` (`family.ts:148`) | **nobody can ever re-adopt the account** |
| `createPairingCode` (`family.ts:212`) | no new device can ever pair |
| `createReleaseCode` (`family.ts:347`) | the phone can never be handed back |
| `setChildPolicy` | frozen on whatever rules it had |
| `advanceContactRequest` | pending requests hang in `awaitingSenderGuardian` forever |
| `deleteChildAccount`, `promoteToAdult` | undeletable, ungraduatable |

And the child cannot rescue it: they're created with
`passwordHash: CHILD_PASSWORD_SENTINEL` so password login is impossible, and
`auth.deleteAccount` refuses child accounts outright.

**The two legitimate exits from supervision are `promoteToAdult` and
`deleteChildAccount`** — not unlinking. The UI reflects this: `isSoleGuardian`
(`lib/models/family.dart:146`) hides the remove action, and the danger zone in
`child_policy_screen.dart` explains why.

> The guard is **server-side on purpose**. Given the app's userId-as-argument
> model, a disabled button is not a guard.

### 4b. Guardians are equal, never quorum

Any guardian can approve, change settings, or remove another guardian —
including the one who created the child. This is stated in the schema comment on
`guardianships` and is deliberate; don't add quorum logic without revisiting it.

## 5. Handing a phone back

### 5a. Why a child can't just sign out

Three layers, all deliberate:

```
auth_service.signOut()          lib/auth/auth_service.dart:123  ← refuses child sessions
profile_screen _meView          lib/screens/profile_screen.dart ← no ACCOUNT section for a child
SessionStore._isChildDevice     lib/auth/session_store.dart:36  ← sticky marker
  └─ login_screen.dart:48 opens in pairing mode while it is set
```

`clearSession()` alone lands a child back on the **pairing** screen.
Only `clearChildDevice()` (`session_store.dart:78`) makes the handset ordinary
again — which is why release goes through `releaseChildDevice()`
(`auth_service.dart:173`) and not `signOut()`.

### 5b. Two credentials, and why both are needed

| Path | Mutation | When it's the right one |
|---|---|---|
| Six-digit code | `releaseDeviceByCode` (`family.ts:376`) | Normal handover. Guardian mints it on **their own** phone. Single-use, short TTL — a child who watches it being typed gains nothing. |
| Guardian password | `releaseDeviceByGuardianPassword` (`family.ts:402`) | **Only one phone.** Pairing a child signs the adult out, so there is no adult session anywhere to mint a code from. Also the path for testing both roles on one device. |

A code-only design cannot unstick a single-phone setup. That's the whole reason
the password fallback exists — it is not redundancy.

Both funnel into `releaseDevice` (`family.ts:334`), which deletes the
`userDevices` row for that `(childId, deviceId)` and marks the child offline.
**Releasing is not deleting** — the account survives untouched and can be
re-paired later.

### 5c. The separate-table invariant

`releaseCodes` is its own table, *not* a `purpose` field on `pairingCodes`.

`redeemPairingCode` (`family.ts:260`) finds codes by `codeHash` alone. Were both
kinds to share a table, one missed purpose-check would let a release code be
redeemed as a **sign-in** code — a child who watched a parent release one handset
could pair themselves onto another. Separate tables make that impossible
structurally rather than by remembering to check.

**Verified live in both directions** (§6). If you ever merge these tables, this
is the test that must not regress.

### 5d. Error messages are deliberately uninformative

`releaseDeviceByGuardianPassword` throws the same `NOT_A_GUARDIAN` for *every*
failure — unknown username, child account, wrong password, adult who isn't this
child's guardian. This runs on a handset the child is holding; distinguishing
them would let a child map out who supervises them and then grind on the one
account that matters. `_humanize` in `release_device_screen.dart` must not get
more specific.

### 5e. UI surfaces

```
Guardian:  family_screen  → child card → RELEASE
             → PairingCodeScreen(purpose: CodePurpose.release)   pairing_code_screen.dart:27
                (same mint/countdown UX as pairing; QR suppressed — :50, :91, :126)
Child:     profile_screen → HAND THIS PHONE BACK    profile_screen.dart:876
             → ReleaseDeviceScreen                  release_device_screen.dart:27
                code path     → _submitCode         (:52)
                password path → _submitPassword     (:56)
```

On success the screen **must pop to the first route** —
`nav.popUntil((r) => r.isFirst)`.

Clearing the session makes `_AppHome` (`lib/app.dart`) rebuild into
`LoginScreen`, but it does that in the Navigator's *initial route*, underneath
anything pushed on top. A pushed screen that doesn't pop leaves the release
having silently succeeded while the user stares at a dead "checking…" button —
which is exactly what happened on the first device test. `_signOut` and
`_deleteAccount` in `profile_screen.dart:267` carry the same pattern and a
comment explaining it; anything else that clears the session from a pushed route
needs it too.

Once popped, the phone lands on the **adult** login form rather than pairing,
because the sticky marker was cleared.

The entry point is **visible**, which softens the older "absent rather than greyed
out" stance in `profile_screen.dart`. That comment has been updated rather than
left contradicting the code: the credential is the real gate, and a parent who
can't find the button can't use the feature.

---

## 6. What is verified, and what is not

Verified live against the deployment, using a seeded fixture that was then
deleted (guardian + second adult + child, two rooms, messages, a reaction on
another user's message, an approval, a device, a pairing code, a report):

- ✅ Zero remaining references across all seeded tables after `deleteChildAccount`
- ✅ Shared room survived; `createdBy` moved to earliest remaining member; that
  member's `roomMembers.role` promoted to `owner`
- ✅ Solo room wiped with its messages
- ✅ Report survived with `reporterId: null`
- ✅ Reaction on another user's *surviving* message removed (the old orphan)
- ✅ Same via `auth.deleteAccount` for an adult
- ✅ Deployment-wide sweep: 0 orphans, 0 frozen rooms
- ✅ Release code **rejected** by `redeemPairingCode`; pairing code **rejected**
  by `releaseDeviceByCode`
- ✅ Release code single-use; second attempt fails
- ✅ Wrong password, and a child using the known `__CHILD_NO_PASSWORD__` sentinel
  on themselves, both fail identically
- ✅ Correct guardian password: child survives, goes offline, `userDevices` row deleted
- ✅ Unconsumed `releaseCodes` purged with the child

**Not verified — do these before trusting them:**

- ❌ **Storage deletion.** Uploading a test file was blocked in the harness, so
  `deleteStored()` — the fix for photos/avatars leaking forever — is verified by
  inspection only. **Delete an account that has sent a photo and confirm the file
  is gone.** This is the highest-value unverified item.
- ❌ `blocks`, `calls`, `callSignals` teardown — same reason (seeding mutations
  were blocked). The code follows the identical pattern as everything that passed.
- ❌ Every Flutter screen in §5e and the co-guardian / danger-zone UI.

**Residue:** one tombstoned report in production with reason
`"zz test report for purge verification"` and a null reporter, left by the
verification run. There is no delete-report mutation; remove it by hand if it
bothers you.

## 7. Test checklist

**Teardown**
1. As an adult, send a photo, set an avatar, then delete the account. Confirm via
   dashboard that both storage files are gone. *(the unverified one)*
2. Create a room with a second person in it, delete the creator, confirm the
   survivor can rename/delete the room.
3. Block someone, then delete the account; confirm no `blocks` row survives in
   either direction.

**Guardianship**
4. Sole guardian → STOP SUPERVISING is hidden/disabled with an explanation.
5. Call `family:unlinkChild` directly via the Convex MCP with a sole guardian —
   must throw `LAST_GUARDIAN`. *(the guard must not be UI-only)*
6. Add a second guardian → removal becomes available → remove → child still works.
7. Graduate a child: password set, `accountType` is `adult`, `childPolicy`
   cleared, guardianships gone, and they can log in with that password.

**Device release**
8. **Two phones:** guardian taps RELEASE, reads six digits; child's phone →
   HAND THIS PHONE BACK → digits → screen pops itself and lands on the **adult
   login form**, not pairing. Sign in as the adult on that same handset.
9. **One phone (the testing case):** child signed in, no adult session anywhere →
   HAND THIS PHONE BACK → guardian username + password → same result.
   *Regression watch:* the screen must pop on its own. If it sits on "checking…"
   until you press back, the pop was lost again (§5e).
10. Wrong password, a non-guardian adult's password, and a child's username all
    give the same generic message.
11. After release, confirm the `userDevices` row is gone and that handset stops
    receiving that child's pushes.
12. Re-pair the same phone afterwards — release must not have broken pairing.
13. Visual: the child card now has three actions (PAIR / RELEASE / SETTINGS)
    where it had two. Check it doesn't overflow on a narrow screen.

## 8. Known gaps

- **No rate limiting anywhere in `auth.ts`.** The password release path is a new
  password-guessing surface a child can reach on their own handset. Requiring a
  username that is actually a guardian *of this child* narrows it a lot, but if
  this ships to real families it deserves an attempt counter.
- **`userId` as a client-supplied argument.** Every mutation here trusts the
  caller's `userId` rather than `ctx.auth`. That is the app's established model
  (see `lib/backend/convex_client.dart`), not something introduced by this work —
  but it means `auth.deleteAccount` will delete any account whose id you know.
  Worth revisiting as its own project.
- **A child in a room with no one else cannot post.** `childMayUseRoom`
  (`childGuard.ts`) returns false when `others.length === 0` and there is no room
  grant, so a child's own private room is unusable until a guardian approves it.
  Noticed while seeding; may or may not be intended.
