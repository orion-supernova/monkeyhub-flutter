import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { buildApnsBody, buildFcmMessage, buildWebPushPayload } from "./push";
import { ENGAGED_MS } from "./engagement";

/**
 * While you are chatting on one device, the others stay quiet.
 *
 * Reported as "I'm on my phone and the Mac and the Linux box go crazy": every
 * device notified for every line of a conversation already on the screen in
 * the person's hand. The rule is held here at its two ends: which device the
 * server believes is in use, and what a push to every other device looks like.
 */

const PHONE = "device-phone";
const MAC = "device-mac";

type Session = { token: string; userId: string };

async function signUp(t: ReturnType<typeof convexTest>, deviceId: string) {
  return (await t.mutation(api.auth.signup, {
    username: "zeynep",
    name: "zeynep",
    passwordHash: "hash-zeynep",
    recoveryKeyHash: "recovery-zeynep",
    deviceId,
  })) as Session;
}

async function login(t: ReturnType<typeof convexTest>, deviceId: string) {
  return (await t.mutation(api.auth.login as any, {
    username: "zeynep",
    passwordHash: "hash-zeynep",
    deviceId,
  })) as Session;
}

async function registerApns(
  t: ReturnType<typeof convexTest>,
  s: Session,
  deviceId: string,
  platform: string,
) {
  await t.mutation(api.voipTokens.setApnsToken, {
    sessionToken: s.token,
    userId: s.userId as any,
    deviceId,
    platform,
    token: `apns-${deviceId}`,
  });
}

async function setStatus(
  t: ReturnType<typeof convexTest>,
  s: Session,
  status: "online" | "away",
) {
  await t.mutation(api.presenceApi.setStatus, {
    sessionToken: s.token,
    status,
  } as any);
}

async function engagedOf(t: ReturnType<typeof convexTest>, userId: string) {
  const [target] = await t.query(internal.push._loadAlertTargets, {
    userIds: [userId as any],
    withEngagement: true,
  });
  return target.engagedDeviceId;
}

async function elsewhere(t: ReturnType<typeof convexTest>, s: Session) {
  return await t.query(api.engagement.engagedElsewhere, {
    sessionToken: s.token,
  } as any);
}

describe("which device is in use", () => {
  beforeEach(() => vi.useFakeTimers({ now: 1_800_000_000_000 }));
  afterEach(() => vi.useRealTimers());

  test("coming to the front claims it; going to the back gives it up", async () => {
    const t = convexTest(schema);
    const phone = await signUp(t, PHONE);
    const mac = await login(t, MAC);
    await registerApns(t, phone, PHONE, "ios");
    await registerApns(t, mac, MAC, "macos");

    expect(await engagedOf(t, phone.userId)).toBeNull();

    await setStatus(t, phone, "online");
    expect(await engagedOf(t, phone.userId)).toBe(PHONE);
    expect(await elsewhere(t, mac)).toBe(true);
    expect(await elsewhere(t, phone)).toBe(false);

    // Newest evidence wins: picking up the Mac moves it, even though the
    // person was already "online".
    await setStatus(t, mac, "online");
    expect(await engagedOf(t, phone.userId)).toBe(MAC);

    // The PHONE locking must not un-quiet anything: the Mac is in use.
    await setStatus(t, phone, "away");
    expect(await engagedOf(t, phone.userId)).toBe(MAC);

    await setStatus(t, mac, "away");
    expect(await engagedOf(t, phone.userId)).toBeNull();
    expect(await elsewhere(t, phone)).toBe(false);
  });

  test("a window left open stops counting", async () => {
    const t = convexTest(schema);
    const phone = await signUp(t, PHONE);
    await login(t, MAC);
    await registerApns(t, phone, PHONE, "ios");

    await setStatus(t, phone, "online");
    vi.advanceTimersByTime(ENGAGED_MS - 1);
    expect(await engagedOf(t, phone.userId)).toBe(PHONE);
    vi.advanceTimersByTime(1);
    expect(await engagedOf(t, phone.userId)).toBeNull();
  });

  test("not resolved unless asked for (rings, approvals)", async () => {
    const t = convexTest(schema);
    const phone = await signUp(t, PHONE);
    await registerApns(t, phone, PHONE, "ios");
    await setStatus(t, phone, "online");
    const [target] = await t.query(internal.push._loadAlertTargets, {
      userIds: [phone.userId as any],
    });
    expect(target.engagedDeviceId).toBeNull();
  });
});

describe("a quiet push", () => {
  const spec = {
    kind: "message" as const,
    title: "murat",
    body: "hi",
    data: { kind: "message", roomId: "r1" },
    badge: 3,
    threadId: "r1",
    quiet: true,
  };

  test("iOS/macOS: delivered passive, with no sound and the badge kept", () => {
    const body = buildApnsBody(spec) as any;
    expect(body.aps.sound).toBeUndefined();
    expect(body.aps["interruption-level"]).toBe("passive");
    expect(body.aps.alert.body).toBe("hi");
    expect(body.aps.badge).toBe(3);
    expect(body.quiet).toBe("true");
  });

  test("an ordinary push is unchanged", () => {
    const body = buildApnsBody({ ...spec, quiet: undefined }) as any;
    expect(body.aps.sound).toBe("default");
    expect(body.aps["interruption-level"]).toBeUndefined();
    expect(body.quiet).toBeUndefined();
  });

  test("Android and web carry the flag for the device to honour", () => {
    expect((buildFcmMessage(spec, "tok") as any).data.quiet).toBe("true");
    expect(buildWebPushPayload(spec).quiet).toBe("true");
    expect(
      (buildFcmMessage({ ...spec, quiet: undefined }, "tok") as any).data.quiet,
    ).toBeUndefined();
  });
});
