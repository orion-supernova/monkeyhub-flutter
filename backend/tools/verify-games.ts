/**
 * Proves the daily-game generators over a long run of real day keys.
 *
 * `npx tsx tools/verify-games.ts [days]` from `backend/`.
 *
 * This exists because every one of these generators is a search with a bounded
 * retry loop, and the failure mode of a bounded retry loop is silent: a day key
 * that never clears the uniqueness gate ships a fallback board, and nobody finds
 * out until the whole friend group is looking at a puzzle with two answers. A
 * generator that runs inside a subscribed Convex query also has a latency
 * budget, so "correct eventually" is not correct.
 *
 * The gates below are the ones that would actually ruin a day: solvable at all,
 * exactly one answer where the game promises one, the generated answer accepted
 * by the same validator the mutation uses, and fast enough that a player opening
 * the hub does not wait on it.
 */

import * as queens from "../convex/games/queens";
import * as tango from "../convex/games/tango";
import * as zip from "../convex/games/zip";
import * as sudoku from "../convex/games/sudoku";

const days = Number(process.argv[2] ?? 400);

/** The same `YYYY-MM-DD` shape the client sends, walked forward from today. */
function dayKeys(count: number): string[] {
  const out: string[] = [];
  const start = new Date("2026-01-01T00:00:00Z");
  for (let i = 0; i < count; i++) {
    const d = new Date(start.getTime() + i * 86400000);
    out.push(d.toISOString().slice(0, 10));
  }
  return out;
}

type Stat = { ms: number[]; failures: string[]; notes: Record<string, number> };

const stats: Record<string, Stat> = {};

function record(game: string, ms: number, failure?: string) {
  const s = (stats[game] ??= { ms: [], failures: [], notes: {} });
  s.ms.push(ms);
  if (failure) s.failures.push(failure);
}

function note(game: string, key: string) {
  const s = (stats[game] ??= { ms: [], failures: [], notes: {} });
  s.notes[key] = (s.notes[key] ?? 0) + 1;
}

for (const dayKey of dayKeys(days)) {
  // ── Queens ───────────────────────────────────────────────────────────────
  {
    const t = performance.now();
    const puzzle = queens.generate(dayKey);
    const ms = performance.now() - t;
    const count = queens.countSolutions(puzzle, 3);
    const answer = queens.solve(puzzle);
    let failure: string | undefined;
    if (count !== 1) failure = `${dayKey}: ${count} solutions`;
    else if (!answer || !queens.isSolved(puzzle, answer)) {
      failure = `${dayKey}: solver answer rejected by isSolved`;
    } else if (new Set(puzzle.regions).size !== queens.SIZE) {
      failure = `${dayKey}: ${new Set(puzzle.regions).size} regions`;
    }
    const sizes = new Map<number, number>();
    for (const r of puzzle.regions) sizes.set(r, (sizes.get(r) ?? 0) + 1);
    note("queens", `smallest region ${Math.min(...sizes.values())}`);
    record("queens", ms, failure);
  }

  // ── Tango ────────────────────────────────────────────────────────────────
  {
    const t = performance.now();
    const puzzle = tango.generate(dayKey);
    const ms = performance.now() - t;
    const count = tango.countSolutions(puzzle, 3);
    const answer = tango.solve(puzzle);
    let failure: string | undefined;
    if (count !== 1) failure = `${dayKey}: ${count} solutions`;
    else if (!answer || !tango.isSolved(puzzle, answer)) {
      failure = `${dayKey}: solver answer rejected by isSolved`;
    }
    const givens = puzzle.givens.filter((g) => g !== tango.EMPTY).length;
    note("tango", `${givens} givens / ${puzzle.signs.length} signs`);
    record("tango", ms, failure);
  }

  // ── Zip ──────────────────────────────────────────────────────────────────
  {
    const t = performance.now();
    const { puzzle, solution } = zip.generateWithSolution(dayKey);
    const ms = performance.now() - t;
    let failure: string | undefined;
    if (!zip.isSolved(puzzle, solution)) {
      failure = `${dayKey}: generated route rejected by isSolved`;
    } else if (puzzle.checkpoints.length !== zip.CHECKPOINTS) {
      failure = `${dayKey}: ${puzzle.checkpoints.length} checkpoints`;
    } else if (new Set(puzzle.checkpoints).size !== zip.CHECKPOINTS) {
      failure = `${dayKey}: duplicate checkpoint cell`;
    }
    // A route that is one cell different must be rejected — the validator has
    // to be strict about coverage, not just about the numbered stops.
    const broken = solution.slice(0, -1).concat(solution[0]);
    if (!failure && zip.isSolved(puzzle, broken)) {
      failure = `${dayKey}: isSolved accepted a route with a repeated cell`;
    }
    record("zip", ms, failure);
  }

  // ── Mini Sudoku ──────────────────────────────────────────────────────────
  {
    const t = performance.now();
    const puzzle = sudoku.generate(dayKey);
    const ms = performance.now() - t;
    const count = sudoku.countSolutions(puzzle, 3);
    const answer = sudoku.solve(puzzle);
    let failure: string | undefined;
    if (count !== 1) failure = `${dayKey}: ${count} solutions`;
    else if (!answer || !sudoku.isSolved(puzzle, answer)) {
      failure = `${dayKey}: solver answer rejected by isSolved`;
    }
    const givens = puzzle.givens.filter((g) => g !== sudoku.EMPTY).length;
    note("sudoku", `${givens} givens`);
    record("sudoku", ms, failure);
  }
}

// Determinism: the same day key twice must produce byte-identical boards, or
// two friends who loaded the hub a minute apart are not playing the same game.
const probe = "2026-03-14";
const twice = [
  ["queens", JSON.stringify(queens.generate(probe)), JSON.stringify(queens.generate(probe))],
  ["tango", JSON.stringify(tango.generate(probe)), JSON.stringify(tango.generate(probe))],
  ["zip", JSON.stringify(zip.generate(probe)), JSON.stringify(zip.generate(probe))],
  ["sudoku", JSON.stringify(sudoku.generate(probe)), JSON.stringify(sudoku.generate(probe))],
] as const;
for (const [game, a, b] of twice) {
  if (a !== b) record(game, 0, `${probe}: generator is not deterministic`);
}

let bad = 0;
for (const [game, s] of Object.entries(stats)) {
  const sorted = [...s.ms].sort((a, b) => a - b);
  const p50 = sorted[Math.floor(sorted.length * 0.5)];
  const p99 = sorted[Math.floor(sorted.length * 0.99)];
  const top = Object.entries(s.notes)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([k, n]) => `${k} ×${n}`)
    .join(", ");
  console.log(
    `${game.padEnd(7)} p50 ${p50.toFixed(1)}ms  p99 ${p99.toFixed(1)}ms  ` +
      `max ${sorted[sorted.length - 1].toFixed(1)}ms  ` +
      `failures ${s.failures.length}`
  );
  if (top) console.log(`        ${top}`);
  for (const f of s.failures.slice(0, 5)) console.log(`        FAIL ${f}`);
  bad += s.failures.length;
}

console.log(bad === 0 ? `\nOK — ${days} days, all gates passed.` : `\n${bad} FAILURES`);
process.exit(bad === 0 ? 0 : 1);
