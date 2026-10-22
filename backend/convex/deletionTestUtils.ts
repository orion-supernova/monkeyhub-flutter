/**
 * Helpers for tests of anything that deletes through the lifecycle engine.
 *
 * A delete now finishes in the background (scheduled `deletions.step` links),
 * so a test that asserts state right after one must drain first. Not a test
 * file, so it must not import vitest: pass `vi.runAllTimers` in.
 */
import { tuning } from "./deletionCore";

/** The slice of a convex-test handle the drain needs. */
interface Drainable {
  finishAllScheduledFunctions(advance: () => void): Promise<void>;
}

/**
 * Run every scheduled function, including the delayed and rescheduled links of
 * a delete chain. Needs `vi.useFakeTimers()` (see `calls.test.ts`):
 *
 *   await drainDeletions(t, vi.runAllTimers);
 */
export async function drainDeletions(
  t: Drainable,
  runAllTimers: () => void,
): Promise<void> {
  await t.finishAllScheduledFunctions(runAllTimers);
}

/**
 * Shrink the engine's budgets so a handful of rows spans several pages and
 * transactions. Returns the function that puts the defaults back (call it in
 * `afterEach`).
 */
export function shrinkTuning(
  over: Partial<typeof tuning> = {},
): () => void {
  const before = { ...tuning };
  Object.assign(tuning, { maxWrites: 4, maxReads: 40, pageRows: 2, inlineCap: 2 }, over);
  return () => {
    Object.assign(tuning, before);
  };
}
