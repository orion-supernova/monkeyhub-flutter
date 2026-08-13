import { query } from "./_generated/server";
import { v } from "convex/values";

/// Which backend clients should be talking to right now.
///
/// ───────── why this exists ─────────
///
/// This app runs on two interchangeable deployments — the VPS and a home
/// server — holding replicated data. Moving traffic between them used to mean
/// shipping a build, because the URL was baked into `env.local`. This is the
/// one thing a client can ask BEFORE it opens a socket, so the answer can
/// change without anybody installing anything.
///
/// Deliberately public and unauthenticated, for the same reason
/// `releases:latest` is: the client runs this on every cold start, before it
/// has restored a session or built a WebSocket. Someone whose deployment moved
/// is exactly who cannot authenticate to ask where it went. It exposes two
/// hostnames the app already ships in its own binary, and nothing else.
///
/// ───────── how the admin flips it ─────────
///
/// From deployment environment variables — no table, no migration, no code
/// change:
///
///   npx convex env set SERVE_FROM homeserver     # move clients over
///   npx convex env set SERVE_FROM primary        # move them back
///
/// Set them on BOTH deployments and keep them in step. A client that has
/// already followed to the home server asks the home server on its next
/// launch, so the home server saying `primary` is what brings everyone back —
/// and a home server still saying `homeserver` after the VPS says `primary`
/// would strand exactly the clients that listened to you.
///
/// `PRIMARY_URL` / `HOMESERVER_URL` are optional overrides for the addresses;
/// omit them and the client falls back to the pair compiled into it. They
/// exist so a host can be renamed without a client release.
export const current = query({
  args: {},
  returns: v.object({
    serve: v.union(v.literal("primary"), v.literal("homeserver")),
    primaryUrl: v.union(v.string(), v.null()),
    homeserverUrl: v.union(v.string(), v.null()),
    note: v.union(v.string(), v.null()),
  }),
  handler: async () => {
    // Anything other than the exact string `homeserver` means primary. A typo
    // in an env var must not be able to scatter clients onto a backend nobody
    // meant to serve from — the failure direction is "stay where you are".
    const serve =
      (process.env.SERVE_FROM ?? "").trim().toLowerCase() === "homeserver"
        ? ("homeserver" as const)
        : ("primary" as const);

    return {
      serve,
      primaryUrl: trimmedOrNull(process.env.PRIMARY_URL),
      homeserverUrl: trimmedOrNull(process.env.HOMESERVER_URL),
      // Shown verbatim in the app's info sheet, so an admin can say why —
      // "migrating the VPS", "testing", "back by Sunday". Capped here rather
      // than in the client because this is the end that knows it is a note and
      // not a payload.
      note: trimmedOrNull(process.env.SERVE_NOTE)?.slice(0, 200) ?? null,
    };
  },
});

function trimmedOrNull(value: string | undefined): string | null {
  const trimmed = (value ?? "").trim();
  return trimmed.length > 0 ? trimmed : null;
}
