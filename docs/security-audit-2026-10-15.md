# Pre-launch security and abuse audit (2026-10-15)

Before submitting to the App Store and Google Play, six reviewers audited the
app and backend in parallel. Their areas were file uploads, rooms, spam and
rate limits, auth and accounts, server load, and store policy. The most
serious findings were re-checked by hand in the code. Everything marked
**Fixed** below is committed on `dev`. The backend was deployed to the VPS on
2026-10-15, and the `roomAccess` backfill has run (92 memberships).

## At a glance

| Area | Before | After |
|---|---|---|
| Reading chats | Anyone who knew a room's ID could read its messages, including private DMs and password rooms | Only members can read a room |
| Device sign-in (QR / code) | An attacker could pre-register codes and take over the account of whoever approved one | The server creates the code; squatting is impossible |
| Child accounts | A 6-digit pairing code could be guessed with no limit, giving access to the child's account | Guessing is capped per device and globally |
| Password guessing | The lockout never engaged, so guessing was unlimited | Lockout works: 10 tries, then 15 minutes |
| Stored passwords | Stored as-is, so a database leak meant working logins | Salted, slow hash (PBKDF2). Old ones upgrade on next login |
| Uploads ("use it as a drive") | No size limit, no quota, unlimited uploads | 25 MB per file. 1 GB/day, 10 GB total and 1 GB in Saved Messages per user. 120 uploads/hour |
| Other people's files | Anyone could delete someone else's photo via the avatar trick | Each file has an owner; nobody else can attach or delete it |
| Abandoned uploads | Stayed on disk forever (the cleanup had stopped working) | Removed after 6 hours, every hour |
| Spam | No limits on sending, calling, reacting, friend requests or invites | Limits on every one (see below) |
| Messages | Up to about 1 MB each | 8,000 characters |
| Ring spam | A phone could be rung on a loop | 3 rings per person per 2 minutes |
| Room size | No limit | 1,000 members (WhatsApp 1,024, Signal 1,000) |
| Kicked members | Could rejoin immediately | Locked out for 7 days unless an admin re-invites them |
| Discover | Loaded every public room; could be knocked offline | 200 most active rooms |
| Big rooms / heavy accounts | Couldn't be deleted (too big for one transaction) | Deleted in batches |
| Fake senders | Anyone could send a push titled "MonkeyHub Team" | The sender name always comes from the account |
| Moderators | A freed moderator handle passed its rights to whoever took it | Moderator handles can't be renamed or re-registered |
| Blocking | Worked only in DMs | Also hides the person in groups and moment comments |
| Reporting | Messages, people and rooms only | Also moments and comments |
| iOS privacy manifest | Missing (App Store rejects the upload) | Added to the app and all 3 extensions |
| Server switcher | Visible to everyone, before sign-in | Hidden in store builds (unlock: 5 taps on the version) |
| Unused Android permission | `READ_MEDIA_AUDIO` declared | Removed |

## Findings and fixes

### Critical: fixed

1. **Room contents were readable by anyone with the room ID** (`14993e1f`).
   - Affected: the message lists, `getThread`, `getRoom` (which includes the DM preview), `getMembers`, read state, receipt times, pins, poll state, reactions, typing, and message media URLs.
   - Fix: a new `roomAccess` table that changes only on join and leave, so live chat queries can check membership without re-running on every receipt.
2. **Device-login code squatting led to account takeover** (`2c8fe06f`).
   - Before: the client chose the code's hash, requests needed no sign-in and had no limit, and a typed code matched the *oldest* request.
   - Fix: the server mints a 6-digit code that never collides with a live one, matches the newest request, and allows at most 1,000 live requests.
3. **Credential lockouts never worked** (`2c8fe06f`).
   - Before: every path recorded the failure and then threw, and Convex rolls back a mutation that throws, failure count included.
   - Fix: failures are now *returned* as `{__refused: CODE}`, and the client (`ServerRefusal`) turns that back into the same error it showed before.
   - Covers login, password reset, recovery key, username change, social unlink, device codes, room passwords, child pairing codes and the guardian password.
4. **The server enforced no upload limits, and other users' files could be deleted** (`fb3d1837`).
   - Fix: every attach point now *claims* its file (checking real size, recording the owner, counting quota) through the `uploads` ledger.
   - Added: an unclaimed-file sweep and an upload-URL rate limit.

### High: fixed

- **Passwords:** salted PBKDF2 replaces bare SHA-256 (`d9ce6dfa`). A password reset now signs all other devices out.
- **Push spoofing:** the client-supplied `senderName` was ignored for push titles; it now always comes from the account (`742ccf9d`).
- **Staff handles:** moderator handles can't be renamed, and are retired when the account is deleted (`742ccf9d`).
- **Rate limits on every write** (`ba8d674c`):
  - Messages: 30 per 10 seconds and 1,500 per hour. Edits: 30 per minute.
  - Read cursor: can't run ahead of the clock; 240 moves per minute.
  - Calls: 3 per 2 minutes per callee, 30 per hour. Group calls ring at most 32 people.
  - Reactions: 60 per minute.
  - Friend requests: 30 per day, 3 per person per week. Message requests are filtered and capped.
  - Room invites: 50 per day. Presence status flips: 20 per minute.
  - `@everyone` is admin-only above 20 members. Poll labels go through the language filter.
- **Signup:** 5 accounts per device per day and 30 per minute overall (`d9ce6dfa`).
  - Handles now reject invisible and control characters and letter-case twins of an existing handle.
  - There is still deliberately no alphabet rule, so non-Latin names keep working.
- **Rooms** (`04e0a4a9`):
  - Caps: 1,000 members per room, 500 rooms per user, 10 room creations per day, names 100 characters, descriptions 500.
  - Kicks stick for 7 days. Discover shows the 200 most active rooms.
  - Room and account deletion run in batches.
  - TURN relay credentials: 60 per hour per account.
- **Children:** adults find a child only by their exact handle (`d9ce6dfa`).

### Store policy: fixed

- iOS `PrivacyInfo.xcprivacy` for Runner and the Share, Notification and Broadcast extensions (`f065a4cf`).
- Blocking hides the blocked person in shared rooms and moment comments (`7e77d24a`).
- Moments and comments can be reported where they're shown (`ccbb419d`).
- The server picker is hidden in store builds (`f065a4cf`).
- `READ_MEDIA_AUDIO` removed (`f065a4cf`).
- The app now says why the server refused a send: too fast, storage full, file too large or message too long (`e7a899cf`).

## Still open

### Needs a product decision
1. **Age check at sign-up.** There's no date-of-birth screen, and Play's Families policy and Apple 1.3 care about this. Suggestion: ask for date of birth and send under-13s to "ask a parent to create a family account". Then pick 13+ (or higher) as the age rating.
2. **Android photo access.** `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` exist only for the in-app recents strip. Play may require switching to the system Photo Picker or filing a declaration.
3. **Server media retention.** Quotas cap abuse, but sent media is kept until deleted. Signal-style expiry (delete from the server after N days) would cut storage further.
4. **Room names are globally unique**, so popular names can be squatted. The creation limit slows this down but doesn't stop it.

### Console work (not code)
- **Play Console declarations:**
  - Background location (needs a demo video).
  - The foreground service types: location, media projection, microphone, camera and phone call.
  - Full-screen intent, battery-optimisation exemption, and overlay (system alert window).
- **App Review:** two demo accounts that are friends with each other, a seeded public room, and review notes covering report, block and the 24-hour moderation promise. Someone has to actually meet that 24-hour promise.
- **coturn:** confirm `user-quota`, `total-quota`, `max-bps` and `denied-peer-ip` for private ranges. Not checked in this audit.
- **Home-server standby:** not deployed (it was unreachable). Run `./deploy.sh --convex-only` when it's back, then `npx convex run roomAccess:backfill '{}'` against it.

### Smaller follow-ups
- File URLs for message media are now members-only through `files:getFileUrl`, but a URL that has already leaked still works forever. Signed, short-lived URLs would close that.
- User search scans the whole users table on every query. That's fine at launch size; a search index would scale better.
- Group-call screen: no report/block option there. Members can still report through the room.
- Account deletion doesn't ask for the password again.
- Joining a full room, or one you were removed from, shows the generic "couldn't join" message.
- Usernames with letters from mixed scripts that look alike are still allowed (a deliberate choice).
- An existing server error: `terms:status` is called without `userId` by some client (seen in logs).

## Effect on older app builds

Testers on builds from before these changes keep working, with these exceptions:
- On the desktop/web sign-in screen, the typed 6-digit code no longer works. The QR code still does.
- A wrong password shows a generic error instead of "wrong password".
- A wrong room password can look like it succeeded, then the room shows empty.

## Tests

- Backend: 647 tests, all passing except three that also fail without these changes:
  - `expressions.test.ts`: official-sticker permission.
  - Puzzle "generation is fast" timing checks, which are flaky under load.
- New test files:
  - `roomAccess.test.ts`
  - `credentialThrottle.test.ts`
  - `uploads.test.ts`
  - `staffHandles.test.ts`
  - `spamLimits.test.ts`
  - `roomLimits.test.ts`
- Client: the affected tests pass. `social_username_screen_test.dart` was already failing before these changes.

## Where the limits live

| What | Where |
|---|---|
| Generic rate limiter | `backend/convex/rateLimit.ts` (`consume`) |
| Credential refusals | `backend/convex/rateLimit.ts` (`refusal`) |
| Upload caps and quotas | `backend/convex/files.ts` (`MAX_*`) |
| Message limits | `backend/convex/messages.ts` (`MAX_CONTENT_CHARS`, `MAX_SENDS_*`) |
| Room limits | `backend/convex/roomAdmin.ts` (`MAX_ROOM_MEMBERS`, `MAX_ROOMS_PER_USER`) and `rooms.ts` |
| Password hashing | `backend/convex/passwords.ts` |
| Room read access | `backend/convex/roomAccess.ts` |
