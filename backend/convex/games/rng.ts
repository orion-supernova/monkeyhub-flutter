/**
 * Seeded randomness shared by every daily game.
 *
 * The whole daily-game model rests on one property: **the puzzle is a pure
 * function of the day key**. There is no `gameDays` table, no seeding job and
 * no row to create, which means no race between the day's first two players,
 * nothing to back-fill when a new game ships, and no way for two friends to be
 * handed different boards for the same day — which would quietly make the
 * shared standings compare nothing.
 *
 * That only holds if the randomness is reproducible, so `Math.random` is out
 * everywhere below this line.
 */

/**
 * mulberry32 — small, fast, and good enough that a group of friends will not
 * reverse-engineer a reliably-strong opening from it by week three.
 *
 * Copied in shape from `puzzle.ts` rather than imported from it, because that
 * file is about the symbol-code puzzle and this one is about the games grid;
 * the duplication is four lines and the coupling would outlive it.
 */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** FNV-1a, so consecutive days look unrelated rather than adjacent. */
export function fnv1a(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/**
 * The generator for one game on one day.
 *
 * `salt` is the game id, so today's Queens board and today's Tango board are
 * not correlated — without it every game would walk the same number stream and
 * a player who worked out one board's structure would have a head start on the
 * others.
 *
 * `attempt` lets a generator re-roll when its first board fails a quality gate
 * (usually "the solution turned out not to be unique") without ever falling
 * back to unseeded randomness.
 */
export function randomFor(dayKey: string, salt: string, attempt = 0): () => number {
  return mulberry32(fnv1a(`${dayKey}:${salt}:${attempt}`));
}

/** Fisher-Yates, in place, driven by a seeded stream. */
export function shuffle<T>(items: T[], rand: () => number): T[] {
  for (let i = items.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [items[i], items[j]] = [items[j], items[i]];
  }
  return items;
}

/** `[0, 1, ..., n - 1]`. */
export function range(n: number): number[] {
  return Array.from({ length: n }, (_, i) => i);
}
