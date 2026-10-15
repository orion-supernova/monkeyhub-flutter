/**
 * The objectionable-text filter: a compact multilingual blocklist, applied to
 * every piece of user-written text that other people read.
 *
 * ── What it is, and what it is not ──────────────────────────────────────────
 *
 * App Store Guideline 1.2 asks for "a method for filtering objectionable
 * material". This is that method at its honest size: a word list, folded so
 * the casual evasions (`f*ck` aside) stop working — case, accents, Turkish
 * dotless letters, leetspeak digits, stretched letters (`fuuuck`). It is not a
 * classifier and does not pretend to be one. Context, sarcasm, homoglyphs and
 * creative spelling get past it, and the answer to those is the report button
 * and the moderators behind it (`moderationCore.ts`), not a longer regex.
 *
 * ── What happens on a hit ───────────────────────────────────────────────────
 *
 * [screenText] decides; callers enforce. Three categories, three policies:
 *
 *   profanity  masked with asterisks for adults; blocks anything involving a
 *              child.
 *   slur       masked for adults AND auto-reported to the moderation room as a
 *              "Filter hit"; blocks anything involving a child.
 *   sexual     ignored between adults (consenting adults may say "sex"), but
 *              blocks anything involving a child and is auto-reported, because
 *              sexual language aimed at a child is the one case this app must
 *              never let pass silently.
 *
 * Masking replaces each matched character with `*`, one for one, so the text
 * keeps its length and every formatting span, mention offset and reply quote
 * computed against it stays valid.
 *
 * ── Performance ─────────────────────────────────────────────────────────────
 *
 * A hard requirement: this runs on every message send. The three patterns are
 * compiled once, at module load; a scan is one linear fold of the text plus
 * three regex passes over it, with no allocation per term and no database
 * reads. Callers only do further work (who is in the room, is anyone a child)
 * AFTER a hit, which is the rare path.
 *
 * Imports nothing, so anything can import it.
 */

export type FilterCategory = "profanity" | "slur" | "sexual";

/** A matched run in the ORIGINAL text, end exclusive. */
export type FilterRange = { start: number; end: number; category: FilterCategory };

/** Thrown (or returned) when text is refused rather than masked. */
export const ERR_FILTER_BLOCKED = "MESSAGE_FILTER_BLOCKED";

/** Thrown when a username, display name or room name trips the filter. */
export const ERR_NAME_INAPPROPRIATE = "NAME_INAPPROPRIATE";

// ── The lists ────────────────────────────────────────────────────────────────
//
// Written in FOLDED form: lowercase ASCII after [foldChar] has run, so `piç`
// would have to be written `pic` — which collides with English, and is why it
// is absent. Every entry was checked for that kind of collision; a term that
// is an ordinary word in another of the app's languages is left out rather
// than allowed to mask innocent text: `hora`, `negro`, `meme`, `bite`, `got`;
// Swedish `sex` (six) and `fick` (got); Turkish `sık`/`sıkış` (often, stuck),
// which fold to `sik`/`sikis`; French `retard` (late). Bare `sex` is caught
// only in phrases for the Swedish reason.
//
// A trailing `*` lets the term take any suffix (`fuck*` → fucking, fucker).
// Without it the match is a whole word. Spaces match any run of non-letters.
// Every letter tolerates repetition, so `shit` also catches `shiiit`.

const PROFANITY: readonly string[] = [
  // en
  "fuck*", "motherfuck*", "fck*", "fuk", "fukin", "fuking", "shit*", "bullshit*", "bitch*",
  "bastard*", "asshole*", "arsehole*", "dickhead*", "dick", "dicks", "cock",
  "cocks", "cocksuck*", "pussy", "pussies", "cunt*", "twat*", "wanker*",
  "slut*", "whore*", "prick", "pricks", "jackass*", "dumbass*", "douchebag*",
  "bollocks", "retarded",
  // tr
  "amk", "aminakoy*", "amina koy*", "amcik*", "orospu*", "siktir*",
  "sikerim", "sikeyim", "sikik", "yarrak*", "yavsak*", "gavat*", "kahpe*",
  "pezevenk*", "kaltak*", "gotveren*",
  // es
  "puta", "putas", "puto", "putos", "mierda*", "cabron*", "cono",
  "gilipollas", "pendejo*", "joder", "jodete", "follar", "verga", "zorra*",
  "culero*", "chingad*", "chingar", "hijueputa*",
  // fr
  "putain*", "merde*", "salope*", "connard*", "connasse*", "encule*",
  "batard*", "nique*", "niquer", "pute", "putes", "couille*", "enfoire*",
  "ntm",
  // pt
  "porra", "caralho*", "merda*", "foda*", "foder", "fodase", "buceta*",
  "arrombad*", "cacete",
  // de
  "scheis*", "fotze*", "hurensohn*", "wichser*", "arschloch*", "ficken",
  "ficker*", "schlampe*", "missgeburt*", "spast*",
  // sv
  "fitta*", "kuk", "javla*", "knull*",
];

const SLURS: readonly string[] = [
  "nigger*", "nigga*", "neger", "faggot*", "tranny*", "trannies", "kike*",
  "paki", "pakis", "wetback*", "raghead*", "towelhead*", "gook*", "beaner*",
  "maricon*", "marica", "sudaca*", "viado*", "ibne*", "kanake*", "kanacke*",
  "untermensch*",
];

const SEXUAL: readonly string[] = [
  "have sex", "having sex", "had sex", "sex with", "sex chat", "sexy",
  "sexting", "sext", "seks*", "nude", "nudes", "naked",
  "porn*", "horny", "blowjob*", "handjob*", "boob", "boobs", "tits",
  "titties", "titten", "tetas", "penis*", "pene", "vagina*", "masturbat*",
  "orgasm*", "dickpic*", "cum", "cumming", "erotic*", "xxx", "onlyfans",
  "ciplak*", "desnud*", "nackt*", "naken", "bumsen", "transar",
];

/**
 * Terms unambiguous enough to look for INSIDE a run of letters, for names
 * only. A username is one word with the separators squeezed out
 * (`bigfuckerxx`, `x_n1gga_x`), so a whole-word test misses it; a substring
 * test of every term would refuse `classic` for `ass`. These are the ones that
 * hide inside no innocent word in any of the app's languages.
 */
const NAME_SUBSTRINGS: readonly string[] = [
  "fuck", "cunt", "nigger", "nigga", "faggot", "whore", "porn", "orospu",
  "siktir", "yarrak", "hurensohn", "fotze", "arschloch", "putain", "salope",
  "caralho", "buceta", "pendejo", "gilipollas", "asshole", "bitch", "dildo",
  "blowjob", "cocksuck", "pussy", "penis", "vagina", "amcik", "aminakoy",
];

// ── Folding ──────────────────────────────────────────────────────────────────

/**
 * One character in, one character out — never more, never fewer, so a match
 * position in the folded text IS a position in the original. That is the
 * whole reason this is a table and not `normalize("NFD")`, which changes the
 * length (and `toLowerCase` on `İ` produces two code units).
 */
const FOLD: Record<string, string> = {
  "0": "o", "1": "i", "3": "e", "4": "a", "@": "a", "5": "s", "$": "s",
  "7": "t", "!": "i",
  "á": "a", "à": "a", "â": "a", "ä": "a", "ã": "a", "å": "a", "ā": "a",
  "æ": "a", "é": "e", "è": "e", "ê": "e", "ë": "e", "í": "i", "ì": "i",
  "î": "i", "ï": "i", "ı": "i", "İ": "i", "ó": "o", "ò": "o", "ô": "o",
  "ö": "o", "õ": "o", "ø": "o", "œ": "o", "ú": "u", "ù": "u", "û": "u",
  "ü": "u", "ç": "c", "ñ": "n", "ş": "s", "ğ": "g", "ß": "s", "ý": "y",
  "ÿ": "y",
};

function foldChar(c: string): string {
  const direct = FOLD[c];
  if (direct !== undefined) return direct;
  const lower = c.toLowerCase();
  if (lower.length !== 1) return c;
  return FOLD[lower] ?? lower;
}

/** The text folded for matching, same length as [text]. */
export function foldText(text: string): string {
  let out = "";
  for (let i = 0; i < text.length; i++) out += foldChar(text[i]);
  return out;
}

// ── Compiling ────────────────────────────────────────────────────────────────

function termPattern(term: string): string {
  const stem = term.endsWith("*");
  const body = stem ? term.slice(0, -1) : term;
  let p = "";
  for (const ch of body) {
    if (ch === " ") p += "[^a-z]+";
    else p += `${ch}+`;
  }
  return stem ? `${p}[a-z]*` : p;
}

function compile(terms: readonly string[]): RegExp {
  // Longest first, so `motherfuck*` wins over `fuck*` at the same position and
  // the whole word is masked rather than its tail.
  const sorted = [...terms].sort((a, b) => b.length - a.length);
  return new RegExp(
    `(?<![a-z])(?:${sorted.map(termPattern).join("|")})(?![a-z])`,
    "g",
  );
}

const PATTERNS: ReadonlyArray<[FilterCategory, RegExp]> = [
  ["slur", compile(SLURS)],
  ["sexual", compile(SEXUAL)],
  ["profanity", compile(PROFANITY)],
];

// ── Scanning ─────────────────────────────────────────────────────────────────

/** Every hit in [text], or an empty array. */
export function scanText(text: string): FilterRange[] {
  if (!text) return [];
  const folded = foldText(text);
  const hits: FilterRange[] = [];
  for (const [category, re] of PATTERNS) {
    re.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = re.exec(folded)) !== null) {
      hits.push({ start: m.index, end: m.index + m[0].length, category });
      if (m[0].length === 0) re.lastIndex++;
    }
  }
  return hits;
}

/** [text] with every character inside [ranges] replaced by `*`. */
export function maskRanges(text: string, ranges: readonly FilterRange[]): string {
  if (ranges.length === 0) return text;
  const chars = text.split("");
  for (const r of ranges) {
    for (let i = r.start; i < r.end && i < chars.length; i++) {
      // Whitespace inside a multi-word match stays, so the shape survives.
      if (!/\s/.test(chars[i])) chars[i] = "*";
    }
  }
  return chars.join("");
}

/** What a caller should do with a piece of text. */
export type ScreenVerdict = {
  /** `pass`: write it as typed. `mask`: write [text]. `block`: refuse it. */
  action: "pass" | "mask" | "block";
  /** The text to store when [action] is `mask`; the input otherwise. */
  text: string;
  /** Post a "Filter hit" card to the moderation room. */
  report: boolean;
  /** Which categories hit, for the card. */
  categories: FilterCategory[];
  /** The matched words as typed, for the card. Never shown to anyone else. */
  terms: string[];
};

/**
 * The policy, in one place. [strict] is true when a child is on either end:
 * the author is a child, or the text is going to one.
 *
 * Callers that need to know whether a child is involved should call this with
 * `strict: false` FIRST and only resolve the audience when [hasHit] says there
 * is anything to decide — see `messages.screenOutgoingText`.
 */
export function screenText(text: string, strict: boolean): ScreenVerdict {
  const hits = scanText(text);
  if (hits.length === 0) {
    return { action: "pass", text, report: false, categories: [], terms: [] };
  }
  const categories = [...new Set(hits.map((h) => h.category))];
  const terms = [...new Set(hits.map((h) => text.slice(h.start, h.end)))];
  const hasSlur = categories.includes("slur");
  const hasSexual = categories.includes("sexual");
  if (strict) {
    return {
      action: "block",
      text,
      report: hasSlur || hasSexual,
      categories,
      terms,
    };
  }
  // Between adults: sexual words are not this filter's business.
  const maskable = hits.filter((h) => h.category !== "sexual");
  if (maskable.length === 0) {
    return { action: "pass", text, report: false, categories, terms };
  }
  return {
    action: "mask",
    text: maskRanges(text, maskable),
    report: hasSlur,
    categories,
    terms,
  };
}

/** True when [text] trips the filter at all. The cheap first question. */
export function hasHit(text: string): boolean {
  if (!text) return false;
  const folded = foldText(text);
  for (const [, re] of PATTERNS) {
    re.lastIndex = 0;
    if (re.test(folded)) return true;
  }
  return false;
}

/**
 * True if [name] may not be used as a username, display name or room name.
 *
 * Stricter than message text in two ways, both because a name is shown to
 * everyone (children included) on every bubble, request and list row: every
 * category counts, sexual included, and the [NAME_SUBSTRINGS] are looked for
 * inside the name with its separators squeezed out.
 */
export function isObjectionableName(name: string): boolean {
  if (hasHit(name)) return true;
  const squeezed = foldText(name).replace(/[^a-z]/g, "");
  return NAME_SUBSTRINGS.some((t) => squeezed.includes(t));
}

/**
 * Throws [ERR_NAME_INAPPROPRIATE] when free text that NAMES something — a room
 * description — trips the filter. Whole-word only, unlike a name: a sentence
 * has real word boundaries, so the substring pass would only add false hits.
 */
export function assertCleanText(text: string | undefined | null): void {
  if (text && hasHit(text)) throw new Error(ERR_NAME_INAPPROPRIATE);
}

/** Throws [ERR_NAME_INAPPROPRIATE] for [isObjectionableName]. */
export function assertCleanName(name: string | undefined | null): void {
  if (name && isObjectionableName(name)) {
    throw new Error(ERR_NAME_INAPPROPRIATE);
  }
}
