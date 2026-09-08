import { internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

/// Which of the two interchangeable deployments this code is running on, and
/// whether it is the one anybody is actually listening to.
///
/// ───────── why this exists ─────────
///
/// This app runs on two backends holding replicated data — the VPS and the
/// home server — and exactly one of them serves clients at a time
/// (`serverDirectory:current`). The other is a warm standby: same schema, same
/// rows, same functions, same deployment env, still running.
///
/// "Still running" is the part that bit. A Convex deployment runs `crons.ts`
/// because it is up, not because anybody is talking to it, so the standby was
/// sweeping and sending on its own schedule the whole time. Every garbage
/// collector in that file is harmless there — it tidies its own copy of the
/// rows and nobody reads them. `dailyNudge.run` is not: the standby's copy of
/// `userDevices` carries the SAME LIVE APNs and FCM credentials as the
/// primary's (the migration was a byte copy of the data directory), and the
/// deployment env carries the same APNs key, so its nudge reached the same
/// real phones. `users.lastNudgedDayKey` is what stops a person being nudged
/// twice, and it is a row — per deployment, invisible to the other one — so
/// nothing in that design could have caught this. Every player on the
/// deployment got two identical lunchtime notifications a day from
/// 2026-08-28 until this landed.
///
/// ───────── how a deployment knows which one it is ─────────
///
/// `CONVEX_CLOUD_URL`, which the backend derives from the `CONVEX_CLOUD_ORIGIN`
/// set per box in its compose file (hosting/termio-docker-compose.yaml,
/// hosting/homeserver-docker-compose.yml).
///
/// That source is chosen for one property: it lives in the CONTAINER's
/// environment, not in the data volume. The deployment env vars (`convex env
/// set`) and every row in the database travel with an rsync of `/convex/data`
/// — which is how the two boxes came to be copies in the first place, and is
/// still how a standby gets refreshed. Anything stored there would be carried
/// from the source box to the destination on the next copy and quietly tell
/// both of them they were the same deployment, which is precisely the state
/// this file exists to detect. `DEPLOYMENT_ROLE` overrides it anyway, for a
/// third box or a local backend that is neither of these two.
export type DeploymentRole = "primary" | "homeserver";

/// The two hosts, by the names their own containers answer to.
///
/// Hard-coded rather than read from `serverDirectory`, because the row names
/// where clients should GO and this asks who this box IS — a deployment whose
/// row was written by a script that pointed it at the wrong pair must still be
/// able to recognise itself. The same two hostnames are already compiled into
/// the client and written into `switchServer.sh`.
const ROLE_BY_HOST: Readonly<Record<string, DeploymentRole>> = {
  "termio-api.walhallaa.com": "primary",
  "monkeyhub-homeserver-api.walhallaa.com": "homeserver",
};

/**
 * This deployment's identity, or `null` if it is neither of the two.
 *
 * `null` is the honest answer for a `convex dev` backend, a test, and any box
 * added later without a `DEPLOYMENT_ROLE` — and everything below reads it as
 * "no opinion", never as "standby". A deployment that cannot identify itself
 * keeps sending, which is the safe direction: the failure this guards against
 * is a duplicate notification, and the failure it must not introduce is a
 * deployment that silently stops notifying anybody.
 *
 * Read per call rather than at module load, for the reason
 * `dailyNudge.fallbackOffsetMinutes` gives: Convex keeps an isolate warm across
 * invocations, so a value captured at import time outlives an env change.
 */
export function deploymentRole(): DeploymentRole | null {
  const override = (process.env.DEPLOYMENT_ROLE ?? "").trim().toLowerCase();
  if (override === "primary" || override === "homeserver") return override;

  const raw = (process.env.CONVEX_CLOUD_URL ?? "").trim();
  if (raw === "") return null;
  let host: string;
  try {
    host = new URL(raw).hostname.toLowerCase();
  } catch {
    return null;
  }
  return ROLE_BY_HOST[host] ?? null;
}

/**
 * Whether this deployment is the one clients are on, and may therefore reach
 * a real phone.
 *
 * Three ways to answer yes and one to answer no, and the asymmetry is the
 * point — only a directory row that explicitly names the OTHER deployment
 * silences this one:
 *
 *   * no role (`convex dev`, a test, an unlisted box) — send;
 *   * no directory row at all — send, matching `serverDirectory:current`'s own
 *     reasoning that a deployment which has never been told anything should
 *     behave as it always did;
 *   * a row naming this deployment — send;
 *   * a row naming the other one — this box is the standby. Stay quiet.
 *
 * Deliberately NOT reading the `SERVE_FROM` env fallback that
 * `serverDirectory:current` falls back to. That default is `primary`, and it is
 * the right default for "where should a client go" — but read here it would
 * mean a home server whose directory row went missing decides it is a standby
 * and stops notifying the entire user base. A missing row must not be able to
 * turn off notifications; it can only fail to turn them off.
 */
export const outboundAllowed = internalQuery({
  args: {},
  returns: v.object({
    allowed: v.boolean(),
    role: v.union(v.literal("primary"), v.literal("homeserver"), v.null()),
    serve: v.union(v.literal("primary"), v.literal("homeserver"), v.null()),
  }),
  handler: async (ctx) => {
    const role = deploymentRole();
    if (role === null) return { allowed: true, role: null, serve: null };
    const row = await ctx.db
      .query("serverDirectory")
      .withIndex("by_key", (q) => q.eq("key", "current"))
      .unique();
    if (!row) return { allowed: true, role, serve: null };
    return { allowed: row.serve === role, role, serve: row.serve };
  },
});

/**
 * The same question, asked from an action, with the explanation logged.
 *
 * Every caller is an action that is about to put bytes on the wire to Apple or
 * Google, so the cost is one extra query against a single indexed row, and the
 * log line is what makes a standby's silence legible in `convex logs` rather
 * than looking like a push system that has stopped working.
 *
 * `what` names the caller, because "skipped" with no subject is the least
 * useful line an operator can find while asking why nobody got notified.
 */
export async function mayReachDevices(
  ctx: { runQuery: (ref: any, args: any) => Promise<any> },
  what: string,
): Promise<boolean> {
  const { allowed, role, serve } = await ctx.runQuery(
    internal.deployment.outboundAllowed,
    {},
  );
  if (!allowed) {
    console.log(
      `${what}: not sending — this deployment is the ${role} and clients ` +
        `are being served by the ${serve}. See deployment.ts.`,
    );
  }
  return allowed;
}
