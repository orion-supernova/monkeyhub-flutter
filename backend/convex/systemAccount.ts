/**
 * The system accounts, and the one rule that governs them.
 *
 * There is currently exactly one: `MonkeyHub Logs`, which `problemReports.ts`
 * posts problem reports as. It is not a *person*. It has no client, no device, no
 * session and no password anybody can present, so every ordinary thing you can
 * do to a user is, applied to this row, a dead end that looks like a live one:
 * a friend request nobody will ever accept, a DM nobody will ever read, a call
 * that rings nothing.
 *
 * So the rule is one line: **a system account is reachable in exactly one
 * direction, and only by the maintainer it writes to.** It writes; nobody
 * addresses it, and nobody else can see it at all.
 *
 * Not merely unaddressable — *invisible*. It is filtered out of both user
 * searches, refuses friend requests, and carries a `visibility` block that keeps
 * its face and presence to accepted friends only, of which the maintainer is the
 * sole one. In an app children use, a findable account named after the app that
 * silently swallows whatever you send it is worse than no account at all, and
 * "cannot be messaged" is a weaker promise than "cannot be found".
 *
 * The one thing this does NOT hide is the row's existence to somebody who
 * already holds its id: `visibility.publicUserView` returns `_id`, `username` and
 * `name` unconditionally, for every user, and narrowing that is a change to the
 * shape every friend-request and room-member read depends on. The protection is
 * that the id cannot be obtained — the account appears in no search, no public
 * room, and no roster but the single DM it writes to.
 *
 * ── Why this module exists at all ──────────────────────────────────────────
 *
 * Two reasons, both practical.
 *
 * The first is import cycles. The guards below belong in `friends.ts`,
 * `calls.ts`, `rooms.ts`, `groupCalls.ts`, `auth.ts` and `users.ts`, and
 * `problemReports.ts` — their natural home — imports `messages.ts`. Putting the
 * predicate there would have half the backend importing the report path. This
 * module imports nothing, so it can be imported from anywhere.
 *
 * The second is that the marker has to be something a caller cannot forge. It is
 * the `passwordHash` prefix rather than the username, because a username is an
 * argument: `friends.sendRequest` takes one, and matching on a string would make
 * "is this a system account" a question about what the caller typed. The prefix
 * is on a row only `problemReports.ensureLogAccount` ever writes, and the rest
 * of that value is 32 random hex characters minted at creation — so it also
 * cannot be presented as a password by somebody who read this file.
 */

/** The account problem reports are posted BY. */
export const LOG_USERNAME = "monkeyhub_logs";

/** Its display name — the one the maintainer's room list renders. */
export const LOG_DISPLAY_NAME = "MonkeyHub Logs";

/**
 * The account problem reports are posted TO, by handle.
 *
 * A username rather than an id so it survives a rebuild of the deployment, and
 * so pointing reports at a different maintainer is a one-line change.
 */
export const REPORT_INBOX_USERNAME = "muratcankoc";

/**
 * Words no human account's username may contain.
 *
 * The brand itself, and the whole brand rather than the specific system handles.
 * Reserving only `monkeyhub_logs` would protect this one account and nothing
 * else: the next system account needs the same protection, and the real damage
 * was never a collision anyway — it is `monkeyhub_support`, `monkeyhub-admin`,
 * `MonkeyHubTeam` in a child's friend request, asking for a password. An
 * account that merely LOOKS official does the scam; it never has to be the one
 * the code writes from.
 *
 * A substring rule, so it holds for handles nobody has thought of yet.
 */
const RESERVED_SUBSTRINGS: readonly string[] = ["monkeyhub"];

/** Refused when a requested username hits [isReservedName]. */
export const ERR_USERNAME_RESERVED = "USERNAME_RESERVED";

/**
 * Refused when a requested DISPLAY name hits [isReservedName].
 *
 * A separate code from the username one because they are separate fields on
 * separate screens, and a profile edit answering "that username isn't available"
 * sends the user looking for a problem with the wrong box.
 */
export const ERR_DISPLAY_NAME_RESERVED = "DISPLAY_NAME_RESERVED";

/**
 * The forms a name is tested against — TWO of them, not one.
 *
 * Case, separators and digit-for-letter substitution all have to come out,
 * because every one of them produces a handle that reads as the brand at a
 * glance: `Monkey_Hub`, `monkey-hub`, `m0nkeyhub`, `M0NKEY.HUB`. A plain
 * lowercase `includes` catches the first and none of the rest, which is the
 * version of this check that looks right and stops nobody.
 *
 * Two variants because some characters are genuinely ambiguous, and a single
 * substitution table gets them wrong in one direction or the other. `|` is `l`
 * in leetspeak but a plain divider between words in `monkey|hub`; substituting
 * yields `monkeylhub` and the name sails through. Stripping instead breaks the
 * leetspeak cases. So both readings are produced and a hit on either is a hit:
 *
 *   substituted  `monkey|hub` → monkeylhub   (miss)
 *   stripped     `monkey|hub` → monkeyhub    (HIT)
 *   substituted  `m0nk3yhub`  → monkeyhub    (HIT)
 *   stripped     `m0nk3yhub`  → mnkyhub      (miss)
 *
 * `m@nkeyhub` is refused by neither, and that is correct rather than a gap: `@`
 * reads as `a`, so the name says "mankeyhub" to whoever sees it, and a filter
 * that blocks it is blocking a name nobody would be fooled by.
 *
 * Not a security boundary. A determined impersonator has Cyrillic homoglyphs,
 * and the answer to those is reporting and moderation, not a regex. This closes
 * the casual attempt, which is the one that actually happens.
 */
function foldsForReservation(name: string): [string, string] {
  const lower = name.toLowerCase();
  const substituted = lower
    .replace(/0/g, "o")
    .replace(/[1|!]/g, "l")
    .replace(/3/g, "e")
    .replace(/[4@]/g, "a")
    .replace(/[5$]/g, "s")
    .replace(/7/g, "t");
  const letters = (s: string) => s.replace(/[^a-z]/g, "");
  // Second variant drops every non-letter BEFORE any substitution, so a symbol
  // used as a separator disappears instead of becoming the letter it resembles.
  return [letters(substituted), letters(lower)];
}

/**
 * True if [name] may not be claimed by a person, as either a username or a
 * display name.
 *
 * One predicate for both fields, because the impersonation does not care which
 * one carries it — and the display name is the more dangerous of the two. A
 * username appears on a profile; the DISPLAY name is what renders on every chat
 * bubble, every friend request and every row of the room list. `helper123`
 * calling itself "MonkeyHub Support" is the whole scam, and blocking only the
 * handle would have left it fully available.
 *
 * Enforced at all FOUR write paths: the three that create an account
 * (`auth.signup`, `socialAuth.completeSocialSignUp`,
 * `family.createChildAccount`) and the one that can change a name afterwards
 * (`users.updateProfile`) — which is the one that matters most, since a name
 * only checked at signup is a name anybody can set on day two.
 *
 * Deliberately not applied to the system account's own row: that is written by
 * `ctx.db.insert` in `problemReports.ensureLogAccount` and never passes through
 * a mutation, so the rule can be absolute here without locking the app out of
 * its own name.
 */
export function isReservedName(name: string): boolean {
  const folds = foldsForReservation(name);
  return RESERVED_SUBSTRINGS.some((word) =>
    folds.some((folded) => folded.includes(word)),
  );
}

/**
 * See the note on this module about why the marker is the password and not the
 * name. Never compared against a caller-supplied value.
 */
export const SYSTEM_PASSWORD_PREFIX = "__SYSTEM_NO_LOGIN__";

/**
 * Told to anyone who tries to address a system account.
 *
 * Its own code rather than a reuse of `USER_NOT_FOUND`, and the reason is that
 * the only caller who can ever see it is the maintainer — everybody else is
 * stopped one step earlier by not being able to find the account. To that one
 * caller the row plainly does exist, with its name and picture in their room
 * list, so `USER_NOT_FOUND` would be a lie the same screen contradicts.
 *
 * The `visibility` block is what keeps this from leaking anything: reaching a
 * path that can return this error at all means already holding an id that only
 * the maintainer has.
 */
export const ERR_SYSTEM_ACCOUNT = "SYSTEM_ACCOUNT";

/**
 * The `users.visibility` block every system account is created with.
 *
 * `avatar: "friends"` rather than `"public"`: the face has to reach the one
 * person the account writes to, and nobody else. Presence is `"nobody"` outright
 * — there is no last time this account was seen and no meaningful status, so the
 * honest answer is to render no dot rather than a permanent grey one.
 *
 * Spelled out in full rather than left absent, which is the trap: the server's
 * defaults in `visibility.DEFAULT_LEVEL` are `"public"` for avatar, status and
 * lastSeen. An empty block is the MOST exposed setting, not the least — the
 * opposite of what the client's settings UI implies, where a user's own unset
 * keys read as "nobody".
 */
export const SYSTEM_VISIBILITY = {
  avatar: "friends",
  status: "nobody",
  lastSeen: "nobody",
  seen: "nobody",
  // Also enforced by `assertNoSystemAccount` on both request paths. This is the
  // belt to that braces, and it is the one the pre-existing check already reads.
  friendRequests: "nobody",
} as const;

/** True for a system account row. Takes the row, so it costs no read. */
export function isSystemAccount(user: { passwordHash?: string } | null): boolean {
  return user?.passwordHash?.startsWith(SYSTEM_PASSWORD_PREFIX) === true;
}

/** [isSystemAccount] for callers holding only an id. */
export async function isSystemAccountId(ctx: any, userId: any): Promise<boolean> {
  if (!userId) return false;
  return isSystemAccount(await ctx.db.get(userId));
}

/**
 * Throws [ERR_SYSTEM_ACCOUNT] if either id names a system account.
 *
 * Both sides, always, even where one of them is obviously the caller. It costs
 * one extra `ctx.db.get` on paths that already do several, and it means a future
 * system account that somehow acquires a session cannot use these paths either —
 * which is the direction a mistake here would go.
 */
export async function assertNoSystemAccount(
  ctx: any,
  ...userIds: any[]
): Promise<void> {
  for (const id of userIds) {
    if (await isSystemAccountId(ctx, id)) throw new Error(ERR_SYSTEM_ACCOUNT);
  }
}
