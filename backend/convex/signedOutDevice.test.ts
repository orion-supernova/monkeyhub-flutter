import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

/**
 * A handset that is no longer signed in must not be notified.
 *
 * Reported by a user who was sitting on the login screen, locked out of her
 * own account because she had forgotten her password, and still receiving
 * notifications for it. The `userDevices` row is what the senders address, and
 * nothing deleted it: `voipTokens.clearDeviceToken` is authenticated and the
 * client called it AFTER clearing its own token, so it was rejected and its
 * error swallowed by a `debugPrint`, on every sign-out on every platform.
 *
 * Two fixes, and this file holds both to the same standard:
 *
 *   * the senders now ask whether the device still has a live session, which
 *     is the only thing that covers rows already stranded in production and
 *     the sign-outs the client is not around to perform;
 *   * `auth.logout` deletes the row itself, so one surviving call does the
 *     whole job.
 */

const PHONE = "device-phone";
const TABLET = "device-tablet";

async function signUp(
  t: ReturnType<typeof convexTest>,
  username: string,
  deviceId: string,
) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId,
  });
}

/** Sign an existing account in on a second handset. */
async function login(
  t: ReturnType<typeof convexTest>,
  username: string,
  deviceId: string,
) {
  return await t.mutation(api.auth.login as any, {
    username,
    passwordHash: `hash-${username}`,
    deviceId,
  });
}

async function registerPush(
  t: ReturnType<typeof convexTest>,
  session: { token: string; userId: string },
  deviceId: string,
  token: string,
) {
  await t.mutation(api.voipTokens.setApnsToken, {
    sessionToken: session.token,
    userId: session.userId as any,
    deviceId,
    platform: "ios",
    token,
  });
  await t.mutation(api.voipTokens.setVoipToken, {
    sessionToken: session.token,
    userId: session.userId as any,
    deviceId,
    platform: "ios",
    token: `voip-${token}`,
  });
}

async function alertDevices(
  t: ReturnType<typeof convexTest>,
  userId: string,
): Promise<Array<{ deviceId: string }>> {
  const targets = await t.query(internal.push._loadAlertTargets, {
    userIds: [userId as any],
  });
  return targets.flatMap((x: { devices: Array<{ deviceId: string }> }) =>
    x.devices,
  );
}

describe("a signed-out handset stops being a push target", () => {
  test("banners stop when the session is revoked, even if the row survives", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");

    expect((await alertDevices(t, me.userId)).length).toBe(1);

    // The row is left behind DELIBERATELY here: this is the state every
    // failed sign-out teardown produced, and the state production is already
    // full of. Revoking the session alone must be enough to silence it.
    await t.run(async (ctx) => {
      for (const row of await ctx.db
        .query("sessions")
        .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
        .collect()) {
        await ctx.db.patch(row._id, { revokedAt: Date.now() });
      }
    });

    const rows = await t.run(async (ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
        .collect(),
    );
    expect(rows.length).toBe(1);
    expect(rows[0].apnsToken).toBe("apns-phone");

    expect(await alertDevices(t, me.userId)).toEqual([]);
  });

  test("the ring path is silenced by the same check", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");

    const before = await t.query(internal.voipPush._loadUserDevices, {
      userId: me.userId as any,
    });
    expect(before.length).toBe(1);

    await t.run(async (ctx) => {
      for (const row of await ctx.db
        .query("sessions")
        .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
        .collect()) {
        await ctx.db.patch(row._id, { revokedAt: Date.now() });
      }
    });

    // And NOT via the legacy `users.voipToken` fallback, which an empty result
    // must not be allowed to reach.
    expect(
      await t.query(internal.voipPush._loadUserDevices, {
        userId: me.userId as any,
      }),
    ).toEqual([]);
  });

  test("the daily nudge skips it too", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");

    const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const args = {
      userIds: [me.userId as any],
      tzOffsetMinutes: null,
      cutoff,
    };
    expect(
      (await t.query(internal.dailyNudge.devicesForUsers, args)).length,
    ).toBe(1);

    await t.run(async (ctx) => {
      for (const row of await ctx.db
        .query("sessions")
        .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
        .collect()) {
        await ctx.db.patch(row._id, { revokedAt: Date.now() });
      }
    });

    expect(await t.query(internal.dailyNudge.devicesForUsers, args)).toEqual([]);
  });

  test("the account's OTHER phone keeps its notifications", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");
    const second = await login(t, "sidika", TABLET);
    await registerPush(t, second, TABLET, "apns-tablet");

    await t.mutation(api.auth.logout, {
      sessionToken: me.token,
      deviceId: PHONE,
    });

    const devices = await alertDevices(t, me.userId);
    expect(devices.map((d) => d.deviceId)).toEqual([TABLET]);
  });

  test("the Devices screen stops calling it reachable", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");
    const second = await login(t, "sidika", TABLET);
    await registerPush(t, second, TABLET, "apns-tablet");

    await t.run(async (ctx) => {
      for (const row of await ctx.db
        .query("sessions")
        .withIndex("by_user_device", (q) =>
          q.eq("userId", me.userId as any).eq("deviceId", PHONE),
        )
        .collect()) {
        await ctx.db.patch(row._id, { revokedAt: Date.now() });
      }
    });

    const listed = await t.query(api.voipTokens.listDevices, {
      sessionToken: second.token,
      userId: second.userId as any,
      deviceId: TABLET,
    });
    const byId = Object.fromEntries(
      listed.map((d: { deviceId: string; reachable: boolean }) => [
        d.deviceId,
        d.reachable,
      ]),
    );
    expect(byId[TABLET]).toBe(true);
    expect(byId[PHONE]).toBe(false);
  });
});

describe("signing out takes the push row with it", () => {
  test("auth.logout deletes the device row, not just the session", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");

    await t.mutation(api.auth.logout, {
      sessionToken: me.token,
      deviceId: PHONE,
    });

    const rows = await t.run(async (ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
        .collect(),
    );
    expect(rows).toEqual([]);
    expect(await alertDevices(t, me.userId)).toEqual([]);
  });

  test("either half of the teardown alone is enough, in either order", async () => {
    // The client fires both, unordered. Whichever lands second is rejected for
    // the revocation the first one performed, so neither may be load-bearing.
    for (const first of ["logout", "clearDeviceToken"] as const) {
      const t = convexTest(schema);
      const me = await signUp(t, "sidika", PHONE);
      await registerPush(t, me, PHONE, "apns-phone");

      if (first === "logout") {
        await t.mutation(api.auth.logout, {
          sessionToken: me.token,
          deviceId: PHONE,
        });
      } else {
        await t.mutation(api.voipTokens.clearDeviceToken, {
          sessionToken: me.token,
          userId: me.userId as any,
          deviceId: PHONE,
        });
      }

      const rows = await t.run(async (ctx) =>
        ctx.db
          .query("userDevices")
          .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
          .collect(),
      );
      expect(rows, `${first} first`).toEqual([]);

      // And the account reads as offline whichever one got there.
      const user = await t.run(async (ctx) => ctx.db.get(me.userId as any));
      expect((user as { status?: string }).status, `${first} first`).toBe(
        "offline",
      );
    }
  });

  test("the triage query counts what is left over", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    await registerPush(t, me, PHONE, "apns-phone");
    const second = await login(t, "sidika", TABLET);
    await registerPush(t, second, TABLET, "apns-tablet");

    expect(await t.query(internal.voipTokens.strandedDevices, {})).toEqual({
      scanned: 2,
      stranded: 0,
      strandedWithCredential: 0,
      truncated: false,
    });

    // A sign-out that could not delete its own row: exactly the backlog this
    // query exists to size.
    await t.run(async (ctx) => {
      for (const row of await ctx.db
        .query("sessions")
        .withIndex("by_user_device", (q) =>
          q.eq("userId", me.userId as any).eq("deviceId", PHONE),
        )
        .collect()) {
        await ctx.db.patch(row._id, { revokedAt: Date.now() });
      }
    });

    expect(await t.query(internal.voipTokens.strandedDevices, {})).toEqual({
      scanned: 2,
      stranded: 1,
      strandedWithCredential: 1,
      truncated: false,
    });
  });

  test("removing one device does not mark a still-signed-in account offline", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    const second = await login(t, "sidika", TABLET);
    await registerPush(t, second, TABLET, "apns-tablet");

    // The Devices screen, on the tablet, removing the phone.
    await t.mutation(api.voipTokens.clearDeviceToken, {
      sessionToken: second.token,
      userId: second.userId as any,
      deviceId: PHONE,
    });

    const user = await t.run(async (ctx) => ctx.db.get(me.userId as any));
    expect((user as { status?: string }).status).not.toBe("offline");
  });
});

describe("signing out marks the account offline in presence", () => {
  test("auth.logout and the last-device removal", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sidika", PHONE);
    const presence = () =>
      t.run(async (ctx) => ({
        row: await ctx.db
          .query("presence")
          .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
          .first(),
        beat: await ctx.db
          .query("presenceBeats")
          .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
          .first(),
      }));
    expect((await presence()).row?.status).toBe("online");

    await t.mutation(api.auth.logout, { sessionToken: me.token, deviceId: PHONE });
    const after = await presence();
    expect(after.row?.status).toBe("offline");
    expect(after.row?.lastSeen).toBeGreaterThan(0);
    // The beat is retired so the sweep does not look at it again.
    expect(after.beat?.live).toBe(false);
  });
});
