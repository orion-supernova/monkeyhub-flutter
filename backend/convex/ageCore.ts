/**
 * Age rules: who may hold an account of their own, decided from a birth year
 * and month. Pure functions, no database, so every path (password sign-up,
 * Apple/Google sign-up, the sheet for existing accounts, staff corrections)
 * applies the same arithmetic.
 *
 * ── The policy (decided 2026-11-17) ─────────────────────────────────────────
 *
 *  * Under [MIN_AGE_APP] (9): MonkeyHub is not for them. No account.
 *  * [MIN_AGE_APP] to [MIN_AGE_OWN_ACCOUNT] - 1 (9 to 12): only a family
 *    account a parent creates (`family.createChildAccount`). A parent creating
 *    and supervising the account is the parental consent COPPA, the UK
 *    Children's Code and GDPR Art. 8 ask for below 13.
 *  * [MIN_AGE_OWN_ACCOUNT] (13) and over: their own account.
 *
 * Year and month only, never the day: enough for a reliable cutoff, and less
 * personal data to hold. The day is unknown, so [ageInYears] assumes the
 * birthday falls at the END of the month. That errs young: someone born in
 * March turns 13 on 1 April, never early.
 *
 * Refused sign-ups store nothing. An existing account that comes out under 13
 * is restricted (`moderation.restrictForAge`), not deleted: it can sign in to
 * nothing until staff correct the age or the person deletes it.
 */

export const MIN_AGE_APP = 9;
export const MIN_AGE_OWN_ACCOUNT = 13;

/** Oldest birth year accepted, so a typo of 1026 is not a 1,000-year-old. */
export const MIN_BIRTH_YEAR = 1900;

/** Under [MIN_AGE_APP]. */
export const ERR_AGE_TOO_YOUNG = "AGE_TOO_YOUNG";
/** [MIN_AGE_APP] to 12: a parent must create a family account. */
export const ERR_AGE_NEEDS_GUARDIAN = "AGE_NEEDS_GUARDIAN";
/** Month outside 1 to 12, a year in the future or before [MIN_BIRTH_YEAR], or
 * only one of the two fields sent. */
export const ERR_AGE_INVALID = "AGE_INVALID";
/** The account already gave its age. It is locked; only staff can change it. */
export const ERR_AGE_ALREADY_SET = "AGE_ALREADY_SET";
/** The account is restricted for age. Thrown by sign-in and by every call on a
 * session the restriction revoked. */
export const ERR_AGE_RESTRICTED = "AGE_RESTRICTED";

export type AgeBand = "tooYoung" | "needsGuardian" | "ok";

/**
 * Whole years old at [now], assuming the birthday is the last day of
 * [birthMonth] (1 to 12). UTC, like every other date on the server.
 */
export function ageInYears(
  birthYear: number,
  birthMonth: number,
  now: number = Date.now(),
): number {
  const d = new Date(now);
  const months =
    (d.getUTCFullYear() * 12 + d.getUTCMonth() + 1) -
    (birthYear * 12 + birthMonth);
  // A full year counts only once the birth month has passed: born March 2013,
  // in March 2026 that is 156 months but still 12 years old.
  return Math.floor((months - 1) / 12);
}

/** Throws [ERR_AGE_INVALID] unless the pair is a real, past month. */
export function assertValidBirth(
  birthYear: number,
  birthMonth: number,
  now: number = Date.now(),
): void {
  const d = new Date(now);
  const nowIndex = d.getUTCFullYear() * 12 + d.getUTCMonth() + 1;
  if (
    !Number.isInteger(birthYear) ||
    !Number.isInteger(birthMonth) ||
    birthMonth < 1 ||
    birthMonth > 12 ||
    birthYear < MIN_BIRTH_YEAR ||
    birthYear * 12 + birthMonth > nowIndex
  ) {
    throw new Error(ERR_AGE_INVALID);
  }
}

export function ageBand(age: number): AgeBand {
  if (age < MIN_AGE_APP) return "tooYoung";
  if (age < MIN_AGE_OWN_ACCOUNT) return "needsGuardian";
  return "ok";
}

/** The refusal for a band below [MIN_AGE_OWN_ACCOUNT]. */
export function errorForBand(band: AgeBand): string | null {
  if (band === "tooYoung") return ERR_AGE_TOO_YOUNG;
  if (band === "needsGuardian") return ERR_AGE_NEEDS_GUARDIAN;
  return null;
}

/**
 * The fields a sign-up writes, or none for an old client that sent no age.
 *
 * Same compatibility as `terms.termsStamp`: a build that predates the age
 * step is not refused (that would break sign-up for every tester on it); the
 * account is created without an age and the next build stops it at the age
 * sheet. A client that sends an age is held to it: under 13 is refused here,
 * before anything is written, so a refused child leaves no data behind.
 */
export function signupAgeStamp(
  birthYear: number | undefined,
  birthMonth: number | undefined,
  now: number = Date.now(),
): { birthYear?: number; birthMonth?: number; ageGivenAt?: number } {
  if (birthYear === undefined && birthMonth === undefined) return {};
  if (birthYear === undefined || birthMonth === undefined) {
    throw new Error(ERR_AGE_INVALID);
  }
  assertValidBirth(birthYear, birthMonth, now);
  const refusal = errorForBand(ageBand(ageInYears(birthYear, birthMonth, now)));
  if (refusal) throw new Error(refusal);
  return { birthYear, birthMonth, ageGivenAt: now };
}

/**
 * Whether [user] still owes the age question. Family (child) accounts never
 * do: the guardian answered for them. Restricted accounts never reach it.
 */
export function ageNeeded(user: {
  accountType?: string;
  ageGivenAt?: number;
}): boolean {
  return user.accountType !== "child" && user.ageGivenAt === undefined;
}
