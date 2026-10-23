import { internal } from "./_generated/api";
import { attachShared } from "./fileShare";
import {
  ERR_SYSTEM_ACCOUNT,
  MODERATION_ROOM_NAME,
  moderationStaffUsernames,
  REPORTER_DISPLAY_NAME,
  REPORTER_USERNAME,
  SYSTEM_ROOM_MODERATION,
  isSystemAccount,
} from "./systemAccount";
import {
  type SystemRoomSpec,
  provisionSystemInbox,
  resolveStaff,
} from "./systemRooms";
import {
  ERR_FILTER_BLOCKED,
  type FilterCategory,
  screenText,
} from "./contentFilter";

/**
 * The moderation inbox: where content reports and filter hits go.
 *
 * Built exactly the way the "Report a problem" inbox is (`problemReports.ts`),
 * and for the same reason: a chat message is the one transport this app
 * already delivers well. Monkey Reporter, a system account, posts a card per
 * report into a private staff room — so a report arrives with a push, an
 * unread badge and the whole chat stack for reading evidence, instead of as a
 * row in a table nobody opens. The `reports` row is still written, and is the
 * record; the card is how a human finds out about it.
 *
 * Plain helpers taking a mutation `ctx`, importing no mutation module, so
 * `messages.ts` can file a filter hit from inside `send` and `users.ts` a
 * report from inside `report` without either importing the other. The staff
 * actions that need `messages.removeMessageAndFanout` live in `moderation.ts`.
 *
 * ── What the reporter is promised ──────────────────────────────────────────
 *
 * The sheet tells them, before they send, that the reported message and the
 * last few messages around it go to the moderators, and that the other person
 * is not told. Both halves are kept here: the evidence below is that snapshot,
 * and nothing in this file writes anywhere the reported person can read.
 */

export const MODERATION_SPEC: SystemRoomSpec = {
  username: REPORTER_USERNAME,
  displayName: REPORTER_DISPLAY_NAME,
  roomName: MODERATION_ROOM_NAME,
  slug: SYSTEM_ROOM_MODERATION,
};

/** Reports one person may file before they have to wait. */
export const MAX_REPORTS_PER_WINDOW = 10;

/** Filter-hit cards about one author before the filter stops filing more. */
const MAX_FILTER_CARDS_PER_WINDOW = 3;

/** The window both limits are counted over. */
const REPORT_WINDOW_MS = 60 * 60 * 1000;

export const ERR_TOO_MANY_REPORTS = "TOO_MANY_REPORTS";

/** How many messages of the conversation ride along with a report. */
export const EVIDENCE_CONTEXT = 5;

/** Longest excerpt of any one message on a card. */
const EXCERPT_CHARS = 280;

/** Longest free-text note from the reporter. */
const MAX_NOTE_CHARS = 1000;

/** Valid `targetType`s. */
export const REPORT_TARGET_TYPES = [
  "user",
  "message",
  "room",
  // A moment and a comment on one: the feed's user content, which App Review
  // expects to be reportable where it is shown, not only through its author.
  "moment",
  "comment",
] as const;

// ── Provisioning ────────────────────────────────────────────────────────────

/**
 * The account, the room and the staff roster, or null when no staff handle
 * resolves on this deployment (a fresh dev box). Null means "record the
 * report, post no card" — unlike a bug report, a person's report about abuse
 * must never be refused over the deployment's bookkeeping.
 */
async function moderationInbox(
  ctx: any,
): Promise<{ accountId: any; roomId: any } | null> {
  const staff = await resolveStaff(ctx, moderationStaffUsernames());
  if (staff.length === 0) return null;
  return await provisionSystemInbox(ctx, MODERATION_SPEC, staff);
}

// ── Formatting ──────────────────────────────────────────────────────────────

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** `2026-10-15 14:03 UTC`. Staff read these across timezones; UTC is honest. */
function stamp(ms: number): string {
  const d = new Date(ms);
  return (
    `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())} ` +
    `${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())} UTC`
  );
}

function clock(ms: number): string {
  const d = new Date(ms);
  return `${pad2(d.getUTCHours())}:${pad2(d.getUTCMinutes())}`;
}

function excerpt(text: string | undefined, max = EXCERPT_CHARS): string {
  const flat = (text ?? "").replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max)}…` : flat;
}

/** `Ada (@ada)`, or a placeholder for an account that is gone. */
async function who(ctx: any, userId: any): Promise<string> {
  if (!userId) return "unknown";
  const u = await ctx.db.get(userId);
  if (!u) return "deleted account";
  return `${u.name ?? u.username} (@${u.username})`;
}

/** Where it happened, in words a moderator can act on. */
function describeRoom(room: any): string {
  if (!room) return "unknown room";
  const secret =
    room.type === "secret" || (room.messageLifetime ?? 0) > 0
      ? ", self-destructing"
      : "";
  if (typeof room.name === "string" && room.name.startsWith("dm:")) {
    return `Direct message${secret}`;
  }
  const vis = room.isPrivate ? "private" : "public";
  return `Group "${excerpt(room.name, 60)}" (${vis}${secret}, ${room.memberCount ?? 0} members)`;
}

/** One message as a line of evidence. Never hands out a view-once picture. */
function describeMessage(m: any, max = EXCERPT_CHARS): string {
  const type = m.type ?? "text";
  if (m.viewOnce === true) return "[view-once media, not included]";
  const caption = excerpt(m.content, max);
  const tag: Record<string, string> = {
    image: "[photo]",
    video: "[video]",
    videoNote: "[video note]",
    audio: "[voice message]",
    file: `[file${m.fileName ? `: ${excerpt(m.fileName, 60)}` : ""}]`,
    gif: "[GIF]",
    sticker: "[sticker]",
    location: "[location]",
    liveLocation: "[live location]",
    poll: "[poll]",
    checklist: "[checklist]",
    event: "[event]",
    gameMove: "[game move]",
  };
  const prefix = tag[type];
  if (prefix) return caption ? `${prefix} ${caption}` : prefix;
  return caption || "[empty]";
}

/** Media types whose blob is attached to the card as evidence. */
const EVIDENCE_MEDIA_TYPES = new Set(["image", "video", "videoNote", "audio", "file"]);

// ── Evidence ────────────────────────────────────────────────────────────────

type Evidence = { lines: string[]; media: any[] };

/**
 * The reported message and the [EVIDENCE_CONTEXT] messages before it, oldest
 * first, as text lines plus the messages whose media should be attached.
 *
 * Self-destructing rooms are included, as WhatsApp does: the snapshot is the
 * whole point of reporting a message that is about to vanish. It lives on in
 * the moderation room under that room's retention (`moderation.ts`), not the
 * source room's lifetime. View-once media is the exception — its promise is
 * that the picture is seen once, by its recipient — so it is named, not
 * attached.
 *
 * Only for a reporter who can read the room. A report is not a way to read a
 * private conversation one is not in, even if the only reader is staff.
 */
async function collectEvidence(
  ctx: any,
  roomId: any,
  reporterId: any,
  anchor: any | null,
): Promise<Evidence> {
  const room = await ctx.db.get(roomId);
  if (!room) return { lines: [], media: [] };
  const member = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", reporterId),
    )
    .first();
  if (!member && room.isPrivate !== false) return { lines: [], media: [] };

  const rows = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) =>
      anchor
        ? q.eq("roomId", roomId).lte("createdAt", anchor.createdAt)
        : q.eq("roomId", roomId),
    )
    .order("desc")
    .take(EVIDENCE_CONTEXT + 1);
  // The anchor is normally the first row, but two messages can share a
  // millisecond; make sure it is in the set whatever the tie-break did.
  if (anchor && !rows.some((r: any) => r._id === anchor._id)) {
    rows.pop();
    rows.unshift(anchor);
  }
  rows.reverse();

  const names = new Map<string, string>();
  const lines: string[] = [];
  const media: any[] = [];
  for (const m of rows) {
    const key = m.userId.toString();
    if (!names.has(key)) names.set(key, await who(ctx, m.userId));
    const marker = anchor && m._id === anchor._id ? "▶ " : "";
    lines.push(`${marker}${clock(m.createdAt)} ${names.get(key)}: ${describeMessage(m)}`);
    if (
      m.mediaStorageId &&
      m.viewOnce !== true &&
      EVIDENCE_MEDIA_TYPES.has(m.type ?? "text")
    ) {
      media.push(m);
    }
  }
  return { lines, media };
}

// ── Evidence snapshot ───────────────────────────────────────────────────────

/** Longest reported text kept on the report row. */
const EVIDENCE_TEXT_CHARS = 4000;
/** Longest reported text shown on the card itself. */
const CARD_TEXT_CHARS = 1500;

type Snapshot = {
  evidence: {
    kind: string;
    text?: string;
    authorName?: string;
    authorUsername?: string;
    contentType?: string;
    contentAt?: number;
    fileName?: string;
    mimeType?: string;
    capturedAt: number;
  };
  mediaStorageId?: any;
  posterStorageId?: any;
};

/**
 * The reported content as it is right now, to be stored ON the report: the
 * words, who wrote them under which name, when, and the media file. A later
 * edit or delete of the content, or of the author's account, cannot change it.
 * View-once media is never kept (its promise is that it is seen once); the
 * words around it are.
 */
async function snapshotContent(
  ctx: any,
  kind: "message" | "moment" | "comment" | "filter",
  row: { authorId: any; text?: string; type?: string; at?: number; media?: any },
): Promise<Snapshot> {
  const author = row.authorId ? await ctx.db.get(row.authorId) : null;
  const text = (row.text ?? "").trim().slice(0, EVIDENCE_TEXT_CHARS);
  const m = row.media;
  return {
    evidence: {
      kind,
      ...(text ? { text } : {}),
      ...(author
        ? { authorName: author.name ?? author.username, authorUsername: author.username }
        : {}),
      ...(row.type ? { contentType: row.type } : {}),
      ...(row.at !== undefined ? { contentAt: row.at } : {}),
      ...(m?.fileName ? { fileName: m.fileName } : {}),
      ...(m?.mimeType ? { mimeType: m.mimeType } : {}),
      capturedAt: Date.now(),
    },
    ...(m?.mediaStorageId ? { mediaStorageId: m.mediaStorageId } : {}),
    ...(m?.posterStorageId ? { posterStorageId: m.posterStorageId } : {}),
  };
}

/** Gives the report its own ref on the media it snapshotted. */
async function holdEvidenceFiles(ctx: any, reportId: any, snap: Snapshot): Promise<void> {
  for (const [field, id] of [
    ["evidenceMediaStorageId", snap.mediaStorageId],
    ["evidencePosterStorageId", snap.posterStorageId],
  ] as const) {
    await attachShared(ctx, id, { table: "reports", id: reportId.toString(), field });
  }
}

// ── Posting ─────────────────────────────────────────────────────────────────

/**
 * Posts [text] as Monkey Reporter, followed by [media] as evidence bubbles,
 * and pushes the staff once. Returns the card's message id.
 *
 * Evidence media re-references the original blob rather than copying it,
 * exactly as forwarding does: each bubble share-attaches its own ref, so the
 * blob is only deleted when nothing points at it any more and the evidence
 * survives the source message being deleted, expiring, or removed by a moderator.
 */
/** Whether [userId] is banned right now. False for no one. */
async function isSuspended(ctx: any, userId: any): Promise<boolean> {
  if (!userId) return false;
  return (await ctx.db.get(userId))?.suspendedAt !== undefined;
}

async function postAsReporter(
  ctx: any,
  inbox: { accountId: any; roomId: any },
  text: string,
  card: {
    reportId: any;
    hasMessage: boolean;
    hasContent?: boolean;
    hasUser: boolean;
    userBanned: boolean;
  } | null,
  media: any[] = [],
): Promise<any> {
  const { accountId, roomId } = inbox;
  // `Date.now()` is frozen for the mutation; offset per row so the card sorts
  // above its own evidence. Same trick as `problemReports.submit`.
  const now = Date.now();
  let seq = 0;
  const messageId = await ctx.db.insert("messages", {
    roomId,
    userId: accountId,
    content: text,
    createdAt: now + seq++,
    type: "text",
    senderName: REPORTER_DISPLAY_NAME,
    ...(card ? { moderationCard: card } : {}),
  });
  for (const m of media) {
    const evidenceId = await ctx.db.insert("messages", {
      roomId,
      userId: accountId,
      content: "",
      createdAt: now + seq++,
      type: m.type,
      mediaStorageId: m.mediaStorageId,
      posterStorageId: m.posterStorageId,
      mediaWidth: m.mediaWidth,
      mediaHeight: m.mediaHeight,
      mediaDurationMs: m.mediaDurationMs,
      fileName: m.fileName,
      fileSize: m.fileSize,
      mimeType: m.mimeType,
      senderName: REPORTER_DISPLAY_NAME,
    });
    // The bubble holds the blob alongside the source message.
    for (const field of ["mediaStorageId", "posterStorageId"]) {
      await attachShared(ctx, m[field], {
        table: "messages",
        id: evidenceId.toString(),
        field,
      });
    }
  }
  const preview = excerpt(text.split("\n")[0], 100);
  await ctx.db.patch(roomId, {
    lastMessage: preview,
    lastMessageTime: now + seq - 1,
    lastMessageSenderId: accountId,
  });
  // The "report alert to the developer": one push for the card, none for
  // its evidence bubbles.
  await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
    roomId,
    messageId,
    senderId: accountId,
    senderName: REPORTER_DISPLAY_NAME,
    content: preview,
    type: "text",
  });
  return messageId;
}

/**
 * A one-line follow-up under a card: what a moderator did. Posted as Monkey
 * Reporter so the room stays read-only for people, and quoted as a reply to
 * the card so the outcome sits on the thing it answers.
 */
export async function postOutcome(ctx: any, report: any, text: string) {
  const inbox = await moderationInbox(ctx);
  if (!inbox) return;
  const card = report.cardMessageId ? await ctx.db.get(report.cardMessageId) : null;
  const now = Date.now();
  const messageId = await ctx.db.insert("messages", {
    roomId: inbox.roomId,
    userId: inbox.accountId,
    content: text,
    createdAt: now,
    type: "text",
    senderName: REPORTER_DISPLAY_NAME,
    ...(card
      ? {
          replyToId: card._id,
          rootId: card.rootId ?? card._id,
          replyToPreview: {
            senderId: inbox.accountId,
            senderName: REPORTER_DISPLAY_NAME,
            contentPreview: excerpt(card.content.split("\n")[0], 140),
            type: "text",
          },
        }
      : {}),
  });
  await ctx.db.patch(inbox.roomId, {
    lastMessage: excerpt(text, 100),
    lastMessageTime: now,
    lastMessageSenderId: inbox.accountId,
  });
  return messageId;
}

// ── Filing a report ─────────────────────────────────────────────────────────

const REASON_LABELS: Record<string, string> = {
  SPAM: "Spam",
  HARASSMENT: "Harassment or bullying",
  IMPERSONATION: "Impersonation",
  INAPPROPRIATE: "Sexual, violent or illegal content",
  OTHER: "Other",
};

function reasonLabel(reason: string): string {
  const code = reason.split(":")[0].trim();
  return REASON_LABELS[code] ?? excerpt(reason, 80);
}

export type FiledReport = {
  reportId: any;
  /** The person on the other end, when there is one: the block target. */
  reportedUserId: any | null;
  /** False when this reporter already had an open report on the target. */
  fresh: boolean;
};

/**
 * Files one content report: the `reports` row, then Monkey Reporter's card
 * with the evidence snapshot.
 *
 * [evidenceRoomId] is for a report on a PERSON: the caller's DM with them, if
 * any, whose last messages are the context a moderator needs. Passed in rather
 * than looked up here so this module does not import `roomCleanup.ts` (which
 * would cycle back into `messages.ts`).
 *
 * A repeat — the same reporter, the same target, still open — is recorded as
 * nothing new and posts no second card: one person tapping report five times
 * is one report, not five alerts.
 */
export async function fileContentReport(
  ctx: any,
  args: {
    reporterId: any;
    targetType: string;
    targetId: string;
    reason: string;
    note?: string;
    evidenceRoomId?: any;
  },
): Promise<FiledReport> {
  const { reporterId, targetType, targetId } = args;
  if (!(REPORT_TARGET_TYPES as readonly string[]).includes(targetType)) {
    throw new Error("INVALID_TARGET_TYPE");
  }

  // Throttle first, before anything is created.
  const since = Date.now() - REPORT_WINDOW_MS;
  const recent = await ctx.db
    .query("reports")
    .withIndex("by_reporter", (q: any) => q.eq("reporterId", reporterId))
    .order("desc")
    .take(MAX_REPORTS_PER_WINDOW);
  if (
    recent.length >= MAX_REPORTS_PER_WINDOW &&
    recent.every((r: any) => r.createdAt > since)
  ) {
    throw new Error(ERR_TOO_MANY_REPORTS);
  }

  // Resolve what was reported into ids a moderator's action can use.
  let message: any = null;
  let room: any = null;
  let reportedUserId: any = null;
  // What a moment or comment report shows the moderator, in place of a
  // message: the words, and what kind of media came with them.
  const feedLines: string[] = [];
  // A moment or comment that exists, so the card can offer to remove it.
  let hasContent = false;
  const db = ctx.db;
  if (targetType === "moment") {
    const id = db.normalizeId("moments", targetId);
    const moment = id ? await db.get(id) : null;
    if (moment) {
      hasContent = true;
      reportedUserId = moment.userId;
      feedLines.push(
        "",
        "Reported moment:",
        `» ${excerpt(moment.caption ?? "", CARD_TEXT_CHARS) || "(no caption)"}` +
          (moment.mediaStorageId ? " [with photo/video]" : ""),
      );
    } else {
      feedLines.push("", "Reported moment: [already deleted]");
    }
  } else if (targetType === "comment") {
    const id = db.normalizeId("momentComments", targetId);
    const comment = id ? await db.get(id) : null;
    if (comment) {
      hasContent = true;
      reportedUserId = comment.userId;
      const on = await db.get(comment.momentId);
      feedLines.push(
        "",
        "Reported comment:",
        `» ${excerpt(comment.text ?? "", CARD_TEXT_CHARS) || "(sticker or reaction)"}`,
        ...(on ? [`On a moment by: ${await who(ctx, on.userId)}`] : []),
      );
    } else {
      feedLines.push("", "Reported comment: [already deleted]");
    }
  } else if (targetType === "message") {
    const id = db.normalizeId("messages", targetId);
    message = id ? await db.get(id) : null;
    if (message) {
      reportedUserId = message.userId;
      room = await db.get(message.roomId);
    }
  } else if (targetType === "room") {
    const id = db.normalizeId("rooms", targetId);
    room = id ? await db.get(id) : null;
  } else {
    const id = db.normalizeId("users", targetId);
    reportedUserId = id && (await db.get(id)) ? id : null;
    if (args.evidenceRoomId) room = await db.get(args.evidenceRoomId);
  }
  if (reportedUserId && reportedUserId.toString() === reporterId.toString()) {
    throw new Error("CANT_REPORT_SELF");
  }
  if (reportedUserId && isSystemAccount(await db.get(reportedUserId))) {
    throw new Error(ERR_SYSTEM_ACCOUNT);
  }

  const existing = await ctx.db
    .query("reports")
    .withIndex("by_target", (q: any) =>
      q.eq("targetType", targetType).eq("targetId", targetId),
    )
    .order("desc")
    .take(25);
  const repeat = existing.find(
    (r: any) =>
      r.reporterId?.toString() === reporterId.toString() &&
      (r.status ?? "open") === "open",
  );
  if (repeat) {
    return { reportId: repeat._id, reportedUserId, fresh: false };
  }

  // Frozen now, before anything can delete it.
  let snap: Snapshot | null = null;
  let momentMedia: any = null;
  if (targetType === "message" && message) {
    snap = await snapshotContent(ctx, "message", {
      authorId: message.userId,
      text: message.content,
      type: message.type ?? "text",
      at: message.createdAt,
      media:
        message.viewOnce !== true &&
        message.mediaStorageId &&
        EVIDENCE_MEDIA_TYPES.has(message.type ?? "text")
          ? message
          : undefined,
    });
  } else if (targetType === "moment" && hasContent) {
    const moment = await db.get(db.normalizeId("moments", targetId));
    snap = await snapshotContent(ctx, "moment", {
      authorId: moment.userId,
      text: moment.caption,
      type: moment.mediaKind,
      at: moment.createdAt,
      media: moment.mediaStorageId ? moment : undefined,
    });
    if (moment.mediaStorageId) {
      momentMedia = {
        type: moment.mediaKind === "video" ? "video" : "image",
        mediaStorageId: moment.mediaStorageId,
        posterStorageId: moment.posterStorageId,
      };
    }
  } else if (targetType === "comment" && hasContent) {
    const comment = await db.get(db.normalizeId("momentComments", targetId));
    snap = await snapshotContent(ctx, "comment", {
      authorId: comment.userId,
      text: comment.text,
      at: comment.createdAt,
    });
  }

  const note = args.note?.trim().slice(0, MAX_NOTE_CHARS);
  const reportId = await ctx.db.insert("reports", {
    reporterId,
    targetType,
    targetId,
    reason: args.reason.slice(0, 500),
    note: note && note.length > 0 ? note : undefined,
    createdAt: Date.now(),
    status: "open",
    source: "user",
    ...(reportedUserId ? { reportedUserId } : {}),
    ...(message ? { messageId: message._id } : {}),
    ...(room ? { roomId: room._id } : {}),
    ...(snap
      ? {
          evidence: snap.evidence,
          ...(snap.mediaStorageId ? { evidenceMediaStorageId: snap.mediaStorageId } : {}),
          ...(snap.posterStorageId ? { evidencePosterStorageId: snap.posterStorageId } : {}),
        }
      : {}),
  });
  if (snap) await holdEvidenceFiles(ctx, reportId, snap);

  const inbox = await moderationInbox(ctx);
  if (inbox) {
    const evidence = room
      ? await collectEvidence(ctx, room._id, reporterId, message)
      : { lines: [], media: [] };
    const header: string[] = [
      `🚩 REPORT · ${targetType.toUpperCase()}`,
      `Reason: ${reasonLabel(args.reason)}`,
      ...(note ? [`Note: ${excerpt(note, 500)}`] : []),
      `Reporter: ${await who(ctx, reporterId)}`,
      ...(reportedUserId ? [`Reported: ${await who(ctx, reportedUserId)}`] : []),
      ...(room ? [`Where: ${describeRoom(room)}`] : []),
      `Filed: ${stamp(Date.now())}`,
      `Ref: ${reportId}`,
    ];
    const body: string[] = [];
    body.push(...feedLines);
    if (message) {
      body.push("", "Reported message:", `» ${describeMessage(message, CARD_TEXT_CHARS)}`);
    } else if (targetType === "message") {
      body.push("", "Reported message: [already deleted]");
    }
    if (evidence.lines.length > 0) {
      body.push("", "Conversation (oldest first, UTC):", ...evidence.lines);
    }
    body.push("", "Long-press this card to act on it.");
    const cardMessageId = await postAsReporter(
      ctx,
      inbox,
      [...header, ...body].join("\n"),
      {
        reportId,
        hasMessage: message !== null,
        ...(targetType === "moment" || targetType === "comment"
          ? { hasContent }
          : {}),
        hasUser: reportedUserId !== null,
        userBanned: await isSuspended(ctx, reportedUserId),
      },
      momentMedia ? [...evidence.media, momentMedia] : evidence.media,
    );
    await ctx.db.patch(reportId, { cardMessageId });
  }

  return { reportId, reportedUserId, fresh: true };
}

// ── Filing a filter hit ─────────────────────────────────────────────────────

const CATEGORY_LABELS: Record<FilterCategory, string> = {
  slur: "slur",
  sexual: "sexual language",
  profanity: "profanity",
};

/**
 * Files what the text filter caught on its own: a hard slur anywhere, or
 * sexual or abusive language involving a child. No human reporter, so
 * `reporterId` is absent and `source` is "filter".
 *
 * Throttled per AUTHOR: somebody who types the same slur ten times in a
 * minute is one incident for a moderator, and the eleventh card would only
 * bury the others. Throttled hits are still masked or blocked; they just stop
 * paging staff.
 */
export async function fileFilterHit(
  ctx: any,
  args: {
    authorId: any;
    roomId?: any;
    /** "message", "edit", "moment", "comment". */
    surface: string;
    text: string;
    categories: FilterCategory[];
    terms: string[];
    /** True when the text was refused outright (a child was involved). */
    blocked: boolean;
    /** True when a child wrote it or would have received it. */
    childInvolved: boolean;
  },
): Promise<void> {
  const authorKey = args.authorId.toString();
  const recent = await ctx.db
    .query("reports")
    .withIndex("by_target", (q: any) =>
      q.eq("targetType", "user").eq("targetId", authorKey),
    )
    .order("desc")
    .take(20);
  const since = Date.now() - REPORT_WINDOW_MS;
  const recentHits = recent.filter(
    (r: any) => r.source === "filter" && r.createdAt > since,
  );
  if (recentHits.length >= MAX_FILTER_CARDS_PER_WINDOW) return;

  const room = args.roomId ? await ctx.db.get(args.roomId) : null;
  const snap = await snapshotContent(ctx, "filter", {
    authorId: args.authorId,
    text: args.text,
    type: args.surface,
  });
  const reportId = await ctx.db.insert("reports", {
    evidence: snap.evidence,
    targetType: "user",
    targetId: authorKey,
    reason: `FILTER: ${args.categories.join(", ")}`,
    createdAt: Date.now(),
    status: "open",
    source: "filter",
    reportedUserId: args.authorId,
    ...(room ? { roomId: room._id } : {}),
  });

  const inbox = await moderationInbox(ctx);
  if (!inbox) return;
  const lines = [
    `🤖 FILTER HIT · ${args.surface.toUpperCase()}`,
    `Caught: ${args.categories.map((c) => CATEGORY_LABELS[c]).join(", ")}`,
    `Terms: ${args.terms.map((t) => `"${excerpt(t, 40)}"`).join(", ")}`,
    `Author: ${await who(ctx, args.authorId)}`,
    ...(room ? [`Where: ${describeRoom(room)}`] : []),
    `Child involved: ${args.childInvolved ? "yes" : "no"}`,
    `Outcome: ${args.blocked ? "blocked, not delivered" : "delivered masked"}`,
    `Filed: ${stamp(Date.now())}`,
    `Ref: ${reportId}`,
    "",
    "Text as typed:",
    `» ${excerpt(args.text, 500)}`,
    "",
    "Long-press this card to act on it.",
  ];
  const cardMessageId = await postAsReporter(ctx, inbox, lines.join("\n"), {
    reportId,
    hasMessage: false,
    hasUser: true,
    userBanned: await isSuspended(ctx, args.authorId),
  });
  await ctx.db.patch(reportId, { cardMessageId });
}

// ── Screening ───────────────────────────────────────────────────────────────

/**
 * Thrown when the filter refuses text outright. Its message is the standard
 * code, so an uncaught one reads like any other guard refusal; a caller that
 * must keep the moderator card it filed catches it and answers with the code
 * as a value (`messages.send`).
 */
export class FilterBlockedError extends Error {
  constructor() {
    super(ERR_FILTER_BLOCKED);
  }
}

/**
 * The filter's policy applied to one piece of user text, with the moderator
 * card filed when the verdict asks for one. Returns the text to store (masked
 * when needed) or throws [FilterBlockedError].
 *
 * The card is filed BEFORE the throw, so a caller that catches the refusal
 * keeps it; an uncaught refusal rolls it back with everything else.
 *
 * Callers answer [childInvolved] themselves, and should only pay to answer it
 * after `contentFilter.hasHit` says there is a hit at all.
 */
export async function screenAndReport(
  ctx: any,
  args: {
    text: string;
    authorId: any;
    childInvolved: boolean;
    surface: string;
    roomId?: any;
  },
): Promise<string> {
  const verdict = screenText(args.text, args.childInvolved);
  if (verdict.report) {
    await fileFilterHit(ctx, {
      authorId: args.authorId,
      roomId: args.roomId,
      surface: args.surface,
      text: args.text,
      categories: verdict.categories,
      terms: verdict.terms,
      blocked: verdict.action === "block",
      childInvolved: args.childInvolved,
    });
  }
  if (verdict.action === "block") throw new FilterBlockedError();
  return verdict.text;
}
