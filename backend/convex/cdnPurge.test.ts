import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { attachFile, claimUpload, releaseFile } from "./files";
import { backoffMs, enqueuePurge, BATCH, MAX_ATTEMPTS } from "./cdnPurge";
import schema from "./schema";

// Vite inlines every module's text at transform time, so no node:fs is needed.
const RAW: Record<string, string> = (import.meta as any).glob(
  ["./*.ts", "./**/*.ts", "!./_generated/**"],
  { query: "?raw", import: "default", eager: true },
);

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  delete process.env.CF_ZONE_ID;
  delete process.env.CF_PURGE_TOKEN;
  delete process.env.CDN_PUBLIC_BASE;
});

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const rows = (t: T): Promise<any[]> =>
  t.run((ctx: any) => ctx.db.query("cdnPurges").collect());
const drain = (t: T) => t.action(internal.cdnPurge.drain, {});

async function enqueueMany(t: T, n: number) {
  await t.run(async (ctx: any) => {
    for (let i = 0; i < n; i++) await enqueuePurge(ctx, `fake${i}`);
  });
}

describe("purge on delete", () => {
  test("releasing the last ref deletes the blob and queues its URL", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await t.run(async (ctx: any) => {
      const id = await ctx.storage.store(new Blob(["jpeg"], { type: "image/jpeg" }));
      await claimUpload(ctx, id, me.userId, "media");
      await attachFile(ctx, id, { table: "messages", id: "m1", field: "mediaStorageId" });
      await releaseFile(ctx, id, { table: "messages", id: "m1", field: "mediaStorageId" });
      return id;
    });
    const queued = await rows(t);
    expect(queued).toHaveLength(1);
    expect(queued[0].url).toBe(`https://termio-api.walhallaa.com/api/storage/${file}`);
    expect(queued[0].attempts).toBe(0);
  });

  test("a shared file that survives is not queued", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run(async (ctx: any) => {
      const id = await ctx.storage.store(new Blob(["jpeg"], { type: "image/jpeg" }));
      await claimUpload(ctx, id, me.userId, "media");
      await attachFile(ctx, id, { table: "messages", id: "m1", field: "mediaStorageId" });
      await attachFile(ctx, id, { table: "messages", id: "m2", field: "mediaStorageId" }, { share: true });
      await releaseFile(ctx, id, { table: "messages", id: "m1", field: "mediaStorageId" });
    });
    expect(await rows(t)).toHaveLength(0);
  });

  test("CDN_PUBLIC_BASE overrides the URL base", async () => {
    process.env.CDN_PUBLIC_BASE = "https://cdn.example.com/";
    const t = convexTest(schema);
    await enqueueMany(t, 1);
    expect((await rows(t))[0].url).toBe("https://cdn.example.com/api/storage/fake0");
  });

  test("a burst schedules one drain, not one per file", async () => {
    process.env.CF_ZONE_ID = "zone1";
    process.env.CF_PURGE_TOKEN = "tok";
    const t = convexTest(schema);
    await enqueueMany(t, 5);
    const scheduled: any[] = await t.run((ctx: any) => ctx.db.system.query("_scheduled_functions").collect());
    expect(scheduled.filter((s: any) => s.name.includes("cdnPurge:drain"))).toHaveLength(1);
  });

  test("unconfigured: rows queue but no drain is scheduled", async () => {
    const t = convexTest(schema);
    await enqueueMany(t, 3);
    const scheduled: any[] = await t.run((ctx: any) => ctx.db.system.query("_scheduled_functions").collect());
    expect(scheduled.filter((s: any) => s.name.includes("cdnPurge:drain"))).toHaveLength(0);
    expect(await rows(t)).toHaveLength(3);
  });

  test("a 4xx batch is retried per URL; a URL refused 8 times is dropped", async () => {
    process.env.CF_ZONE_ID = "zone1";
    process.env.CF_PURGE_TOKEN = "tok";
    const t = convexTest(schema);
    await enqueueMany(t, 3);
    const bad = (await rows(t))[0].url;
    const fetchMock = vi.fn(async (_u: any, init: any) => {
      const files: string[] = JSON.parse(init.body).files;
      if (files.length > 1 || files[0] === bad) return new Response("{}", { status: 400 });
      return new Response("{}", { status: 200 });
    });
    vi.stubGlobal("fetch", fetchMock);
    await drain(t);
    let left = await rows(t);
    expect(left.map((r: any) => r.url)).toEqual([bad]);
    for (let i = 1; i < MAX_ATTEMPTS; i++) await drain(t);
    left = await rows(t);
    expect(left).toHaveLength(0);
  });
});

describe("drain", () => {
  test("no env: nothing is sent and the rows stay queued", async () => {
    const t = convexTest(schema);
    await enqueueMany(t, 2);
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
    await drain(t);
    expect(fetchMock).not.toHaveBeenCalled();
    expect(await rows(t)).toHaveLength(2);
  });

  test("success posts up to 30 URLs to Cloudflare and deletes them", async () => {
    process.env.CF_ZONE_ID = "zone1";
    process.env.CF_PURGE_TOKEN = "tok";
    const t = convexTest(schema);
    await enqueueMany(t, BATCH + 2);
    const fetchMock = vi.fn(async () => new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await drain(t);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as any;
    expect(url).toBe("https://api.cloudflare.com/client/v4/zones/zone1/purge_cache");
    expect(init.method).toBe("POST");
    expect(init.headers.Authorization).toBe("Bearer tok");
    const body = JSON.parse(init.body);
    expect(body.files).toHaveLength(BATCH);
    expect(body.files[0]).toBe("https://termio-api.walhallaa.com/api/storage/fake0");
    expect(await rows(t)).toHaveLength(2);
  });

  test("failure keeps the rows, bumps attempts and records the error", async () => {
    process.env.CF_ZONE_ID = "zone1";
    process.env.CF_PURGE_TOKEN = "tok";
    const t = convexTest(schema);
    await enqueueMany(t, 2);
    vi.stubGlobal("fetch", vi.fn(async () => new Response("no", { status: 500 })));
    await drain(t);
    const left = await rows(t);
    expect(left).toHaveLength(2);
    expect(left.every((r: any) => r.attempts === 1 && /500/.test(r.lastError))).toBe(true);
    // A thrown network error is handled the same way.
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("offline"); }));
    await drain(t);
    expect((await rows(t)).every((r: any) => r.attempts === 2 && /offline/.test(r.lastError))).toBe(true);
  });

  test("backoff doubles and is capped", () => {
    expect(backoffMs(1)).toBe(5_000);
    expect(backoffMs(2)).toBe(10_000);
    expect(backoffMs(3)).toBe(20_000);
    expect(backoffMs(30)).toBe(5 * 60_000);
  });
});

describe("only the helper deletes stored files", () => {
  // Sites not yet routed through files.destroy (owned by other workers).
  const ALLOWED = new Set<string>([
    "./files.ts", // destroy(): the choke point
    "./systemAvatars.ts", // an action: deletes a blob it just stored and never published
  ]);

  test("no other source calls storage.delete", () => {
    const offenders: string[] = [];
    for (const [path, src] of Object.entries(RAW)) {
      if (path.endsWith(".test.ts") || ALLOWED.has(path)) continue;
      if (/\bstorage\s*\.\s*delete\s*\(/.test(src)) offenders.push(path);
    }
    expect(Object.keys(RAW).length).toBeGreaterThan(50);
    expect(offenders).toEqual([]);
  });

  test("files.ts calls it exactly once, inside destroy", () => {
    const src = RAW["./files.ts"];
    expect(src.match(/storage\s*\.\s*delete\s*\(/g)).toHaveLength(1);
    const i = src.indexOf("storage.delete(");
    expect(src.lastIndexOf("export async function", i)).toBe(src.indexOf("export async function destroy"));
  });
});
