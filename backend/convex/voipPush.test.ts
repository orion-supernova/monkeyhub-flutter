import { describe, expect, test } from "vitest";
import {
  groupCallerName,
  selectTakenTargets,
  voipCollapseId,
  voipExpirySeconds,
} from "./voipPush";

/**
 * Which devices a native `taken` push reaches. The selection is pure so the
 * rules that keep a dismissal from turning into a phantom ring — and the ones
 * that keep it reaching a killed process — can be pinned without a transport.
 */

const row = (
  deviceId: string,
  tokens: { voip?: boolean; fcm?: boolean },
) =>
  ({
    deviceRowId: `row-${deviceId}` as any,
    legacy: false as const,
    deviceId,
    platform: tokens.voip ? "ios" : "android",
    voipToken: tokens.voip ? `voip-${deviceId}` : undefined,
    fcmToken: tokens.fcm ? `fcm-${deviceId}` : undefined,
  });

const none = new Set<string>();

describe("selectTakenTargets", () => {
  test("reaches every device with a native channel by default", () => {
    const out = selectTakenTargets(
      [row("a", { voip: true }), row("b", { fcm: true }), row("c", {})],
      { excludeDeviceId: null, iosVoip: true, dismissed: none },
    );
    expect(out.map((d) => d.deviceId)).toEqual(["a", "b"]);
  });

  test("never the device that settled the call", () => {
    const out = selectTakenTargets(
      [row("a", { voip: true }), row("b", { voip: true })],
      { excludeDeviceId: "a", iosVoip: true, dismissed: none },
    );
    expect(out.map((d) => d.deviceId)).toEqual(["b"]);
  });

  test("an acked iPhone loses its PushKit leg — the phantom ring", () => {
    const out = selectTakenTargets(
      [row("a", { voip: true }), row("b", { voip: true })],
      { excludeDeviceId: null, iosVoip: true, dismissed: new Set(["a"]) },
    );
    expect(out.map((d) => d.deviceId)).toEqual(["b"]);
  });

  test("an acked Android still gets its taken — the ack is not proof", () => {
    // 2026-10-07: a Galaxy acked its card gone and kept ringing after the
    // caller cancelled, because this push skipped it.
    const out = selectTakenTargets(
      [row("droid", { fcm: true }), row("both", { voip: true, fcm: true })],
      {
        excludeDeviceId: null,
        iosVoip: true,
        dismissed: new Set(["droid", "both"]),
      },
    );
    expect(out.map((d) => d.deviceId)).toEqual(["droid", "both"]);
    for (const d of out) expect(d.voipToken).toBeUndefined();
  });

  test("iosVoip:false strips PushKit off the row so the retry cannot re-add it", () => {
    const out = selectTakenTargets(
      [row("iphone", { voip: true }), row("both", { voip: true, fcm: true }), row("droid", { fcm: true })],
      { excludeDeviceId: null, iosVoip: false, dismissed: none },
    );
    expect(out.map((d) => d.deviceId)).toEqual(["both", "droid"]);
    for (const d of out) expect(d.voipToken).toBeUndefined();
    expect(out[0].fcmToken).toBe("fcm-both");
  });

  test("iosVoip:true leaves the rows untouched", () => {
    const rows = [row("iphone", { voip: true })];
    const out = selectTakenTargets(rows, {
      excludeDeviceId: null,
      iosVoip: true,
      dismissed: none,
    });
    expect(out[0]).toBe(rows[0]);
  });

  test("a legacy fallback row is still a target — it can never have acked", () => {
    const legacy = {
      deviceRowId: null,
      legacy: true as const,
      deviceId: "_legacy",
      platform: "ios",
      voipToken: "voip-legacy",
    };
    const out = selectTakenTargets([legacy], {
      excludeDeviceId: null,
      iosVoip: true,
      dismissed: new Set(["phone-a"]),
    });
    expect(out).toEqual([legacy]);
  });
});

/**
 * The transport-level pairing of an invite with its own dismissal. Group
 * pushes carry `groupCallId` and no `callId`, and for a while that meant they
 * had no collapse key at all: a phone back from Doze received the queued
 * `group_invite` AND the `group_taken`, in order, and full-screen-rang a call
 * that had ended minutes earlier.
 */
describe("voipCollapseId", () => {
  test("a 1:1 invite and its taken share the callId", () => {
    expect(voipCollapseId({ kind: "invite", callId: "c1" })).toBe("c1");
    expect(voipCollapseId({ kind: "taken", callId: "c1" })).toBe("c1");
  });

  test("a group invite and its taken share the groupCallId", () => {
    expect(voipCollapseId({ kind: "group_invite", groupCallId: "g1" })).toBe(
      "g1",
    );
    expect(voipCollapseId({ kind: "group_taken", groupCallId: "g1" })).toBe(
      "g1",
    );
  });

  test("nothing to key on means no collapse, not a shared one", () => {
    expect(voipCollapseId({ kind: "invite" })).toBeUndefined();
  });
});

describe("voipExpirySeconds", () => {
  test("both kinds of dismissal chase a reconnecting device for a minute", () => {
    expect(voipExpirySeconds({ kind: "taken" })).toBe(60);
    expect(voipExpirySeconds({ kind: "group_taken" })).toBe(60);
  });

  test("an invite is only worth its ring window", () => {
    expect(voipExpirySeconds({ kind: "invite" })).toBe(30);
    expect(voipExpirySeconds({ kind: "group_invite" })).toBe(30);
  });
});

describe("groupCallerName", () => {
  test("says who is calling, and where", () => {
    expect(groupCallerName("Ayşe", "Design Crew")).toBe("Ayşe · Design Crew");
  });
});
