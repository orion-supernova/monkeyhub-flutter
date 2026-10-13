/**
 * Explained hints for the daily puzzles.
 *
 * A hint used to be "the next square that disagrees with the answer", rotated
 * by how many hints had been taken. On an empty board that is a random square
 * with no reason attached; on a full board it is a random square somewhere in
 * the middle of the player's own marks, and a mistake elsewhere on the board
 * was never mentioned at all. Sudoku and Tango also counted printed squares as
 * "disagreeing" (the client sends them blank), so a hint could be spent on a
 * square that was already printed.
 *
 * The model now, the same for every game, in this order:
 *
 *  1. **A mistake first.** If anything the player put down disagrees with the
 *     answer, the hint is that square (`kind: "wrong"`). The client clears it.
 *     The player's next move built on a wrong square is wasted, so nothing
 *     else is worth saying until it is gone.
 *  2. **Otherwise the next forced step** (`kind: "step"`): a square one rule
 *     decides from what is already on the board, with the rule as a `reason`
 *     code the client turns into a sentence, the squares that rule looks at
 *     (`area`) and the marks that do the forcing (`cause`).
 *  3. **Otherwise one square, honestly labelled** (`kind: "reveal"`), with the
 *     most constrained line or region as its `area` so it still has context.
 *
 * One square per hint, always: a hint never hands over more than one step.
 * Deterministic for a given board, so a resent call is answered identically.
 */

import * as flow from "./flow";
import * as futoshiki from "./futoshiki";
import * as minesweeper from "./minesweeper";
import * as nonogram from "./nonogram";
import * as queens from "./queens";
import * as starbattle from "./starbattle";
import * as sudoku from "./sudoku";
import * as tango from "./tango";

export type HintKind = "wrong" | "step" | "reveal";

export type Explained = {
  kind: HintKind;
  /** The square the hint is about, row-major. Flow: the pipe's first dot. */
  cell: number;
  /**
   * What belongs in [cell], in the game's own alphabet. For "wrong" the client
   * clears the square instead; this is still the answer, for older clients.
   */
  value: number;
  /** Which rule, as a code. See the client's `hintReasonText`. */
  reason: string;
  /** The squares the rule looks at. Lit, not dimmed. */
  area: number[];
  /** Squares already on the board that force the answer. Drawn emphasised. */
  cause: number[];
  /** A digit the reason sentence names (Sudoku, Futoshiki). */
  digit?: number;
  /** For "wrong": how many other wrong squares are still on the board. */
  more?: number;
  /** Flow only: the whole pipe, dot to dot. */
  cells?: number[];
  /** The reply's pre-existing `index`/`value`, for clients from before this. */
  legacy: { index: number; value: number };
};

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

function rowCells(r: number, n: number): number[] {
  const out: number[] = [];
  for (let c = 0; c < n; c++) out.push(r * n + c);
  return out;
}

function colCells(c: number, n: number): number[] {
  const out: number[] = [];
  for (let r = 0; r < n; r++) out.push(r * n + c);
  return out;
}

/** Whether two cells touch, corners included (and are not the same cell). */
function touches(a: number, b: number, n: number): boolean {
  if (a === b) return false;
  const dr = Math.abs(Math.floor(a / n) - Math.floor(b / n));
  const dc = Math.abs((a % n) - (b % n));
  return dr <= 1 && dc <= 1;
}

function uniq(cells: number[]): number[] {
  return Array.from(new Set(cells)).sort((a, b) => a - b);
}

function wrongHint(
  wrong: number[],
  value: (cell: number) => number,
  legacy: (cell: number) => { index: number; value: number },
  area: (cell: number) => number[] = (c) => [c]
): Explained {
  const cell = wrong[0];
  return {
    kind: "wrong",
    cell,
    value: value(cell),
    reason: "wrong",
    area: area(cell),
    cause: [],
    more: wrong.length - 1,
    legacy: legacy(cell),
  };
}

// ---------------------------------------------------------------------------
// Queens and Star Battle: units of a colour-region board
// ---------------------------------------------------------------------------

type Unit = { reason: string; cells: number[] };

function regionUnits(regions: number[], n: number, prefix: string): Unit[] {
  const units: Unit[] = [];
  // Regions in the order their first square appears, so "the first region"
  // means the one nearest the top-left, as a reader would scan for it.
  const seen = new Map<number, number[]>();
  for (let i = 0; i < n * n; i++) {
    const r = regions[i];
    if (!seen.has(r)) seen.set(r, []);
    seen.get(r)!.push(i);
  }
  for (const cells of seen.values()) units.push({ reason: `${prefix}.region`, cells });
  for (let r = 0; r < n; r++) units.push({ reason: `${prefix}.row`, cells: rowCells(r, n) });
  for (let c = 0; c < n; c++) units.push({ reason: `${prefix}.col`, cells: colCells(c, n) });
  return units;
}

/**
 * The colour-region model both games share, with [per] marks per unit.
 *
 * [marks]: which squares hold a piece (all correct by the time this runs).
 * Returns the forced step if one unit has exactly as many open squares as it
 * still needs pieces, else the reveal from the tightest unit.
 */
function regionStep(
  regions: number[],
  n: number,
  per: number,
  pieces: Set<number>,
  crossed: Set<number>,
  answerHas: (cell: number) => boolean,
  prefix: string,
  legacy: (cell: number) => { index: number; value: number }
): Explained | null {
  const units = regionUnits(regions, n, prefix);
  const unitsOf = (cell: number) => units.filter((u) => u.cells.includes(cell));
  const full = (u: Unit) => u.cells.filter((c) => pieces.has(c)).length >= per;

  // What rules a square out, if anything: a piece touching it, or a unit it
  // belongs to that is already full. Returns the pieces responsible.
  const blockers = (cell: number): number[] | null => {
    const out: number[] = [];
    for (const p of pieces) if (touches(p, cell, n)) out.push(p);
    for (const u of unitsOf(cell)) {
      if (full(u)) for (const c of u.cells) if (pieces.has(c)) out.push(c);
    }
    return out.length > 0 ? out : null;
  };
  // The player's own crosses count: they are right (a wrong one is caught
  // before this runs), and "the only square you have not ruled out" is how
  // the player sees the board.
  const open = (cell: number) =>
    !pieces.has(cell) && !crossed.has(cell) && blockers(cell) === null;

  let tightest: { unit: Unit; slack: number } | null = null;
  for (const u of units) {
    const have = u.cells.filter((c) => pieces.has(c)).length;
    const need = per - have;
    if (need <= 0) continue;
    const free = u.cells.filter(open);
    if (free.length === need) {
      const cell = free.find(answerHas) ?? free[0];
      const cause: number[] = [];
      for (const c of u.cells) {
        if (pieces.has(c)) cause.push(c);
        else if (c !== cell) cause.push(...(blockers(c) ?? []));
      }
      return {
        kind: "step",
        cell,
        value: 1,
        reason: u.reason,
        area: u.cells.slice(),
        cause: uniq(cause),
        legacy: legacy(cell),
      };
    }
    const slack = free.length - need;
    if (!tightest || slack < tightest.slack) tightest = { unit: u, slack };
  }
  if (!tightest) return null;
  if (per === 1) {
    const confined = confinement(units, open, n, legacy);
    if (confined) return confined;
  }
  const cell = tightest.unit.cells.find((c) => answerHas(c) && !pieces.has(c));
  if (cell === undefined) return null;
  return {
    kind: "reveal",
    cell,
    value: 1,
    reason: "reveal",
    area: tightest.unit.cells.slice(),
    cause: [],
    legacy: legacy(cell),
  };
}

/**
 * The other half of Queens' logic: a unit whose open squares all sit inside
 * one other unit claims that unit's crown. A colour that only fits in row 3
 * means nothing else in row 3 can hold a crown; a row that only has room in
 * one colour means the rest of that colour is out.
 *
 * A step that rules squares OUT rather than putting a crown in: `value` 0 and
 * the squares to cross in `cells`. Still one deduction, so still one hint.
 */
function confinement(
  units: Unit[],
  open: (cell: number) => boolean,
  n: number,
  legacy: (cell: number) => { index: number; value: number }
): Explained | null {
  for (const u of units) {
    const free = u.cells.filter(open);
    if (free.length < 2) continue;
    for (const other of units) {
      if (other === u || other.reason === u.reason) continue;
      if (!free.every((c) => other.cells.includes(c))) continue;
      const out = other.cells.filter((c) => open(c) && !u.cells.includes(c));
      if (out.length === 0) continue;
      const from = u.reason.split(".")[1];
      const to = other.reason.split(".")[1];
      const reason = `queens.${from}In${to[0].toUpperCase()}${to.slice(1)}`;
      return {
        kind: "step",
        cell: out[0],
        value: 0,
        reason,
        area: uniq([...u.cells, ...other.cells]),
        cause: free,
        cells: out,
        legacy: legacy(out[0]),
      };
    }
  }
  return null;
}

/**
 * Queens. [board] is the player's marks, one per square (0 empty, 1 their
 * cross, 2 a crown) — or, from older clients, a column per row (-1 none).
 * Legacy reply: `index` a ROW, `value` its column.
 */
export function queensHint(puzzle: queens.QueensPuzzle, board: number[]): Explained | null {
  const n = puzzle.size;
  const answer = queens.solve(puzzle);
  if (!answer) return null;
  const crownAt = (cell: number) => answer[Math.floor(cell / n)] === cell % n;
  const legacy = (cell: number) => {
    const row = Math.floor(cell / n);
    return { index: row, value: answer[row] };
  };

  const marks = new Array<number>(n * n).fill(0);
  if (board.length === n) {
    for (let r = 0; r < n; r++) {
      const c = board[r];
      if (Number.isInteger(c) && c >= 0 && c < n) marks[r * n + c] = 2;
    }
  } else {
    for (let i = 0; i < n * n; i++) marks[i] = board[i] === 1 || board[i] === 2 ? board[i] : 0;
  }

  // A crown where none goes, then a cross over a square that IS a crown.
  const wrong = [
    ...range(n * n).filter((i) => marks[i] === 2 && !crownAt(i)),
    ...range(n * n).filter((i) => marks[i] === 1 && crownAt(i)),
  ];
  if (wrong.length > 0) return wrongHint(wrong, (c) => (crownAt(c) ? 1 : 0), legacy);

  const crowns = new Set(range(n * n).filter((i) => marks[i] === 2));
  if (crowns.size >= n) return null;
  const crosses = new Set(range(n * n).filter((i) => marks[i] === 1));
  return regionStep(puzzle.regions, n, 1, crowns, crosses, crownAt, "queens", legacy);
}

/**
 * Star Battle. [board]: 1 a star, 2 the player's dot, anything else empty.
 * Older clients send only 0/1, which reads the same minus the dots.
 * Legacy reply: `value` 1 for a star to place, 0 for a wrong one to clear.
 */
export function starbattleHint(
  puzzle: starbattle.StarBattlePuzzle,
  board: number[]
): Explained | null {
  const answer = starbattle.solve(puzzle);
  if (answer.length === 0) return null;
  const n = puzzle.size;
  const legacy = (cell: number) => ({ index: cell, value: answer[cell] });
  const wrong = [
    ...range(n * n).filter((i) => board[i] === 1 && answer[i] !== 1),
    ...range(n * n).filter((i) => board[i] === 2 && answer[i] === 1),
  ];
  if (wrong.length > 0) return wrongHint(wrong, (c) => answer[c], legacy);
  const stars = new Set(range(n * n).filter((i) => board[i] === 1));
  if (stars.size >= n * starbattle.STARS) return null;
  const dots = new Set(range(n * n).filter((i) => board[i] === 2));
  return regionStep(
    puzzle.regions,
    n,
    starbattle.STARS,
    stars,
    dots,
    (c) => answer[c] === 1,
    "stars",
    legacy
  );
}

function range(k: number): number[] {
  return Array.from({ length: k }, (_, i) => i);
}

// ---------------------------------------------------------------------------
// Tango
// ---------------------------------------------------------------------------

/** Tango. [board]: -1 empty, 0 sun, 1 moon; printed squares may be blank. */
export function tangoHint(puzzle: tango.TangoPuzzle, board: number[]): Explained | null {
  const answer = tango.solve(puzzle);
  if (!answer) return null;
  const n = puzzle.size;
  const E = tango.EMPTY;
  const given = (i: number) => puzzle.givens[i] !== E;
  const cells = range(n * n).map((i) =>
    given(i) ? puzzle.givens[i] : board[i] === 0 || board[i] === 1 ? board[i] : E
  );
  const legacy = (cell: number) => ({ index: cell, value: answer[cell] });

  const wrong = range(n * n).filter((i) => !given(i) && cells[i] !== E && cells[i] !== answer[i]);
  if (wrong.length > 0) return wrongHint(wrong, (c) => answer[c], legacy);
  if (!cells.includes(E)) return null;

  const step = (cell: number, reason: string, area: number[], cause: number[]): Explained => ({
    kind: "step",
    cell,
    value: answer[cell],
    reason,
    area: uniq(area),
    cause: uniq(cause),
    legacy: legacy(cell),
  });

  // 1. A sign beside a filled square.
  for (const s of puzzle.signs) {
    for (const [from, to] of [
      [s.a, s.b],
      [s.b, s.a],
    ]) {
      if (cells[from] !== E && cells[to] === E) {
        return step(to, s.eq ? "tango.equal" : "tango.cross", [from, to], [from]);
      }
    }
  }

  const lines: number[][] = [];
  for (let k = 0; k < n; k++) lines.push(rowCells(k, n));
  for (let k = 0; k < n; k++) lines.push(colCells(k, n));

  // 2. Two the same side by side: the squares either end are the other one.
  // 3. The same either side of a gap: the gap is the other one.
  for (const line of lines) {
    for (let k = 0; k + 1 < n; k++) {
      const a = cells[line[k]];
      if (a === E || cells[line[k + 1]] !== a) continue;
      for (const end of [k - 1, k + 2]) {
        if (end >= 0 && end < n && cells[line[end]] === E) {
          const lo = Math.min(k, end);
          return step(line[end], "tango.pair", line.slice(lo, lo + 3), [line[k], line[k + 1]]);
        }
      }
    }
    for (let k = 0; k + 2 < n; k++) {
      const a = cells[line[k]];
      if (a !== E && cells[line[k + 2]] === a && cells[line[k + 1]] === E) {
        return step(line[k + 1], "tango.sandwich", line.slice(k, k + 3), [line[k], line[k + 2]]);
      }
    }
  }

  // 4. A line that already has its three of one symbol.
  for (let l = 0; l < lines.length; l++) {
    const line = lines[l];
    for (const v of [tango.SUN, tango.MOON]) {
      const have = line.filter((c) => cells[c] === v);
      const gap = line.find((c) => cells[c] === E);
      if (have.length === n / 2 && gap !== undefined) {
        const kind = l < n ? "row" : "col";
        const sym = v === tango.SUN ? "Suns" : "Moons";
        return step(gap, `tango.${kind}${sym}`, line, have);
      }
    }
  }

  // Nothing one rule settles: the emptiest-but-one line's first gap, so the
  // square at least lands where it unlocks the most.
  let best: number[] | null = null;
  let bestFilled = -1;
  for (const line of lines) {
    const filled = line.filter((c) => cells[c] !== E).length;
    if (filled < n && filled > bestFilled) {
      best = line;
      bestFilled = filled;
    }
  }
  if (!best) return null;
  const cell = best.find((c) => cells[c] === E)!;
  return {
    kind: "reveal",
    cell,
    value: answer[cell],
    reason: "reveal",
    area: best.slice(),
    cause: [],
    legacy: legacy(cell),
  };
}

// ---------------------------------------------------------------------------
// Sudoku and Futoshiki: Latin squares
// ---------------------------------------------------------------------------

type LatinUnit = { reason: string; cells: number[] };

/**
 * The digit model both games share: wrong digits, then a hidden single (the
 * only square in a unit a digit fits), then a naked single (the only digit a
 * square fits), then a reveal of the most constrained square.
 *
 * [allowed] is the candidate mask per square, bit d-1 for digit d, already
 * narrowed by everything the game knows (Futoshiki's signs included).
 */
function latinStep(
  n: number,
  cells: number[],
  answer: number[],
  units: LatinUnit[],
  peers: (cell: number) => number[],
  allowed: number[],
  onlyReason: (cell: number) => string,
  legacy: (cell: number) => { index: number; value: number }
): Explained | null {
  // Hidden singles, unit by unit.
  for (const u of units) {
    for (let d = 1; d <= n; d++) {
      if (u.cells.some((c) => cells[c] === d)) continue;
      const spots = u.cells.filter((c) => cells[c] === 0 && allowed[c] & (1 << (d - 1)));
      if (spots.length !== 1) continue;
      const cell = spots[0];
      // The copies of [d] that rule the unit's other gaps out.
      const cause: number[] = [];
      for (const c of u.cells) {
        if (c === cell || cells[c] !== 0) continue;
        const by = peers(c).find((p) => cells[p] === d);
        if (by !== undefined) cause.push(by);
      }
      return {
        kind: "step",
        cell,
        value: answer[cell],
        reason: u.reason,
        digit: d,
        area: u.cells.slice(),
        cause: uniq(cause),
        legacy: legacy(cell),
      };
    }
  }
  // Naked singles.
  let tight = -1;
  let tightCount = n + 1;
  for (let i = 0; i < n * n; i++) {
    if (cells[i] !== 0) continue;
    const count = popcount(allowed[i]);
    if (count === 1) {
      return {
        kind: "step",
        cell: i,
        value: answer[i],
        reason: onlyReason(i),
        area: uniq([i, ...peers(i)]),
        cause: [],
        legacy: legacy(i),
      };
    }
    if (count < tightCount) {
      tight = i;
      tightCount = count;
    }
  }
  if (tight < 0) return null;
  return {
    kind: "reveal",
    cell: tight,
    value: answer[tight],
    reason: "reveal",
    area: uniq([tight, ...peers(tight)]),
    cause: [],
    legacy: legacy(tight),
  };
}

function popcount(m: number): number {
  let k = 0;
  while (m) {
    m &= m - 1;
    k++;
  }
  return k;
}

/** Sudoku. [board]: 0 empty or 1..6; printed squares may come blank. */
export function sudokuHint(puzzle: sudoku.SudokuPuzzle, board: number[]): Explained | null {
  const answer = sudoku.solve(puzzle);
  if (!answer) return null;
  const n = sudoku.SIZE;
  const given = (i: number) => puzzle.givens[i] !== sudoku.EMPTY;
  const cells = range(n * n).map((i) => {
    if (given(i)) return puzzle.givens[i];
    const v = board[i];
    return Number.isInteger(v) && v >= 1 && v <= n ? v : 0;
  });
  const legacy = (cell: number) => ({ index: cell, value: answer[cell] });
  const wrong = range(n * n).filter((i) => !given(i) && cells[i] !== 0 && cells[i] !== answer[i]);
  if (wrong.length > 0) return wrongHint(wrong, (c) => answer[c], legacy);
  if (!cells.includes(0)) return null;

  const boxOf = (i: number) => {
    const r0 = Math.floor(i / n) - (Math.floor(i / n) % sudoku.BOX_ROWS);
    const c0 = (i % n) - ((i % n) % sudoku.BOX_COLS);
    const out: number[] = [];
    for (let r = 0; r < sudoku.BOX_ROWS; r++) {
      for (let c = 0; c < sudoku.BOX_COLS; c++) out.push((r0 + r) * n + c0 + c);
    }
    return out;
  };
  const units: LatinUnit[] = [];
  for (let b = 0; b < n; b++) {
    const r0 = Math.floor(b / (n / sudoku.BOX_COLS)) * sudoku.BOX_ROWS;
    const c0 = (b % (n / sudoku.BOX_COLS)) * sudoku.BOX_COLS;
    units.push({ reason: "latin.box", cells: boxOf(r0 * n + c0) });
  }
  for (let k = 0; k < n; k++) units.push({ reason: "latin.row", cells: rowCells(k, n) });
  for (let k = 0; k < n; k++) units.push({ reason: "latin.col", cells: colCells(k, n) });
  const peers = (i: number) =>
    uniq([...rowCells(Math.floor(i / n), n), ...colCells(i % n, n), ...boxOf(i)]).filter(
      (c) => c !== i
    );
  const allowed = range(n * n).map((i) => {
    if (cells[i] !== 0) return 0;
    let m = (1 << n) - 1;
    for (const p of peers(i)) if (cells[p] !== 0) m &= ~(1 << (cells[p] - 1));
    return m;
  });
  return latinStep(n, cells, answer, units, peers, allowed, () => "latin.only", legacy);
}

/** Futoshiki. [board]: 0 empty or 1..5; printed squares may come blank. */
export function futoshikiHint(
  puzzle: futoshiki.FutoshikiPuzzle,
  board: number[]
): Explained | null {
  const answer = futoshiki.solve(puzzle);
  if (answer.length === 0) return null;
  const n = puzzle.size;
  const given = (i: number) => puzzle.givens[i] !== futoshiki.EMPTY;
  const cells = range(n * n).map((i) => {
    if (given(i)) return puzzle.givens[i];
    const v = board[i];
    return Number.isInteger(v) && v >= 1 && v <= n ? v : 0;
  });
  const legacy = (cell: number) => ({ index: cell, value: answer[cell] });
  const wrong = range(n * n).filter((i) => !given(i) && cells[i] !== 0 && cells[i] !== answer[i]);
  if (wrong.length > 0) return wrongHint(wrong, (c) => answer[c], legacy);
  if (!cells.includes(0)) return null;

  const units: LatinUnit[] = [];
  for (let k = 0; k < n; k++) units.push({ reason: "latin.row", cells: rowCells(k, n) });
  for (let k = 0; k < n; k++) units.push({ reason: "latin.col", cells: colCells(k, n) });
  const lines = (i: number) =>
    uniq([...rowCells(Math.floor(i / n), n), ...colCells(i % n, n)]).filter((c) => c !== i);
  const signed = (i: number) =>
    puzzle.signs.filter((s) => s.a === i || s.b === i).map((s) => (s.a === i ? s.b : s.a));
  const peers = (i: number) => uniq([...lines(i), ...signed(i)]);

  const full = (1 << n) - 1;
  const byLines = range(n * n).map((i) => {
    if (cells[i] !== 0) return 1 << (cells[i] - 1);
    let m = full;
    for (const p of lines(i)) if (cells[p] !== 0) m &= ~(1 << (cells[p] - 1));
    return m;
  });
  // Signs narrow by bounds: a < b means a is below b's largest option and b
  // above a's smallest. Repeated until nothing moves.
  const allowed = byLines.slice();
  for (let guard = 0; guard < 50; guard++) {
    let moved = false;
    for (const s of puzzle.signs) {
      const lo = s.lt ? s.a : s.b;
      const hi = s.lt ? s.b : s.a;
      if (!allowed[lo] || !allowed[hi]) continue;
      const loMin = 31 - Math.clz32(allowed[lo] & -allowed[lo]);
      const hiMax = 31 - Math.clz32(allowed[hi]);
      const loNext = allowed[lo] & ((1 << hiMax) - 1);
      const hiNext = allowed[hi] & ~((1 << (loMin + 1)) - 1);
      if (loNext !== allowed[lo] || hiNext !== allowed[hi]) {
        allowed[lo] = loNext;
        allowed[hi] = hiNext;
        moved = true;
      }
    }
    if (!moved) break;
  }
  for (let i = 0; i < n * n; i++) if (cells[i] !== 0) allowed[i] = 0;
  return latinStep(
    n,
    cells,
    answer,
    units,
    peers,
    allowed,
    (i) => (popcount(byLines[i]) === 1 ? "latin.onlyLines" : "latin.onlySigns"),
    legacy
  );
}

// ---------------------------------------------------------------------------
// Nonogram
// ---------------------------------------------------------------------------

const maskCache = new Map<string, number[]>();

/** Every way [clue] fits a line of [n], as bitmasks (bit k = square k). */
function masksFor(clue: number[], n: number): number[] {
  const key = `${n}:${clue.join(",")}`;
  const hit = maskCache.get(key);
  if (hit) return hit;
  const out: number[] = [];
  const rec = (k: number, from: number, mask: number) => {
    if (k === clue.length) {
      out.push(mask);
      return;
    }
    let rest = 0;
    for (let j = k + 1; j < clue.length; j++) rest += clue[j] + 1;
    for (let s = from; s + clue[k] + rest <= n; s++) {
      let run = 0;
      for (let b = 0; b < clue[k]; b++) run |= 1 << (s + b);
      rec(k + 1, s + clue[k] + 1, mask | run);
    }
  };
  rec(0, 0, 0);
  maskCache.set(key, out);
  return out;
}

/** Nonogram. [board]: -1 untouched, 0 the player's cross, 1 filled. */
export function nonogramHint(puzzle: nonogram.NonogramPuzzle, board: number[]): Explained | null {
  const n = nonogram.SIZE;
  if (!puzzle || puzzle.size !== n) return null;
  const answer = nonogram.solve(puzzle);
  const known = range(n * n).map((i) => (board[i] === 0 || board[i] === 1 ? board[i] : -1));
  const legacy = (cell: number) => ({ index: cell, value: answer[cell] });
  const lineOf = (cell: number) => rowCells(Math.floor(cell / n), n);
  const wrong = [
    ...range(n * n).filter((i) => known[i] === 1 && answer[i] !== 1),
    ...range(n * n).filter((i) => known[i] === 0 && answer[i] === 1),
  ];
  if (wrong.length > 0) return wrongHint(wrong, (c) => answer[c], legacy);
  if (!known.includes(-1)) return null;

  // Every line's arrangements that agree with what is known; a square every
  // one of them fills (or none of them does) is forced. Fills are preferred
  // over crosses, and the line with the fewest arrangements over the rest,
  // because that is the line a person would read first.
  type Found = { cell: number; value: number; line: number[]; reason: string; ways: number };
  let bestFill: Found | null = null;
  let bestCross: Found | null = null;
  for (let l = 0; l < 2 * n; l++) {
    const isRow = l < n;
    const line = isRow ? rowCells(l, n) : colCells(l - n, n);
    const clue = (isRow ? puzzle.rows[l] : puzzle.cols[l - n]) ?? [];
    let filled = 0;
    let empty = 0;
    line.forEach((c, k) => {
      if (known[c] === 1) filled |= 1 << k;
      else if (known[c] === 0) empty |= 1 << k;
    });
    let and = (1 << n) - 1;
    let or = 0;
    let ways = 0;
    for (const m of masksFor(clue, n)) {
      if ((m & filled) !== filled || (m & empty) !== 0) continue;
      and &= m;
      or |= m;
      ways++;
    }
    if (ways === 0) continue;
    for (let k = 0; k < n; k++) {
      if (known[line[k]] !== -1) continue;
      const bit = 1 << k;
      const kind = isRow ? "row" : "col";
      if (and & bit) {
        if (!bestFill || ways < bestFill.ways) {
          bestFill = { cell: line[k], value: 1, line, reason: `nonogram.${kind}Fill`, ways };
        }
        break;
      }
      if (!(or & bit) && (!bestCross || ways < bestCross.ways)) {
        bestCross = { cell: line[k], value: 0, line, reason: `nonogram.${kind}Cross`, ways };
      }
    }
  }
  const found = bestFill ?? bestCross;
  if (found) {
    return {
      kind: "step",
      cell: found.cell,
      value: found.value,
      reason: found.reason,
      area: found.line.slice(),
      cause: [],
      legacy: legacy(found.cell),
    };
  }
  const cell = known.indexOf(-1);
  return {
    kind: "reveal",
    cell,
    value: answer[cell],
    reason: "reveal",
    area: lineOf(cell),
    cause: [],
    legacy: legacy(cell),
  };
}

// ---------------------------------------------------------------------------
// Minesweeper
// ---------------------------------------------------------------------------

function around(cell: number, n: number): number[] {
  const out: number[] = [];
  const r = Math.floor(cell / n);
  const c = cell % n;
  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      const rr = r + dr;
      const cc = c + dc;
      if (rr >= 0 && rr < n && cc >= 0 && cc < n) out.push(rr * n + cc);
    }
  }
  return out;
}

/**
 * Minesweeper. [board]: -1 hidden, 0..8 revealed, 9 flagged (a mine the
 * player walked onto comes as a flag). `value` 0 opens [cell], 1 flags it.
 */
export function minesweeperHint(
  puzzle: minesweeper.MinesweeperPuzzle,
  board: number[],
  dayKey: string
): Explained | null {
  const n = minesweeper.SIZE;
  if (!puzzle || puzzle.size !== n) return null;
  const mines = minesweeper.decodeMines(puzzle, dayKey);
  const legacy = (cell: number) => ({ index: cell, value: mines[cell] ? 1 : 0 });
  const revealed = (i: number) => {
    const v = board[i];
    return Number.isInteger(v) && v >= 0 && v <= 8 && !mines[i];
  };
  const flagged = (i: number) => board[i] === minesweeper.FLAGGED;

  const wrong = range(n * n).filter((i) => flagged(i) && !mines[i]);
  if (wrong.length > 0) return wrongHint(wrong, () => 0, legacy);

  if (!range(n * n).some(revealed)) {
    const start = puzzle.start;
    return {
      kind: "step",
      cell: start,
      value: 0,
      reason: "mines.start",
      area: [start],
      cause: [],
      legacy: legacy(start),
    };
  }

  // One number on its own: its flags already make its count (the rest are
  // safe), or its hidden squares are exactly its count (all mines). Safe
  // squares first: opening is what moves the board.
  const count = (i: number) => around(i, n).filter((j) => mines[j]).length;
  let mineStep: Explained | null = null;
  for (let i = 0; i < n * n; i++) {
    if (!revealed(i)) continue;
    const hidden = around(i, n).filter((j) => !revealed(j));
    const flags = hidden.filter(flagged);
    const open = hidden.filter((j) => !flagged(j));
    if (open.length === 0) continue;
    const need = count(i);
    const area = [i, ...around(i, n)];
    if (flags.length === need) {
      return {
        kind: "step",
        cell: open[0],
        value: 0,
        reason: "mines.safe",
        area,
        cause: [i, ...flags],
        legacy: legacy(open[0]),
      };
    }
    if (!mineStep && hidden.length === need) {
      mineStep = {
        kind: "step",
        cell: open[0],
        value: 1,
        reason: "mines.flag",
        area,
        cause: [i],
        legacy: legacy(open[0]),
      };
    }
  }
  if (mineStep) return mineStep;

  // Something only several numbers together prove: the engine's own solver.
  const proved = minesweeper.hint(puzzle, board, 0, dayKey);
  if (!proved) return null;
  const nearby = around(proved.index, n).filter(revealed);
  return {
    kind: "step",
    cell: proved.index,
    value: proved.value,
    reason: proved.value === 1 ? "mines.proofMine" : "mines.proofSafe",
    area: [proved.index, ...nearby],
    cause: nearby,
    legacy: legacy(proved.index),
  };
}

// ---------------------------------------------------------------------------
// Flow
// ---------------------------------------------------------------------------

/** Flow: one whole pipe, as before, now labelled. */
export function flowHint(puzzle: flow.FlowPuzzle, board: number[]): Explained | null {
  const h = flow.hint(puzzle, board, 0);
  if (!h || !h.cells || h.cells.length === 0) return null;
  return {
    kind: "reveal",
    cell: h.cells[0],
    value: h.value,
    reason: "flow.pipe",
    area: h.cells.slice(),
    cause: [],
    cells: h.cells.slice(),
    legacy: { index: h.index, value: h.value },
  };
}
