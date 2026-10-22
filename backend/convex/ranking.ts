/**
 * Shared places for every scoreboard: dense ranking, "1, 1, 2".
 *
 * A place is decided only by what the board SHOWS. Two people who both read
 * "1:42" share a spot even if one was 300ms quicker, because a rank the reader
 * cannot see the reason for reads as the app picking favourites. Hidden data
 * (milliseconds, finish time, ids) may order a tie for stability, never place
 * it. The order WITHIN a tie is the client's job: it sorts tied names
 * alphabetically, which needs the viewer's locale and the server has neither.
 */

/**
 * The shared place of each row of [sorted], which must already be ordered so
 * that rows with the same [key] are adjacent. Equal keys share a place; the
 * next distinct key takes the very next place (three golds, then a silver).
 */
export function competitionPlaces<T>(
  sorted: readonly T[],
  key: (row: T) => string | number,
): number[] {
  const places: number[] = [];
  for (let i = 0; i < sorted.length; i++) {
    places.push(
      i === 0
        ? 1
        : key(sorted[i]) === key(sorted[i - 1])
          ? places[i - 1]
          : places[i - 1] + 1,
    );
  }
  return places;
}

/** A duration at the precision a scoreboard prints it: whole seconds. */
export function shownSeconds(ms: number | undefined): number {
  return ms === undefined ? Number.MAX_SAFE_INTEGER : Math.floor(ms / 1000);
}

/**
 * A stable, visibility-neutral last key for rows that tie on everything shown:
 * the display name (the viewer's REAL name, not the "" they are emitted with),
 * then the id only for two people with the same name.
 */
export function byNameThenId(
  a: { name: string; userId: string },
  b: { name: string; userId: string },
): number {
  const an = a.name.toLowerCase();
  const bn = b.name.toLowerCase();
  if (an !== bn) return an < bn ? -1 : 1;
  return a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0;
}
