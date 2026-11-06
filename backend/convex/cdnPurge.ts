import { internalAction, internalQuery } from "./_generated/server";
import { internalMutation } from "./dbHooks";
import { internal } from "./_generated/api";
import { v } from "convex/values";

/**
 * Purge-on-delete for the CDN (Cloudflare) in front of the storage URLs.
 *
 * Privacy: once a stored file is deleted, its URL must stop being served from
 * the edge cache within seconds. Every real deletion goes through
 * `files.destroy`, which calls [enqueuePurge]; a single drain action posts the
 * URLs to Cloudflare in batches.
 *
 * Cost shape: one insert per deleted file, and at most one drain scheduled at a
 * time (`cdnPurgeState`), not one job per file. Without CF_ZONE_ID and
 * CF_PURGE_TOKEN the drain does nothing and the rows stay queued, so enabling
 * it later drains the backlog.
 *
 * View-once media is never addressed by storage URL (it is served by
 * `/viewOnce` with `Cache-Control: no-store`), so a purge for it is a harmless
 * no-op at the edge.
 */

export const BATCH = 30; // Cloudflare allows 30 URLs per purge call.
export const BACKOFF_BASE_MS = 5_000;
export const BACKOFF_CAP_MS = 5 * 60_000;
/**
 * A URL Cloudflare keeps refusing is dropped after this many attempts (logged),
 * so one bad row can never hold up every purge queued behind it.
 */
export const MAX_ATTEMPTS = 8;
/** A drain "scheduled" longer ago than this is presumed lost and rescheduled. */
export const STALE_SCHEDULE_MS = 10 * 60_000;

export const backoffMs = (attempts: number) =>
  Math.min(BACKOFF_CAP_MS, BACKOFF_BASE_MS * 2 ** Math.max(0, attempts - 1));

export const publicBase = () =>
  (process.env.CDN_PUBLIC_BASE || "https://termio-api.walhallaa.com").replace(/\/+$/, "");

export const storageUrl = (storageId: any) => `${publicBase()}/api/storage/${storageId}`;

/** Queues [storageId]'s URL for purging and makes sure a drain is scheduled. */
export async function enqueuePurge(ctx: any, storageId: any): Promise<void> {
  if (!storageId) return;
  await ctx.db.insert("cdnPurges", {
    url: storageUrl(storageId),
    enqueuedAt: Date.now(),
    attempts: 0,
  });
  await ensureDrain(ctx, 0);
}

const purgeConfigured = () => !!process.env.CF_ZONE_ID && !!process.env.CF_PURGE_TOKEN;

async function ensureDrain(ctx: any, delayMs: number): Promise<void> {
  // Not configured: rows stay queued and nothing is scheduled (a drain could
  // only go idle again). The first delete after the env is set drains the
  // whole backlog, oldest first.
  if (!purgeConfigured()) return;
  const now = Date.now();
  const state = await ctx.db.query("cdnPurgeState").first();
  if (state?.scheduledAt && now - state.scheduledAt < STALE_SCHEDULE_MS) return;
  if (state) await ctx.db.patch(state._id, { scheduledAt: now });
  else await ctx.db.insert("cdnPurgeState", { scheduledAt: now });
  await ctx.scheduler.runAfter(delayMs, internal.cdnPurge.drain, {});
}

export const nextBatch = internalQuery({
  args: {},
  handler: async (ctx) =>
    await ctx.db.query("cdnPurges").withIndex("by_enqueuedAt").order("asc").take(BATCH),
});

/** Ends a drain pass: deletes [done], records [failed], then reschedules or goes idle. */
export const settle = internalMutation({
  args: {
    done: v.array(v.id("cdnPurges")),
    failed: v.array(v.id("cdnPurges")),
    error: v.optional(v.string()),
    // true: stop and leave rows queued (purging not configured).
    idle: v.optional(v.boolean()),
  },
  handler: async (ctx, { done, failed, error, idle }) => {
    for (const id of done) await ctx.db.delete(id);
    let maxAttempts = 0;
    for (const id of failed) {
      const row = await ctx.db.get(id);
      if (!row) continue;
      const attempts = row.attempts + 1;
      if (attempts >= MAX_ATTEMPTS) {
        console.error(`[cdnPurge] giving up on ${row.url} after ${attempts} attempts: ${error ?? "error"}`);
        await ctx.db.delete(id);
        continue;
      }
      maxAttempts = Math.max(maxAttempts, attempts);
      await ctx.db.patch(id, { attempts, lastError: (error ?? "error").slice(0, 300) });
    }
    const state = await ctx.db.query("cdnPurgeState").first();
    const more = idle ? null : await ctx.db.query("cdnPurges").withIndex("by_enqueuedAt").first();
    if (!more) {
      if (state) await ctx.db.patch(state._id, { scheduledAt: undefined });
      return;
    }
    const delay = failed.length > 0 ? backoffMs(maxAttempts) : 0;
    if (state) await ctx.db.patch(state._id, { scheduledAt: Date.now() });
    await ctx.scheduler.runAfter(delay, internal.cdnPurge.drain, {});
  },
});

let warnedUnconfigured = false;

export const drain = internalAction({
  args: {},
  handler: async (ctx) => {
    const zone = process.env.CF_ZONE_ID;
    const token = process.env.CF_PURGE_TOKEN;
    if (!zone || !token) {
      if (!warnedUnconfigured) {
        warnedUnconfigured = true;
        console.warn("[cdnPurge] CF_ZONE_ID / CF_PURGE_TOKEN unset: purges stay queued");
      }
      await ctx.runMutation(internal.cdnPurge.settle, { done: [], failed: [], idle: true });
      return;
    }
    const batch = await ctx.runQuery(internal.cdnPurge.nextBatch, {});
    if (batch.length === 0) {
      await ctx.runMutation(internal.cdnPurge.settle, { done: [], failed: [] });
      return;
    }
    const ids = batch.map((r: any) => r._id);
    const purge = (urls: string[]) =>
      fetch(`https://api.cloudflare.com/client/v4/zones/${zone}/purge_cache`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ files: urls }),
      });
    try {
      const res = await purge(batch.map((r: any) => r.url));
      if (res.ok) {
        await ctx.runMutation(internal.cdnPurge.settle, { done: ids, failed: [] });
        return;
      }
      // A refusal of the request itself (4xx other than rate limiting) may be
      // one bad URL: purge one by one so the good ones still go through and
      // only the refused row is retried (and eventually dropped).
      if (res.status >= 400 && res.status < 500 && res.status !== 429 && batch.length > 1) {
        const done: any[] = [];
        const failed: any[] = [];
        for (const r of batch) {
          const one = await purge([r.url]);
          (one.ok ? done : failed).push(r._id);
        }
        await ctx.runMutation(internal.cdnPurge.settle, {
          done,
          failed,
          error: `cloudflare ${res.status} (per-URL retry)`,
        });
        return;
      }
      throw new Error(`cloudflare ${res.status}`);
    } catch (e: any) {
      await ctx.runMutation(internal.cdnPurge.settle, {
        done: [],
        failed: ids,
        error: String(e?.message ?? e),
      });
    }
  },
});
