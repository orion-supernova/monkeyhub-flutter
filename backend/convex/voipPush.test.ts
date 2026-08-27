import { describe, expect, test } from "vitest";
import { selectTakenTargets } from "./voipPush";

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

  test("never a device that acked its card gone", () => {
    const out = selectTakenTargets(
      [row("a", { voip: true }), row("b", { voip: true }), row("c", { fcm: true })],
      { excludeDeviceId: null, iosVoip: true, dismissed: new Set(["a", "c"]) },
    );
    expect(out.map((d) => d.deviceId)).toEqual(["b"]);
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
