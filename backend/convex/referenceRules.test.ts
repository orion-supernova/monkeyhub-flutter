import { describe, expect, test } from "vitest";
import schema from "./schema";
import { REFERENCE_RULES } from "./referenceRules";
import { refKey, schemaRefs, tableIndexes } from "./schemaRefs";

/**
 * The guard for Phase 1 of the data-integrity plan: every `v.id(...)` in the
 * schema must carry an explicit rule in `referenceRules.ts`. Pure (no
 * convex-test), so it runs in milliseconds.
 */

const refs = schemaRefs(schema as any);
const byKey = new Map(refs.map((r) => [refKey(r), r]));

describe("reference rules", () => {
  test("every schema reference has a rule", () => {
    const missing = refs.filter((r) => !(refKey(r) in REFERENCE_RULES));
    expect(
      missing.map((r) => refKey(r)),
      missing
        .map(
          (r) =>
            `Add a rule for "${refKey(r)}" to REFERENCE_RULES in referenceRules.ts ` +
            `(-> ${r.target}${r.array ? ", array" : ""})`,
        )
        .join("\n") +
        "\nEach entry is keyed \"<table>.<path>\" with rule: \"cascade\" | " +
        '"setNull" | "restrict" | "history" | "ephemeral" | "softRef" | "file", ' +
        "a one-line `why`, and for cascade/setNull an `index` (first field = the " +
        "path; add it in schema.ts if missing) or a `via` index.",
    ).toEqual([]);
  });

  test("no rule names a path that is gone", () => {
    const stale = Object.keys(REFERENCE_RULES).filter((k) => !byKey.has(k));
    expect(
      stale,
      "These rules name a reference path that no longer exists in " +
        "schema.ts (renamed or removed). Delete or rename the entries in " +
        "backend/convex/referenceRules.ts:\n" +
        stale.map((k) => `  ${k}`).join("\n"),
    ).toEqual([]);
  });

  test("cascade and setNull rules say how to find their rows", () => {
    const problems: string[] = [];
    for (const [key, rule] of Object.entries(REFERENCE_RULES)) {
      const ref = byKey.get(key);
      if (!ref || (rule.rule !== "cascade" && rule.rule !== "setNull")) continue;
      const indexes = tableIndexes(schema as any, ref.table);
      const byName = new Map(indexes.map((i) => [i.name, i]));
      if (rule.index !== undefined) {
        const idx = byName.get(rule.index);
        if (!idx) {
          problems.push(
            `${key}: index "${rule.index}" does not exist on ${ref.table}. ` +
              `Add .index("${rule.index}", ["${ref.path}"]) to ${ref.table} in schema.ts, or fix the name.`,
          );
        } else if (idx.fields[0] !== ref.path) {
          problems.push(
            `${key}: index "${rule.index}" starts with "${idx.fields[0]}", not "${ref.path}". ` +
              `Point \`index\` at an index whose first field is the path, or use \`via\`.`,
          );
        }
      } else if (rule.via !== undefined) {
        if (!byName.has(rule.via)) {
          problems.push(
            `${key}: via index "${rule.via}" does not exist on ${ref.table}. Fix the name.`,
          );
        }
      } else {
        const candidates = indexes
          .filter((i) => i.fields[0] === ref.path)
          .map((i) => i.name);
        problems.push(
          `${key}: ${rule.rule} needs \`index\` or \`via\`. ` +
            (candidates.length > 0
              ? `Existing candidates: ${candidates.join(", ")}.`
              : ref.path.includes("[") || ref.path.includes(".")
                ? `A nested or array path cannot be indexed: set \`via\` to an index on ${ref.table} the rows are found through (for example one starting with roomId or messageId).`
                : `Add .index("by_${ref.path}", ["${ref.path}"]) to ${ref.table} in schema.ts, then set \`index\`.`),
        );
      }
    }
    expect(
      problems,
      "Some cascade/setNull rules cannot find their rows:\n" + problems.join("\n"),
    ).toEqual([]);
  });

  test("every rule has a why, and file rules say who owns the file", () => {
    const bad = Object.entries(REFERENCE_RULES)
      .filter(([, r]) => r.why.trim() === "" || r.why.includes("—"))
      .map(([k]) => k);
    expect(bad, "Empty `why` (or an em dash) on:\n" + bad.join("\n")).toEqual([]);
    const targetOf = (k: string) => byKey.get(k)?.target;
    const fileWithoutOwner = Object.entries(REFERENCE_RULES)
      .filter(([k, r]) => (r.rule === "file") !== (targetOf(k) === "_storage"))
      .map(([k]) => k);
    expect(
      fileWithoutOwner,
      'Rule "file" is for `_storage` references only, and every `_storage` reference must use it:\n' +
        fileWithoutOwner.join("\n"),
    ).toEqual([]);
  });
});
