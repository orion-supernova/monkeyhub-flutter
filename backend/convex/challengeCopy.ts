import { formatDuration, socialCopyFor } from "./socialPush";

/**
 * The words of a "Beat my time" card, in the message itself and in its push.
 *
 * Phrased as a QUESTION on purpose. The first version said "Beat my time:
 * Zip 0:17", which is a dare in print but not out loud: Siri announced it as
 * "zeynepz said they beat your time on zero seventeen", which is a claim, and
 * the wrong one. A question survives paraphrase and text-to-speech, because
 * nothing a reader does to "Can you beat my 0:17 on Zip?" turns it into a
 * statement about the recipient. The time sits INSIDE the sentence rather
 * than trailing it, so it is read as part of the question and not dropped as
 * a stray number.
 *
 * No glyph in front, unlike the poll or game pushes: an announced
 * notification reads emoji by name, and "chequered flag, can you beat..." is
 * the kind of noise this rewrite exists to remove.
 */

/** The message's `content`: English, shared by every member of the room. */
export function challengeContent(gameName: string, durationMs: number): string {
  return `Can you beat my ${formatDuration(durationMs)} on ${gameName}?`;
}

/**
 * The push body per language. `{game}` is the board's name as the app's own
 * tile spells it (lifted from `socialPush`'s table, which mirrors the ARB
 * files), `{time}` the clock. Every row keeps the time inside the question.
 */
const CHALLENGE_PUSH: Record<string, string> = {
  en: "Can you beat my {time} on {game}?",
  tr: "{game} oyununda {time} yaptım. Geçebilir misin?",
  es: "¿Puedes superar mi {time} en {game}?",
  fr: "Tu peux battre mon {time} sur {game} ?",
  pt: "Consegues bater o meu {time} em {game}?",
  "pt-br": "Você consegue bater meu {time} em {game}?",
  sv: "Kan du slå min tid på {time} i {game}?",
  ar: "هل تستطيع التغلب على وقتي {time} في {game}؟",
  hi: "क्या आप {game} में मेरा {time} का टाइम हरा सकते हैं?",
  ja: "{game}で私の{time}を超えられる？",
  ko: "{game}에서 내 기록 {time}, 깰 수 있어?",
  zh: "{game}我用了{time}，你能超过我吗？",
};

/** Exposed for the test that checks every shipped language has a row. */
export const CHALLENGE_PUSH_TABLE = CHALLENGE_PUSH;

function lookup(tag: string | undefined): { line: string; lang: string } {
  if (!tag) return { line: CHALLENGE_PUSH.en, lang: "en" };
  const norm = tag.toLowerCase().replace(/_/g, "-");
  if (CHALLENGE_PUSH[norm]) return { line: CHALLENGE_PUSH[norm], lang: norm };
  const base = norm.split("-")[0];
  if (CHALLENGE_PUSH[base]) return { line: CHALLENGE_PUSH[base], lang: base };
  return { line: CHALLENGE_PUSH.en, lang: "en" };
}

/**
 * A board's name as a proper noun: "mini sudoku" → "Mini Sudoku". The shared
 * table spells names in lowercase for the app to case; in a sentence they
 * read as the titles they are, and a screen reader stresses them as such.
 * Locale-aware so Turkish "i" capitalizes to "İ". A no-op for scripts with no
 * case.
 */
function properName(name: string, lang: string): string {
  return name
    .split(" ")
    .map((w) =>
      w.length === 0 ? w : w[0].toLocaleUpperCase(lang) + w.slice(1),
    )
    .join(" ");
}

/** A challenge push body for one recipient's [locale]. */
export function challengePushBody(
  locale: string | undefined,
  game: string,
  durationMs: number,
): string {
  const { line, lang } = lookup(locale);
  const names = socialCopyFor(locale).games;
  const name = names[game] ?? socialCopyFor("en").games[game] ?? game;
  return line
    .replace("{game}", properName(name, lang))
    .replace("{time}", formatDuration(durationMs));
}
