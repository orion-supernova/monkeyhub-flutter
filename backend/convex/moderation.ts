import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { mutation } from "./functions";
import { v } from "convex/values";
import { removeMessageAndFanout } from "./messages";
import { removeMembership } from "./roomAdmin";
import {
  REPORTER_USERNAME,
  isModerationStaff,
  isSystemAccount,
  isSystemRoom,
} from "./systemAccount";
import { postOutcome } from "./moderationCore";
import { deleteMomentCore } from "./momentCleanup";
import { deleteCommentCore } from "./momentComments";
import { REPORT_RETENTION_MS } from "./users";
import { markOffline } from "./presenceCore";
import { SESSION_LIVE_CAP } from "./sessionCore";

/** Sessions revoked per transaction; a full page schedules the continuation. */
const SUSPEND_SESSIONS_MAX = SESSION_LIVE_CAP * 2;

/**
 * Keep revoking a suspended account's live sessions, a page at a time, for
 * legacy accounts that hold more than one page. Stops when none are live, or
 * when the ban was lifted meanwhile.
 */
export const revokeSuspendedSessions = internalMutation({
  args: { userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (!user || user.suspendedAt === undefined) return null;
    const now = Date.now();
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user_live_seen", (q) =>
        q.eq("userId", userId).eq("revokedAt", undefined),
      )
      .take(SUSPEND_SESSIONS_MAX);
    for (const s of rows) {
      await ctx.db.patch(s._id, { revokedAt: now, revokedReason: "suspended" });
    }
    if (rows.length === SUSPEND_SESSIONS_MAX) {
      await ctx.scheduler.runAfter(0, internal.moderation.revokeSuspendedSessions, { userId });
    }
    return null;
  },
});

/**
 * What a moderator can do from a report card in the moderation room.
 *
 * The promise behind it is the one App Store Guideline 1.2 asks for and the
 * report sheet makes to the user: reports are reviewed, and objectionable
 * content and abusive users are acted on, within 24 hours. These are the
 * actions: remove the reported message for everyone, ban (suspend) the person
 * — reversibly — or dismiss the report. Each updates the `reports` row and
 * posts a one-line outcome under the card, so the room doubles as the audit
 * log of what was decided. The line is signed "MonkeyHub", never a
 * username: who pressed the button is recorded on the report row
 * (`actionedBy`), not broadcast.
 *
 * ── Who may act ─────────────────────────────────────────────────────────────
 *
 * Staff only, decided HERE against `moderationStaffUsernames()` and the
 * caller's own row — never against room membership, which the client shows
 * the buttons from but which is a row a bug could create. A caller who is not
 * staff gets NOT_AUTHORIZED whatever card id they hold.
 */

export const ERR_NOT_STAFF = "NOT_AUTHORIZED";
export const ERR_REPORT_NOT_FOUND = "REPORT_NOT_FOUND";
/** Banning a moderator or a system account is refused. */
export const ERR_CANT_BAN = "CANT_BAN_ACCOUNT";

async function assertStaff(ctx: any, userId: any) {
  const me = await ctx.db.get(userId);
  if (!isModerationStaff(me)) throw new Error(ERR_NOT_STAFF);
  return me;
}

/**
 * Suspends [targetId]: blocks sign-in and every live session, hides the
 * account from search, and takes it out of every public room.
 *
 * Sessions are REVOKED, not merely refused, so the push senders (which read
 * live sessions) stop ringing the banned person's handsets too. Their next
 * call answers ACCOUNT_SUSPENDED, which the client shows on the login screen
 * — see `sessionCore.requireSession`.
 *
 * Private rooms and DMs are left alone: the people in those chose this person
 * and can block or remove them themselves, and wiping someone's private
 * history is not reversible the way a ban must be. Public rooms are where a
 * stranger meets them, so those memberships go (through the same teardown as
 * an admin removing them, which re-seats ownership if they held it).
 */
export async function suspendAccount(ctx: any, targetId: any, byId: any) {
  const target = await ctx.db.get(targetId);
  if (!target) throw new Error("USER_NOT_FOUND");
  if (isSystemAccount(target) || isModerationStaff(target)) {
    throw new Error(ERR_CANT_BAN);
  }
  const now = Date.now();
  await ctx.db.patch(targetId, {
    suspendedAt: now,
    suspendedBy: byId,
    status: "offline",
  });
  const sessions = await ctx.db
    .query("sessions")
    .withIndex("by_user_live_seen", (q: any) =>
      q.eq("userId", targetId).eq("revokedAt", undefined),
    )
    .take(SUSPEND_SESSIONS_MAX);
  for (const s of sessions) {
    await ctx.db.patch(s._id, { revokedAt: now, revokedReason: "suspended" });
  }
  if (sessions.length === SUSPEND_SESSIONS_MAX) {
    await ctx.scheduler.runAfter(0, internal.moderation.revokeSuspendedSessions, {
      userId: targetId,
    });
  }
  // `users.status` was patched above, so don't mirror it again.
  await markOffline(ctx, targetId, { now, mirror: false });
  const memberships = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", targetId))
    .collect();
  for (const m of memberships) {
    const room = await ctx.db.get(m.roomId);
    if (!room || room.isPrivate !== false || isSystemRoom(room)) continue;
    await removeMembership(ctx, room._id, targetId);
  }
}

/** Lifts a suspension. Sessions stay revoked; the person signs in again. */
export async function unsuspendAccount(ctx: any, targetId: any) {
  const target = await ctx.db.get(targetId);
  if (!target) throw new Error("USER_NOT_FOUND");
  if (target.suspendedAt === undefined) return;
  await ctx.db.patch(targetId, { suspendedAt: undefined, suspendedBy: undefined });
}

/**
 * Sets `userBanned` on every report card about [userId], so each one offers
 * Ban or Unban to match the account as it is now, not as it was when that
 * card was posted. Every card, not only the one acted on: a second report
 * about someone already banned must not offer to ban them again.
 */
async function syncCardBanState(ctx: any, userId: any, banned: boolean) {
  const reports = await ctx.db
    .query("reports")
    .withIndex("by_reportedUser", (q: any) => q.eq("reportedUserId", userId))
    .collect();
  for (const r of reports) {
    const card = r.cardMessageId ? await ctx.db.get(r.cardMessageId) : null;
    if (!card?.moderationCard || card.moderationCard.userBanned === banned) continue;
    await ctx.db.patch(card._id, {
      moderationCard: { ...card.moderationCard, userBanned: banned },
    });
  }
}

/**
 * Sets `hasContent` on every card about the moment or comment [targetId], so
 * a second report about something already removed stops offering Remove.
 */
async function syncCardContentState(
  ctx: any,
  targetType: string,
  targetId: string,
  hasContent: boolean,
) {
  const reports = await ctx.db
    .query("reports")
    .withIndex("by_target", (q: any) =>
      q.eq("targetType", targetType).eq("targetId", targetId),
    )
    .take(100);
  for (const r of reports) {
    const card = r.cardMessageId ? await ctx.db.get(r.cardMessageId) : null;
    if (!card?.moderationCard || card.moderationCard.hasContent === hasContent) {
      continue;
    }
    await ctx.db.patch(card._id, {
      moderationCard: { ...card.moderationCard, hasContent },
    });
  }
}

/**
 * The one moderator mutation. One entry point with an `action` rather than
 * four mutations, so the staff check, the report lookup and the outcome line
 * cannot be forgotten by whichever action is added fifth.
 */
export const act = mutation({
  args: {
    userId: v.id("users"),
    reportId: v.id("reports"),
    action: v.union(
      v.literal("removeMessage"),
      v.literal("removeContent"),
      v.literal("ban"),
      v.literal("unban"),
      v.literal("dismiss"),
    ),
  },
  returns: v.object({ ok: v.boolean(), outcome: v.string() }),
  handler: async (ctx, { userId, reportId, action }) => {
    await assertStaff(ctx, userId);
    const report = await ctx.db.get(reportId);
    if (!report) throw new Error(ERR_REPORT_NOT_FOUND);
    let outcome: string;

    switch (action) {
      case "removeMessage": {
        const msg = report.messageId ? await ctx.db.get(report.messageId) : null;
        if (msg) {
          // Never a message in the moderation room itself: the card's own
          // evidence is not what anybody reported.
          const room = await ctx.db.get(msg.roomId);
          if (isSystemRoom(room)) throw new Error(ERR_NOT_STAFF);
          await removeMessageAndFanout(ctx, msg, msg._id);
          outcome = "✅ Message removed for everyone by MonkeyHub.";
        } else {
          outcome = "ℹ️ Message was already gone. Checked by MonkeyHub.";
        }
        break;
      }
      case "removeContent": {
        // A reported moment or comment, through the same delete cores the
        // author's own delete uses, so children and files go with it. The
        // author's account may be mid-deletion; nothing here reads it. The
        // card's excerpt is its own text and stays as the evidence.
        if (report.targetType !== "moment" && report.targetType !== "comment") {
          throw new Error("NOT_REMOVABLE");
        }
        const isMoment = report.targetType === "moment";
        const id = ctx.db.normalizeId(
          isMoment ? "moments" : "momentComments",
          report.targetId,
        );
        const row = id ? await ctx.db.get(id) : null;
        if (row) {
          if (isMoment) await deleteMomentCore(ctx, row);
          else await deleteCommentCore(ctx, row);
        }
        await syncCardContentState(ctx, report.targetType, report.targetId, false);
        const noun = isMoment ? "Moment" : "Comment";
        outcome = row
          ? `✅ ${noun} removed for everyone by MonkeyHub.`
          : `ℹ️ ${noun} was already gone. Checked by MonkeyHub.`;
        break;
      }
      case "ban": {
        if (!report.reportedUserId) throw new Error("USER_NOT_FOUND");
        await suspendAccount(ctx, report.reportedUserId, userId);
        await syncCardBanState(ctx, report.reportedUserId, true);
        const u = await ctx.db.get(report.reportedUserId);
        outcome = `⛔ @${u?.username ?? "unknown"} was banned by MonkeyHub. Long-press the card to unban.`;
        break;
      }
      case "unban": {
        if (!report.reportedUserId) throw new Error("USER_NOT_FOUND");
        await unsuspendAccount(ctx, report.reportedUserId);
        await syncCardBanState(ctx, report.reportedUserId, false);
        const u = await ctx.db.get(report.reportedUserId);
        outcome = `↩️ @${u?.username ?? "unknown"} was unbanned by MonkeyHub.`;
        break;
      }
      case "dismiss": {
        outcome = "🗂 Dismissed by MonkeyHub. No action taken.";
        break;
      }
    }

    await ctx.db.patch(reportId, {
      status: action === "dismiss" ? "dismissed" : "actioned",
      action,
      actionedBy: userId,
      actionedAt: Date.now(),
    });
    await postOutcome(ctx, report, outcome);
    return { ok: true, outcome };
  },
});

/**
 * Deletes moderation-room messages older than the report retention period.
 *
 * The evidence snapshot outlives its source on purpose (a self-destructing
 * message that was reported must still be readable by whoever reviews it), so
 * it needs a lifetime of its own, and the one already published for reports —
 * 24 months — is the honest one. Through `removeMessageAndFanout`, so evidence
 * media is released exactly when nothing else points at it.
 *
 * Batched at 100 per day; the room is low-traffic, so a backlog drains fast.
 */
export const gcExpiredEvidence = internalMutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const account = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", REPORTER_USERNAME))
      .first();
    if (!account || !isSystemAccount(account)) return null;
    const memberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", account._id))
      .collect();
    const cutoff = Date.now() - REPORT_RETENTION_MS;
    for (const m of memberships) {
      const room = await ctx.db.get(m.roomId);
      if (!isSystemRoom(room)) continue;
      const old = await ctx.db
        .query("messages")
        .withIndex("by_room_time", (q) =>
          q.eq("roomId", m.roomId).lt("createdAt", cutoff),
        )
        .take(100);
      for (const msg of old) await removeMessageAndFanout(ctx, msg, msg._id);
    }
    return null;
  },
});
