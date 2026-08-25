import { internalMutation } from "./_generated/server";
import { publicQuery, query } from "./functions";
import { v } from "convex/values";

/// Which backend clients should be talking to right now.
///
/// ───────── why this exists ─────────
///
/// This app runs on two interchangeable deployments — the VPS and a home
/// server — holding replicated data. Moving traffic between them used to mean
/// shipping a build, because the URL was baked into `env.local`.
///
/// Deliberately public and unauthenticated, for the same reason
/// `releases:latest` is: a client runs this on every cold start, before it has
/// restored a session or built a WebSocket. Someone whose deployment moved is
/// exactly who cannot authenticate to ask where it went. It exposes two
/// hostnames the app already ships in its own binary, and nothing else.
///
/// ───────── it is REACTIVE, and that is the point ─────────
///
/// Clients subscribe to this query over their live socket, so writing the row
/// moves everyone within a second — no relaunch, no polling. That only works
/// because the answer comes out of the database: a Convex query invalidates on
/// the reads it made, and the `process.env` fallback below recomputes for
/// nobody. Prefer `serverDirectory:set` over `convex env set` for exactly that
/// reason; the env vars remain as a seed for a deployment that has never had
/// the row written.
export const current = publicQuery({
  args: {},
  returns: v.object({
    serve: v.union(v.literal("primary"), v.literal("homeserver")),
    primaryUrl: v.union(v.string(), v.null()),
    homeserverUrl: v.union(v.string(), v.null()),
    note: v.union(v.string(), v.null()),
  }),
  handler: async (ctx) => {
    const row = await ctx.db
      .query("serverDirectory")
      .withIndex("by_key", (q) => q.eq("key", "current"))
      .unique();

    if (row) {
      return {
        serve: row.serve,
        primaryUrl: row.primaryUrl ?? null,
        homeserverUrl: row.homeserverUrl ?? null,
        note: row.note ?? null,
      };
    }

    // No row yet — fall back to the environment, so a deployment that only ever
    // had `SERVE_FROM` set still answers correctly. Anything other than the
    // exact string `homeserver` means primary: a typo in an env var must not be
    // able to scatter clients onto a backend nobody meant to serve from, and
    // the safe failure direction is always "stay where you are".
    const serve =
      (process.env.SERVE_FROM ?? "").trim().toLowerCase() === "homeserver"
        ? ("homeserver" as const)
        : ("primary" as const);
    return {
      serve,
      primaryUrl: trimmedOrNull(process.env.PRIMARY_URL),
      homeserverUrl: trimmedOrNull(process.env.HOMESERVER_URL),
      note: trimmedOrNull(process.env.SERVE_NOTE)?.slice(0, 200) ?? null,
    };
  },
});

/// Move every client, live.
///
///   npx convex run serverDirectory:set '{"serve":"homeserver","note":"migrating the VPS"}'
///   npx convex run serverDirectory:set '{"serve":"primary"}'
///
/// **The VPS is the one that counts.** Clients ask the primary first at launch,
/// and a client that has followed to the home server polls the primary every
/// half-minute — precisely because a Convex subscription rides the socket, so
/// once it has moved it is watching THIS deployment's row and cannot see yours.
/// That is why moving people out is instant and bringing them back would
/// otherwise be silent.
///
/// Setting it on both is still worth doing, and is required for one case: a
/// client on the home server while the VPS is unreachable falls back to asking
/// the home server, and one still saying `homeserver` there would keep exactly
/// the clients that listened to you. But forgetting no longer strands anybody —
/// the poll brings them home within a minute of the VPS row changing.
///
/// `internalMutation`, not `mutation`: `npx convex run` carries admin
/// credentials and reaches internal functions fine, while leaving no public
/// write surface. A public version of this would let anyone redirect every
/// client of this app to a server of their choosing — which is as bad as it
/// sounds, and is why the read side is the only thing exposed.
///
/// Omitted optional args CLEAR the field rather than leaving it alone, unlike
/// `releases:publish`. The opposite of what that function wants: a note reading
/// "back by Sunday" must not outlive the migration it described, and a URL
/// override must not survive the rename it was written for.
export const set = internalMutation({
  args: {
    serve: v.union(v.literal("primary"), v.literal("homeserver")),
    primaryUrl: v.optional(v.string()),
    homeserverUrl: v.optional(v.string()),
    note: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const next = {
      key: "current" as const,
      serve: args.serve,
      primaryUrl: trimmedOrUndefined(args.primaryUrl),
      homeserverUrl: trimmedOrUndefined(args.homeserverUrl),
      note: trimmedOrUndefined(args.note)?.slice(0, 200),
      updatedAt: Date.now(),
    };
    const row = await ctx.db
      .query("serverDirectory")
      .withIndex("by_key", (q) => q.eq("key", "current"))
      .unique();
    if (row) {
      await ctx.db.replace(row._id, next);
    } else {
      await ctx.db.insert("serverDirectory", next);
    }
    return null;
  },
});

function trimmedOrNull(value: string | undefined): string | null {
  const trimmed = (value ?? "").trim();
  return trimmed.length > 0 ? trimmed : null;
}

function trimmedOrUndefined(value: string | undefined): string | undefined {
  const trimmed = (value ?? "").trim();
  return trimmed.length > 0 ? trimmed : undefined;
}
