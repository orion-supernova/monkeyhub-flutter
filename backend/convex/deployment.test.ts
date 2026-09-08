import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { deploymentRole } from "./deployment";

/**
 * The standby must not reach a real phone.
 *
 * This is the whole content of the bug it was written for: two deployments
 * hold the same rows and the same push credentials, both run `crons.ts`, and
 * `users.lastNudgedDayKey` — the thing that makes the daily nudge once per
 * person per day — is a row, so neither box could see the other's claim.
 * Everyone got two lunchtime notifications a day.
 *
 * Four claims:
 *
 *   1. A deployment recognises itself from `CONVEX_CLOUD_URL`, which lives in
 *      the container's environment and therefore does NOT travel with a copy
 *      of the data directory the way `convex env` and every row does.
 *   2. A directory row naming the OTHER deployment is the only thing that
 *      silences a box. Nothing else may.
 *   3. An unidentified deployment (a test, `convex dev`, a box added later)
 *      sends. The failure direction is a duplicate, never a silence.
 *   4. `dailyNudge.run` returns without claiming anybody when it is the
 *      standby — the claim being skipped is what proves it stopped before it
 *      did any work, since a stamped day with no send is the one outcome that
 *      would cost somebody their nudge.
 */

/**
 * The three variables these tests move, restored by name rather than by
 * replacing `process.env` wholesale — the object is read-only under this
 * tsconfig, and the isolate is shared with every other test file.
 */
const TOUCHED = [
  "CONVEX_CLOUD_URL",
  "DEPLOYMENT_ROLE",
  "NUDGE_FALLBACK_TZ_OFFSET",
] as const;
const ORIGINAL = new Map(TOUCHED.map((k) => [k, process.env[k]]));

afterEach(() => {
  vi.useRealTimers();
  for (const k of TOUCHED) {
    const v = ORIGINAL.get(k);
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
});

/** Pretend to be one of the two boxes, the way its compose file does. */
function runningOn(role: "primary" | "homeserver") {
  delete process.env.DEPLOYMENT_ROLE;
  process.env.CONVEX_CLOUD_URL =
    role === "primary"
      ? "https://termio-api.walhallaa.com"
      : "https://monkeyhub-homeserver-api.walhallaa.com";
}

async function serveFrom(
  t: ReturnType<typeof convexTest>,
  serve: "primary" | "homeserver",
) {
  await t.run(async (ctx) => {
    await ctx.db.insert("serverDirectory", {
      key: "current",
      serve,
      updatedAt: Date.now(),
    });
  });
}

describe("which deployment am I", () => {
  test("recognises both boxes by their own origin", () => {
    runningOn("primary");
    expect(deploymentRole()).toBe("primary");
    runningOn("homeserver");
    expect(deploymentRole()).toBe("homeserver");
  });

  test("DEPLOYMENT_ROLE overrides the origin, for a third box", () => {
    runningOn("primary");
    process.env.DEPLOYMENT_ROLE = "homeserver";
    expect(deploymentRole()).toBe("homeserver");
  });

  test("an unknown or missing origin is 'no opinion', not a guess", () => {
    delete process.env.DEPLOYMENT_ROLE;
    process.env.CONVEX_CLOUD_URL = "https://fervent-lion-42.convex.cloud";
    expect(deploymentRole()).toBeNull();
    delete process.env.CONVEX_CLOUD_URL;
    expect(deploymentRole()).toBeNull();
    process.env.CONVEX_CLOUD_URL = "not a url";
    expect(deploymentRole()).toBeNull();
  });
});

describe("may this deployment reach a device", () => {
  test("the box clients are on may send", async () => {
    const t = convexTest(schema);
    runningOn("homeserver");
    await serveFrom(t, "homeserver");
    const r = await t.query(internal.deployment.outboundAllowed, {});
    expect(r).toMatchObject({ allowed: true, role: "homeserver" });
  });

  test("the standby may not — this is the bug", async () => {
    const t = convexTest(schema);
    runningOn("primary");
    await serveFrom(t, "homeserver");
    const r = await t.query(internal.deployment.outboundAllowed, {});
    expect(r).toMatchObject({
      allowed: false,
      role: "primary",
      serve: "homeserver",
    });
  });

  test("no directory row cannot silence anybody", async () => {
    const t = convexTest(schema);
    runningOn("primary");
    const r = await t.query(internal.deployment.outboundAllowed, {});
    // Note the asymmetry: `serverDirectory:current` would answer "primary"
    // here off its SERVE_FROM default, and reading that default here would let
    // a lost row turn the notifications off for the whole user base.
    expect(r).toMatchObject({ allowed: true, serve: null });
  });

  test("an unidentified deployment sends", async () => {
    const t = convexTest(schema);
    delete process.env.DEPLOYMENT_ROLE;
    delete process.env.CONVEX_CLOUD_URL;
    await serveFrom(t, "homeserver");
    const r = await t.query(internal.deployment.outboundAllowed, {});
    expect(r).toMatchObject({ allowed: true, role: null });
  });
});

describe("the daily nudge on a standby", () => {
  /**
   * One account with one push-capable phone, signed in, in the fallback zone,
   * with nothing played today — the exact shape `run` is supposed to nudge.
   *
   * Built through `auth.signup` rather than by inserting rows, because the
   * audience query reads the SESSION as well as the device
   * (`liveSessionDeviceIds`): a hand-made `userDevices` row with no session
   * behind it is skipped for a reason that has nothing to do with what this
   * file is testing, and the test would then pass while proving nothing.
   */
  async function onePlayerDue(t: ReturnType<typeof convexTest>) {
    const { userId, token } = await t.mutation(api.auth.signup, {
      username: "player",
      name: "player",
      passwordHash: "hash-player",
      recoveryKeyHash: "recovery-player",
      deviceId: "phone-1",
    });
    await t.mutation(api.voipTokens.setApnsToken, {
      sessionToken: token,
      userId,
      deviceId: "phone-1",
      platform: "ios",
      token: "a".repeat(64),
      apnsEnv: "production",
      locale: "en",
      tzOffsetMinutes: 180,
    });
    return userId;
  }

  /**
   * Noon in the fixture's zone, so `dueOffsetsAt` actually has a bucket for it.
   * Without this the test would be green whenever it happened to run at the
   * wrong hour — for the wrong reason.
   */
  function atLocalNoon() {
    const noonUtc = new Date();
    noonUtc.setUTCHours(9, 0, 0, 0); // 12:00 at +03:00
    vi.setSystemTime(noonUtc);
  }

  test("claims nobody, so nobody loses their nudge tomorrow", async () => {
    const t = convexTest(schema);
    runningOn("primary");
    process.env.NUDGE_FALLBACK_TZ_OFFSET = "180";
    await serveFrom(t, "homeserver");
    const userId = await onePlayerDue(t);
    atLocalNoon();

    await t.action(internal.dailyNudge.run, {});

    // Not merely "sent nothing": the day is UNCLAIMED. A standby that claimed
    // and then declined to send would be the worse bug of the two, since the
    // stamp is per deployment and the person would still be nudged by the
    // primary — but only until the day somebody copies the data across.
    const user = await t.run(async (ctx) => await ctx.db.get(userId));
    expect((user as any)?.lastNudgedDayKey).toBeUndefined();
  });

  test("and the serving box, given the same fixture, does claim them", async () => {
    const t = convexTest(schema);
    runningOn("homeserver");
    process.env.NUDGE_FALLBACK_TZ_OFFSET = "180";
    await serveFrom(t, "homeserver");
    const userId = await onePlayerDue(t);
    atLocalNoon();

    await t.action(internal.dailyNudge.run, {});

    // The control. Without it the test above passes for any reason at all —
    // a fixture that was never nudgeable, a tick that was never due.
    const user = await t.run(async (ctx) => await ctx.db.get(userId));
    expect((user as any)?.lastNudgedDayKey).toBeDefined();
  });
});
