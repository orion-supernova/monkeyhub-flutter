import { query, internalQuery, internalMutation } from "./_generated/server";
import { v } from "convex/values";

/// Per-device unlock for the in-app diagnostics viewer.
///
/// Exists because a UI bug reproduced on exactly one handset and nowhere else.
/// With no way to reproduce it, the only path forward was to instrument the
/// affected device — and shipping a build to do that, or asking a non-technical
/// user to sideload anything, was not it. Adding a row here unlocks capture on
/// one device, on the next cold start, with no release.
///
/// ───────── this is a convenience gate, not a security boundary ─────────
///
/// `deviceId` is minted by the client and asserted by the client, exactly like
/// `userId` everywhere else in this backend (see the note at auth.setRecoveryKey
/// for why that is a known, separate problem). Someone who guessed a deviceId
/// could enable the viewer on THEIR OWN device, where it would show them their
/// own traffic — already redacted client-side, and never uploaded anywhere.
/// That is close enough to harmless.
///
/// What it must never become is the authorization for an upload channel. If
/// client logs ever get sent to the server, the write path needs a real
/// credential, not this.
///
/// Managed entirely from the CLI, following the releases.publish precedent:
/// `npx convex run` carries admin credentials, so an internalMutation is the
/// whole access-control story and there is no public write surface to abuse.
///
///   npx convex run diagnostics:findDevices '{"username":"ahmet"}'
///   npx convex run diagnostics:enable '{"deviceId":"…","label":"Ahmet S26"}'
///   npx convex run diagnostics:list '{}'
///   npx convex run diagnostics:disable '{"deviceId":"…"}'

const DAY_MS = 24 * 60 * 60 * 1000;

/// Default unlock window. Deliberately short: diagnostics capture is a thing
/// you turn on to answer a question, and an unlock nobody remembers is one
/// that stays on forever.
const DEFAULT_DAYS = 14;

/// How long an expired row is kept before the sweep deletes it. The grace is so
/// `list` still shows a just-expired device while you decide whether to extend
/// it, rather than the row vanishing the moment it lapses.
export const DIAGNOSTIC_RETENTION_MS = 7 * DAY_MS;

/// Whether this device may capture. Called on every cold start.
///
/// Public and unauthenticated for the same reason `releases.latest` is: it runs
/// before a session is restored, and a client that is broken — which is the only
/// kind that needs this — may never get a session at all. The returned object is
/// three fields about the caller's own device, so there is nothing here to leak;
/// an enumerator learns only whether a random 122-bit id is in a table with
/// roughly one row in it.
export const isEnabled = query({
  args: { deviceId: v.string() },
  returns: v.object({
    enabled: v.boolean(),
    expiresAt: v.union(v.number(), v.null()),
    label: v.union(v.string(), v.null()),
  }),
  handler: async (ctx, { deviceId }) => {
    const row = await ctx.db
      .query("diagnosticDevices")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .unique();
    if (!row) return { enabled: false, expiresAt: null, label: null };
    const enabled = row.expiresAt > Date.now();
    return {
      enabled,
      expiresAt: row.expiresAt,
      label: row.label ?? null,
    };
  },
});

/// Unlock one device. Upsert, so re-running it extends the window.
export const enable = internalMutation({
  args: {
    deviceId: v.string(),
    label: v.optional(v.string()),
    note: v.optional(v.string()),
    days: v.optional(v.number()),
  },
  returns: v.object({
    deviceId: v.string(),
    expiresAt: v.number(),
    created: v.boolean(),
  }),
  handler: async (ctx, { deviceId, label, note, days }) => {
    const now = Date.now();
    const expiresAt = now + (days ?? DEFAULT_DAYS) * DAY_MS;
    const existing = await ctx.db
      .query("diagnosticDevices")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .unique();

    if (existing) {
      // Omitted optional args leave the existing value alone rather than
      // clearing it — same contract as releases.publish.
      await ctx.db.patch(existing._id, {
        expiresAt,
        enabledAt: now,
        ...(label !== undefined ? { label } : {}),
        ...(note !== undefined ? { note } : {}),
      });
      return { deviceId, expiresAt, created: false };
    }

    await ctx.db.insert("diagnosticDevices", {
      deviceId,
      label,
      note,
      enabledAt: now,
      expiresAt,
      createdAt: now,
    });
    return { deviceId, expiresAt, created: true };
  },
});

/// Lock a device again. The client re-checks at most every 6 hours, so this
/// takes effect on the next check or the next cold start, whichever is sooner.
export const disable = internalMutation({
  args: { deviceId: v.string() },
  returns: v.object({ deviceId: v.string(), removed: v.boolean() }),
  handler: async (ctx, { deviceId }) => {
    const row = await ctx.db
      .query("diagnosticDevices")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .unique();
    if (!row) return { deviceId, removed: false };
    await ctx.db.delete(row._id);
    return { deviceId, removed: true };
  },
});

/// Everything currently unlocked, for when you want to know what you left on.
/// `.take` rather than `.collect` per the house rule at users.sweepStalePresence.
export const list = internalQuery({
  args: {},
  returns: v.array(
    v.object({
      deviceId: v.string(),
      label: v.union(v.string(), v.null()),
      note: v.union(v.string(), v.null()),
      expiresAt: v.number(),
      active: v.boolean(),
    }),
  ),
  handler: async (ctx) => {
    const rows = await ctx.db.query("diagnosticDevices").take(200);
    const now = Date.now();
    return rows.map((r) => ({
      deviceId: r.deviceId,
      label: r.label ?? null,
      note: r.note ?? null,
      expiresAt: r.expiresAt,
      active: r.expiresAt > now,
    }));
  },
});

/// The device ids registered to one username.
///
/// Solves the chicken-and-egg that would otherwise make this whole feature
/// unusable: to unlock a device you need its id, and the device will not show
/// you its id because the viewer is locked. The id is already here from login —
/// `userDevices.deviceId` is the same client-minted value the gate keys on.
export const findDevices = internalQuery({
  args: { username: v.string() },
  returns: v.object({
    found: v.boolean(),
    userId: v.optional(v.id("users")),
    devices: v.array(
      v.object({
        deviceId: v.string(),
        platform: v.union(v.string(), v.null()),
        deviceName: v.union(v.string(), v.null()),
        updatedAt: v.union(v.number(), v.null()),
      }),
    ),
  }),
  handler: async (ctx, { username }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .unique();
    if (!user) return { found: false, devices: [] };

    const devices = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) => q.eq("userId", user._id))
      .take(50);

    return {
      found: true,
      userId: user._id,
      devices: devices.map((d) => ({
        deviceId: d.deviceId,
        platform: d.platform ?? null,
        deviceName: d.deviceName ?? null,
        updatedAt: d.updatedAt ?? null,
      })),
    };
  },
});

/// Unlock every device belonging to one username, in one command.
///
/// The device-id route works but has a hole in the middle: a report arrives,
/// and turning it into a capture means a lookup, a copy-paste of a 36-character
/// id, and a second command — per device. People do not have one device, and a
/// mistyped id fails silently, creating a row that never matches anything while
/// you wait for logs that cannot come.
///
/// A username is something the reporter can say out loud. The device ids are
/// already here from their logins, so resolving them is our job, not theirs.
export const enableForUser = internalMutation({
  args: {
    username: v.string(),
    days: v.optional(v.number()),
    note: v.optional(v.string()),
  },
  returns: v.object({
    found: v.boolean(),
    enabled: v.array(
      v.object({
        deviceId: v.string(),
        label: v.string(),
        created: v.boolean(),
      }),
    ),
  }),
  handler: async (ctx, { username, days, note }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .unique();
    if (!user) return { found: false, enabled: [] };

    const devices = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) => q.eq("userId", user._id))
      .take(50);

    const now = Date.now();
    const expiresAt = now + (days ?? DEFAULT_DAYS) * DAY_MS;
    const enabled = [];

    for (const d of devices) {
      // Label built here rather than left to the caller: `list` a fortnight
      // later is unreadable without it, and this is the one place that knows
      // both the account and the hardware.
      const label = `${username} ${d.deviceName ?? d.platform ?? "device"}`;
      const existing = await ctx.db
        .query("diagnosticDevices")
        .withIndex("by_device", (q) => q.eq("deviceId", d.deviceId))
        .unique();

      if (existing) {
        await ctx.db.patch(existing._id, { expiresAt, enabledAt: now, label });
        enabled.push({ deviceId: d.deviceId, label, created: false });
      } else {
        await ctx.db.insert("diagnosticDevices", {
          deviceId: d.deviceId,
          label,
          note,
          enabledAt: now,
          expiresAt,
          createdAt: now,
        });
        enabled.push({ deviceId: d.deviceId, label, created: true });
      }
    }
    return { found: true, enabled };
  },
});

/// The most recently active devices, newest first.
///
/// For the case where you cannot even get a username: somebody says "it just
/// happened" in a group chat, and the handset that was live ninety seconds ago
/// is almost certainly theirs. Gives you a name to confirm against rather than
/// a guess.
///
/// Bounded with `.take` and sorted in memory rather than by index — there is no
/// `by_lastSeenAt` on userDevices, and adding one to serve a debugging tool
/// would put a write on the hot device-registration path forever. The scan is
/// capped, so the cost is fixed and small.
export const recentDevices = internalQuery({
  args: { limit: v.optional(v.number()) },
  returns: v.array(
    v.object({
      deviceId: v.string(),
      username: v.union(v.string(), v.null()),
      platform: v.union(v.string(), v.null()),
      deviceName: v.union(v.string(), v.null()),
      lastSeenAt: v.union(v.number(), v.null()),
      allowlisted: v.boolean(),
    }),
  ),
  handler: async (ctx, { limit }) => {
    const scanned = await ctx.db.query("userDevices").take(500);
    const sorted = scanned
      .sort((a, b) => (b.lastSeenAt ?? 0) - (a.lastSeenAt ?? 0))
      .slice(0, Math.min(limit ?? 15, 50));

    const out = [];
    for (const d of sorted) {
      const user = await ctx.db.get(d.userId);
      const row = await ctx.db
        .query("diagnosticDevices")
        .withIndex("by_device", (q) => q.eq("deviceId", d.deviceId))
        .unique();
      out.push({
        deviceId: d.deviceId,
        username: user?.username ?? null,
        platform: d.platform ?? null,
        deviceName: d.deviceName ?? null,
        lastSeenAt: d.lastSeenAt ?? null,
        // So you can see at a glance what is already on, instead of
        // cross-referencing against `list`.
        allowlisted: row != null && row.expiresAt > Date.now(),
      });
    }
    return out;
  },
});

/// Retention sweep. Bounded with `.take` for the reason spelled out at
/// users.sweepStalePresence — an unbounded `.collect()` eventually blows the
/// read limit, at which point the sweep silently stops working and nobody
/// notices. Daily is plenty: the table holds single digits of rows.
export const gcExpiredDevices = internalMutation({
  args: {},
  returns: v.object({ deleted: v.number() }),
  handler: async (ctx) => {
    const cutoff = Date.now() - DIAGNOSTIC_RETENTION_MS;
    const expired = await ctx.db
      .query("diagnosticDevices")
      .withIndex("by_expiresAt", (q) => q.lt("expiresAt", cutoff))
      .take(200);
    for (const row of expired) await ctx.db.delete(row._id);
    return { deleted: expired.length };
  },
});
