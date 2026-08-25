import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

/**
 * Reproductions for the two regressions the session migration caused.
 *
 * Written before either fix, so that "fixed" means these went green rather
 * than that the symptom stopped being reported.
 */

const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  });
}

describe("push registration still reaches the server", () => {
  test("an APNs token lands on the device row and is findable by the sender", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    await t.mutation(api.voipTokens.setApnsToken, {
      sessionToken: me.token,
      userId: me.userId,
      deviceId: DEVICE,
      platform: "ios",
      // The PUSH token, in the argument the collision used to clobber.
      token: "apns-abc",
    });

    // What `push.sendAlert` actually reads. If this is empty, no notification
    // is ever sent, and every client-side call site swallows its error with a
    // debugPrint — which is how this could break silently.
    const targets = await t.query(internal.push._loadAlertTargets, {
      userIds: [me.userId],
    });
    expect(targets.length).toBeGreaterThan(0);
    const devices = targets.flatMap(
      (x: { devices: { apnsToken?: string }[] }) => x.devices,
    );
    expect(devices.some((d) => d.apnsToken === "apns-abc")).toBe(true);
  });

  test("a VoIP token lands too — this is what makes a phone ring", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    await t.mutation(api.voipTokens.setVoipToken, {
      sessionToken: me.token,
      userId: me.userId,
      deviceId: DEVICE,
      platform: "ios",
      token: "voip-abc",
    });

    const rows = await t.run(async (ctx) =>
      ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", me.userId))
        .collect(),
    );
    expect(rows.length).toBe(1);
    expect(rows[0].voipToken).toBe("voip-abc");
  });
});

describe("per-call overhead", () => {
  /**
   * Every authed call now resolves a session: one SHA-256 plus one indexed
   * read. Messages are the hot path and "blazing fast" is the standing rule,
   * so the cost is measured rather than assumed.
   */
  test("resolving a session is not the thing making sends slow", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    // Warm.
    await t.query(api.voipTokens.listDevices, {
      sessionToken: me.token,
      userId: me.userId,
      deviceId: DEVICE,
    });

    const N = 50;
    const started = performance.now();
    for (let i = 0; i < N; i++) {
      await t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      });
    }
    const perCall = (performance.now() - started) / N;
    // eslint-disable-next-line no-console
    console.log(`  session-resolved call: ${perCall.toFixed(2)}ms each`);
    expect(perCall).toBeLessThan(50);
  });
});

describe("the sessions table stays bounded", () => {
  test("the sweep takes revoked rows and leaves live ones alone", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    // One revoked session, aged past retention, and one live one.
    await t.run(async (ctx) => {
      const rows = await ctx.db.query("sessions").collect();
      expect(rows.length).toBe(1);
      await ctx.db.insert("sessions", {
        userId: me.userId,
        tokenHash: "deadbeef",
        deviceId: "old-device",
        createdAt: 0,
        lastSeenAt: 0,
        revokedAt: Date.now() - 30 * 24 * 60 * 60 * 1000,
      });
    });

    await t.mutation(internal.sessionCore.gcRevokedSessions, {});

    const left = await t.run(async (ctx) => ctx.db.query("sessions").collect());
    expect(left.length).toBe(1);
    expect(left[0].revokedAt).toBeUndefined();

    // The surviving session still works — the sweep did not sign anyone out.
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).resolves.toBeDefined();
  });

  test("a recently revoked session is KEPT, so the user is told the truth", async () => {
    // Deleting it immediately would turn "you were signed out" into
    // SESSION_UNKNOWN, which is the shape a bug takes.
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    await t.mutation(api.auth.logout, { sessionToken: me.token, deviceId: DEVICE });

    await t.mutation(internal.sessionCore.gcRevokedSessions, {});

    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });
});
