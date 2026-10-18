import { describe, expect, test } from "vitest";
import {
  type AlertSpec,
  buildWebPushPayload,
  secretPreviewFor,
  webSafeSpec,
} from "./push";

/**
 * A browser cannot block a screenshot, so the app never opens a secret room
 * there — and the web notification must not show what the room would not.
 */
const spec = (secretRoom: boolean): AlertSpec => ({
  kind: "message",
  title: "Ece",
  body: "the thing nobody may keep",
  data: {
    kind: "message",
    roomId: "r1",
    messageId: "m1",
    senderName: "Ece",
    content: "the thing nobody may keep",
    plain: "true",
    isGroup: "true",
    roomName: "After hours",
  },
  badge: 1,
  threadId: "r1",
  collapseId: "m1",
  ...(secretRoom ? { secretRoom: true } : {}),
});

describe("web pushes from a secret room", () => {
  test("carry none of the message", () => {
    const out = buildWebPushPayload(webSafeSpec(spec(true), "en-US"));
    expect(JSON.stringify(out)).not.toContain("nobody may keep");
    expect(out.body).toBe("Open in the app to read");
    expect(out.plain).toBeUndefined();
  });

  test("still route the tap to the room", () => {
    const out = buildWebPushPayload(webSafeSpec(spec(true), "en"));
    expect(out.roomId).toBe("r1");
    expect(out.senderName).toBe("Ece");
    expect(out.collapseId).toBe("m1");
  });

  test("speak the device's language", () => {
    expect(secretPreviewFor("tr-TR")).toBe("Okumak için uygulamada aç");
    expect(secretPreviewFor("pt-BR")).toBe("Abra no app para ler");
    expect(secretPreviewFor("pt_PT")).toBe("Abre na app para ler");
    expect(secretPreviewFor(undefined)).toBe("Open in the app to read");
    expect(secretPreviewFor("xx")).toBe("Open in the app to read");
  });

  test("an ordinary room is untouched", () => {
    const s = spec(false);
    expect(webSafeSpec(s, "en")).toBe(s);
  });
});
