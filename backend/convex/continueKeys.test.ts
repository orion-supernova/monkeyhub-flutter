import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { CONTINUE_KEYS_PER_USER } from "./continueKeys";

/**
 * "Continue as @name" on a second device of the same Apple / Google account.
 * The reported case: a child paired on their phone installs the app on a
 * tablet signed into the same Google account and had to be paired again.
 */

async function pairedChild(t: ReturnType<typeof convexTest>) {
  const parent = await t.mutation(api.auth.signup, {
    username: "parent",
    name: "parent",
    passwordHash: "hash-parent",
    recoveryKeyHash: "recovery-parent",
    deviceId: "device-parent",
  });
  const child = await t.mutation(api.family.createChildAccount, {
    sessionToken: parent.token,
    guardianId: parent.userId,
    username: "lena",
    name: "lena",
  });
  await t.mutation(api.family.createPairingCode, {
    sessionToken: parent.token,
    guardianId: parent.userId,
    childId: child.userId,
    codeHash: "pair-lena",
  });
  const phone = await t.mutation(api.family.redeemPairingCode as any, {
    codeHash: "pair-lena",
    deviceId: "lena-phone",
    platform: "android",
  });
  return { parent, child, phone };
}

describe("continue keys", () => {
  test("a child's second device continues without a pairing code", async () => {
    const t = convexTest(schema);
    const { child, phone } = await pairedChild(t);

    const { key } = await t.mutation(api.continueKeys.mint, {
      sessionToken: phone.token,
      userId: phone.userId,
    });
    expect(key).toMatch(/^[0-9a-f]{64}$/);

    const tablet = await t.mutation(api.continueKeys.redeem as any, {
      key,
      deviceId: "lena-tablet",
      platform: "android",
      deviceName: "Huawei tablet",
    });
    expect(tablet.userId).toBe(child.userId);
    expect(tablet.accountType).toBe("child");
    expect(tablet.token).toBeTruthy();

    // The tablet is its own device, and the phone stays signed in.
    const devices = await t.run((ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", child.userId as any))
        .collect(),
    );
    expect(devices.map((d) => d.deviceId).sort()).toEqual([
      "lena-phone",
      "lena-tablet",
    ]);
    const live = await t.run((ctx) =>
      ctx.db
        .query("sessions")
        .withIndex("by_user", (q) => q.eq("userId", child.userId as any))
        .collect(),
    );
    expect(live.filter((s) => s.revokedAt === undefined)).toHaveLength(2);
  });

  test("a wrong key is refused, and the plaintext is never stored", async () => {
    const t = convexTest(schema);
    const { phone } = await pairedChild(t);
    const { key } = await t.mutation(api.continueKeys.mint, {
      sessionToken: phone.token,
      userId: phone.userId,
    });
    const rows = await t.run((ctx) => ctx.db.query("continueKeys").collect());
    expect(rows[0].keyHash).not.toBe(key);

    await expect(
      t.mutation(api.continueKeys.redeem, {
        key: "0".repeat(64),
        deviceId: "thief",
        platform: "web",
      }),
    ).resolves.toEqual({ __refused: "CONTINUE_KEY_INVALID" });
  });

  test("minting keeps at most the cap, newest kept", async () => {
    const t = convexTest(schema);
    const { phone } = await pairedChild(t);
    const keys: string[] = [];
    for (let i = 0; i < CONTINUE_KEYS_PER_USER + 2; i++) {
      const { key } = await t.mutation(api.continueKeys.mint, {
        sessionToken: phone.token,
        userId: phone.userId,
      });
      keys.push(key);
    }
    const rows = await t.run((ctx) => ctx.db.query("continueKeys").collect());
    expect(rows).toHaveLength(CONTINUE_KEYS_PER_USER);
    await expect(
      t.mutation(api.continueKeys.redeem, {
        key: keys[0],
        deviceId: "old",
        platform: "ios",
      }),
    ).resolves.toEqual({ __refused: "CONTINUE_KEY_INVALID" });
    const latest = await t.mutation(api.continueKeys.redeem as any, {
      key: keys[keys.length - 1],
      deviceId: "new",
      platform: "ios",
    });
    expect(latest.token).toBeTruthy();
  });
  test("adult accounts get no key, and a graduated child's key dies", async () => {
    const t = convexTest(schema);
    const { parent, child, phone } = await pairedChild(t);
    await expect(
      t.mutation(api.continueKeys.mint, {
        sessionToken: parent.token,
        userId: parent.userId,
      }),
    ).rejects.toThrow(/NOT_ALLOWED/);

    const { key } = await t.mutation(api.continueKeys.mint, {
      sessionToken: phone.token,
      userId: phone.userId,
    });
    await t.run((ctx) =>
      ctx.db.patch(child.userId as any, { accountType: "adult" }),
    );
    await expect(
      t.mutation(api.continueKeys.redeem as any, {
        key,
        deviceId: "lena-tablet",
        platform: "android",
      }),
    ).resolves.toEqual({ __refused: "CONTINUE_KEY_INVALID" });
  });
});
