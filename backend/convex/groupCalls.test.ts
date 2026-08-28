import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

/**
 * A group call rings.
 *
 * It did not used to. `start` scheduled a banner and nothing else, so an
 * invitee whose app was backgrounded or killed got a notification in the shade
 * and no incoming-call UI at all — while a 1:1 call to the same phone raised
 * CallKit or a full-screen ConnectionService card. These tests pin the four
 * things that difference cost, all of which are scheduling decisions and so
 * are testable without a push transport:
 *
 *   - `start` schedules the RING, and the banner only as a rescue;
 *   - the ring is skipped for anyone who settled the invite first;
 *   - settling it later takes the card back down, sparing the device that
 *     settled it;
 *   - and an invite nobody answers stops ringing on its own.
 */

// Scheduled work runs on real timers under convex-test, and the ring expiry is
// a minute out — so every drain advances a fake clock instead of waiting.
beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

async function drain(t: ReturnType<typeof convexTest>) {
  await t.finishAllScheduledFunctions(vi.runAllTimers);
}

/** Every scheduled job whose name contains [needle], with its args and delay. */
async function jobs(t: ReturnType<typeof convexTest>, needle: string) {
  return await t.run(async (ctx) => {
    const rows = await ctx.db.system.query("_scheduled_functions").collect();
    return rows
      .filter((r) => r.name.includes(needle))
      .map((r) => ({
        args: r.args[0] as any,
        delayMs: r.scheduledTime - r._creationTime,
      }));
  });
}

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

/** A room with [starter] and two other members, none of them in a call yet. */
async function roomOfThree(t: ReturnType<typeof convexTest>) {
  const starter = await signUp(t, "starter");
  const alice = await signUp(t, "alice");
  const bob = await signUp(t, "bob");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: starter.token,
    userId: starter.userId as any,
    name: "design crew",
    isPrivate: false,
  });
  for (const who of [alice, bob]) {
    await t.mutation(api.rooms.join, {
      sessionToken: who.token,
      userId: who.userId as any,
      roomId,
    });
  }
  return { starter, alice, bob, roomId };
}

async function startCall(
  t: ReturnType<typeof convexTest>,
  starter: { token: string; userId: string },
  roomId: any,
) {
  const res: any = await t.mutation(api.groupCalls.start, {
    sessionToken: starter.token,
    userId: starter.userId as any,
    roomId,
    type: "audio",
    deviceId: "device-starter",
  });
  return res.groupCallId;
}

describe("a group invite rings before it announces", () => {
  test("start schedules the VoIP ring, not the banner", async () => {
    const t = convexTest(schema);
    const { starter, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    const ring = await jobs(t, "sendGroupVoip");
    expect(ring.length).toBe(1);
    expect(ring[0].args.groupCallId).toBe(groupCallId);
    // Both other members of the room, and never the starter.
    expect(ring[0].args.inviteeIds.length).toBe(2);
    expect(ring[0].args.roomName).toBe("design crew");

    // The banner is NOT scheduled up front any more. It is what
    // `sendGroupVoip` falls back to for whoever it could not reach, which is
    // the next test.
    expect(await jobs(t, "sendGroupInvitePush")).toEqual([]);
  });

  test("the banner is the rescue for whoever the ring could not reach", async () => {
    const t = convexTest(schema);
    const { starter, alice, bob, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    // Run the ring itself rather than draining everything, so what it
    // scheduled is still sitting there to be read.
    await t.action(internal.voipPush.sendGroupVoip, {
      groupCallId,
      roomId,
      inviteeIds: [alice.userId, bob.userId] as any,
      starterName: "starter",
      roomName: "design crew",
      type: "audio",
    });

    // No device here holds a VoIP or FCM credential — signup registers a
    // device row, never a push token — so the ring reaches nobody and every
    // invitee falls through to the banner they used to get instead of it.
    const banner = await jobs(t, "sendGroupInvitePush");
    expect(banner.length).toBe(1);
    expect([...banner[0].args.inviteeIds].sort()).toEqual(
      [alice.userId, bob.userId].sort(),
    );
  });

  test("nobody is rung for an invite they already settled", async () => {
    const t = convexTest(schema);
    const { starter, alice, bob, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    // Alice declines in the window between `start` scheduling the ring and
    // the ring actually running — the ghost-ring case, and the reason the
    // audience is re-read at send time rather than trusted from the payload.
    await t.mutation(api.groupCalls.decline, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      groupCallId,
      deviceId: "device-alice",
    });

    const pending = await t.query(internal.groupCalls._pendingInvitees, {
      groupCallId,
      userIds: [alice.userId, bob.userId] as any,
    });
    expect(pending).toEqual([bob.userId]);
  });

  test("an ended call rings nobody, whatever was scheduled for it", async () => {
    const t = convexTest(schema);
    const { starter, alice, bob, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    // The starter walks out before anyone answers — `endCallIfEmpty` ends the
    // call, because nobody is left joined.
    await t.mutation(api.groupCalls.leave, {
      sessionToken: starter.token,
      userId: starter.userId as any,
      groupCallId,
    });

    expect(
      await t.query(internal.groupCalls._pendingInvitees, {
        groupCallId,
        userIds: [alice.userId, bob.userId] as any,
      }),
    ).toEqual([]);
  });
});

describe("and stops ringing when it should", () => {
  test("declining clears this person's other phones, never the one that declined", async () => {
    const t = convexTest(schema);
    const { starter, alice, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    await t.mutation(api.groupCalls.decline, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      groupCallId,
      deviceId: "device-alice",
    });

    const taken = await jobs(t, "sendGroupVoipTaken");
    expect(taken.length).toBe(1);
    expect(taken[0].args).toMatchObject({
      groupCallId,
      reason: "declined",
      // The phone that pressed decline already took its own card down. A
      // dismissal that reaches it has nothing to end, which on iOS is a
      // one-second phantom ring rather than a no-op.
      excludeDeviceId: "device-alice",
    });
    expect(taken[0].args.targetUserIds).toEqual([alice.userId]);
  });

  test("joining clears the joiner's OTHER phones", async () => {
    const t = convexTest(schema);
    const { starter, alice, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    await t.mutation(api.groupCalls.join, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      groupCallId,
      deviceId: "phone-in-hand",
    });

    const taken = await jobs(t, "sendGroupVoipTaken");
    expect(taken.length).toBe(1);
    expect(taken[0].args).toMatchObject({
      groupCallId,
      reason: "joined",
      excludeDeviceId: "phone-in-hand",
    });
    expect(taken[0].args.targetUserIds).toEqual([alice.userId]);
  });

  test("a second join does not re-send the dismissal", async () => {
    const t = convexTest(schema);
    const { starter, alice, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    const joinOnce = async () =>
      await t.mutation(api.groupCalls.join, {
        sessionToken: alice.token,
        userId: alice.userId as any,
        groupCallId,
        deviceId: "phone-in-hand",
      });
    await joinOnce();
    // A rejoin (reconnect, screen re-entry) must not fire a fresh dismissal
    // at phones that have had none to dismiss since the first one.
    await joinOnce();

    expect((await jobs(t, "sendGroupVoipTaken")).length).toBe(1);
  });

  test("an unanswered invite stops ringing on its own", async () => {
    const t = convexTest(schema);
    const { starter, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    const expiry = await jobs(t, "_expireRingers");
    expect(expiry.length).toBe(1);
    expect(expiry[0].args.groupCallId).toBe(groupCallId);
    // The same instant `pendingInviteForUser` stops offering the invite, so a
    // live app and a killed one give up on the same call at the same moment.
    expect(Math.round(expiry[0].delayMs)).toBe(60 * 1000);
  });

  test("the expiry dismisses whoever is still ringing, and nobody else", async () => {
    const t = convexTest(schema);
    const { starter, alice, bob, roomId } = await roomOfThree(t);
    const groupCallId = await startCall(t, starter, roomId);

    await t.mutation(api.groupCalls.join, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      groupCallId,
      deviceId: "phone-in-hand",
    });

    await t.mutation(internal.groupCalls._expireRingers, { groupCallId });

    const timeouts = (await jobs(t, "sendGroupVoipTaken")).filter(
      (j) => j.args.reason === "timeout",
    );
    expect(timeouts.length).toBe(1);
    // Alice answered; only Bob's phone is still ringing.
    expect(timeouts[0].args.targetUserIds).toEqual([bob.userId]);
  });
});
