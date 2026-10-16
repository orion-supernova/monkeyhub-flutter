import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { publicQuery, query } from "./functions";
import { v } from "convex/values";

/// The latest shipped build for one distribution channel, or null if nothing
/// has ever been published for it.
///
/// Deliberately public and unauthenticated, like `rooms:listPublic`: the client
/// runs this check on every cold start, *before* restoring a session. Someone
/// locked out by a client too old to talk to this backend is exactly who needs
/// the prompt, and they can't authenticate to ask for it.
export const latest = publicQuery({
  args: { channel: v.string() },
  handler: async (ctx, { channel }) => {
    const row = await ctx.db
      .query("appReleases")
      .withIndex("by_channel", (q) => q.eq("channel", channel))
      .unique();
    if (!row) return null;
    return {
      channel: row.channel,
      version: row.version,
      minSupported: row.minSupported ?? null,
      updateUrl: row.updateUrl ?? null,
      notes: row.notes ?? null,
      publishedAt: row.publishedAt,
    };
  },
});

/// Upserts the row for one channel. Called by deploy.sh via `npx convex run`
/// after that channel's upload succeeds — so a failed build never announces a
/// version nobody can install.
///
/// `internalMutation`, not `mutation`: `npx convex run` carries admin
/// credentials and reaches internal functions fine, while leaving no public
/// write surface. A public version of this would let anyone fabricate a
/// mandatory-update prompt for every user on every platform.
///
/// Omitted optional args leave the existing value alone rather than clearing
/// it, so publishing a new version from deploy.sh can't silently drop a
/// hand-set `minSupported` or a store `updateUrl`. Pass null explicitly to
/// clear one.
export const publish = internalMutation({
  args: {
    channel: v.string(),
    version: v.string(),
    minSupported: v.optional(v.union(v.string(), v.null())),
    updateUrl: v.optional(v.union(v.string(), v.null())),
    notes: v.optional(v.union(v.string(), v.null())),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("appReleases")
      .withIndex("by_channel", (q) => q.eq("channel", args.channel))
      .unique();

    // undefined → leave as-is; null → clear; string → set.
    const resolve = (
      next: string | null | undefined,
      current: string | undefined,
    ): string | undefined =>
      next === undefined ? current : next === null ? undefined : next;

    const patch = {
      channel: args.channel,
      version: args.version,
      minSupported: resolve(args.minSupported, existing?.minSupported),
      updateUrl: resolve(args.updateUrl, existing?.updateUrl),
      notes: resolve(args.notes, existing?.notes),
      publishedAt: Date.now(),
    };

    if (existing) {
      await ctx.db.replace(existing._id, patch);
      return { channel: args.channel, version: args.version, created: false };
    }
    await ctx.db.insert("appReleases", patch);
    return { channel: args.channel, version: args.version, created: true };
  },
});

// ── App Store rows, kept in step with what Apple actually sells ─────────────
//
// `ios-appstore` and `macos-appstore` used to be published by hand after each
// approval, which meant store users were never told about an update whenever
// someone forgot. An upload is not a release (it may sit in review for days,
// or be rejected), so deploy.sh can't publish these; only Apple knows when a
// version is live. Its public lookup API says so with no credentials, so this
// asks it hourly and moves each row the moment the store has a newer version.

/** The App Store Connect app id, shared by the iOS and macOS listings. */
const APPLE_APP_ID = "6739744338";
/** The storefront asked. MonkeyHub ships the same version everywhere. */
const LOOKUP_COUNTRY = "us";

const STORE_CHANNELS = [
  {
    channel: "ios-appstore",
    entity: "software",
    kind: "software",
    updateUrl: `itms-apps://apps.apple.com/app/id${APPLE_APP_ID}`,
  },
  {
    channel: "macos-appstore",
    entity: "macSoftware",
    kind: "mac-software",
    updateUrl: `macappstore://apps.apple.com/app/id${APPLE_APP_ID}`,
  },
] as const;

/** Numeric dotted-version compare; missing parts count as 0. */
export function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  return 0;
}

export const currentVersion = internalQuery({
  args: { channel: v.string() },
  handler: async (ctx, { channel }) => {
    const row = await ctx.db
      .query("appReleases")
      .withIndex("by_channel", (q) => q.eq("channel", channel))
      .unique();
    return row?.version ?? null;
  },
});

/** Hourly from crons.ts. Publishes only forward, and only what Apple sells. */
export const syncAppStoreReleases = internalAction({
  args: {},
  handler: async (ctx) => {
    const out: Record<string, string> = {};
    for (const s of STORE_CHANNELS) {
      try {
        const res = await fetch(
          `https://itunes.apple.com/lookup?id=${APPLE_APP_ID}` +
            `&country=${LOOKUP_COUNTRY}&entity=${s.entity}`,
        );
        if (!res.ok) {
          out[s.channel] = `lookup HTTP ${res.status}`;
          continue;
        }
        const body: any = await res.json();
        const hit = (body.results ?? []).find(
          (r: any) => r.kind === s.kind && typeof r.version === "string",
        );
        if (!hit) {
          out[s.channel] = "not on sale";
          continue;
        }
        const current: string | null = await ctx.runQuery(
          internal.releases.currentVersion,
          { channel: s.channel },
        );
        if (current && compareVersions(hit.version, current) <= 0) {
          out[s.channel] = `unchanged ${current}`;
          continue;
        }
        await ctx.runMutation(internal.releases.publish, {
          channel: s.channel,
          version: hit.version,
          updateUrl: s.updateUrl,
        });
        out[s.channel] = `published ${hit.version}`;
      } catch (e) {
        out[s.channel] = `error ${e}`;
      }
    }
    console.log(`releases.syncAppStoreReleases: ${JSON.stringify(out)}`);
    return out;
  },
});
