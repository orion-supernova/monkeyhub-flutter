import { describe, expect, test } from "vitest";
import {
  CUSTOM_STEPS,
  KIND_TABLE,
  PARENT_STEP_ID,
  PLAN_EXEMPT,
  coveredKeys,
  isGeneric,
  planFor,
} from "./deletionPlans";
import type { DeletionKind } from "./deletionCore";
import { REFERENCE_RULES } from "./referenceRules";
import schema from "./schema";
import { refKey, schemaRefs } from "./schemaRefs";

/**
 * The guard for the delete plans: a reference rule that removes or clears a
 * child (cascade, setNull, restrict) pointing at a plan kind's table must be
 * built generically, claimed by a custom step, or exempt. Pure, no convex-test.
 */

const KINDS = Object.keys(KIND_TABLE) as DeletionKind[];
const refs = new Map(schemaRefs(schema as any).map((r) => [refKey(r), r]));

const claimsOf = (kind: DeletionKind) =>
  new Set(CUSTOM_STEPS[kind].flatMap((s) => s.claims ?? []));

describe("delete plans", () => {
  test("every cascade/setNull/restrict rule on a plan kind is generic, claimed or exempt", () => {
    const orphans: string[] = [];
    for (const kind of KINDS) {
      const claimed = claimsOf(kind);
      for (const key of coveredKeys(kind)) {
        if (isGeneric(key) || claimed.has(key) || key in PLAN_EXEMPT) continue;
        orphans.push(`${kind}: ${key} (${REFERENCE_RULES[key].rule})`);
      }
    }
    expect(
      orphans,
      "These references have no step. Either claim the key in a custom step " +
        "(deletionSteps/<kind>Steps.ts, `claims`) or add it to PLAN_EXEMPT in " +
        "deletionPlans.ts with the reason it is never a plan step:\n" +
        orphans.map((o) => `  ${o}`).join("\n"),
    ).toEqual([]);
  });

  test("claimed and exempt keys exist and target a plan kind's table", () => {
    const tables = new Set(Object.values(KIND_TABLE).filter(Boolean));
    const bad: string[] = [];
    for (const key of Object.keys(PLAN_EXEMPT)) {
      const ref = refs.get(key);
      if (!ref) bad.push(`exempt ${key}: not in the schema any more`);
      else if (!tables.has(ref.target)) bad.push(`exempt ${key}: ${ref.target} is no plan kind`);
      else if (!["cascade", "setNull", "restrict"].includes(REFERENCE_RULES[key].rule)) {
        bad.push(`exempt ${key}: its rule is ${REFERENCE_RULES[key].rule}, nothing to exempt`);
      }
    }
    for (const kind of KINDS) {
      const covered = new Set(coveredKeys(kind));
      for (const key of claimsOf(kind)) {
        if (!covered.has(key)) bad.push(`${kind} claims ${key}: not a rule targeting ${KIND_TABLE[kind]}`);
      }
    }
    expect(bad).toEqual([]);
  });

  test("a key is never both claimed and exempt (claiming removes the exemption)", () => {
    const both: string[] = [];
    for (const kind of KINDS) {
      for (const key of claimsOf(kind)) if (key in PLAN_EXEMPT) both.push(`${kind}: ${key}`);
    }
    expect(both, "Delete these keys from PLAN_EXEMPT: a step claims them now.").toEqual([]);
  });

  test("exempt keys get no generic step", () => {
    for (const kind of KINDS) {
      const ids = planFor(kind).map((s) => s.id);
      for (const key of Object.keys(PLAN_EXEMPT)) {
        expect(ids).not.toContain(`generic:${key}`);
      }
    }
  });

  test("plans have unique step ids, are ordered, and user/room end with the parent", () => {
    for (const kind of KINDS) {
      const plan = planFor(kind);
      const ids = plan.map((s) => s.id);
      expect(new Set(ids).size).toBe(ids.length);
      for (let i = 1; i < plan.length; i++) {
        expect(plan[i].tier).toBeGreaterThanOrEqual(plan[i - 1].tier);
      }
      if (kind === "user" || kind === "room") {
        expect(ids[ids.length - 1]).toBe(PARENT_STEP_ID);
      } else {
        expect(ids).not.toContain(PARENT_STEP_ID);
      }
    }
  });

  test("the room plan is built from the rules, not hand-listed", () => {
    const ids = planFor("room").map((s) => s.id);
    expect(ids).toContain("generic:roomAccess.roomId");
    expect(ids).toContain("generic:friendships.roomId");
    expect(planFor("avatar")).toEqual([]);
  });
});
