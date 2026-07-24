import { query, internalMutation } from "./_generated/server";
import { v } from "convex/values";

/// The latest shipped build for one distribution channel, or null if nothing
/// has ever been published for it.
///
/// Deliberately public and unauthenticated, like `rooms:listPublic`: the client
/// runs this check on every cold start, *before* restoring a session. Someone
/// locked out by a client too old to talk to this backend is exactly who needs
/// the prompt, and they can't authenticate to ask for it.
export const latest = query({
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
