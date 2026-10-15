import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import { MAX_PASSWORD_FAILURES } from "./rateLimit";
import schema from "./schema";

/**
 * The credential throttles actually count.
 *
 * Every one of these paths used to record a failure and then throw, and a
 * throw rolls back the mutation's writes, the failure count included. So the
 * lockout existed on paper and never engaged. These pin that a wrong guess
 * now leaves a mark that the next guess runs into.
 */

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const login = (t: ReturnType<typeof convexTest>, passwordHash: string) =>
  t.mutation(api.auth.login as any, {
    username: "victim",
    passwordHash,
    deviceId: "attacker",
  });

describe("password guessing locks the account", () => {
  test("a wrong password is refused, and enough of them lock it", async () => {
    const t = convexTest(schema);
    await signUp(t, "victim");

    expect(await login(t, "guess-0")).toEqual({ __refused: "WRONG_PASSWORD" });
    for (let i = 1; i < MAX_PASSWORD_FAILURES; i++) {
      await login(t, `guess-${i}`);
    }
    // Locked: even the right password is refused until the window passes.
    await expect(login(t, "hash-victim")).rejects.toThrow("TOO_MANY_ATTEMPTS");
  });
});

describe("device sign-in codes", () => {
  test("the server mints the code, and a client-chosen one is ignored", async () => {
    const t = convexTest(schema);
    const req: any = await t.mutation(api.deviceLogin.createLoginRequest, {
      deviceInfo: "Chrome on macOS",
      codeHash: "attacker-chosen",
    });
    expect(req.code).toMatch(/^\d{6}$/);
    const rows = await t.run((ctx) =>
      ctx.db.query("deviceLoginRequests").take(5),
    );
    expect(rows).toHaveLength(1);
    expect(rows[0].codeHash).not.toBe("attacker-chosen");
  });
});

describe("pairing-code guessing is throttled", () => {
  test("one device runs out of guesses", async () => {
    const t = convexTest(schema);
    const guess = (i: number) =>
      t.mutation(api.family.redeemPairingCode as any, {
        codeHash: `wrong-${i}`,
        deviceId: "script",
        platform: "android",
      });
    expect(await guess(0)).toEqual({ __refused: "PAIRING_CODE_INVALID" });
    for (let i = 1; i < 10; i++) await guess(i);
    await expect(guess(99)).rejects.toThrow("TOO_MANY_ATTEMPTS");
  });
});
