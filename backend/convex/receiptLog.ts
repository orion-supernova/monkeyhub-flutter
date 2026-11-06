/**
 * When each message reached a recipient, without a row per message.
 *
 * The receipt cursors on `roomReceipts` (`lastDeliveredAt`, `lastReadAt`) say
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
 * Moves kept per cursor. Not served by `getReadState` (the hot subscription every
 * open room holds); only `getReceiptTimes` reads it, while the receipts screen
 * is open. 200 moves is days of an active chat, and nobody checks the minute a
 * month-old message arrived.
 */
export const RECEIPT_LOG_CAP = 200;
