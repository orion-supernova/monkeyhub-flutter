/**
 * The plan for each deletion kind: its custom steps plus a generic step for
 * every reference rule that needs nothing special.
 *
 * `REFERENCE_RULES` already says, for each reference to a table, what happens
 * to the child (`cascade`, `setNull`, ...) and which index finds it. For the
 * simple ones that is enough to build the step: probe the index for the dead
 * id, delete or clear a page, repeat until the range is empty. A rule that
 * cannot be that (a `via` walk, an array, a nested path, files, a side effect
 * like releasing a blob) needs a custom step that CLAIMS its key, or an entry
 * in `PLAN_EXEMPT`. `deletionPlans.test.ts` fails on a rule that is none of
 * the three, so a new reference cannot be forgotten.
 *
 * Custom steps live in `deletionSteps/<kind>Steps.ts` (one array per kind).
 */
import { REFERENCE_RULES, type ReferenceRule } from "./referenceRules";
import schema from "./schema";
import { refKey, schemaRefs, type SchemaRef } from "./schemaRefs";
import {
  tuning,
  type DeletionKind,
  type Job,
  type Step,
} from "./deletionCore";
import { avatarSteps } from "./deletionSteps/avatarSteps";
import { commentSteps } from "./deletionSteps/commentSteps";
import { matchSteps } from "./deletionSteps/matchSteps";
import { messageSteps } from "./deletionSteps/messageSteps";
import { momentSteps } from "./deletionSteps/momentSteps";
import { roomSteps } from "./deletionSteps/roomSteps";
import { userSteps } from "./deletionSteps/userSteps";
import type { MutationCtx } from "./_generated/server";

/** The table whose rows a kind's `targetId` names; null for kinds with none. */
export const KIND_TABLE: Record<DeletionKind, string | null> = {
  user: "users",
  room: "rooms",
  message: "messages",
  moment: "moments",
  match: "matches",
  comment: "momentComments",
  avatar: null,
};

export const CUSTOM_STEPS: Record<DeletionKind, Step[]> = {
  user: userSteps,
  room: roomSteps,
  message: messageSteps,
  moment: momentSteps,
  match: matchSteps,
  comment: commentSteps,
  avatar: avatarSteps,
};

export const GENERIC_TIER = 50;
/** The parent row goes after everything else. */
export const PARENT_TIER = 1000;
/** Id of the step that deletes the parent row (user and room kinds). */
export const PARENT_STEP_ID = "parent";

/**
 * Rule keys that never get a generic step, and why. A key a custom step
 * handles is listed in that step's `claims` instead (the coverage test fails
 * if a key is both claimed and exempt), so what is left here is exempt for a
 * lasting reason.
 */
export const PLAN_EXEMPT: Record<string, string> = {
  // Not indexable by the path (a nested array), so no generic step can find the rows.
  "matches.watchers[]":
    "live viewers on the match row; not worth a walk of every match, and a dead id in a finished game is harmless (Phase 4, optional)",
  // Found through the message, not by the user id.
  "messageInteractions.createdBy":
    "the poll body is the author's message: removeMessageBounded deletes it (capped, rest in the `message` job) when the user plan removes that message",
};

const REFS = new Map<string, SchemaRef>(
  schemaRefs(schema as any).map((r) => [refKey(r), r]),
);

/** Rules a plan must account for: the ones that remove or clear a child. */
const COVERED = new Set(["cascade", "setNull", "restrict"]);

/** Can the engine build a step from this rule alone? */
export function isGeneric(key: string): boolean {
  const rule = REFERENCE_RULES[key];
  const ref = REFS.get(key);
  if (!rule || !ref) return false;
  return (
    (rule.rule === "cascade" || rule.rule === "setNull") &&
    rule.index !== undefined &&
    rule.via === undefined &&
    !ref.array &&
    /^[A-Za-z0-9_]+$/.test(ref.path)
  );
}

/** Every rule key (cascade, setNull, restrict) that targets this kind's table. */
export function coveredKeys(kind: DeletionKind): string[] {
  const table = KIND_TABLE[kind];
  if (table === null) return [];
  const keys: string[] = [];
  for (const [key, ref] of REFS) {
    const rule = REFERENCE_RULES[key];
    if (ref.target === table && rule && COVERED.has(rule.rule)) keys.push(key);
  }
  return keys.sort();
}

/**
 * Page through `eq(path, targetId)` on one index, deleting (cascade) or
 * clearing (setNull) each row. No cursor: handled rows leave the range, so the
 * next probe starts from the top and a re-run is a no-op.
 */
export function genericStep(key: string): Step {
  const rule = REFERENCE_RULES[key] as ReferenceRule;
  const ref = REFS.get(key) as SchemaRef;
  const table = ref.table as any;
  const index = rule.index as string;
  const path = ref.path;
  const cascade = rule.rule === "cascade";

  return {
    id: `generic:${key}`,
    tier: GENERIC_TIER,
    async run(ctx: MutationCtx, job: Job, b) {
      // `eq(path, undefined)` matches every row with the field unset.
      if (!job.targetId) return { done: true };
      const seen = new Set<string>();
      for (;;) {
        if (b.spent()) return { done: false };
        const rows: any[] = await ctx.db
          .query(table)
          .withIndex(index, (q: any) => q.eq(path, job.targetId))
          .take(tuning.pageRows);
        b.read(Math.max(rows.length, 1));
        if (rows.length === 0) return { done: true };
        const fresh = rows.filter((r) => !seen.has(r._id));
        // Rows that survive their own handling would loop forever; fail loudly.
        if (fresh.length === 0) {
          throw new Error(`STUCK ${key} ${job.kind} ${job.targetId}`);
        }
        for (const row of fresh) {
          if (b.spent()) return { done: false };
          seen.add(row._id);
          if (cascade) await ctx.db.delete(row._id);
          else await ctx.db.patch(row._id, { [path]: undefined });
          b.write();
        }
        if (rows.length < tuning.pageRows) return { done: true };
      }
    },
  };
}

/** Deletes the user or room row, skipping one that is already gone. */
function defaultParentStep(table: "users" | "rooms"): Step {
  return {
    id: PARENT_STEP_ID,
    tier: PARENT_TIER,
    async run(ctx, job, b) {
      const id = ctx.db.normalizeId(table, job.targetId);
      if (id !== null && (await ctx.db.get(id)) !== null) {
        await ctx.db.delete(id);
        b.write();
      }
      b.read();
      return { done: true };
    },
  };
}

/**
 * The ordered steps for a kind: custom steps, a generic step for every
 * unclaimed, non-exempt generic rule, and (user, room) the parent row last.
 * A custom step with id `"parent"` replaces the default parent step.
 */
export function planFor(kind: DeletionKind): Step[] {
  const custom = CUSTOM_STEPS[kind];
  const claimed = new Set(custom.flatMap((s) => s.claims ?? []));
  const generic = coveredKeys(kind)
    .filter((k) => isGeneric(k) && !claimed.has(k) && !(k in PLAN_EXEMPT))
    .map(genericStep);
  const steps = [...custom, ...generic];
  if (
    (kind === "user" || kind === "room") &&
    !steps.some((s) => s.id === PARENT_STEP_ID)
  ) {
    steps.push(defaultParentStep(kind === "user" ? "users" : "rooms"));
  }
  return steps.sort((a, b) =>
    a.tier !== b.tier ? a.tier - b.tier : a.id.localeCompare(b.id),
  );
}
