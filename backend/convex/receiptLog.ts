/**
 * When each message reached a recipient, without a row per message.
 *
 * The receipt cursors on `roomMembers` (`lastDeliveredAt`, `lastReadAt`) say
 * WHETHER a message got there: it did when the cursor is at or past its
 * `createdAt`. They cannot say WHEN. The one wall-clock stamp beside each
 * cursor (`lastDeliveredClock`, `lastReadClock`) is when it last moved, so
 * every message behind it showed the newest move's time: a message delivered
 * at 23:17 read "delivered 23:18" the moment a later one was read at 23:18.
 *
 * So each cursor keeps a short history of its own moves, `{upTo, at}`: "moved
 * up to the message stamped `upTo`, at wall-clock `at`". A message's time is
 * the first move that covered it. Entries are appended in the same patch that
 * moves the cursor, so this costs no write of its own, and a burst of messages
 * delivered together is one entry, not one per message.
 *
 * `at: 0` marks a stretch whose time is not known: the cursor's position
 * before the log existed, or the entries trimmed off the front once the log is
 * full. A message in that stretch reached the person and has no time to show,
 * which is the honest answer, rather than borrowing a neighbour's.
 */

export type ReceiptLogEntry = { upTo: number; at: number };

/**
 * Moves kept per cursor. Each is ~20 bytes, so a full log is about 4 KB on the
 * membership row. Not served by `getReadState` (the hot subscription every
 * open room holds); only `getReceiptTimes` reads it, while the receipts screen
 * is open. 200 moves is days of an active chat, and nobody checks the minute a
 * month-old message arrived.
 */
export const RECEIPT_LOG_CAP = 200;

/**
 * [log] with the cursor's move from [before] up to [upTo] at [at] appended.
 *
 * If the log does not end where the cursor stood, the gap is closed with an
 * unknown-time entry first. That is the first write to a row from before this
 * existed, and it keeps any future writer that moves a cursor without logging
 * from having its stretch claimed by the next logged move.
 */
export function appendReceiptLog(
  log: ReceiptLogEntry[] | undefined,
  before: number,
  upTo: number,
  at: number,
): ReceiptLogEntry[] {
  const out = [...(log ?? [])];
  const end = out.length > 0 ? out[out.length - 1].upTo : 0;
  if (before > end) out.push({ upTo: before, at: 0 });
  out.push({ upTo, at });
  if (out.length <= RECEIPT_LOG_CAP) return out;
  // Trim from the front, and leave a marker where the trimmed run ended:
  // without it the oldest kept entry would claim every message before it.
  const kept = out.slice(out.length - (RECEIPT_LOG_CAP - 1));
  const lastDropped = out[out.length - RECEIPT_LOG_CAP];
  return [{ upTo: lastDropped.upTo, at: 0 }, ...kept];
}

/**
 * When the cursor this log belongs to first covered a message stamped
 * [createdAt], or null when that is not known — including when the cursor has
 * not reached it at all, which callers tell apart with the cursor itself.
 */
export function receiptTimeFor(
  log: ReceiptLogEntry[] | undefined,
  createdAt: number,
): number | null {
  if (!log) return null;
  for (const e of log) {
    if (e.upTo >= createdAt) return e.at > 0 ? e.at : null;
  }
  return null;
}
