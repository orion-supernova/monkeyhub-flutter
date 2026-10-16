import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { compareVersions } from "./releases";
import schema from "./schema";

/**
 * App Store rows follow what Apple sells, never what was merely uploaded.
 */

afterEach(() => vi.unstubAllGlobals());

function appleSays(ios: string | null, mac: string | null) {
  vi.stubGlobal("fetch", async (url: string) => {
    const mac_ = url.includes("entity=macSoftware");
    const version = mac_ ? mac : ios;
    const results = version
      ? [{ kind: mac_ ? "mac-software" : "software", version }]
      : [];
    return new Response(JSON.stringify({ resultCount: results.length, results }));
  });
}

const row = (t: ReturnType<typeof convexTest>, channel: string) =>
  t.query(api.releases.latest, { channel });

describe("App Store release sync", () => {
  test("nothing on sale publishes nothing", async () => {
    const t = convexTest(schema);
    appleSays(null, null);
    await t.action(internal.releases.syncAppStoreReleases, {});
    expect(await row(t, "ios-appstore")).toBeNull();
    expect(await row(t, "macos-appstore")).toBeNull();
  });

  test("a live version is published with its store link, and only forward", async () => {
    const t = convexTest(schema);
    appleSays("1.3.130", "1.3.129");
    await t.action(internal.releases.syncAppStoreReleases, {});
    expect((await row(t, "ios-appstore"))?.version).toBe("1.3.130");
    expect((await row(t, "ios-appstore"))?.updateUrl).toContain("itms-apps://");
    expect((await row(t, "macos-appstore"))?.version).toBe("1.3.129");

    // A stale storefront answering an older version never moves a row back.
    appleSays("1.3.129", "1.3.129");
    await t.action(internal.releases.syncAppStoreReleases, {});
    expect((await row(t, "ios-appstore"))?.version).toBe("1.3.130");
  });

  test("version compare is numeric, not lexical", () => {
    expect(compareVersions("1.3.130", "1.3.99")).toBe(1);
    expect(compareVersions("1.3.9", "1.3.10")).toBe(-1);
    expect(compareVersions("1.3", "1.3.0")).toBe(0);
  });
});
