import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { ageInYears, signupAgeStamp } from "./ageCore";
import { TERMS_VERSION } from "./terms";

/**
 * The age check (decided 2026-11-17): under 9 no account, 9 to 12 only a family
 * account, 13 and over their own. Sign-up refuses before writing anything; an
 * existing account that answers under 13 is restricted, can delete itself, and
 * staff get one reset and an always-allowed "make younger".
 */

const NOW_YEAR = new Date().getUTCFullYear();
const ADULT = { birthYear: NOW_YEAR - 30, birthMonth: 1 };
const TWEEN = { birthYear: NOW_YEAR - 11, birthMonth: 1 };
const TODDLER = { birthYear: NOW_YEAR - 5, birthMonth: 1 };

async function signUp(
  t: ReturnType<typeof convexTest>,
  username: string,
  extra: Record<string, any> = {},
) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
    termsVersion: TERMS_VERSION,
    ...extra,
  } as any);
}

const login = (t: ReturnType<typeof convexTest>, username: string) =>
  t.mutation(api.auth.login, {
    username,
    passwordHash: `hash-${username}`,
    deviceId: `device-${username}-2`,
  } as any);

const usersNamed = (t: ReturnType<typeof convexTest>, username: string): Promise<any[]> =>
  t.run((ctx: any) =>
    ctx.db
      .query("users")
      .withIndex("by_username", (q: any) => q.eq("username", username))
      .collect(),
  );

describe("ageInYears", () => {
  test("a year counts only once the birth month has passed", () => {
    const march2026 = Date.UTC(2026, 2, 15);
    const april2026 = Date.UTC(2026, 3, 1);
    expect(ageInYears(2013, 3, march2026)).toBe(12);
    expect(ageInYears(2013, 3, april2026)).toBe(13);
    expect(ageInYears(2013, 2, march2026)).toBe(13);
  });

  test("signupAgeStamp: nothing for an old client, refusals below 13", () => {
    expect(signupAgeStamp(undefined, undefined)).toEqual({});
    expect(() => signupAgeStamp(2000, undefined)).toThrow("AGE_INVALID");
    expect(() => signupAgeStamp(2000, 13)).toThrow("AGE_INVALID");
    expect(() => signupAgeStamp(NOW_YEAR + 1, 1)).toThrow("AGE_INVALID");
    expect(() => signupAgeStamp(TODDLER.birthYear, 1)).toThrow("AGE_TOO_YOUNG");
    expect(() => signupAgeStamp(TWEEN.birthYear, 1)).toThrow("AGE_NEEDS_GUARDIAN");
    expect(signupAgeStamp(ADULT.birthYear, 1)).toMatchObject(ADULT);
  });
});

describe("sign-up", () => {
  test("under 9 and 9 to 12 are refused and leave no account behind", async () => {
    const t = convexTest(schema);
    await expect(signUp(t, "tiny", TODDLER)).rejects.toThrow("AGE_TOO_YOUNG");
    await expect(signUp(t, "tween", TWEEN)).rejects.toThrow("AGE_NEEDS_GUARDIAN");
    expect(await usersNamed(t, "tiny")).toHaveLength(0);
    expect(await usersNamed(t, "tween")).toHaveLength(0);
  });

  test("13 and over is stored and owes nothing", async () => {
    const t = convexTest(schema);
    const who = await signUp(t, "grown", ADULT);
    const [row] = await usersNamed(t, "grown");
    expect(row).toMatchObject(ADULT);
    expect(row.ageGivenAt).toBeTypeOf("number");
    expect(await t.query(api.age.status, { sessionToken: who.token } as any)).toEqual({
      needed: false,
    });
  });

  test("an old build's sign-up (no age) is let in and owes the age sheet", async () => {
    const t = convexTest(schema);
    const who = await signUp(t, "oldbuild");
    expect(await t.query(api.age.status, { sessionToken: who.token } as any)).toEqual({
      needed: true,
    });
  });
});

describe("the age sheet", () => {
  test("13 and over: stored once, then locked", async () => {
    const t = convexTest(schema);
    const who = await signUp(t, "sheet");
    const res = await t.mutation(api.age.submit, { sessionToken: who.token, ...ADULT } as any);
    expect(res).toEqual({ restricted: false });
    expect(await t.query(api.age.status, { sessionToken: who.token } as any)).toEqual({
      needed: false,
    });
    await expect(
      t.mutation(api.age.submit, { sessionToken: who.token, ...ADULT } as any),
    ).rejects.toThrow("AGE_ALREADY_SET");
  });

  test("under 13: restricted, signed out everywhere, and can still delete itself", async () => {
    const t = convexTest(schema);
    const who = await signUp(t, "kid");
    const res = await t.mutation(api.age.submit, { sessionToken: who.token, ...TWEEN } as any);
    expect(res).toEqual({ restricted: true });
    // The session that answered is revoked with the age reason.
    await expect(
      t.query(api.age.status, { sessionToken: who.token } as any),
    ).rejects.toThrow("AGE_RESTRICTED");
    // And no sign-in path mints a new one.
    await expect(login(t, "kid")).rejects.toThrow("AGE_RESTRICTED");
    // Deleting it is the person's right.
    await t.mutation(api.auth.deleteSuspendedAccount, {
      username: "kid",
      passwordHash: "hash-kid",
    });
    const [row] = await usersNamed(t, "kid");
    expect(row).toBeUndefined();
  });

  test("a normal account cannot use the locked-account delete", async () => {
    const t = convexTest(schema);
    await signUp(t, "normal", ADULT);
    await expect(
      t.mutation(api.auth.deleteSuspendedAccount, {
        username: "normal",
        passwordHash: "hash-normal",
      }),
    ).rejects.toThrow();
  });
});

describe("staff", () => {
  test("one reset: clears the age and the restriction, a second is refused", async () => {
    const t = convexTest(schema);
    const who = await signUp(t, "typo");
    await t.mutation(api.age.submit, { sessionToken: who.token, ...TWEEN } as any);
    await t.mutation(internal.moderation.staffResetAge, {
      username: "typo",
      by: "murat",
      reason: "typed the wrong year",
    });
    const [row] = await usersNamed(t, "typo");
    expect(row.ageRestrictedAt).toBeUndefined();
    expect(row.birthYear).toBeUndefined();
    expect(row).toMatchObject({ ageResetBy: "murat", ageResetReason: "typed the wrong year" });
    // They sign in again and owe the sheet once more.
    const back: any = await login(t, "typo");
    expect(await t.query(api.age.status, { sessionToken: back.token } as any)).toEqual({
      needed: true,
    });
    await expect(
      t.mutation(internal.moderation.staffResetAge, {
        username: "typo",
        by: "murat",
        reason: "again",
      }),
    ).rejects.toThrow("AGE_RESET_USED");
  });

  test("make younger: allowed, restricts under 13; make older: refused", async () => {
    const t = convexTest(schema);
    await signUp(t, "lower", ADULT);
    await expect(
      t.mutation(internal.moderation.staffLowerAge, {
        username: "lower",
        by: "murat",
        birthYear: ADULT.birthYear - 1,
        birthMonth: 1,
      }),
    ).rejects.toThrow("AGE_NOT_LOWER");
    const res = await t.mutation(internal.moderation.staffLowerAge, {
      username: "lower",
      by: "murat",
      ...TWEEN,
    });
    expect(res).toEqual({ restricted: true });
    await expect(login(t, "lower")).rejects.toThrow("AGE_RESTRICTED");
  });
});
