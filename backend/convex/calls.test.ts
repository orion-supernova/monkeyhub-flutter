import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

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
    await t.finishInProgressScheduledFunctions();
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
