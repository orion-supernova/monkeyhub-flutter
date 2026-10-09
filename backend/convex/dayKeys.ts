/**
 * Day-key arithmetic, in a module that imports nothing.
 *
 * `dailyNudge.ts` and `recordBook.ts` both need it, and either importing the
 * other would close a cycle through `games.ts` (see `recordBook.ts`'s header
 * for what a cycle costs here).
 */

/**
 * Days since the Unix epoch for a `YYYY-MM-DD` key.
 *
 * A calendar day rather than a hash on purpose: consecutive days must land on
 * consecutive numbers, which is what both the nudge's line rotation and a
 * streak ("solved yesterday too?") are asking.
 */
export function dayOrdinal(dayKey: string): number {
  const [y, m, d] = dayKey.split("-").map(Number);
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d)) {
    return 0;
  }
  return Math.floor(Date.UTC(y, m - 1, d) / 86_400_000);
}
