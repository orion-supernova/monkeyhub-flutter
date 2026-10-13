/**
 * The explained hint, game by game: a mistake first, then a forced step with
 * its reason, then a labelled reveal — one square at a time, never a printed
 * one, and always the answer.
 */
import { describe, expect, test } from "vitest";
import * as h from "./hints";
import * as flow from "./flow";
import * as futoshiki from "./futoshiki";
import * as minesweeper from "./minesweeper";
import * as nonogram from "./nonogram";
import * as queens from "./queens";
import * as starbattle from "./starbattle";
import * as sudoku from "./sudoku";
import * as tango from "./tango";

const DAYS = ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"];

describe("queens", () => {
  for (const day of DAYS) {
    test(`${day}: hints alone solve the board, one deduction at a time`, () => {
      const p = queens.generate(day);
      const answer = queens.solve(p)!;
      const crown = (c: number) => answer[Math.floor(c / 8)] === c % 8;
      const b = new Array(64).fill(0);
      let steps = 0;
      for (let k = 0; k < 80; k++) {
        const x = h.queensHint(p, b);
        if (!x) break;
        expect(x.kind).not.toBe("wrong");
        // Older clients still read a row and its column.
        expect(x.legacy.value).toBe(answer[x.legacy.index]);
        if (x.value === 0) {
          // A cross step: every square it rules out really holds no crown.
          expect(x.cells!.length).toBeGreaterThan(0);
          for (const c of x.cells!) {
            expect(crown(c)).toBe(false);
            expect(b[c]).toBe(0);
            b[c] = 1;
          }
        } else {
          expect(crown(x.cell)).toBe(true);
          expect(x.area).toContain(x.cell);
          b[x.cell] = 2;
        }
        if (x.kind === "step") steps++;
      }
      expect(b.filter((v) => v === 2)).toHaveLength(8);
      expect(steps).toBeGreaterThan(0);
    });
  }

  test("a crown in the wrong place comes first, before any step", () => {
    const p = queens.generate(DAYS[0]);
    const answer = queens.solve(p)!;
    const b = new Array(64).fill(0);
    const bad = answer[0] === 0 ? 1 : 0;
    b[bad] = 2;
    const x = h.queensHint(p, b)!;
    expect(x.kind).toBe("wrong");
    expect(x.cell).toBe(bad);
    expect(x.more).toBe(0);
  });

  test("a cross over a real crown is a mistake too", () => {
    const p = queens.generate(DAYS[0]);
    const answer = queens.solve(p)!;
    const b = new Array(64).fill(0);
    b[3 * 8 + answer[3]] = 1;
    const x = h.queensHint(p, b)!;
    expect(x.kind).toBe("wrong");
    expect(x.cell).toBe(3 * 8 + answer[3]);
  });

  test("older clients' column-per-row board still reads", () => {
    const p = queens.generate(DAYS[1]);
    const answer = queens.solve(p)!;
    const cols = answer.map((c, r) => (r < 4 ? c : -1));
    const x = h.queensHint(p, cols)!;
    expect(x.kind).not.toBe("wrong");
    expect(Math.floor(x.cell / 8)).toBeGreaterThanOrEqual(0);
  });
});

describe("tango", () => {
  for (const day of DAYS) {
    test(`${day}: never a printed square, always the answer, solves`, () => {
      const p = tango.generate(day);
      const answer = tango.solve(p)!;
      const b = new Array(36).fill(-1);
      for (let k = 0; k < 40; k++) {
        const x = h.tangoHint(p, b);
        if (!x) break;
        expect(p.givens[x.cell]).toBe(tango.EMPTY);
        expect(b[x.cell]).toBe(-1);
        expect(x.value).toBe(answer[x.cell]);
        expect(x.area).toContain(x.cell);
        b[x.cell] = x.value;
      }
      for (let i = 0; i < 36; i++) if (p.givens[i] === tango.EMPTY) expect(b[i]).toBe(answer[i]);
    });
  }

  test("a sign next to a filled square is the first thing said", () => {
    const p = tango.generate(DAYS[0]);
    const answer = tango.solve(p)!;
    const s = p.signs.find((s) => p.givens[s.a] === tango.EMPTY && p.givens[s.b] === tango.EMPTY)!;
    const b = new Array(36).fill(-1);
    // Nothing else on the board can be forced by a sign before this one.
    for (const g of p.signs) if (g !== s && p.givens[g.a] !== tango.EMPTY) return;
    b[s.a] = answer[s.a];
    const x = h.tangoHint(p, b)!;
    expect(x.reason).toBe(s.eq ? "tango.equal" : "tango.cross");
  });

  test("a wrong square first; the count of others rides along", () => {
    const p = tango.generate(DAYS[2]);
    const answer = tango.solve(p)!;
    const open = answer.map((_, i) => i).filter((i) => p.givens[i] === tango.EMPTY);
    const b = new Array(36).fill(-1);
    b[open[0]] = 1 - answer[open[0]];
    b[open[1]] = 1 - answer[open[1]];
    const x = h.tangoHint(p, b)!;
    expect(x.kind).toBe("wrong");
    expect(x.cell).toBe(open[0]);
    expect(x.more).toBe(1);
  });
});

describe("sudoku", () => {
  for (const day of DAYS) {
    test(`${day}: printed digits are never "revealed" and every step is forced`, () => {
      const p = sudoku.generate(day);
      const answer = sudoku.solve(p)!;
      const b = new Array(36).fill(0);
      let reveals = 0;
      for (let k = 0; k < 40; k++) {
        const x = h.sudokuHint(p, b);
        if (!x) break;
        expect(p.givens[x.cell]).toBe(sudoku.EMPTY);
        expect(x.value).toBe(answer[x.cell]);
        if (x.reason.startsWith("latin.") && x.reason !== "latin.only") {
          expect(x.digit).toBe(x.value);
        }
        if (x.kind === "reveal") reveals++;
        b[x.cell] = x.value;
      }
      // A generated mini sudoku is singles all the way down.
      expect(reveals).toBe(0);
    });
  }

  test("a wrong digit is pointed at, and nothing is revealed with it", () => {
    const p = sudoku.generate(DAYS[0]);
    const answer = sudoku.solve(p)!;
    const i = p.givens.findIndex((g) => g === sudoku.EMPTY);
    const b = new Array(36).fill(0);
    b[i] = (answer[i] % 6) + 1;
    const x = h.sudokuHint(p, b)!;
    expect(x).toMatchObject({ kind: "wrong", cell: i, more: 0, reason: "wrong" });
  });

  test("the same board always gets the same hint", () => {
    const p = sudoku.generate(DAYS[3]);
    const b = new Array(36).fill(0);
    expect(h.sudokuHint(p, b)).toEqual(h.sudokuHint(p, b));
  });
});

describe("futoshiki", () => {
  for (const day of DAYS) {
    test(`${day}: walks to the answer`, () => {
      const p = futoshiki.generate(day);
      const answer = futoshiki.solve(p);
      const b = new Array(25).fill(0);
      for (let k = 0; k < 30; k++) {
        const x = h.futoshikiHint(p, b);
        if (!x) break;
        expect(p.givens[x.cell]).toBe(futoshiki.EMPTY);
        expect(x.value).toBe(answer[x.cell]);
        b[x.cell] = x.value;
      }
      for (let i = 0; i < 25; i++) if (p.givens[i] === futoshiki.EMPTY) expect(b[i]).toBe(answer[i]);
    });
  }

  test("wrong first", () => {
    const p = futoshiki.generate(DAYS[1]);
    const answer = futoshiki.solve(p);
    const i = p.givens.findIndex((g) => g === futoshiki.EMPTY);
    const b = new Array(25).fill(0);
    b[i] = (answer[i] % 5) + 1;
    expect(h.futoshikiHint(p, b)).toMatchObject({ kind: "wrong", cell: i });
  });
});

describe("nonogram", () => {
  for (const day of DAYS) {
    test(`${day}: every hint is a line deduction, never a reveal`, () => {
      const p = nonogram.generate(day);
      const answer = nonogram.solve(p);
      const b = new Array(100).fill(-1);
      for (let k = 0; k < 110; k++) {
        const x = h.nonogramHint(p, b);
        if (!x) break;
        expect(x.kind).toBe("step");
        expect(x.reason).toMatch(/^nonogram\.(row|col)(Fill|Cross)$/);
        expect(x.value).toBe(answer[x.cell]);
        expect(x.area).toHaveLength(10);
        b[x.cell] = x.value;
      }
      expect(b).toEqual(answer);
    });
  }

  test("a wrong fill before a wrong cross before anything else", () => {
    const p = nonogram.generate(DAYS[0]);
    const answer = nonogram.solve(p);
    const empty = answer.indexOf(0);
    const ink = answer.indexOf(1);
    const b = new Array(100).fill(-1);
    b[ink] = 0;
    b[empty] = 1;
    const x = h.nonogramHint(p, b)!;
    expect(x).toMatchObject({ kind: "wrong", cell: empty, more: 1 });
  });
});

describe("star battle", () => {
  for (const day of DAYS.slice(0, 3)) {
    test(`${day}: walks to the answer`, () => {
      const p = starbattle.generate(day);
      const answer = starbattle.solve(p);
      const b = new Array(100).fill(0);
      for (let k = 0; k < 30; k++) {
        const x = h.starbattleHint(p, b);
        if (!x) break;
        expect(x.kind).not.toBe("wrong");
        expect(answer[x.cell]).toBe(1);
        b[x.cell] = 1;
      }
      expect(b).toEqual(answer);
    });
  }

  test("a dot over a real star is a mistake", () => {
    const p = starbattle.generate(DAYS[0]);
    const answer = starbattle.solve(p);
    const b = new Array(100).fill(0);
    const star = answer.indexOf(1);
    b[star] = 2;
    expect(h.starbattleHint(p, b)).toMatchObject({ kind: "wrong", cell: star });
  });
});

describe("minesweeper", () => {
  const day = DAYS[0];
  const p = minesweeper.generate(day);
  const mines = minesweeper.decodeMines(p, day);

  test("an untouched board starts at the promised square", () => {
    expect(h.minesweeperHint(p, new Array(81).fill(-1), day)).toMatchObject({
      kind: "step",
      cell: p.start,
      value: 0,
      reason: "mines.start",
    });
  });

  test("a wrong flag is the first thing said", () => {
    const b = new Array(81).fill(-1);
    const safe = mines.findIndex((m, i) => !m && i !== p.start);
    b[safe] = minesweeper.FLAGGED;
    expect(h.minesweeperHint(p, b, day)).toMatchObject({ kind: "wrong", cell: safe });
  });

  test("hints never send a player onto a mine", () => {
    const numbers = mines.map((_, i) => {
      let k = 0;
      const r = Math.floor(i / 9);
      const c = i % 9;
      for (let dr = -1; dr <= 1; dr++)
        for (let dc = -1; dc <= 1; dc++) {
          const rr = r + dr;
          const cc = c + dc;
          if ((dr || dc) && rr >= 0 && rr < 9 && cc >= 0 && cc < 9 && mines[rr * 9 + cc]) k++;
        }
      return k;
    });
    const b = new Array(81).fill(-1);
    for (let k = 0; k < 120; k++) {
      const x = h.minesweeperHint(p, b, day);
      if (!x) break;
      expect(x.kind).toBe("step");
      expect(mines[x.cell]).toBe(x.value);
      b[x.cell] = x.value === 1 ? minesweeper.FLAGGED : numbers[x.cell];
    }
    for (let i = 0; i < 81; i++) if (!mines[i]) expect(b[i]).toBe(numbers[i]);
  });
});

describe("flow", () => {
  test("a pipe, labelled", () => {
    const p = flow.generate(DAYS[0]);
    const x = h.flowHint(p, [])!;
    expect(x.kind).toBe("reveal");
    expect(x.reason).toBe("flow.pipe");
    expect(x.cells!.length).toBeGreaterThan(1);
    expect(x.area).toEqual(x.cells);
  });
});
