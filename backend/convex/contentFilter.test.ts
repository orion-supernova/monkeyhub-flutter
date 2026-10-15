import { describe, expect, test } from "vitest";
import {
  ERR_NAME_INAPPROPRIATE,
  assertCleanName,
  foldText,
  hasHit,
  isObjectionableName,
  maskRanges,
  scanText,
  screenText,
} from "./contentFilter";

/**
 * The objectionable-text filter, pinned at the unit level: what it catches,
 * what it must NOT catch, and that masking never moves a character.
 */

describe("folding", () => {
  test("is one character in, one character out", () => {
    for (const s of ["İstanbul", "Straße", "f0ck", "ŞİŞLİ", "naïve 😀 emoji"]) {
      expect(foldText(s)).toHaveLength(s.length);
    }
  });

  test("undoes case, accents, Turkish letters and leetspeak", () => {
    expect(foldText("SH1T")).toBe("shit");
    expect(foldText("$h!t")).toBe("shit");
    expect(foldText("orospu")).toBe("orospu");
    expect(foldText("ORUSPU".replace("U", "Ü"))).toBe("oruspu");
    expect(foldText("cabrón")).toBe("cabron");
  });
});

describe("scanning", () => {
  test("catches the casual evasions", () => {
    for (const s of ["fuck", "FUCK", "fuuuuck", "sh1t", "b1tch", "motherfucker"]) {
      expect(hasHit(s)).toBe(true);
    }
  });

  test("covers the app's languages", () => {
    for (const s of ["siktir git", "puta madre", "putain", "caralho", "Arschloch", "jävla"]) {
      expect(hasHit(s)).toBe(true);
    }
  });

  test("leaves innocent words alone (the collisions the list was pruned for)", () => {
    for (const s of [
      "class assessment",
      "Scunthorpe United",
      "vi ses klockan sex",       // Swedish: six
      "jag fick den",             // Swedish: got
      "sık sık gelirim",          // Turkish: often
      "kapı sıkıştı",             // Turkish: stuck
      "je suis en retard",        // French: late
      "Fukushima",
      "a unique technique",
      "computer",
      "cocktail hour",
    ]) {
      expect(hasHit(s)).toBe(false);
    }
  });

  test("a stem takes its suffixes", () => {
    const hits = scanText("fucking fuckers");
    expect(hits.map((h) => h.category)).toEqual(["profanity", "profanity"]);
  });

  test("longest term wins, so the whole word is masked", () => {
    const text = "you motherfucker";
    const masked = maskRanges(text, scanText(text));
    expect(masked).toBe("you ************");
  });
});

describe("masking", () => {
  test("keeps the text's length, so spans and offsets stay valid", () => {
    const text = "well shit, that is bullshit!";
    const masked = maskRanges(text, scanText(text));
    expect(masked).toHaveLength(text.length);
    expect(masked).not.toMatch(/shit/i);
    expect(masked.startsWith("well ")).toBe(true);
  });
});

describe("the policy", () => {
  test("clean text passes untouched and costs nothing more", () => {
    const v = screenText("see you at six", false);
    expect(v.action).toBe("pass");
    expect(v.report).toBe(false);
  });

  test("adults: profanity is masked, not reported", () => {
    const v = screenText("what the fuck", false);
    expect(v.action).toBe("mask");
    expect(v.text).toBe("what the ****");
    expect(v.report).toBe(false);
  });

  test("adults: a slur is masked AND reported", () => {
    const v = screenText("you faggot", false);
    expect(v.action).toBe("mask");
    expect(v.report).toBe(true);
    expect(v.categories).toContain("slur");
  });

  test("adults: sexual words are not this filter's business", () => {
    const v = screenText("send nudes", false);
    expect(v.action).toBe("pass");
    expect(v.text).toBe("send nudes");
  });

  test("a child on either end: anything is blocked, sexual is reported", () => {
    const profane = screenText("shit", true);
    expect(profane.action).toBe("block");
    expect(profane.report).toBe(false);
    const sexual = screenText("send nudes", true);
    expect(sexual.action).toBe("block");
    expect(sexual.report).toBe(true);
  });
});

describe("names", () => {
  test("whole words and hidden substrings are both refused", () => {
    expect(isObjectionableName("big_fuck")).toBe(true);
    expect(isObjectionableName("xXfuckerXx")).toBe(true);
    expect(isObjectionableName("n1gga")).toBe(true);
    expect(isObjectionableName("sexy_girl")).toBe(true);
  });

  test("ordinary names pass", () => {
    for (const n of ["ada", "Ayşe Yılmaz", "classic_gamer", "Assistant Manager"]) {
      expect(isObjectionableName(n)).toBe(false);
    }
  });

  test("assertCleanName throws the code the client maps", () => {
    expect(() => assertCleanName("fuckface")).toThrow(ERR_NAME_INAPPROPRIATE);
    expect(() => assertCleanName("ada")).not.toThrow();
    expect(() => assertCleanName(undefined)).not.toThrow();
  });
});
