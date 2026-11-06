import { describe, expect, test } from "vitest";
import {
  ALERT_BURST_GAP_MS,
  ALERT_BURST_REMINDER_MS,
  SERVER_BURST_PLATFORMS,
  alertBurstStep,
} from "./alertBurst";

/**
 * The server's copy of the burst rule (Mac and web banners). Reported as
 * "an active group buzzes my MacBook for every message": the phones had the
 * rule on the device, the Mac had nothing to run it in.
 */
describe("alertBurstStep", () => {
  /** Feeds message times through the rule the way sendCore does. */
  function run(times: number[]): boolean[] {
    let prev: number | undefined;
    let burstAt: number | undefined;
    return times.map((now) => {
      const step = alertBurstStep(prev, burstAt, now);
      prev = now;
      burstAt = step.burstAt;
      return step.alerts;
    });
  }

  test("ten messages in two seconds alert once", () => {
    const times = Array.from({ length: 10 }, (_, i) => 1_000_000 + i * 200);
    expect(run(times)).toEqual([true, ...Array(9).fill(false)]);
  });

  test("a pause as long as the gap starts a new burst", () => {
    expect(run([0, 1_000, 1_000 + ALERT_BURST_GAP_MS])).toEqual([
      true,
      false,
      true,
    ]);
  });

  test("a conversation that never pauses still alerts every few minutes", () => {
    const step = 30_000;
    const times = Array.from({ length: 13 }, (_, i) => i * step);
    const alerts = run(times);
    // 0 alerts; the next one at the first message >= 3 min after it.
    const at = times.filter((_, i) => alerts[i]);
    expect(at).toEqual([0, ALERT_BURST_REMINDER_MS, 2 * ALERT_BURST_REMINDER_MS]);
  });

  test("a room with no history alerts", () => {
    expect(alertBurstStep(undefined, undefined, 5).alerts).toBe(true);
    // A room whose last message predates the field.
    expect(alertBurstStep(4, undefined, 5).alerts).toBe(true);
  });

  test("only the devices with no rule of their own", () => {
    expect([...SERVER_BURST_PLATFORMS].sort()).toEqual(["macos", "web"]);
  });
});
