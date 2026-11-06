/**
 * Call history in one place (docs/design/calls.md): the `call:` chat bubble
 * and the per-person `callLog` rows.
 *
 * Every terminal path of a 1:1 call (`end`, ring timeout, stuck-active reaper,
 * reject, cancel, stuck-ringing sweep) and of a group call (`endCallIfEmpty`)
 * funnels through `recordDirectCallEnd` / `recordGroupCallEnd`, so what the
 * bubble says and what the Calls tab says cannot drift between paths. Room
 * teardown deliberately does not call them: the room is going away.
 *
 * Both are idempotent (a `callLog` row for the first participant means the
 * call was already recorded), because several sweepers can race to the same
 * terminal transition.
 */
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { isTombstoned } from "./deletionCore";
import { VANISH_PREVIEW, isSeenClockRoom, vanishUntilFor } from "./vanishCore";

/** Handoffs kept per call; a flapping client must not grow the row. */
export const MAX_HANDOFFS = 20;

const QUALITY_RANK = ["good", "fair", "poor"] as const;

export function qualityRank(q: unknown): number {
  const i = QUALITY_RANK.indexOf(q as any);
  return i < 0 ? -1 : i;
}

// ───────────────────────── the `call:` content ─────────────────────────

export type CallFields = {
  v?: number;
  k?: "d" | "g";
  id?: string;
  t?: string;
  s?: "ringing" | "active" | "ended" | "missed" | "declined" | "cancelled";
  a?: number;
  e?: number;
  d?: number;
  n?: number;
  o?: string;
  q?: string;
};

// Fixed key order so the same state always serialises to the same string.
const KEY_ORDER: (keyof CallFields)[] = [
  "v", "k", "id", "t", "s", "a", "e", "d", "n", "o", "q",
];

export function encodeCall(f: CallFields): string {
  const o: Record<string, unknown> = {};
  for (const key of KEY_ORDER) {
    if (f[key] !== undefined) o[key] = f[key];
  }
  return `call:${JSON.stringify(o)}`;
}

export function decodeCall(content: string): CallFields | null {
  if (typeof content !== "string" || !content.startsWith("call:")) return null;
  try {
    const parsed = JSON.parse(content.slice(5));
    return parsed && typeof parsed === "object" ? (parsed as CallFields) : null;
  } catch {
    return null;
  }
}

// ───────────────────────── the message ─────────────────────────

/**
 * Insert the ringing bubble. Follows the huddle line for expiry and vanish;
 * a tombstoned or missing room gets none (null back, the call still works).
 */
export async function openCallMessage(
  ctx: any,
  a: {
    roomId: Id<"rooms">;
    userId: Id<"users">;
    startedAt: number;
    k: "d" | "g";
    id: string;
    t: string;
  },
): Promise<Id<"messages"> | null> {
  const room = await ctx.db.get(a.roomId);
  if (!room || isTombstoned(room)) return null;
  const vanishUntil = vanishUntilFor(room, a.startedAt);
  const expiresAt =
    room.messageLifetime && !isSeenClockRoom(room)
      ? a.startedAt + room.messageLifetime * 1000
      : undefined;
  const messageId = await ctx.db.insert("messages", {
    roomId: a.roomId,
    userId: a.userId,
    content: encodeCall({ v: 1, k: a.k, id: a.id, t: a.t, s: "ringing" }),
    createdAt: a.startedAt,
    type: "system",
    ...(expiresAt !== undefined ? { expiresAt } : {}),
    ...(vanishUntil !== undefined ? { vanishUntil } : {}),
  });
  if (expiresAt !== undefined) {
    await ctx.scheduler.runAt(new Date(expiresAt), internal.messages.expireMessage, {
      messageId,
    });
  }
  return messageId;
}

/**
 * Merge [fields] into the bubble. A message that was deleted or expired in
 * the meantime is skipped (null back). With [settle] it is the final write:
 * the room's last-message line follows, like the huddle line, unless the room
 * is being torn down.
 */
async function patchCallMessage(
  ctx: any,
  messageId: Id<"messages"> | undefined | null,
  fields: CallFields,
  settle?: { at: number },
): Promise<CallFields | null> {
  if (!messageId) return null;
  const msg = await ctx.db.get(messageId);
  if (!msg) return null;
  const cur = decodeCall(msg.content);
  if (!cur) return null;
  const next = { ...cur, ...fields };
  const content = encodeCall(next);
  await ctx.db.patch(messageId, { content });
  if (settle) {
    const room = await ctx.db.get(msg.roomId);
    if (room && !isTombstoned(room)) {
      await ctx.db.patch(msg.roomId, {
        lastMessage: msg.vanishUntil !== undefined ? VANISH_PREVIEW : content,
        lastMessageTime: settle.at,
        lastMessageSenderId: msg.userId,
      });
    }
  }
  return next;
}

/** The call was answered: the bubble goes live (one write, once). */
export async function markCallMessageActive(
  ctx: any,
  messageId: Id<"messages"> | undefined | null,
  a: { at: number; platform?: string },
) {
  await patchCallMessage(ctx, messageId, {
    s: "active",
    a: a.at,
    ...(a.platform !== undefined ? { o: a.platform } : {}),
  });
}

/** Worsen the bubble's quality badge; never improves it. */
export async function worsenCallMessageQuality(
  ctx: any,
  messageId: Id<"messages"> | undefined | null,
  q: string,
) {
  if (!messageId) return;
  const msg = await ctx.db.get(messageId);
  if (!msg) return;
  const cur = decodeCall(msg.content);
  if (!cur || qualityRank(q) <= qualityRank(cur.q)) return;
  await ctx.db.patch(messageId, { content: encodeCall({ ...cur, q }) });
}

// ───────────────────────── 1:1 calls ─────────────────────────

export type DirectEnd = "ended" | "missed" | "rejected" | "cancelled" | "failed";

/**
 * Write the final bubble, the room line and the two `callLog` rows for a 1:1
 * call that just reached [status]. [call] is the row as it was BEFORE the
 * status patch (it carries `acceptedAt`, `messageId`, `handoffs`).
 */
export async function recordDirectCallEnd(
  ctx: any,
  call: any,
  status: DirectEnd,
  endedAt: number,
) {
  // Already recorded: a second terminal transition must not double-write.
  const done = await ctx.db
    .query("callLog")
    .withIndex("by_call_user", (q: any) =>
      q.eq("callId", call._id).eq("userId", call.callerId),
    )
    .first();
  if (done) return;

  const answered = call.acceptedAt !== undefined;
  const durationMs = answered ? Math.max(0, endedAt - call.acceptedAt) : 0;
  const s: NonNullable<CallFields["s"]> =
    status === "ended"
      ? answered
        ? "ended"
        : "cancelled"
      : status === "rejected"
        ? "declined"
        : status === "cancelled"
          ? "cancelled"
          : "missed"; // missed, failed

  const msg = await patchCallMessage(
    ctx,
    call.messageId,
    {
      s,
      e: endedAt,
      ...(answered ? { a: call.acceptedAt, d: durationMs } : {}),
    },
    { at: endedAt },
  );

  // Who answered: written to the bubble at accept; the device row is the
  // fallback for a call whose bubble is gone.
  let answeredOn: string | undefined = msg?.o;
  if (answered && answeredOn === undefined && call.acceptingDeviceId) {
    const dev = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q: any) =>
        q.eq("userId", call.calleeId).eq("deviceId", call.acceptingDeviceId),
      )
      .first();
    answeredOn = dev?.platform;
  }

  const callerOutcome =
    s === "ended"
      ? "answered"
      : s === "declined"
        ? "declined"
        : s === "cancelled"
          ? "cancelled"
          : "unanswered";
  const calleeOutcome =
    s === "ended" ? "answered" : s === "declined" ? "declined" : "missed";

  const shared = {
    roomId: call.roomId,
    kind: "direct" as const,
    callId: call._id,
    type: call.type,
    startedAt: call.startedAt,
    ...(call.ringingAt !== undefined ? { ringingAt: call.ringingAt } : {}),
    ...(answered ? { answeredAt: call.acceptedAt } : {}),
    endedAt,
    durationMs,
    ...(answeredOn !== undefined ? { answeredOn } : {}),
    ...(call.handoffs && call.handoffs.length > 0
      ? { handoffs: call.handoffs }
      : {}),
  };
  await ctx.db.insert("callLog", {
    ...shared,
    userId: call.callerId,
    direction: "out",
    outcome: callerOutcome,
    peerId: call.calleeId,
  });
  await ctx.db.insert("callLog", {
    ...shared,
    userId: call.calleeId,
    direction: "in",
    outcome: calleeOutcome,
    peerId: call.callerId,
  });
}

// ───────────────────────── group calls and huddles ─────────────────────────

/**
 * The group twin of `recordDirectCallEnd`, run when a group call or huddle
 * ends. [rows] are the call's participant rows as they stand at the end
 * (before the ring fan-out flips the remaining invites to `missed`; either
 * way they read as missed here). A huddle keeps its own history line and
 * only gets rows for the people who joined.
 */
export async function recordGroupCallEnd(
  ctx: any,
  call: any,
  rows: any[],
  endedAt: number,
) {
  const huddle = call.kind === "huddle";
  const starterKey = call.startedBy.toString();
  const joined = rows.filter((r) => r.joinedAt !== undefined);
  const others = joined.filter((r) => r.userId.toString() !== starterKey);
  if (huddle && others.length === 0) return; // nobody came: no history

  const starterRow = rows.find((r) => r.userId.toString() === starterKey);
  if (starterRow) {
    const done = await ctx.db
      .query("callLog")
      .withIndex("by_group_call_user", (q: any) =>
        q.eq("groupCallId", call._id).eq("userId", call.startedBy),
      )
      .first();
    if (done) return;
  }

  // The "answered" instant: the first join by someone other than the starter.
  const firstOther: number | undefined =
    call.firstJoinAt ??
    (others.length > 0
      ? Math.min(...others.map((r) => r.joinedAt as number))
      : undefined);
  const answered = firstOther !== undefined;

  if (!huddle) {
    await patchCallMessage(
      ctx,
      call.messageId,
      {
        s: answered ? "ended" : "missed",
        e: endedAt,
        n: joined.length,
        ...(answered ? { a: firstOther, d: Math.max(0, endedAt - firstOther) } : {}),
      },
      { at: endedAt },
    );
  }

  const kind = huddle ? ("huddle" as const) : ("group" as const);
  const base = {
    roomId: call.roomId,
    kind,
    groupCallId: call._id,
    type: call.type,
    startedAt: call.startedAt,
    people: joined.length,
  };
  for (const r of rows) {
    const isStarter = r.userId.toString() === starterKey;
    const didJoin = r.joinedAt !== undefined;
    if (huddle && !didJoin) continue;
    const myEnd: number = didJoin ? (r.leftAt ?? endedAt) : endedAt;
    if (isStarter) {
      // Talk time counts from when someone else was there to talk to.
      const from = answered ? Math.max(firstOther as number, r.joinedAt ?? 0) : undefined;
      await ctx.db.insert("callLog", {
        ...base,
        userId: r.userId,
        direction: "out",
        outcome: answered ? "answered" : "unanswered",
        ...(answered ? { answeredAt: firstOther } : {}),
        endedAt: myEnd,
        durationMs: from !== undefined ? Math.max(0, myEnd - from) : 0,
      });
    } else if (didJoin) {
      await ctx.db.insert("callLog", {
        ...base,
        userId: r.userId,
        direction: "in",
        outcome: "answered",
        peerId: call.startedBy,
        answeredAt: r.joinedAt,
        endedAt: myEnd,
        durationMs: Math.max(0, myEnd - r.joinedAt),
      });
    } else {
      await ctx.db.insert("callLog", {
        ...base,
        userId: r.userId,
        direction: "in",
        outcome: r.status === "declined" ? "declined" : "missed",
        peerId: call.startedBy,
        endedAt,
        durationMs: 0,
      });
    }
  }
}
