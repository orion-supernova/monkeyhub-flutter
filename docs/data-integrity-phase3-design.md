# Phase 3 design: files with real references (2026-10-22)

Companion to `data-integrity-and-scale-plan-2026-10-22.md` (Phase 3). Drafted
by a planning agent against the code, then reviewed; the **Decisions** section
at the end overrides anything above it.

## 0. Where the plan was stale

- `files.sweepUnclaimed` already exists: hourly, pages `_storage` by
  `by_creation_time` with a saved cursor (`uploadSweep`). Limits: starts at
  `UPLOADS_EPOCH` (pre-epoch files never swept), and only adopts a ledger-less
  file if `messages.by_media` points at it.
- Phase 0 already fixed moment poster sharing (`momentCleanup.releaseMomentFiles`
  checks both indexes) and the `roomChangeRequests.storageId` orphan.
- Sticker sends have no owner check (`messages.expressionFieldsFor`). Decided:
  that stays (Decision 2).
- The app already degrades: `StickerArt` (`lib/widgets/expressions/expression_media.dart`)
  draws the sticker's emoji when the URL resolves to null. No app change needed.
- `deleteCapped` has no per-row hook, so comment sticker refs need the
  `repairRefs` safety net.
- `releaseLedger` gives bytes back for adopted rows that never added bytes;
  fixed by `uncounted`.

## 1. Data model: one ref row per use, plus a per-file `tracked` flag

Chosen over a `refs` counter on `uploads`: auditable both ways by the integrity
scan, naturally idempotent release (a missing row is a no-op), no OCC hotspot
on a hot file (each share is an insert at its own key), resumable backfill
(insert-if-missing). Official stickers, the real hot files, are `permanent`
and never ref'd.

```ts
uploads: + tracked: v.optional(v.boolean())     // refs are authoritative for this file
         + permanent: v.optional(v.boolean())   // server-owned (official stickers)
         + uncounted: v.optional(v.boolean())   // never charged to uploadUsage
         + zeroSince: v.optional(v.number())    // no refs since; set at claim, cleared at first attach
         + .index("by_zero_since", ["zeroSince"])
         + .index("by_tracked", ["tracked"])    // eq(undefined) = still to mark

fileRefs: defineTable({
  storageId: v.id("_storage"),
  holderTable: v.string(),
  holderId: v.string(),      // _id as string, deliberately not v.id
  field: v.string(),
  createdAt: v.number(),
}).index("by_file_holder", ["storageId", "holderId", "field"])
  .index("by_holder", ["holderId", "field"])

fileBackfill: singleton progress row (section 6)
uploadSweep: + liftedAt?: number, + refCursor?: number
```

**Why `tracked`:** between deploy and backfill a legacy file has no ref rows;
a ref-only "anyone else?" check would say no and delete live data. Release is
per file: tracked = ref-based; untracked = drop this holder's ref if any, then
today's index checks (`legacyInUse`) and delete only if nothing is found.
New claims are `tracked: true`; the backfill marks the rest after
verification; `legacyInUse` goes in the release after the flip.

`REFERENCE_RULES` gets `fileHold: "ref" | "copy" | "ledger"` on every `file`
rule, and exports `FILE_FIELDS: Record<table, string[]>` derived from it.

- `ref`: `users.avatarStorageId`, `rooms.avatarStorageId`,
  `messages.{media,poster,sticker}StorageId`, `moments.{media,poster}StorageId`,
  `momentComments.stickerStorageId`, `stickers.storageId`,
  `scheduledMessages.mediaStorageId`, `roomChangeRequests.storageId`.
- `copy` (weak, no ref, readers degrade): `messages.replyToPreview.{media,sticker}StorageId`,
  `moments.authorAvatarStorageId`, `momentReactions.userAvatarStorageId`,
  `typingIndicators.avatarStorageId`, `userExpressions.{favorites,recents}[].storageId`.
- `ledger`: `uploads.storageId`, `fileRefs.storageId`.

Reply previews stay weak: the parent's own ref keeps the bytes, and
`markReplyDeleted` already drops the preview id only when the file was freed.

## 2. API (`files.ts`)

```ts
export type FileHolder = { table: string; id: string; field: string };
attachFile(ctx, storageId, holder, opts?: { share?: boolean }): Promise<void>
releaseFile(ctx, storageId, holder): Promise<{ released: boolean; deleted: boolean }>
transferFile(ctx, storageId, from: FileHolder, to: FileHolder): Promise<void>
releaseRowFiles(ctx, table: string, row: any): Promise<string[]>   // ids actually deleted
forceDeleteFile(ctx, storageId): Promise<void>   // storage + ledger; refs left for repairRefs
fileInUse(ctx, storageId, except?: FileHolder): Promise<boolean>
backfillRef(ctx, storageId, holder, ownerId|null): Promise<"inserted"|"exists"|"missingFile">
```

- **attachFile:** needs a ledger row (else `FILE_NOT_CLAIMED`); `permanent` is
  a no-op; an existing (file, holderId, field) ref returns (idempotent).
  Exclusive by default: if any ref has a different `holderId`, throw
  `FILE_IN_USE`, but only when `ledger.tracked` and env `FILE_REFS_ENFORCE=1`;
  otherwise `console.warn("file_in_use")`. A second field on the same holder
  is fine (poster equal to media). Share mode skips the check. Insert, then
  clear `zeroSince` if set.
- **releaseFile:** point lookup; absent means `{released: false}` (double
  release guard); delete it; tracked: any ref left stops; at zero `destroy`
  (delete storage swallowing "already gone", delete ledger, give bytes back
  unless `uncounted`). Untracked: legacy rule. Immediate, never deferred
  (view-once burn and account deletion free bytes at once).
- **transferFile:** share-attach `to`, then release `from`, same transaction.
- **releaseRowFiles:** release every `FILE_FIELDS[table]` field on the row,
  then sweep `by_holder` for stragglers (`take(16)`). Replaces
  `releaseMessageBlobs`, `releaseMomentFiles`, `releaseRoomPhoto`
  (`releaseMessageBlobs` stays as a thin wrapper so engine call sites don't
  churn).
- **claimUpload:** same signature and idempotent same-owner behaviour; inserts
  `tracked: true, zeroSince: createdAt`; accepts `{permanent: true}`. It does
  NOT reject a second claim (`messages.send` claims before `sendCore`'s
  `clientId` dedupe; a retry presents the same file). The check lives in
  `attachFile`.

**Share paths** (`{share: true}`): `messages.forwardToRoom` (media, poster,
sticker); `moderationCore.postAsReporter` (evidence); `messages.sendCore`
sticker (skipped for `mediaSource === "pack"`); `momentComments.add` sticker;
scheduled release / sendNow (attach the message, then release the scheduled
row); `roomChangeRequests.applyChange` (`transferFile` request to room);
system-room avatar (section 4). Rollout: warn first, `FILE_REFS_ENFORCE=1`
after a week of clean logs; `roomChangeRequests.propose` maps `FILE_IN_USE` to
the existing `ERR_PHOTO_IN_USE`.

## 3. Call sites

**Attach:**
- `messages.sendCore` after the insert: exclusive for media and final poster,
  share for sticker (not pack); new arg `fileMode` so scheduled release passes
  share. `messages.send` unchanged (`claimUpload`, `discardUpload` for a
  dropped poster). `messages.forwardToRoom` share. `moderationCore.postAsReporter`
  share. `problemReports.submit` exclusive on the log-file and screenshot
  messages (it inserts directly). `designSamples` goes through `sendCore`.
- `feed.post` exclusive media and poster. `momentComments.add` share sticker.
- `expressions.createPersonalSticker`: claim, then exclusive attach
  `stickers:<id>`. `expressions.insertOfficialSticker`, the seeders and
  `systemAvatars` blob creation: `claimUpload(..., {permanent: true})` for
  official stickers only.
- `users.updateAvatar` exclusive attach new (old released by the avatar job).
  `rooms.updateRoomAvatar` exclusive attach new, then `releaseFile(previous)`.
- `roomChangeRequests.propose` exclusive attach the request (replaces
  `roomPhotoInUse`); check the admin direct-apply branch (~L270-310), which
  may write the room without a request row and needs an attach to the room.
  `decide` / `applyChange`: approve = `transferFile` to the room and release
  the previous avatar; reject / withdraw = `releaseFile`.
- `scheduledMessages.schedule` exclusive attach.

**Release:**
- `files.releaseMessageBlobs` = wrapper over `releaseRowFiles("messages", msg)`;
  `removeMessageImmediate` uses it (its `deletedStorageIds` still feeds
  `markReplyDeleted`). `messages.burnBlobs` uses `releaseRowFiles` then clears
  fields. `files.discardUpload`: any ref means return, else `destroy`.
- Engine: `roomSteps` message wipe (via wrapper), request sweep
  (`releaseRowFiles("roomChangeRequests", row)`), `parent`
  (`releaseRowFiles("rooms", room)` for EVERY room, removing the system-room
  exemption); `userSteps` request step (pending rows), `parent`
  (`releaseFile(job.args.avatarStorageId, users holder)` + `by_holder` sweep);
  `avatarSteps.deleteOld` = `releaseFile(from, users holder)`;
  `commentSteps` and the user comment purge release each comment.
  Bump the per-row write accounting where a row now does ref deletes.
- `momentCleanup.releaseMomentFiles` = `releaseRowFiles("moments", m)`;
  the capped `deleteCapped(momentComments)` gets an `onRow` hook or relies on
  `repairRefs`.
- `roomAdmin.releaseRoomPhoto` / `roomPhotoInUse` deleted; callers use
  `releaseFile` / `fileInUse`. `roomAdmin.clearPendingFor` and
  `roomChangeRequests.releaseProposal` use `releaseRowFiles`.
- `scheduledMessages` cancel, purge, purge-by-room: `releaseRowFiles`.
- `expressions.deletePersonalSticker`: `releaseFile(stickers:<id>)`; the file
  stays while copies hold refs and is freed with the last one (fixes the
  soft-delete leak). `expressions.purgeUserExpressions`: `forceDeleteFile`
  (account deletion wins, Phase 0); `repairRefs` drops the leftover refs.
- `momentComments.deleteCommentCore`: `releaseRowFiles` per row.

## 4. System rooms

Today rooms copy the account's `avatarStorageId`, room deletion skips the
avatar for system rooms, and `systemAvatars.apply` never frees the old file.
- `systemRooms.ensureSystemRoom` / `repairSystemRoom`: share-attach the
  account's avatar onto the room (`rooms:<id>`); room wipe then releases it
  with no special case.
- `systemAvatars.set` (action): new internal query `systemAvatars.targets`
  (account + eligible stamped rooms); `ctx.storage.store` one blob per target
  from the same bytes; `apply` per target with `expectPrevious`: claim (owner
  undefined), exclusive-attach, patch, `releaseFile(previous, holder)`. Keep
  today's rule that the account face only reaches a room still wearing the old
  file. After one `set`, every holder owns its own file.

## 5. Unused-file cleanup

Remove `gcOrphanedFiles`, `listOrphans`, `collectReferenced`, `MAX_SCAN`,
`SWEEP_LIMIT`, `GRACE_MS` and their daily cron.
- **`files.reapUnreferenced`** (every 10 min): `uploads.by_zero_since`,
  `.gt("zeroSince", 0).lt("zeroSince", now - 24h).take(100)` (`gt(0)` excludes
  undefined); per row re-check refs (a ref clears `zeroSince`), else
  `destroy`; reschedule `runAfter(0)` while full. `permanent` rows never get
  `zeroSince`.
- **`sweepUnclaimed`** keeps paging `_storage` with
  `withIndex("by_creation_time", q => q.gt(...).lt(...)).take(200)` and its
  cursor (no `.paginate()`). The adoption branch becomes a warn plus an
  adopted ledger row (`tracked: false, uncounted: true`). After the flip,
  `files.liftEpoch` resets the cursor to 0 and sets `liftedAt` so pre-epoch
  files are swept; it refuses while `uploads.by_tracked` has `eq(undefined)`
  rows; `legacyInUse` is a last guard before deleting a ledger-less file.
- **`files.repairRefs`** (nightly, paged over `fileRefs` by `_creationTime`
  with `uploadSweep.refCursor`, using the tie-safe `pageAfter`/`cursorOf`
  helpers from `deletionCore.ts`): deletes a ref whose holder is gone, whose
  field no longer equals the id, or whose ledger row is missing; an emptied
  tracked file runs the zero logic.

## 6. Backfill and rollout

1. Deploy P1+P2+P3. New writes carry refs; untracked files release by the
   legacy rule; `FILE_REFS_ENFORCE` unset (warn only).
2. `internal.fileBackfill.start`.
3. Verify: `internal.integrity.start`, then `internal.integrity.latest`.
4. Review `internal.files.zeroRefReport`.
5. `internal.fileBackfill.markTracked`.
6. A week of warn logs, then `FILE_REFS_ENFORCE=1`.
7. `files.liftEpoch`.
8. Next release: delete `legacyInUse`, `deleteStored` and the sweep's adoption.

**`fileBackfill.ts`:** singleton progress row on the `integrity.ts` pattern
(`runAfter(50)` chain, hourly `resumeStalled`, 3 tries). Scan phase: tables
from `REFERENCE_RULES` `fileHold: "ref"`; one `.paginate()` page per step
(100 for messages, 200 otherwise; worst case ~1.2k reads / 600 writes); per
(row, field) `backfillRef`: ensure a ledger row (missing: `tracked: false,
uncounted: true`, size from `ctx.db.system.get`, owner = the holder's author,
undefined for rooms and non-personal stickers), insert the ref if absent,
tally `missingFile`. `roomChangeRequests` count only when pending. Re-runs
insert nothing.

**Verify:** `integrity.ts` gains `missingRef` (a strong field with no ref
row) and `staleRef` (a ref whose holder is gone or whose field changed, via a
final `fileRefs` pass), both violations. `markTracked` refuses unless the
latest finished integrity run started after the scan finished and shows zero
file violations.

**Mark:** `markTracked` loops `uploads.by_tracked eq(undefined) take(100)`:
with refs, `tracked: true`; without and not permanent, `tracked: true,
zeroSince: now` (reaped after 24 h). `zeroRefReport` (paged internal query,
URL and size) is read by a human before this step: it is the irreversible one.

## 7. Stickers

- `stickers.storageId`: official = `permanent`; personal = the owner's
  `stickers` row holds a ref; owner soft-delete releases it and the file
  survives while copies exist; account deletion `forceDeleteFile`s it.
- `messages.stickerStorageId`, `momentComments.stickerStorageId`: strong,
  share-attached (not for pack stickers); after a forced delete they dangle
  and readers degrade.
- `replyToPreview.stickerStorageId`: weak copy.
- `userExpressions` favorites/recents: weak; `expressions.state` drops
  personal-source entries whose `stickers` row is missing or `deletedAt`
  (bounded point reads, only for `source: "personal"`).
- Server read shapes unchanged; `getFileUrl` returns null for a deleted file
  and the app draws the emoji. No app change required.

## 8. Packages

**P1 core (first):** `schema.ts`, `files.ts`, `crons.ts`. The API, `destroy`,
`legacyInUse`, `reapUnreferenced`, `repairRefs`, `zeroRefReport`,
`liftEpoch`, sweep changes, `discardUpload`; wrappers kept; old gc removed.
Tests (`fileRefs.test.ts`): forwarded copy keeps the file; double release;
500 share-attaches leave the ledger doc untouched; exclusive second holder
throws under enforce and warns without; zero-ref reap with grace, self-heal,
paging, permanent skipped; untracked legacy file not deleted while
`by_media` still points at it; ledger-less old file swept only after
`liftEpoch`; `repairRefs` drops dead refs.

**P2 call sites (after P1, parallel with P3):** `messages.ts`,
`moderationCore.ts`, `problemReports.ts`, `feed.ts`, `momentCleanup.ts`,
`momentComments.ts`, `expressions.ts`, `users.ts` (updateAvatar only),
`rooms.ts`, `roomAdmin.ts`, `roomChangeRequests.ts`, `scheduledMessages.ts`,
`systemAvatars.ts`, `systemRooms.ts`, `designSamples.ts`,
`deletionSteps/{avatar,user,room,comment}Steps.ts`, and existing tests whose
assertions change. Tests: forward/delete end to end; scheduled release leaves
one ref; room-photo propose/approve/reject; avatar old file freed only after
the job; personal sticker soft-delete keeps the file while a message holds it
and the last copy frees it; account deletion force-deletes and readers
degrade; `expressions.state` filters dead personal entries; system-room
avatars (two rooms + account, `set` twice, each on its own file, wiping one
room keeps the account's avatar); view-once burn frees at once; comment
delete releases its sticker ref (or `repairRefs` does).

**P3 backfill, verification, rules (after P1, parallel with P2):**
`referenceRules.ts` (`fileHold`, `FILE_FIELDS`, sticker notes),
`referenceRules.test.ts` (a `file` rule without `fileHold` fails),
`integrity.ts` (`missingRef`, `staleRef`), new `fileBackfill.ts`, plan doc
status and runbook. Tests: backfill paging across two tables and a no-op
re-run; resume after a stall; untracked to tracked; `markTracked` refusing on
a dirty run; zero-ref rows reaped; `missingFile` tallied, not thrown.

## Decisions (orchestrator and user, 2026-10-22)

1. Per-use `fileRefs` rows with the `tracked` flag, as designed.
2. **Personal stickers: anyone may keep forwarding them** (user decision).
   `expressionFieldsFor` gets NO owner check. A personal sticker's file lives
   while any message or comment uses it, and goes with its owner's account
   (Phase 0), after which it shows as the emoji.
3. Owner soft-delete of a personal sticker keeps the file while copies exist
   (today's behaviour).
4. Rollout is warn-first; enforcement (`FILE_REFS_ENFORCE=1`), `markTracked`
   and `liftEpoch` are manual steps for after the deploy, each after a dry run
   or report. Nothing irreversible runs automatically.
5. Phase 4 work runs in parallel. `crons.ts` and `schema.ts` are shared:
   make small exact edits, never rewrite those files. `users.ts`: P2 touches
   `updateAvatar` only (a Phase 4 worker may edit the heartbeat).
