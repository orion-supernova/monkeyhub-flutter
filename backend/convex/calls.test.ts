import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { TAKEN_PUSH_GRACE_MS } from "./calls";
import schema from "./schema";
import type { Doc } from "./_generated/dataModel";

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
      // The immediate FCM-only twin (`scheduleTakenPush`) has its own test;
      // everything that reads this is about the graced push.
      .filter((r) => (r.args[0] as any)?.fcmOnly !== true)
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

/**
 * The terminal-transition / signaling write conflict. `purgeCallSignals`
 * reads the whole `by_call` range, so run inline inside `end` it conflicted
 * with every concurrent `sendSignal` insert for the call — ICE trickles for
 * the life of a video call, and on 2026-08-31 a hangup lost OCC four times
 * and then failed outright. The purge is now its own scheduled transaction:
 * `end` itself leaves the range alone (the stale rows are still there when
 * it returns) and the sweep, once it runs, removes everything but the bye.
 */
describe("signal purge is deferred out of the terminal transition", () => {
  async function signalRows(
    t: ReturnType<typeof convexTest>,
    callId: any,
  ): Promise<any[]> {
    return await t.run(async (ctx) =>
      (ctx.db as any)
        .query("callSignals")
        .withIndex("by_call", (q: any) => q.eq("callId", callId))
        .collect(),
    );
  }

  test("end keeps the range untouched; the scheduled sweep leaves only the bye", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await activeCall(t);
    // Drain the accept/ring pipeline first so the only scheduled work left
    // after `end` is the purge itself. The rows the setup itself left behind
    // (invite, offer, …) are the baseline — the sweep must take those too.
    await drain(t);
    const base = (await signalRows(t, callId)).length;

    // A trickle of ICE from both sides, as during any live call.
    for (let i = 0; i < 3; i++) {
      await t.mutation(api.calls.sendSignal, {
        sessionToken: caller.token,
        callId,
        fromUserId: caller.userId as any,
        toUserId: callee.userId as any,
        kind: "ice",
        payload: `{"i":${i}}`,
      });
      await t.mutation(api.calls.sendSignal, {
        sessionToken: callee.token,
        callId,
        fromUserId: callee.userId as any,
        toUserId: caller.userId as any,
        kind: "ice",
        payload: `{"i":${i}}`,
      });
    }
    expect((await signalRows(t, callId)).length).toBe(base + 6);

    expect(
      await t.mutation(api.calls.end, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      }),
    ).toBe("ended");
    // The transition wrote the row and its bye — and read none of the ICE.
    const afterEnd = await signalRows(t, callId);
    expect(afterEnd.length).toBe(base + 7);
    expect(afterEnd.filter((r) => r.kind === "bye").length).toBe(1);

    // A late candidate from the other side now drops on the terminal status
    // instead of racing the sweep.
    await t.mutation(api.calls.sendSignal, {
      sessionToken: callee.token,
      callId,
      fromUserId: callee.userId as any,
      toUserId: caller.userId as any,
      kind: "ice",
      payload: '{"late":true}',
    });
    expect((await signalRows(t, callId)).length).toBe(base + 7);

    await drain(t);
    const swept = await signalRows(t, callId);
    expect(swept.map((r) => r.kind)).toEqual(["bye"]);
    expect(swept[0].toUserId).toBe(callee.userId);
  });
});

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

  test("…and each one's Android leg goes at once, FCM only", async () => {
    const t = convexTest(schema);
    const { caller, callId } = await activeCall(t);
    await t.mutation(api.calls.end, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
    });
    const rows = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).filter(
        (r) => r.name.includes("sendVoipTaken"),
      ),
    );
    const now = rows.filter((r) => (r.args[0] as any).fcmOnly === true);
    const graced = rows.filter((r) => (r.args[0] as any).fcmOnly !== true);
    expect(now.length).toBe(graced.length);
    expect(now.length).toBeGreaterThan(0);
    for (const r of now) {
      expect(Math.abs(Math.round(r.scheduledTime - r._creationTime))).toBe(0);
    }
    const { fcmOnly, ...rest } = now[0].args[0] as any;
    expect(rest).toEqual(graced[0].args[0]);
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

describe("callee ringing report (markRinging)", () => {
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

  async function ringingSignals(t: ReturnType<typeof convexTest>, callId: any) {
    return await t.run(async (ctx) =>
      (await ctx.db.query("callSignals").collect()).filter(
        (s) => s.callId === callId && s.kind === "ringing",
      ),
    );
  }

  test("the first report stamps the call and tells the caller once", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    for (let i = 0; i < 2; i++) {
      await t.mutation(api.calls.markRinging, {
        sessionToken: callee.token,
        callId,
        userId: callee.userId as any,
      });
    }
    await t.mutation(internal.calls.markRingingInternal, {
      callId,
      userId: callee.userId as any,
    });
    const signals = await ringingSignals(t, callId);
    expect(signals).toHaveLength(1);
    expect(signals[0].toUserId).toBe(caller.userId);
    const row: any = await t.run(async (ctx) => await ctx.db.get(callId));
    expect(row?.ringingAt).toBeTypeOf("number");
    await drain(t);
  });

  test("only the callee can say their phone is ringing", async () => {
    const t = convexTest(schema);
    const { caller, callId } = await ringingCall(t);
    await expect(
      t.mutation(api.calls.markRinging, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      }),
    ).rejects.toThrow("NOT_THE_CALLEE");
    await drain(t);
  });

  test("a report for a cancelled call says nothing", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    await t.mutation(api.calls.cancel, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
    });
    await t.mutation(internal.calls.markRingingInternal, {
      callId,
      userId: callee.userId as any,
    });
    expect(await ringingSignals(t, callId)).toHaveLength(0);
    await drain(t);
  });
});

/**
 * The ring report answers with the call's status, and that answer is what an
 * iPhone uses to take down a card raised for a call that is already over:
 * an invite VoIP push APNs delivered AFTER the cancel, on a phone whose app
 * had already acked "no card" (so no `taken` push was ever coming), rang
 * until the plugin's own 30s timeout. `probe: true` is the native ring
 * watch's read-only re-ask.
 */
describe("ring report tells the phone the call's status", () => {
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

  test("markRingingInternal returns the status, and null for anyone but the callee", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    expect(
      await t.mutation(internal.calls.markRingingInternal, {
        callId,
        userId: callee.userId as any,
      }),
    ).toBe("ringing");
    expect(
      await t.mutation(internal.calls.markRingingInternal, {
        callId,
        userId: caller.userId as any,
      }),
    ).toBeNull();
    await t.mutation(api.calls.cancel, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
    });
    expect(
      await t.mutation(internal.calls.markRingingInternal, {
        callId,
        userId: callee.userId as any,
      }),
    ).toBe("cancelled");
    expect(
      await t.query(internal.calls.ringStatusInternal, {
        callId,
        userId: callee.userId as any,
      }),
    ).toBe("cancelled");
    expect(
      await t.query(internal.calls.ringStatusInternal, {
        callId,
        userId: caller.userId as any,
      }),
    ).toBeNull();
    await drain(t);
  });

  test("the endpoint answers {status}; a probe reads without reporting a ring", async () => {
    vi.stubEnv("RECEIPT_SECRET", "test-secret");
    vi.stubEnv("RECEIPT_URL", "");
    vi.stubEnv("CONVEX_CLOUD_URL", "https://api.example.com");
    try {
      const t = convexTest(schema);
      const { caller, callee, callId } = await ringingCall(t);
      const { ringFields } = await import("./receiptToken");
      const fields = (await ringFields(callId, callee.userId))!;
      const post = (body: Record<string, unknown>) =>
        t.fetch("/calls/ringing", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });
      const ringingRows = async () =>
        await t.run(async (ctx) =>
          (await ctx.db.query("callSignals").collect()).filter(
            (s) => s.callId === callId && s.kind === "ringing",
          ),
        );

      // A probe while ringing: the status, and no ring reported.
      const probe = await post({
        callId,
        userId: callee.userId,
        sig: fields.ringSig,
        probe: true,
      });
      expect(probe.status).toBe(200);
      expect(await probe.json()).toEqual({ status: "ringing" });
      expect(await ringingRows()).toHaveLength(0);

      // The real report: rings the caller AND says the call still rings.
      const report = await post({
        callId,
        userId: callee.userId,
        sig: fields.ringSig,
      });
      expect(await report.json()).toEqual({ status: "ringing" });
      expect(await ringingRows()).toHaveLength(1);

      await t.mutation(api.calls.cancel, {
        sessionToken: caller.token,
        callId,
        userId: caller.userId as any,
      });
      // The late invite's report: the phone learns the call is over.
      const late = await post({
        callId,
        userId: callee.userId,
        sig: fields.ringSig,
      });
      expect(await late.json()).toEqual({ status: "cancelled" });

      // A forged proof still learns nothing.
      const forged = await post({
        callId,
        userId: caller.userId,
        sig: fields.ringSig,
        probe: true,
      });
      expect(forged.status).toBe(403);

      // A GC'd row reads as gone.
      await t.run(async (ctx) => await ctx.db.delete(callId));
      const gone = await post({
        callId,
        userId: callee.userId,
        sig: fields.ringSig,
        probe: true,
      });
      expect(await gone.json()).toEqual({ status: "gone" });
      await drain(t);
    } finally {
      vi.unstubAllEnvs();
    }
  });
});

/**
 * Signals are consumed per USER, but every callee device rings. On
 * 2026-10-11 the iPhone drained the invite and the cancel first and a Mac
 * and a Galaxy never saw either. While the call rings, untargeted rows to
 * the callee stay visible to all of their devices; `accept` retires them.
 */
describe("ring-phase signals reach every callee device", () => {
  async function unconsumedFor(
    t: ReturnType<typeof convexTest>,
    user: { token: string; userId: string },
  ): Promise<any[]> {
    return await t.query(api.calls.signalsForUser, {
      sessionToken: user.token,
      userId: user.userId as any,
    });
  }

  async function consumeAll(
    t: ReturnType<typeof convexTest>,
    user: { token: string; userId: string },
    deviceId?: string,
  ) {
    const rows = await unconsumedFor(t, user);
    await t.mutation(api.calls.consumeSignals, {
      sessionToken: user.token,
      signalIds: rows.map((r) => r._id),
      userId: user.userId as any,
      deviceId,
    });
  }

  async function signal(
    t: ReturnType<typeof convexTest>,
    from: { token: string; userId: string },
    to: { userId: string },
    callId: any,
    kind: string,
    fromDeviceId?: string,
  ) {
    await t.mutation(api.calls.sendSignal, {
      sessionToken: from.token,
      callId,
      fromUserId: from.userId as any,
      toUserId: to.userId as any,
      kind,
      payload: "{}",
      fromDeviceId,
    });
  }

  test("one device consuming a ringing call's rows leaves them for its siblings", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    await t.mutation(api.calls.sendSignal, {
      sessionToken: caller.token,
      callId,
      fromUserId: caller.userId as any,
      toUserId: callee.userId as any,
      kind: "offer",
      payload: "{}",
    });
    const before = (await unconsumedFor(t, callee)).map((r) => r.kind);
    expect(before).toEqual(expect.arrayContaining(["invite", "offer"]));

    await consumeAll(t, callee);
    expect((await unconsumedFor(t, callee)).map((r) => r.kind)).toEqual(
      before,
    );
    await drain(t);
  });

  test("accept retires the ring-phase rows but keeps `taken` and later traffic", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    await signal(t, caller, callee, callId, "offer");
    await consumeAll(t, callee);
    await t.mutation(api.calls.accept, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
    });
    vi.advanceTimersByTime(1);
    await signal(t, caller, callee, callId, "ice");
    await drain(t);
    expect(
      (await unconsumedFor(t, callee)).map((r) => r.kind).sort(),
    ).toEqual(["ice", "taken"]);

    // A live call's rows consume normally again.
    await consumeAll(t, callee);
    expect(await unconsumedFor(t, callee)).toEqual([]);
  });

  test("accept from a named device hands it the ring-phase rows instead of consuming them", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    await signal(t, caller, callee, callId, "offer");
    await t.mutation(api.calls.accept, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
      acceptingDeviceId: "mac-b",
    });
    await drain(t);
    const rows = await unconsumedFor(t, callee);
    const ring = rows.filter((r) => r.kind !== "taken");
    expect(ring.map((r) => r.kind).sort()).toEqual(["invite", "offer"]);
    expect(ring.every((r) => r.targetDeviceId === "mac-b")).toBe(true);

    // The sibling that rang alongside it can no longer take them…
    await consumeAll(t, callee, "phone-b");
    expect((await unconsumedFor(t, callee)).map((r) => r.kind).sort()).toEqual(
      ["invite", "offer", "taken"],
    );
    // …the answering device can. `taken` stays for the siblings.
    await consumeAll(t, callee, "mac-b");
    expect((await unconsumedFor(t, callee)).map((r) => r.kind)).toEqual([
      "taken",
    ]);
  });

  test("a live call's traffic is consumed only by the device holding each side", async () => {
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
      type: "video",
      callerDeviceId: "phone-a",
    });
    await t.mutation(api.calls.accept, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
      acceptingDeviceId: "mac-b",
    });
    await drain(t);
    await consumeAll(t, callee, "mac-b");
    vi.advanceTimersByTime(1);

    // The callee's ICE after the answer; the callee's iPhone (woken by the
    // VoIP push, never answered) drains first and must leave it.
    await signal(t, caller, callee, callId, "ice-batch", "phone-a");
    await consumeAll(t, callee, "phone-b");
    expect((await unconsumedFor(t, callee)).map((r) => r.kind).sort()).toEqual(
      ["ice-batch", "taken"],
    );
    await consumeAll(t, callee, "mac-b");
    expect((await unconsumedFor(t, callee)).map((r) => r.kind)).toEqual([
      "taken",
    ]);

    // The answer to the caller; the caller's idle Mac must leave it.
    await signal(t, callee, caller, callId, "answer", "mac-b");
    await consumeAll(t, caller, "mac-a");
    expect((await unconsumedFor(t, caller)).map((r) => r.kind)).toEqual([
      "answer",
    ]);
    await consumeAll(t, caller, "phone-a");
    expect(await unconsumedFor(t, caller)).toEqual([]);

    // A client that names no device keeps the old per-user consume.
    await signal(t, caller, callee, callId, "ice-batch", "phone-a");
    await consumeAll(t, callee);
    expect(await unconsumedFor(t, callee)).toEqual([]);

    // The end purges what was held.
    await t.mutation(api.calls.end, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
    });
    await drain(t);
    expect(
      (await unconsumedFor(t, callee)).filter((r) => r.kind !== "bye"),
    ).toEqual([]);
  });

  test("an older caller's device is learned from its first signal", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    await signal(t, caller, callee, callId, "offer", "phone-a");
    await signal(t, caller, callee, callId, "ice", "phone-z");
    const row = (await t.run(async (ctx) => await ctx.db.get(callId))) as Doc<"calls"> | null;
    expect(row?.callerDeviceId).toBe("phone-a");
    await drain(t);
  });

  test("a caller's handoff moves the caller's device, not the callee's", async () => {
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
      callerDeviceId: "phone-a",
    });
    await t.mutation(api.calls.accept, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
      acceptingDeviceId: "mac-b",
    });
    const res = await t.mutation(api.calls.handoffCall, {
      sessionToken: caller.token,
      callId,
      userId: caller.userId as any,
      newDeviceId: "mac-a",
    });
    expect(res).toEqual({ oldDeviceId: "phone-a" });
    const row = (await t.run(async (ctx) => await ctx.db.get(callId))) as Doc<"calls"> | null;
    expect(row?.callerDeviceId).toBe("mac-a");
    expect(row?.acceptingDeviceId).toBe("mac-b");
    const takeover = (await unconsumedFor(t, caller)).find(
      (r) => r.kind === "handoff-takeover",
    );
    expect(takeover?.targetDeviceId).toBe("phone-a");
    await drain(t);
  });

  test("rows to the caller consume normally while ringing", async () => {
    const t = convexTest(schema);
    const { caller, callee, callId } = await ringingCall(t);
    await t.mutation(api.calls.markRinging, {
      sessionToken: callee.token,
      callId,
      userId: callee.userId as any,
    });
    expect((await unconsumedFor(t, caller)).map((r) => r.kind)).toEqual([
      "ringing",
    ]);
    await consumeAll(t, caller);
    expect(await unconsumedFor(t, caller)).toEqual([]);
    await drain(t);
  });
});
