import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { TAKEN_PUSH_GRACE_MS } from "./calls";
import schema from "./schema";

// Native `taken` pushes are scheduled TAKEN_PUSH_GRACE_MS out (see calls.ts),
// and convex-test runs scheduled work on real timers — so every drain below
// advances a fake clock instead of waiting three real seconds per test.
beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

// Runs every scheduled function, including the grace-delayed ones.
async function drain(t: ReturnType<typeof convexTest>) {
  await t.finishAllScheduledFunctions(vi.runAllTimers);
}

/**
 * The ghost-ring guard. A call's invite VoIP push (`voipPush.sendVoip`, its
 * 2s retry, and the alert-banner rescue) is scheduled `runAfter(0)` at
 * initiate with every field precomputed, so it can execute AFTER a fast
 * cancel/accept/reject has already ended the call — ringing a phone for a
 * call that is already over. The fix is a single status re-check the whole
 * ring pipeline shares: `calls.callStatusInternal`. These tests pin that
 * query (the load-bearing surface) and prove the guarded flow runs its
 * scheduled push work without resurrecting or erroring on a terminal call.
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

async function makeRoom(
  t: ReturnType<typeof convexTest>,
  owner: { token: string; userId: string },
) {
  return await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    name: "room",
    isPrivate: false,
  });
}

async function join(
  t: ReturnType<typeof convexTest>,
  who: { token: string; userId: string },
  roomId: any,
) {
  await t.mutation(api.rooms.join, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
  });
}

describe("ring-path guard (callStatusInternal)", () => {
  test("tracks ringing → cancelled, and the scheduled push runs without resurrecting the call", async () => {
    const t = convexTest(schema);
    const caller = await signUp(t, "caller");
    const callee = await signUp(t, "callee");
    const roomId = await makeRoom(t, caller);
    await join(t, callee, roomId);

    const callId = await t.mutation(api.calls.initiate, {
      sessionToken: caller.token,
      callerId: caller.userId as any,
      calleeId: callee.userId as any,
      roomId,
      type: "audio",
    });

    // Fresh call is ringing — the ring pipeline is allowed to fire.
    expect(
      await t.query(internal.calls.callStatusInternal, { callId }),
    ).toBe("ringing");

    // Caller hangs up before the callee answers, BEFORE the scheduled invite
    // push has run.
    await t.mutation(api.calls.cancel, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
    });
    expect(
      await t.query(internal.calls.callStatusInternal, { callId }),
    ).toBe("cancelled");

    // Now drain the scheduled work (the invite `sendVoip`, the `taken`
    // dismissal from cancel, etc.). `sendVoip` must see the terminal status
    // and return before ringing anything — the whole point of the guard. The
    // flow completes cleanly and nothing flips the row back to ringing.
    await drain(t);
    expect(
      await t.query(internal.calls.callStatusInternal, { callId }),
    ).toBe("cancelled");
  });

  test("is null once the call row is gone (GC'd)", async () => {
    const t = convexTest(schema);
    const caller = await signUp(t, "caller");
    const callee = await signUp(t, "callee");
    const roomId = await makeRoom(t, caller);
    await join(t, callee, roomId);

    const callId = await t.mutation(api.calls.initiate, {
      sessionToken: caller.token,
      callerId: caller.userId as any,
      calleeId: callee.userId as any,
      roomId,
      type: "audio",
    });

    await t.run(async (ctx) => {
      await ctx.db.delete(callId as any);
    });

    expect(
      await t.query(internal.calls.callStatusInternal, { callId }),
    ).toBeNull();
  });
});

/**
 * The hangup-path phantom ring. `endCallImpl` chases the realtime `bye` with a
 * `taken` push so a native card in a KILLED process still gets dismissed. On
 * iOS that push is PushKit, and PushKit's contract makes AppDelegate report a
 * placeholder incoming call for every push it cannot match to a live card —
 * which current iOS renders as a one-second "Call" that rings and vanishes.
 * Every remote hangup used to flash one on the peer's iPhone, because the
 * peer's app is alive (mid-WebRTC), had already dismissed its card on `bye`,
 * or never had an invite card at all (it placed the call). The fix keeps
 * PushKit only where a killed process can hold a card: the CALLEE of a call
 * that was still RINGING. These tests pin the `iosVoip` flag each terminal
 * path schedules `voipPush.sendVoipTaken` with.
 */

type TakenJob = {
  targetUserId: string;
  reason: string;
  excludeDeviceId: string | null;
  iosVoip?: boolean;
  // How far out it was scheduled — every `taken` waits the grace.
  delayMs: number;
};

// Every `sendVoipTaken` the flow scheduled, in scheduling order, by its args.
async function takenJobs(
  t: ReturnType<typeof convexTest>,
): Promise<TakenJob[]> {
  return await t.run(async (ctx) => {
    const rows = await ctx.db.system.query("_scheduled_functions").collect();
    return rows
      .filter((r) => r.name.includes("sendVoipTaken"))
      .map((r) => ({
        ...(r.args[0] as Omit<TakenJob, "delayMs">),
        delayMs: r.scheduledTime - r._creationTime,
      }));
  });
}

async function ringingCall(t: ReturnType<typeof convexTest>) {
  const caller = await signUp(t, "caller");
  const callee = await signUp(t, "callee");
  const roomId = await makeRoom(t, caller);
  await join(t, callee, roomId);
  const callId = await t.mutation(api.calls.initiate, {
    sessionToken: caller.token,
    callerId: caller.userId as any,
    calleeId: callee.userId as any,
    roomId,
    type: "audio",
  });
  return { caller, callee, callId };
}

async function activeCall(t: ReturnType<typeof convexTest>) {
  const c = await ringingCall(t);
  expect(
    await t.mutation(api.calls.accept, {
      sessionToken: c.callee.token,
      callId: c.callId,
      userId: c.callee.userId as any,
      acceptingDeviceId: "phone-b",
    }),
  ).toBe("accepted");
  return c;
}

describe("hangup `taken` push keeps PushKit only for a ringing callee", () => {
  test("accept still fans a full PushKit dismissal to the callee's other devices", async () => {
    const t = convexTest(schema);
    const { callee } = await activeCall(t);
    const [accepted] = await takenJobs(t);
    expect(accepted).toMatchObject({
      targetUserId: callee.userId,
      reason: "accepted",
      excludeDeviceId: "phone-b",
    });
    // Absent = true: the sibling that rang from the invite push may be a
    // killed process, which only PushKit can reach.
    expect(accepted.iosVoip).toBeUndefined();
    await drain(t);
  });

  test("callee ends an active call → caller gets bye, no PushKit", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    expect(
      await t.mutation(api.calls.end, {
        sessionToken: callee.token,
        callId,
        userId: callee.userId as any,
      }),
    ).toBe("ended");
    const ended = (await takenJobs(t)).find((j) => j.reason === "ended");
    expect(ended).toMatchObject({
      targetUserId: caller.userId,
      excludeDeviceId: null,
      iosVoip: false,
    });
    await drain(t);
    expect(
      await t.query(internal.calls.callStatusInternal, { callId }),
    ).toBe("ended");
  });

  test("caller ends an active call → callee gets bye, no PushKit", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    expect(
      await t.mutation(api.calls.end, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      }),
    ).toBe("ended");
    const ended = (await takenJobs(t)).find((j) => j.reason === "ended");
    expect(ended).toMatchObject({
      targetUserId: callee.userId,
      iosVoip: false,
    });
    await drain(t);
  });

  test("a cancel that lost the race to an accept converts to an end without PushKit", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    expect(
      await t.mutation(api.calls.cancel, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      }),
    ).toBe("ended");
    const ended = (await takenJobs(t)).find((j) => j.reason === "ended");
    expect(ended).toMatchObject({
      targetUserId: callee.userId,
      iosVoip: false,
    });
    await drain(t);
  });

  test("caller ends while still ringing → callee's ringer may be in a killed process: PushKit stays", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    expect(
      await t.mutation(api.calls.end, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      }),
    ).toBe("ended");
    const ended = (await takenJobs(t)).find((j) => j.reason === "ended");
    expect(ended).toMatchObject({
      targetUserId: callee.userId,
      iosVoip: true,
    });
    await drain(t);
  });

  test("callee ends while ringing → the caller only has an outbound card: no PushKit", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    expect(
      await t.mutation(api.calls.end, {
        sessionToken: callee.token,
        callId,
        userId: callee.userId as any,
      }),
    ).toBe("ended");
    const ended = (await takenJobs(t)).find((j) => j.reason === "ended");
    expect(ended).toMatchObject({
      targetUserId: caller.userId,
      iosVoip: false,
    });
    await drain(t);
  });

  test("a second end is already-terminal and schedules nothing more", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    await t.mutation(api.calls.end, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
    });
    const before = (await takenJobs(t)).length;
    expect(
      await t.mutation(api.calls.end, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      }),
    ).toBe("already-terminal");
    expect((await takenJobs(t)).length).toBe(before);
    await drain(t);
  });
});

/**
 * The dismissal ack. A LIVE app ends its own native card from the realtime
 * terminal signal long before the grace-delayed `taken` push goes out; on iOS
 * that push would then find nothing to end and flash the phantom. So the
 * client acks (`ackNativeDismissed`), and `sendVoipTaken` skips acked devices
 * — pinned here through the query it reads. A KILLED process never acks and
 * still gets the push, which is the whole reason the push exists.
 */
describe("native-card dismissal ack", () => {
  test("every `taken` push waits the grace so acks can land first", async () => {
    const t = convexTest(schema);
    const { caller, callId } = await activeCall(t);
    await t.mutation(api.calls.end, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
    });
    const jobs = await takenJobs(t);
    expect(jobs.length).toBeGreaterThan(0);
    // `_creationTime` carries sub-millisecond fraction; round it away.
    for (const j of jobs) expect(Math.round(j.delayMs)).toBe(TAKEN_PUSH_GRACE_MS);
    await drain(t);
  });

  test("records each device once, and the push reads exactly those", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    expect(
      await t.query(internal.calls.dismissedDevicesInternal, { callId }),
    ).toEqual([]);

    await t.mutation(api.calls.ackNativeDismissed, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
      deviceId: "phone-b",
    });
    // Idempotent: the sibling-`taken` and the teardown may both ack.
    await t.mutation(api.calls.ackNativeDismissed, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
      deviceId: "phone-b",
    });
    await t.mutation(api.calls.ackNativeDismissed, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
      deviceId: "phone-a",
    });
    expect(
      await t.query(internal.calls.dismissedDevicesInternal, { callId }),
    ).toEqual(["phone-b", "phone-a"]);
    await drain(t);
  });

  test("only a participant may ack", async () => {
    const t = convexTest(schema);
    const { callId } = await activeCall(t);
    const stranger = await signUp(t, "stranger");
    await expect(
      t.mutation(api.calls.ackNativeDismissed, {
        sessionToken: stranger.token,
        callId,
        userId: stranger.userId as any,
        deviceId: "phone-x",
      }),
    ).rejects.toThrow("NOT_A_PARTICIPANT");
    await drain(t);
  });

  test("an ack for a GC'd call is a no-op, and the push reads nothing", async () => {
    const t = convexTest(schema);
    const { callee, callId } = await activeCall(t);
    await drain(t);
    await t.run(async (ctx) => {
      await ctx.db.delete(callId as any);
    });
    await t.mutation(api.calls.ackNativeDismissed, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
      deviceId: "phone-b",
    });
    expect(
      await t.query(internal.calls.dismissedDevicesInternal, { callId }),
    ).toEqual([]);
  });

  test("a hangup's `taken` push runs to completion against acked devices", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    await t.mutation(api.calls.end, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
    });
    // The caller's live app dismissed its outbound card from `bye` and acks
    // inside the grace; the push then has nobody left and exits cleanly.
    await t.mutation(api.calls.ackNativeDismissed, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
      deviceId: DEVICE,
    });
    await drain(t);
    expect(
      await t.query(internal.calls.callStatusInternal, { callId }),
    ).toBe("ended");
  });
});
