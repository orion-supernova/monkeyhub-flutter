import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

const DAY_MS = 24 * 60 * 60 * 1000;

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: "seed-device",
  });
}

async function insertDevice(
  t: ReturnType<typeof convexTest>,
  userId: string,
  deviceId: string,
  lastSeenAt: number,
) {
  await t.run(async (ctx) =>
    ctx.db.insert("userDevices", {
      userId: userId as any,
      deviceId,
      platform: "web",
      lastSeenAt,
      createdAt: lastSeenAt,
    }),
  );
}

describe("voipTokens.gcStaleDevices", () => {
  test("deletes a device nobody has seen in over 90 days", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    await insertDevice(t, me.userId, "old-browser", Date.now() - 91 * DAY_MS);

    await t.mutation(internal.voipTokens.gcStaleDevices, {});

    const rows = await t.run(async (ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", me.userId))
        .collect(),
    );
    // The seed device from signUp survives (freshly created); only the
    // manually-backdated row should be gone.
    expect(rows.some((r) => r.deviceId === "old-browser")).toBe(false);
  });

  test("a device seen within the window survives", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "elif");
    await insertDevice(t, me.userId, "quiet-phone", Date.now() - 45 * DAY_MS);

    await t.mutation(internal.voipTokens.gcStaleDevices, {});

    const rows = await t.run(async (ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", me.userId))
        .collect(),
    );
    expect(rows.some((r) => r.deviceId === "quiet-phone")).toBe(true);
  });

  test("a device exactly at the cutoff survives (boundary is exclusive)", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "kaan");
    // Slightly inside 90 days, so a slow test run cannot flake it across the
    // boundary the way an exact `Date.now() - 90 * DAY_MS` could.
    await insertDevice(t, me.userId, "edge-device", Date.now() - 90 * DAY_MS + 5000);

    await t.mutation(internal.voipTokens.gcStaleDevices, {});

    const rows = await t.run(async (ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", me.userId))
        .collect(),
    );
    expect(rows.some((r) => r.deviceId === "edge-device")).toBe(true);
  });

  test("a stale device is gone from the daily nudge's own audience report", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "zeynep");
    await insertDevice(t, me.userId, "abandoned-tablet", Date.now() - 120 * DAY_MS);

    const before = await t.query(internal.dailyNudge.audienceReport, {
      sinceDays: 200,
    });
    expect(before.devices).toBeGreaterThan(0);

    await t.mutation(internal.voipTokens.gcStaleDevices, {});

    const after = await t.query(internal.dailyNudge.audienceReport, {
      sinceDays: 200,
    });
    expect(after.devices).toBe(before.devices - 1);
  });
});
