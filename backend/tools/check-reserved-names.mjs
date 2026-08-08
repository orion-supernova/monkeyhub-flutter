/**
 * Exercises `systemAccount.isReservedName` against the evasion shapes it exists
 * to stop, and against innocent names it must not touch.
 *
 *   node tools/check-reserved-names.mjs
 *
 * A script rather than a unit test because this repo has no TypeScript test
 * runner for the Convex side — `typescript` is not even a dependency, and
 * `convex deploy` bundles with esbuild. Rather than stand up a runner for one
 * pure function, this reads the rule out of the module source and runs it, so
 * the cases cannot drift from the implementation: change the fold and this
 * exercises the change.
 *
 * Run it whenever `RESERVED_SUBSTRINGS` or `foldsForReservation` changes. Two
 * bugs were already caught this way — `monkey|hub` and `monkey!hub` both slipped
 * through an earlier single-variant fold, because `|` and `!` were substituted
 * for `l` instead of being read as the separators they are.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "..", "convex", "systemAccount.ts"), "utf8");

const bodyMatch = src.match(
  /function foldsForReservation\(name: string\): \[string, string\] \{([\s\S]*?)\n\}/,
);
const wordsMatch = src.match(
  /const RESERVED_SUBSTRINGS: readonly string\[\] = \[([^\]]*)\]/,
);
if (!bodyMatch || !wordsMatch) {
  console.error(
    "Could not find foldsForReservation / RESERVED_SUBSTRINGS in systemAccount.ts.\n" +
      "If either was renamed or reshaped, update the two regexes above.",
  );
  process.exit(2);
}

const words = JSON.parse(`[${wordsMatch[1]}]`);
const folds = new Function("name", bodyMatch[1].replace(/: string/g, ""));
const isReserved = (name) =>
  words.some((word) => folds(name).some((fold) => fold.includes(word)));

/** Must be refused — each reads as the brand to whoever sees it. */
const mustBlock = [
  "monkeyhub",
  "MonkeyHub",
  "MONKEYHUB",
  "MoNkEyHuB",
  "monkeyhub_logs",
  "monkeyhub_support",
  "monkeyhub-admin",
  "MonkeyHub Team",
  "MonkeyHub Support",
  "monkeyhub official",
  "monkey_hub",
  "monkey.hub",
  "monkey-hub",
  "monkey|hub",
  "monkey!hub",
  "monkeyh u b",
  "mOnKeY__hUb",
  "m0nkeyhub",
  "M0NKEY_HUB",
  "monk3yhub",
  "M0nk3yHub",
  "m0nk3y-hub",
  "x_monkeyhub_x",
  "themonkeyhubofficial",
  "monkeyhub2",
];

/** Must be allowed — blocking any of these is the filter overreaching. */
const mustAllow = [
  "murat",
  "muratcankoc",
  "monkey",
  "monkeys",
  "monkeylover",
  "monkey_king",
  "little monkey",
  "hub",
  "hubba",
  "hubmonkey",
  "bananahub",
  "hub of fun",
  "mon_key_hu",
  "hubertmonk",
  "ali",
  "zeynep99",
  // Reads as "mankeyhub" — `@` is an `a` to a human eye, so this is not an
  // impersonation and refusing it would be blocking a name nobody is fooled by.
  // See the note on `foldsForReservation`.
  "m@nkeyhub",
];

let failures = 0;
for (const name of mustBlock) {
  if (!isReserved(name)) {
    console.error(`LEAK            ${JSON.stringify(name)} → ${JSON.stringify(folds(name))}`);
    failures++;
  }
}
for (const name of mustAllow) {
  if (isReserved(name)) {
    console.error(`FALSE POSITIVE  ${JSON.stringify(name)} → ${JSON.stringify(folds(name))}`);
    failures++;
  }
}

if (failures > 0) {
  console.error(`\n${failures} problem(s).`);
  process.exit(1);
}
console.log(
  `OK — reserved ${JSON.stringify(words)}; ` +
    `${mustBlock.length} refused, ${mustAllow.length} allowed.`,
);
