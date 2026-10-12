/**
 * Writes seeded random playouts of every turn game out for the Dart mirrors.
 *
 * `npx tsx tools/turn-fixtures.ts` from `backend/`; name ids after it
 * (`... chess`) to rewrite only those games' files.
 *
 * Each game's rules live twice: in `convex/turnGames/*.ts`, which decides
 * whether a move counts, and in `lib/turn_games/*.dart`, which draws it before
 * the server answers and lets the bot search offline. A test on either side
 * alone only checks an implementation against its own idea of the rules, so
 * the server engine plays here and the Dart side replays every step of it:
 * the same states, the same legal moves in the same order, the same next
 * state and the same outcome.
 *
 * Output: `test/fixtures/turn_games/<id>.json`, a JSON list of games, each a
 * list of steps `{state, toMove, legal, move, next, outcome}` where `outcome`
 * is that of `next` (null while the game goes on). A game's first state is
 * `initial(seats)` for some seat count in the game's range.
 *
 * Committed rather than generated at test time: the Dart suite must not need a
 * node toolchain, and a fixture that regenerated itself would quietly agree
 * with whatever the engine does today. A game whose module is missing (one
 * still being written) is skipped with a note rather than failing the rest.
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import type { TurnRules } from "../convex/turnGames/types";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyRules = TurnRules<any>;

/** Playouts per game. Enough to reach odd corners (Reversi passes, draws). */
const GAMES = 24;

/** A playout that runs this long is a rules bug, not a long game. */
const MAX_STEPS = 2000;

/** The modules the registry imports, for when the registry itself can't load. */
const MODULES = [
  "ticTacToe",
  "connectFour",
  "reversi",
  "checkers",
  "dots",
  "chess",
];

/**
 * Fewer random playouts where one is long. A random chess game runs a few
 * hundred plies before a draw rule stops it, and every step carries its
 * whole legal list; the scripted lines below cover what random play misses.
 */
const GAMES_FOR: Record<string, number> = { chess: 6 };

/**
 * Extra random playouts by seed, found by search, for endings the regular
 * seeds miss. Chess: 9217 ends on the fifty-move rule, 9143 in stalemate,
 * 9169 in a fourteen-ply mate.
 */
const EXTRA_SEEDS: Record<string, number[]> = { chess: [9217, 9143, 9169] };

/**
 * Hand-picked lines appended after the random ones, for endings random play
 * almost never reaches. Played at the game's minimum seat count.
 */
const SCRIPTED: Record<string, string[][]> = {
  // A full board with no four: random play has never drawn in 24 games.
  connectfour: [
    [0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 2, 3, 2, 3, 2, 3, 3, 2, 3, 2, 3, 2,
      4, 5, 4, 5, 4, 5, 5, 4, 5, 4, 5, 4, 6, 6, 6, 6, 6, 6].map(String),
  ],
  // Every special move and every ending by name. Lines that do not end the
  // game carry on at random from where they stop.
  chess: [
    "f2f3 e7e5 g2g4 d8h4", // fool's mate: black mates
    "e2e4 e7e5 d1h5 b8c6 f1c4 g8f6 h5f7", // scholar's mate: white mates
    // White castles short, black long.
    "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 e1g1 d7d6 d2d3 c8g4 b1c3 d8d7 c1e3 e8c8",
    // White castles long, black short.
    "d2d4 d7d5 b1c3 g8f6 c1f4 e7e6 d1d2 f8e7 e1c1 e8g8",
    "e2e4 a7a6 e4e5 d7d5 e5d6", // white takes en passant
    "a2a3 e7e5 a3a4 e5e4 d2d4 e4d3", // black takes en passant
    "a2a4 b7b5 a4b5 a7a6 b5a6 c8b7 a6b7 b8c6 b7a8q", // capture-promotion
    "a2a4 b7b5 a4b5 a7a6 b5a6 c8b7 a6b7 b8c6 b7a8n", // under-promotion
    "h2h4 g7g5 h4g5 h7h6 g5h6 f8g7 h6g7 g8f6 g7g8q", // quiet promotion
    // Sam Loyd's ten-move stalemate.
    "e2e3 a7a5 d1h5 a8a6 h5a5 h7h5 h2h4 a6h6 a5c7 f7f6 c7d7 e8f7 d7b7 d8d3 " +
      "b7b8 d3h7 b8c8 f7g6 c8e6",
    "g1f3 g8f6 f3g1 f6g8 g1f3 g8f6 f3g1 f6g8", // threefold repetition
  ].map((line) => line.split(" ")),
};

/**
 * Per-game move preference for the random part of a playout: with
 * [PREFER_RATE] the playout picks among the moves this accepts, when there
 * are any. Chess prefers captures, so random games thin out into the
 * endgames where the draw rules live instead of shuffling for 400 plies.
 */
const PREFER: Record<string, (before: string, after: string) => boolean> = {
  chess: (before, after) => pieces(after) < pieces(before),
};
const PREFER_RATE = 0.5;

function pieces(encoded: string): number {
  return encoded.split(" ")[0].replace(/[^a-zA-Z]/g, "").length;
}

/** mulberry32: tiny, seedable, and the same sequence on every machine. */
function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

async function loadGames(): Promise<AnyRules[]> {
  try {
    const registry = await import("../convex/turnGames/registry");
    return Object.values(registry.turnGames);
  } catch (e) {
    console.warn(`registry did not load (${String(e)}); trying each module`);
  }
  const out: AnyRules[] = [];
  for (const name of MODULES) {
    try {
      const mod = await import(`../convex/turnGames/${name}`);
      out.push(mod.rules as AnyRules);
    } catch {
      console.warn(`skipping ${name}: module missing or broken`);
    }
  }
  return out;
}

/**
 * One game from the opening, taking [script]'s moves first and seeded random
 * ones after that.
 */
function playout(
  rules: AnyRules,
  seed: number,
  seats: number,
  script: string[] = [],
) {
  const next = rng(seed);
  const steps: unknown[] = [];
  let state = rules.initial(seats);
  for (let n = 0; n < MAX_STEPS; n++) {
    const legal = rules.legalMoves(state);
    if (legal.length === 0) return steps;
    let pool = legal;
    const prefer = PREFER[rules.id];
    if (prefer && n >= script.length && next() < PREFER_RATE) {
      const before = rules.encode(state);
      const liked = legal.filter((m) =>
        prefer(before, rules.encode(rules.apply(state, m))),
      );
      if (liked.length > 0) pool = liked;
    }
    const move =
      n < script.length ? script[n] : pool[Math.floor(next() * pool.length)];
    const after = rules.apply(state, move);
    steps.push({
      state: rules.encode(state),
      toMove: rules.toMove(state),
      legal,
      move,
      next: rules.encode(after),
      outcome: rules.outcome(after),
    });
    state = after;
  }
  throw new Error(`${rules.id}: playout ${seed} did not finish`);
}

async function main() {
  const here = dirname(fileURLToPath(import.meta.url));
  const outDir = resolve(here, "../../test/fixtures/turn_games");
  mkdirSync(outDir, { recursive: true });
  // `npx tsx tools/turn-fixtures.ts chess` rewrites only that game's file.
  const only = process.argv.slice(2);
  for (const rules of await loadGames()) {
    const games = [];
    if (only.length > 0 && !only.includes(rules.id)) continue;
    const count = GAMES_FOR[rules.id] ?? GAMES;
    for (let g = 0; g < count; g++) {
      // Walk the seat range so a 2–4 seat game is fixtured at every size.
      const span = rules.maxSeats - rules.minSeats + 1;
      const seats = rules.minSeats + (g % span);
      games.push(playout(rules, 1000 + g, seats));
    }
    for (const seed of EXTRA_SEEDS[rules.id] ?? []) {
      games.push(playout(rules, seed, rules.minSeats));
    }
    for (const [i, script] of (SCRIPTED[rules.id] ?? []).entries()) {
      games.push(playout(rules, 9000 + i, rules.minSeats, script));
    }
    const path = resolve(outDir, `${rules.id}.json`);
    // One step per line, so a rules change shows up as a readable diff.
    const body = games
      .map((g) => `  [\n${g.map((s) => `    ${JSON.stringify(s)}`).join(",\n")}\n  ]`)
      .join(",\n");
    writeFileSync(path, `[\n${body}\n]\n`);
    const steps = games.reduce((n, g) => n + g.length, 0);
    console.log(`${rules.id}: ${games.length} games, ${steps} steps → ${path}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
