import { describe, expect, test } from "vitest";
import {
  IMPOSTER_CATEGORIES,
  IMPOSTER_CATEGORY_NAMES,
  IMPOSTER_WORDS,
  type ImposterLocale,
} from "./imposterWords";

const LOCALES: readonly ImposterLocale[] = [
  "en", "tr", "ar", "es", "fr", "hi", "ja", "ko", "pt-br", "pt", "sv", "zh",
];

const EM_DASH = "—";

describe("imposter word bank", () => {
  test("ids are unique", () => {
    const ids = IMPOSTER_WORDS.map((w) => w.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  test("ids are snake_case", () => {
    for (const w of IMPOSTER_WORDS) expect(w.id).toMatch(/^[a-z][a-z0-9_]*$/);
  });

  test("has at least 150 words", () => {
    expect(IMPOSTER_WORDS.length).toBeGreaterThanOrEqual(150);
  });

  test("every word and category has every locale, short and non-empty", () => {
    const all: [string, Record<string, string>][] = [
      ...IMPOSTER_WORDS.map((w) => [w.id, w.names] as [string, Record<string, string>]),
      ...Object.entries(IMPOSTER_CATEGORY_NAMES).map(
        ([id, n]) => [`category:${id}`, n] as [string, Record<string, string>],
      ),
    ];
    for (const [id, names] of all) {
      expect(Object.keys(names).sort(), id).toEqual([...LOCALES].sort());
      for (const loc of LOCALES) {
        const name = names[loc];
        expect(typeof name, `${id}.${loc}`).toBe("string");
        expect(name.trim().length, `${id}.${loc}`).toBeGreaterThan(0);
        expect(name.length, `${id}.${loc}`).toBeLessThanOrEqual(40);
        expect(name.includes(EM_DASH), `${id}.${loc}`).toBe(false);
      }
    }
  });

  test("every category is labelled, used, and every word's category is known", () => {
    expect(new Set(IMPOSTER_CATEGORIES).size).toBe(IMPOSTER_CATEGORIES.length);
    expect(Object.keys(IMPOSTER_CATEGORY_NAMES).sort()).toEqual([...IMPOSTER_CATEGORIES].sort());
    const used = new Set(IMPOSTER_WORDS.map((w) => w.category));
    for (const c of IMPOSTER_CATEGORIES) expect(used.has(c), c).toBe(true);
    for (const w of IMPOSTER_WORDS) expect(IMPOSTER_CATEGORIES, w.id).toContain(w.category);
  });

  test("no two words share an English name", () => {
    const en = IMPOSTER_WORDS.map((w) => w.names.en.trim().toLowerCase());
    expect(new Set(en).size).toBe(en.length);
  });
});
