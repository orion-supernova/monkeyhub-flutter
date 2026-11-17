# Age check

Decided 2026-11-17 after the MONK case, where a group of school children (shared
school PCs, ages unknown) were chatting, swearing and reporting each other. The
2026-10-15 security audit had left "age check at sign-up" open as a product
decision. This is that decision.

Not legal advice. It follows how COPPA (US), the UK Children's Code and GDPR
Art. 8 treat a service that has "actual knowledge" of a user's age.

## Policy

| Age | Own account | What happens |
|---|---|---|
| Under 9 | No | "MonkeyHub is for ages 9 and up". Nothing is stored. |
| 9 to 12 | No | "Ask a parent": a parent creates a family account from their own account (`family.createChildAccount`). Nothing is stored. |
| 13 and over | Yes | Normal sign-up. |

So the store rating can be 9+: 9 to 12 year olds use MonkeyHub through a family
account, which is the parental consent the law asks for below 13.

- **Year and month only**, never the day. The birthday is taken as the last day
  of the month, so the cutoff errs young (born March 2013: 13 on 1 April 2026).
- **Locked once given.** The person cannot change it. A confirm step ("born
  March 2014, so you're 12. Is that right?") catches typos first.
- **Private, and the sheet says so.** Never shown on the profile or to anyone else (`visibility.publicUserView`), never shared, used only for the age check. Staff see it only for a support request.

## Where it is asked

| Who | Where | Code |
|---|---|---|
| Password sign-up | Before the recovery phrase step | `login_screen.dart` → `askAgeForSignUp` |
| Apple/Google sign-up | Before the account is created on the username step | `social_username_screen.dart` → `askAgeForSignUp` |
| Accounts with no age (everyone before 2026-11-17, old builds) | Blocking sheet after Terms, once per launch | `home_shell.dart` → `ensureAgeGiven` |
| Family (child) accounts | Never: the guardian answered | `ageCore.ageNeeded` |

The server decides (`backend/convex/ageCore.ts`); the app asks first only so a
refused child sends nothing. Old builds that send no age can still sign up (same
compatibility as Terms) and are stopped by the sheet on their next build.

A sign-up refusal is remembered on the install (`AgeGateLock`,
`mh.ageGate.refused`), so closing the sheet and picking an older year is not a
way past it. Reinstalling clears it; that is accepted.

## An existing account that answers under 13

`age.submit` stores the answer and calls `moderation.restrictForAge`:

- every session revoked with reason `"age"`; sign-in and every call answer
  `AGE_RESTRICTED`;
- offline, out of public rooms, hidden from search (like a ban; private rooms
  and DMs are left alone so it stays reversible);
- **not** a ban: no install or email hashes, because a parent making a family
  account on the same phone is what should happen next.

The app signs out to the login screen, which explains the pause, gives the
support address, and offers "Delete my account" (the suspended-account delete
paths accept it).

## What support can do

Both are internal mutations run from the CLI with the admin key.

| Request | Command | Rule |
|---|---|---|
| "I'm older than I entered" | `moderation:staffResetAge {username, by, reason}` | Once per account. Clears the age and any restriction; the person signs in and answers again. Records who, when and why on the row; a second reset answers `AGE_RESET_USED`. |
| "I'm younger than I entered" | `moderation:staffLowerAge {username, by, birthYear, birthMonth}` | Always allowed, any number of times. An older date answers `AGE_NOT_LOWER`. Under 13 restricts. |
| Asking for ID or a photo | Never | More sensitive data, from children, than the check is worth. |

## Not built (needs a yes)

- **Deleting restricted accounts after a grace period.** Holding an under-13's
  data with no parental consent should end. Today the account is frozen and the
  person or staff can delete it; an automatic delete after N days (a sweep over
  `ageRestrictedAt`) is the remaining step.
- **Linking a restricted account into a family account.** Today the parent
  creates a new child account; the old one is deleted.

## Cost table

| Action | Reads | Writes | Re-runs | Idle |
|---|---|---|---|---|
| `age.status` (once per launch) | 1 get | 0 | none (one-shot query) | 0 |
| `age.submit`, 13+ | 1 get | 1 patch | the caller's own `users` readers, once | 0 |
| `age.submit`, under 13 | + ≤ 100 live sessions, memberships of the caller | + 1 patch per live session, presence, public-room removals | friends' presence, each public room's roster, once | 0 |
| Sign-up with an age | 0 extra | 0 extra (3 fields on the insert) | 0 | 0 |
| `resolveSession` | 0 extra on a live session; 1 get on a session revoked for age (cold path) | 0 | 0 | 0 |
| `mintSession` | 0 extra (row already read) | 0 | 0 | 0 |
| Staff reset / lower | 1 index read | 1 patch (+ restriction as above) | rare | 0 |

No new tables, indexes or crons.
