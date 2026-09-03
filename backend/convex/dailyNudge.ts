import {
  internalAction,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { GAMES } from "./games";
import type { AlertSpec } from "./push";
import { liveSessionDeviceIds } from "./sessionCore";

/**
 * The once-a-day "you haven't played today" nudge.
 *
 * Every other push in this backend is a consequence: somebody sent a message,
 * somebody rang, a guardian has something waiting. This one is the only push
 * the app sends nobody asked for, which is what shapes every decision below.
 *
 * ## Local noon, not a single global blast
 *
 * The cron ticks on every quarter hour and each tick asks one question — whose
 * wall clock reads 12:00 right now? — answered by an equality probe on
 * `userDevices.by_tz_offset`. So Istanbul is nudged at Istanbul's lunchtime and
 * California at California's, from one job, and nobody is woken at 02:00 for
 * the convenience of a fixed UTC hour.
 *
 * Fifteen minutes rather than hourly because real zones are not all whole
 * hours: India is +5:30, Nepal +5:45, Chatham +12:45. An hourly tick would
 * never land on their noon at all.
 *
 * ## Nobody is invisible to it
 *
 * A zone maps to exactly one of the 96 daily ticks, which makes every way of
 * missing a tick a way of losing a whole zone for a day, and every way of
 * falling out of the index a way of losing somebody permanently. Three things
 * hold that shut, and each earns its place in `crons.ts` or below:
 *
 *   * the schedule is a **cron string, not an interval**, so the ticks land on
 *     the quarter hour instead of drifting off it by however long yesterday's
 *     runs took;
 *   * every tick re-serves the **previous hour's** zones as well as its own
 *     (`dueOffsetsAt`), so a run that threw is swept up by the next one rather
 *     than waiting a day, and each bucket is its own try/catch so one bad zone
 *     cannot take the rest down with it;
 *   * a device that has **never reported a zone** is not dropped. It is served
 *     with its account's zoned phones when it has any, and out of the
 *     deployment's fallback bucket when it has none — see
 *     `fallbackOffsetMinutes`, which is the difference between "most of the
 *     fleet, until they update" and "nobody".
 *
 * ## It is sent to people with something left, and to nobody else
 *
 * A reminder to play, delivered to somebody who already played, is the single
 * fastest way to teach a user to swipe this app's notifications away unread.
 * `claimNudges` checks the day's five results — the code puzzle and the four
 * boards — and a finished set is silently skipped.
 *
 * ## It does not say the same thing every day
 *
 * The second way to teach somebody to ignore a daily notification is to send
 * them the same sentence every day, which is what this did: two fixed lines,
 * for the rest of time. Now `claimNudges` returns the day's SHAPE — how many
 * are left, whether anything was opened and abandoned, whether the day is
 * untouched — `friendsAhead` adds how many friends got there first, and
 * `composeNudge` picks from every line that is true, rotating by calendar day
 * so consecutive days cannot repeat and everyone in a language reads the same
 * line on the same day.
 *
 * The lines never name a game. The backend knows perfectly well which board was
 * left half-played, and saying so would turn a nudge into a status report — and
 * would multiply the table below by four game names in twelve languages for a
 * detail nobody wants at lunchtime.
 *
 * ## Once per person per day, provably
 *
 * `users.lastNudgedDayKey` is claimed and stamped inside one mutation. A retry,
 * an overlapping deploy, a catch-up tick, or a person carrying a phone in
 * Auckland and a laptop in Lisbon — whose local noons are two different cron
 * ticks — all find the day already claimed and send nothing.
 *
 * The claim is per ACCOUNT and the audience index is per DEVICE, so the fan-out
 * runs the other way round afterwards: the winner of a claim is re-read through
 * `by_user` (`devicesForUsers`) and every phone it owns in that bucket is sent
 * to. Reading the devices straight off the audience page instead — which is
 * what this did first — dropped every phone that happened to land on a later
 * page of a busy zone.
 *
 * ## Phones, and phones only
 *
 * The audience is APNs and FCM devices. Web is left out on purpose and desktop
 * has no way to be reached at all; `nudgeableDevice` carries the reasoning and
 * what each would need.
 *
 * ## In the language the screen is already in
 *
 * Copy is resolved per DEVICE, off `userDevices.locale`, which is the language
 * that device's app actually resolved (see `push.sendAlertToDevices` for why
 * this one is not per-account) — so the phone and the tablet of one bilingual
 * household each read in their own. The table below is the whole vocabulary; it
 * mirrors `lib/l10n/app_*.arb` and must gain a row on the day a thirteenth
 * language ships. `daily_nudge_copy_test.dart` fails if it doesn't, and fails
 * too if a language is given fewer lines than English — a row that quietly
 * shrinks to one variant is a language back on the treadmill this file just
 * got off.
 */

/** Local minutes past midnight the nudge is sent at. */
const NOON_MINUTES = 12 * 60;

/**
 * The real range of UTC offsets — Baker Island at −12:00 through Kiritimati at
 * +14:00. Wider than a day, which is why a tick can have two answers: at 22:00
 * UTC it is noon both in Hawaii (−10) and, tomorrow, on Kiritimati (+14).
 */
const MIN_OFFSET = -720;
const MAX_OFFSET = 840;

/**
 * How stale a device may be and still be worth nudging.
 *
 * A phone nobody has opened in a month is not a player taking a day off; the
 * push either fails or lands somewhere it isn't wanted. This bound is also what
 * keeps a tick's index range from growing without limit as the table does.
 */
const ACTIVE_WINDOW_DAYS = 30;

/** Devices read per page, and users claimed per mutation. */
const DEVICE_PAGE = 200;
const CLAIM_BATCH = 100;

/**
 * The same, for the zone-less bucket, which pays more per row.
 *
 * Every distinct account on such a page costs a `by_user` read of up to
 * [DEVICES_PER_USER] rows, to establish that it has no zoned phone somewhere
 * else (`hasZonedDevice`). At the full page size that is 200 × 50 documents in
 * one query — near Convex's per-query read ceiling, and a limit is not a thing
 * to find out about from a cron job that has quietly stopped.
 */
const ZONELESS_PAGE = 50;

/**
 * Ceiling on pages per tick, so one runaway zone cannot turn a cron job into an
 * unbounded loop. 60 × 200 is 12 000 devices in a single time zone; passing it
 * is logged loudly rather than silently truncated.
 */
const MAX_PAGES = 60;

/**
 * Devices read per account when fanning a claim back out.
 *
 * A person owns a handful; the cap is there because `by_user` also accumulates
 * the rows of every phone they have ever signed out of and back into, and an
 * unbounded read is not a thing a per-account loop may contain.
 */
const DEVICES_PER_USER = 50;

/**
 * How many ticks after a zone's noon will still try to nudge it.
 *
 * A zone gets exactly ONE tick a day. That made a single throw — a deploy
 * landing mid-run, the push action refusing, the box swapping hard enough to
 * time a query out — cost that entire zone its day, silently, with the next
 * attempt twenty-four hours away.
 *
 * A grace window is affordable because the decision is claimed per person per
 * day (`users.lastNudgedDayKey`): a second look at a zone already served reads
 * one document per person and sends nothing. Four ticks is an hour of second
 * chances.
 */
const CATCH_UP_TICKS = 4;

/**
 * The zone assumed for a device that has never reported one.
 *
 * `tzOffsetMinutes` is absent on every row written before this feature shipped
 * and on every row an older app build writes — which, for a while after it
 * ships, is most of the fleet. Those are not a tail worth rounding off: they
 * hold live APNs and FCM tokens, they are opened daily, and under a strictly
 * zoned audience query they are unreachable FOREVER, because nothing in this
 * path is what teaches a device to report its zone. Measured on the day after
 * this shipped, they were five of the eleven push-capable phones on the
 * deployment.
 *
 * So they are nudged at noon in this offset instead, and the moment their app
 * does report a zone they move to their own bucket and this is never consulted
 * for them again. `NUDGE_FALLBACK_TZ_OFFSET` overrides it per deployment — set
 * it to the offset most of these users actually live in (`180` for Istanbul)
 * so the guess is a good one rather than merely a defined one.
 *
 * Read per call rather than at module load: Convex keeps an isolate warm across
 * invocations, so a value captured at import time would survive an
 * `npx convex env set` and go on being the old one for as long as that isolate
 * lives.
 */
export function fallbackOffsetMinutes(): number {
  const raw = process.env.NUDGE_FALLBACK_TZ_OFFSET;
  const parsed = raw === undefined || raw === "" ? NaN : Number(raw);
  if (!Number.isFinite(parsed)) return 0;
  const snapped = Math.round(parsed / 15) * 15;
  return Math.min(MAX_OFFSET, Math.max(MIN_OFFSET, snapped));
}

// ────────────────────────── the copy ──────────────────────────

/**
 * The lines one language can say, grouped by what is true of the reader.
 *
 * Every field is a LIST, and that is the whole point. This notification arrives
 * at the same hour every single day forever; two fixed sentences — which is
 * what this was — stop being read within a week, and a reminder nobody reads is
 * a reminder that only costs goodwill. `pickLine` rotates through the list by
 * calendar day, so everyone in a language sees the same line on the same day
 * and nobody sees the same line two days running.
 *
 * The lines are also DELIBERATELY GENERIC. None of them names Queens or Tango
 * or the code, even though the backend knows exactly which board was left open:
 * naming one turns a nudge into a report, and it multiplies this table by four
 * game names in twelve languages for a detail nobody needs at lunchtime.
 * "you left one half finished" is the whole idea, and it is true in every
 * language without a glossary.
 *
 * `{count}` is substituted where it appears — how many are LEFT in `partway`,
 * how many FRIENDS in `friendsAhead`. A language whose grammar makes a bare
 * numeral awkward (Arabic's dual, chiefly) is free to write the line without
 * the placeholder; nothing requires it.
 */
type NudgeCopy = {
  /** Rotated too — the shade should not read identically every noon. */
  titles: string[];
  /** Nothing finished and nothing opened today. */
  fresh: string[];
  /** Some of it is done. `{count}` is how many are left. */
  partway: string[];
  /** Something was opened, played into, and walked away from. */
  halfDone: string[];
  /** Exactly one thing left in the whole day. */
  oneLeft: string[];
  /** Friends have already played today. `{count}` is how many. */
  friendsAhead: string[];
};

/**
 * One row per language the app ships, keyed by the same tags
 * `AppLocalizations.supportedLocales` yields, lowercased and hyphenated.
 *
 * The register is the app's own: lower case where the script has case, second
 * person the way each `app_*.arb` already addresses the reader (informal in
 * Turkish, Korean and Swedish; polite in Japanese and Hindi, because those ARBs
 * are), and dry rather than cheerful. A notification that sounds like a
 * different product than the screen it opens reads as spam.
 */
const NUDGE_COPY: Record<string, NudgeCopy> = {
  en: {
    titles: ["today's games", "the games", "still open"],
    fresh: [
      "nobody is going to play these for you.",
      "today's set is untouched.",
      "still all there, exactly as you left it.",
      "the day is half gone and none of them are.",
    ],
    partway: [
      "{count} left today. they aren't going anywhere.",
      "{count} still open.",
      "you got some of them. {count} to go.",
      "{count} short of a clean day.",
    ],
    halfDone: [
      "you left one half finished. it is still half finished.",
      "something is sitting there mid-move.",
      "one of them is waiting exactly where you stopped.",
    ],
    oneLeft: [
      "one left. that's it.",
      "one to go, and then today is done.",
      "just the one.",
    ],
    friendsAhead: [
      "{count} of your friends have already been here today.",
      "{count} of them got there first.",
      "{count} friends have played today. you haven't.",
    ],
  },
  tr: {
    titles: ["bugünün oyunları", "oyunlar", "hâlâ açık"],
    fresh: [
      "bunları senin yerine kimse oynamayacak.",
      "bugünkülere hiç dokunulmamış.",
      "hepsi yerinde duruyor, sabahki gibi.",
      "günün yarısı gitti, onların hiçbiri gitmedi.",
    ],
    partway: [
      "bugün {count} tane kaldı. bir yere gittikleri yok.",
      "{count} tanesi hâlâ açık.",
      "bir kısmını hallettin. {count} tane duruyor.",
      "temiz bir günden {count} tane uzaktasın.",
    ],
    halfDone: [
      "birini yarım bıraktın. hâlâ yarım.",
      "bir tanesi tam ortasında öylece duruyor.",
      "biri seni bıraktığın yerde bekliyor.",
    ],
    oneLeft: [
      "bir tane kaldı. o kadar.",
      "bir tane daha, sonra bugün biter.",
      "sadece bir tane.",
    ],
    friendsAhead: [
      "{count} arkadaşın bugün buraya çoktan uğradı.",
      "{count} kişi senden önce davrandı.",
      "{count} arkadaşın bugün oynadı. sen oynamadın.",
    ],
  },
  es: {
    titles: ["los juegos de hoy", "los juegos", "sigue abierto"],
    fresh: [
      "nadie va a jugarlos por ti.",
      "lo de hoy sigue sin tocar.",
      "todo sigue ahí, tal como lo dejaste.",
      "va medio día y ninguno hecho.",
    ],
    partway: [
      "quedan {count} para hoy. no se van a mover.",
      "{count} siguen abiertos.",
      "algunos ya están. quedan {count}.",
      "a {count} de un día completo.",
    ],
    halfDone: [
      "dejaste uno a medias. sigue a medias.",
      "hay uno parado justo donde lo dejaste.",
      "uno se quedó a mitad de camino.",
    ],
    oneLeft: [
      "queda uno. nada más.",
      "uno más y el día está hecho.",
      "solo queda uno.",
    ],
    friendsAhead: [
      "{count} de tus amigos ya pasaron por aquí hoy.",
      "{count} se te adelantaron.",
      "{count} amigos ya jugaron hoy. tú no.",
    ],
  },
  fr: {
    titles: ["les jeux du jour", "les jeux", "toujours ouvert"],
    fresh: [
      "personne ne va les faire à ta place.",
      "rien de touché aujourd'hui.",
      "tout est encore là, comme ce matin.",
      "la journée est à moitié passée, eux non.",
    ],
    partway: [
      "il en reste {count} aujourd'hui. ils ne bougeront pas.",
      "{count} encore ouverts.",
      "tu en as fait une partie. il en reste {count}.",
      "à {count} d'une journée complète.",
    ],
    halfDone: [
      "tu en as laissé un à moitié. il est toujours à moitié.",
      "il y en a un arrêté en plein milieu.",
      "un t'attend exactement là où tu t'es arrêté.",
    ],
    oneLeft: [
      "il en reste un. c'est tout.",
      "encore un et la journée est bouclée.",
      "juste un.",
    ],
    friendsAhead: [
      "{count} de tes amis sont déjà passés aujourd'hui.",
      "{count} t'ont devancé.",
      "{count} amis ont joué aujourd'hui. pas toi.",
    ],
  },
  pt: {
    titles: ["os jogos de hoje", "os jogos", "ainda aberto"],
    fresh: [
      "ninguém os vai jogar por ti.",
      "os de hoje continuam por tocar.",
      "está tudo lá, tal como deixaste.",
      "já vai meio dia e nenhum feito.",
    ],
    partway: [
      "faltam {count} hoje. não vão a lado nenhum.",
      "{count} ainda por fazer.",
      "já fizeste alguns. faltam {count}.",
      "a {count} de um dia completo.",
    ],
    halfDone: [
      "deixaste um a meio. continua a meio.",
      "há um parado exatamente onde paraste.",
      "um ficou a meio caminho.",
    ],
    oneLeft: [
      "falta um. é só isso.",
      "mais um e o dia fica feito.",
      "só falta um.",
    ],
    friendsAhead: [
      "{count} dos teus amigos já passaram por aqui hoje.",
      "{count} chegaram primeiro.",
      "{count} amigos já jogaram hoje. tu não.",
    ],
  },
  // Kept apart from `pt` for the same reason the ARB files are: the second
  // person is "você" here and "tu" there, and one file cannot be both.
  "pt-br": {
    titles: ["os jogos de hoje", "os jogos", "ainda aberto"],
    fresh: [
      "ninguém vai jogar isso por você.",
      "os de hoje continuam intocados.",
      "está tudo lá, do jeito que você deixou.",
      "já é meio-dia e nenhum foi feito.",
    ],
    partway: [
      "faltam {count} hoje. não vão sair do lugar.",
      "{count} ainda abertos.",
      "você fez alguns. faltam {count}.",
      "a {count} de um dia completo.",
    ],
    halfDone: [
      "você deixou um pela metade. continua pela metade.",
      "tem um parado exatamente onde você parou.",
      "um ficou no meio do caminho.",
    ],
    oneLeft: [
      "falta um. só isso.",
      "mais um e o dia acaba.",
      "só falta um.",
    ],
    friendsAhead: [
      "{count} dos seus amigos já passaram por aqui hoje.",
      "{count} chegaram antes.",
      "{count} amigos jogaram hoje. você não.",
    ],
  },
  sv: {
    titles: ["dagens spel", "spelen", "fortfarande öppet"],
    fresh: [
      "ingen kommer att spela dem åt dig.",
      "dagens är helt orörda.",
      "allt ligger kvar, precis som i morse.",
      "halva dagen är borta, ingen av dem.",
    ],
    partway: [
      "{count} kvar idag. de går ingenstans.",
      "{count} fortfarande öppna.",
      "du tog några. {count} kvar.",
      "{count} från en hel dag.",
    ],
    halfDone: [
      "du lämnade ett halvfärdigt. det är fortfarande halvfärdigt.",
      "ett står stilla mitt i.",
      "ett väntar exakt där du slutade.",
    ],
    oneLeft: [
      "ett kvar. det var allt.",
      "ett till, sen är dagen klar.",
      "bara ett.",
    ],
    friendsAhead: [
      "{count} av dina vänner har redan varit här idag.",
      "{count} hann före.",
      "{count} vänner har spelat idag. inte du.",
    ],
  },
  // No `{count}` anywhere in this row, and that is a grammar decision rather
  // than an oversight: Arabic inflects the counted noun three different ways
  // across 2, 3–10 and 11+, so a single template with a numeral in it is wrong
  // for most of its range. The lines say the same thing without counting.
  ar: {
    titles: ["ألعاب اليوم", "الألعاب", "ما زالت مفتوحة"],
    fresh: [
      "لن يلعبها أحد نيابة عنك.",
      "ألعاب اليوم لم تُفتح بعد.",
      "كل شيء في مكانه، كما تركته.",
      "مضى نصف اليوم ولم يمضِ أي منها.",
    ],
    partway: [
      "أنجزت بعضها. الباقي ما زال مفتوحًا.",
      "ما زال بعضها ينتظر.",
      "لم ينتهِ اليوم بعد.",
      "لم يبقَ الكثير ليكتمل اليوم.",
    ],
    halfDone: [
      "تركت واحدة في منتصفها. ما زالت كذلك.",
      "هناك واحدة متوقفة عند النقطة التي تركتها.",
      "واحدة تنتظرك تمامًا حيث توقفت.",
    ],
    oneLeft: [
      "بقيت واحدة فقط.",
      "واحدة أخرى وينتهي اليوم.",
      "واحدة. لا أكثر.",
    ],
    friendsAhead: [
      "أصدقاؤك مرّوا من هنا اليوم قبلك.",
      "سبقك بعض أصدقائك اليوم.",
      "أصدقاؤك لعبوا اليوم. أنت لا.",
    ],
  },
  hi: {
    titles: ["आज के खेल", "खेल", "अब भी खुले हैं"],
    fresh: [
      "ये आपकी जगह कोई नहीं खेलेगा।",
      "आज वालों को अब तक छुआ भी नहीं गया।",
      "सब वैसे ही रखा है, जैसे सुबह छोड़ा था।",
      "आधा दिन निकल गया, इनमें से एक भी नहीं।",
    ],
    partway: [
      "आज {count} बाकी हैं। वे कहीं नहीं जा रहे।",
      "{count} अब भी खुले हैं।",
      "कुछ निपटा दिए। {count} बचे हैं।",
      "पूरे दिन से {count} दूर।",
    ],
    halfDone: [
      "एक अधूरा छोड़ा था। अब भी अधूरा है।",
      "एक ठीक वहीं रुका है जहाँ आप रुके थे।",
      "एक बीच रास्ते में पड़ा है।",
    ],
    oneLeft: [
      "एक बचा है। बस।",
      "एक और, फिर आज पूरा।",
      "सिर्फ़ एक।",
    ],
    friendsAhead: [
      "आपके {count} दोस्त आज यहाँ हो आए।",
      "{count} लोग आपसे पहले निकल गए।",
      "{count} दोस्त आज खेल चुके। आप नहीं।",
    ],
  },
  ja: {
    titles: ["今日のゲーム", "ゲーム", "まだ開いています"],
    fresh: [
      "誰も代わりに解いてはくれません。",
      "今日のはまだ手つかずです。",
      "全部そのまま、朝のままです。",
      "一日の半分は過ぎました。こちらは一つも。",
    ],
    partway: [
      "今日はあと{count}個。どこにも行きません。",
      "{count}個、まだ開いています。",
      "いくつかは片付きました。残り{count}個です。",
      "完全な一日まであと{count}個。",
    ],
    halfDone: [
      "途中でやめたものがそのまま残っています。",
      "一つ、手を止めたところで止まったままです。",
      "やめた場所でそのまま待っています。",
    ],
    oneLeft: [
      "あと一つ。それだけです。",
      "あと一つで今日は終わりです。",
      "残りは一つだけです。",
    ],
    friendsAhead: [
      "友だち{count}人が今日もう来ています。",
      "{count}人に先を越されました。",
      "{count}人は今日やりました。あなたはまだです。",
    ],
  },
  ko: {
    titles: ["오늘의 게임", "게임", "아직 열려 있어"],
    fresh: [
      "대신 풀어줄 사람은 없어.",
      "오늘 건 아직 손도 안 댔네.",
      "전부 그대로야, 아침 그대로.",
      "하루의 절반이 갔는데, 이건 하나도.",
    ],
    partway: [
      "오늘 {count}개 남았어. 어디 안 가.",
      "{count}개 아직 열려 있어.",
      "몇 개는 했네. {count}개 남았어.",
      "완벽한 하루까지 {count}개.",
    ],
    halfDone: [
      "하나 하다 말았지. 아직 그대로야.",
      "하나가 멈춘 자리에 그대로 있어.",
      "멈춘 그 자리에서 기다리는 중.",
    ],
    oneLeft: [
      "하나 남았어. 그게 다야.",
      "하나만 더 하면 오늘 끝.",
      "딱 하나.",
    ],
    friendsAhead: [
      "친구 {count}명이 오늘 벌써 다녀갔어.",
      "{count}명이 먼저 갔어.",
      "{count}명은 오늘 했어. 너는 아직.",
    ],
  },
  zh: {
    titles: ["今日游戏", "游戏", "还开着"],
    fresh: [
      "没人会替你玩。",
      "今天的还没动过。",
      "都还在，跟早上一样。",
      "半天过去了，一个都没动。",
    ],
    partway: [
      "今天还剩 {count} 个。它们不会跑。",
      "{count} 个还开着。",
      "做掉几个了。还剩 {count} 个。",
      "离满勤还差 {count} 个。",
    ],
    halfDone: [
      "有一个做了一半，还是一半。",
      "有一个停在你离开的地方。",
      "一个卡在半路上。",
    ],
    oneLeft: [
      "还剩一个。就这些。",
      "再一个，今天就完了。",
      "只剩一个。",
    ],
    friendsAhead: [
      "{count} 个朋友今天已经来过了。",
      "{count} 个人比你先到。",
      "{count} 个朋友今天玩了。你还没。",
    ],
  },
};

/**
 * The copy for one device's language, falling back the way a locale resolver
 * should: exact tag, then the bare language, then English.
 *
 * "pt-BR" therefore finds its own row, "pt-PT" falls to "pt", and a device that
 * has never reported a locale at all — every row written before this shipped —
 * reads in English rather than reading in nothing.
 */
export function copyFor(tag: string | undefined): NudgeCopy {
  if (!tag) return NUDGE_COPY.en;
  const norm = tag.toLowerCase().replace(/_/g, "-");
  return NUDGE_COPY[norm] ?? NUDGE_COPY[norm.split("-")[0]] ?? NUDGE_COPY.en;
}

// ────────────────────────── choosing a line ──────────────────────────

/** What the day's own rows say about one person, as the copy needs it. */
export type Signals = {
  /** How many of the five are still unfinished. Never 0 — those are skipped. */
  remaining: number;
  /** Nothing opened and nothing finished. */
  startedNothing: boolean;
  /** Something was played into and left. */
  halfDone: boolean;
  /** Friends who have already finished something today. 0 if not looked up. */
  friendsAhead: number;
};

/**
 * Below this, the social line is not used.
 *
 * Two is where "some of your friends" starts being a crowd rather than a
 * person. At one it is a message about one identifiable friend's day, which is
 * a disclosure nobody asked for and a far weaker line besides.
 */
const FRIENDS_MIN = 2;

/** One candidate line and the number that belongs in its `{count}`. */
type Line = { text: string; count: number };

/**
 * Every line that is true of this person today.
 *
 * Pooled rather than ranked, which is what keeps the strongest hook from
 * becoming the only one anybody ever sees: somebody with active friends is
 * eligible for the social line EVERY day, and ranking it first would hand them
 * the same sentence forever — the exact failure this rewrite exists to fix.
 * Pooling lets it come round often without crowding out the rest.
 *
 * `oneLeft` is the single exception and replaces the pool outright. It is true
 * on maybe one day in ten, it is the day the person is most likely to act on,
 * and it would be a waste to say anything else.
 */
export function poolFor(copy: NudgeCopy, s: Signals): Line[] {
  if (s.remaining === 1) return copy.oneLeft.map((text) => ({ text, count: 1 }));
  const pool: Line[] = (s.startedNothing ? copy.fresh : copy.partway).map(
    (text) => ({ text, count: s.remaining }),
  );
  if (s.halfDone) {
    for (const text of copy.halfDone) pool.push({ text, count: s.remaining });
  }
  if (s.friendsAhead >= FRIENDS_MIN) {
    for (const text of copy.friendsAhead) {
      pool.push({ text, count: s.friendsAhead });
    }
  }
  return pool;
}

/**
 * Days since the Unix epoch for a `YYYY-MM-DD` key.
 *
 * The rotation index, and a calendar day rather than a hash on purpose:
 * consecutive days must land on consecutive lines, or two days running can
 * collide and the whole point of having more than one line is lost. It also
 * means everyone in a language reads the same line on the same day, which is
 * what makes the copy something friends can mention to each other.
 */
export function dayOrdinal(dayKey: string): number {
  const [y, m, d] = dayKey.split("-").map(Number);
  if (!Number.isFinite(y) || !Number.isFinite(m) || !Number.isFinite(d)) {
    return 0;
  }
  return Math.floor(Date.UTC(y, m - 1, d) / 86_400_000);
}

/** Index [ordinal] into [items], safe for an empty or short list. */
function rotate<T>(items: T[], ordinal: number): T | undefined {
  if (items.length === 0) return undefined;
  return items[((ordinal % items.length) + items.length) % items.length];
}

/**
 * The title and body one device reads today.
 *
 * The title is advanced on a different stride from the body so the two do not
 * lock into the same pairing for good — three titles against a three-line pool
 * would otherwise reproduce the same notification every third day, which is the
 * problem again with extra steps.
 */
export function composeNudge(
  copy: NudgeCopy,
  s: Signals,
  ordinal: number,
): { title: string; body: string } {
  const line = rotate(poolFor(copy, s), ordinal);
  const title = rotate(copy.titles, ordinal * 2 + 1) ?? NUDGE_COPY.en.titles[0];
  return {
    title,
    body: (line?.text ?? "").split("{count}").join(String(line?.count ?? 0)),
  };
}

// ────────────────────────── time ──────────────────────────

/**
 * The quarter-hour this tick belongs to, as minutes past UTC midnight.
 *
 * Rounded rather than floored: a cron that fires at 08:59:58 because of clock
 * skew still means the 09:00 tick, and flooring it would silently target a
 * time zone fifteen minutes off — one that is real, populated, and would then
 * be nudged at 12:15 forever while its neighbour got nothing.
 */
export function tickMinutes(now: number): number {
  const utcMinutes = Math.floor(now / 60_000) % 1440;
  return (Math.round(utcMinutes / 15) * 15) % 1440;
}

/** Which UTC offsets are at [NOON_MINUTES] on the tick containing [now]. */
export function noonOffsetsAt(now: number): number[] {
  const tick = tickMinutes(now);
  const base = (((NOON_MINUTES - tick) % 1440) + 1440) % 1440;
  // Both candidates, not one: the offset range spans 26 hours, so a single
  // instant can be noon in two zones a day apart.
  return [base, base - 1440].filter((o) => o >= MIN_OFFSET && o <= MAX_OFFSET);
}

/**
 * Every offset this tick is responsible for — the ones at noon right now, and
 * the ones that were at noon over the previous [CATCH_UP_TICKS].
 *
 * The overlap is the point. Whatever went wrong an hour ago — a run that threw,
 * a deploy that landed mid-sweep, a tick the scheduler never fired — this tick
 * covers, and it covers it for free: those zones are already claimed for the
 * day, so re-reading them sends nothing.
 *
 * Ordered nearest-first and deduped, so the zone whose noon this actually is
 * gets served before the ones being swept up behind it.
 */
export function dueOffsetsAt(now: number): number[] {
  const out: number[] = [];
  for (let back = 0; back <= CATCH_UP_TICKS; back++) {
    for (const o of noonOffsetsAt(now - back * 15 * 60_000)) {
      if (!out.includes(o)) out.push(o);
    }
  }
  return out;
}

/**
 * The day key a device at [offsetMinutes] is living in at [now].
 *
 * Identical in shape to Dart's `dayKeyOf` (lib/data/feed_day.dart) because it
 * indexes the same rows: `YYYY-MM-DD` of the LOCAL date. Read off a UTC-shifted
 * instant rather than a formatter, so it does not depend on the runtime's ICU
 * data being present or on what zone the deployment thinks it is in.
 */
export function dayKeyAt(now: number, offsetMinutes: number): string {
  const d = new Date(now + offsetMinutes * 60_000);
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${d.getUTCFullYear()}-${m}-${day}`;
}

// ────────────────────────── audience ──────────────────────────

/** What one nudgeable device contributes to the send. */
type NudgeDevice = {
  deviceRowId: Id<"userDevices">;
  deviceId: string;
  platform: string;
  apnsToken?: string;
  apnsEnv?: "sandbox" | "production";
  fcmToken?: string;
  locale?: string;
};

/**
 * [NudgeDevice] as a validator, because `candidates` hands these across a
 * function boundary and Convex checks what crosses one.
 */
const vNudgeDevice = v.object({
  deviceRowId: v.id("userDevices"),
  deviceId: v.string(),
  platform: v.string(),
  apnsToken: v.optional(v.string()),
  apnsEnv: v.optional(
    v.union(v.literal("sandbox"), v.literal("production")),
  ),
  fcmToken: v.optional(v.string()),
  locale: v.optional(v.string()),
});

/**
 * Whether this device should be sent the nudge, and what the sender needs if so.
 *
 * **Phones only — APNs and FCM.** The two switches are checked first, and then
 * the transport, and that last test is a product decision rather than a
 * technical limit:
 *
 *   * **Web is deliberately excluded** even though `push.sendAlertToDevices`
 *     could reach it. A browser only receives a push while its service worker
 *     is alive, so the audience is "people who happened to leave the tab open",
 *     and the ones it misses look identical to the ones who ignored it. Enabling
 *     it later is this one condition plus a `daily_games` branch in
 *     `notificationclick` (web/mh-push-sw.js) to open the games shelf — nothing
 *     else here changes.
 *   * **Desktop cannot be reached at all**, and not just for this: macOS,
 *     Windows and Linux have no notification surface in this app, so they hold
 *     a `userDevices` row with no credential on it and fail this test on their
 *     own. They still report their language and time zone (see
 *     `PushManager.syncDeviceContext`), so the day one of them grows a local
 *     notifier it joins the audience with no change to this file.
 */
function nudgeableDevice(r: Doc<"userDevices">): NudgeDevice | null {
  // `undefined` means enabled on both switches — every row written before
  // either field existed. They are separate gates on purpose: the first is
  // "reach this device at all", the second is "…including for this".
  if (r.pushEnabled === false) return null;
  if (r.gameRemindersEnabled === false) return null;
  if (!r.apnsToken && !r.fcmToken) return null;
  // `voipToken` is deliberately absent, exactly as in `push._loadAlertTargets`:
  // it belongs to a different APNs topic, and sending an alert to it clears a
  // perfectly good credential and stops that phone ringing.
  return {
    deviceRowId: r._id,
    deviceId: r.deviceId,
    platform: r.platform,
    apnsToken: r.apnsToken,
    apnsEnv: r.apnsEnv,
    fcmToken: r.fcmToken,
    locale: r.locale,
  };
}

/**
 * Whether [userId] owns a live device that HAS reported a zone.
 *
 * Asked only of the zone-less bucket, and it is what keeps that bucket a
 * fallback rather than a second address: somebody whose phone reports Istanbul
 * and whose tablet reports nothing is served at Istanbul's noon, with the
 * tablet riding along (see `devicesForUsers`), and must not also be served at
 * the deployment's guess.
 */
async function hasZonedDevice(
  ctx: any,
  userId: Id<"users">,
  cutoff: number,
): Promise<boolean> {
  const rows: Array<Doc<"userDevices">> = await ctx.db
    .query("userDevices")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .take(DEVICES_PER_USER);
  const live = await liveSessionDeviceIds(ctx, userId);
  return rows.some(
    (r) =>
      r.tzOffsetMinutes !== undefined &&
      r.lastSeenAt > cutoff &&
      live.has(r.deviceId) &&
      nudgeableDevice(r) !== null,
  );
}

/**
 * One page of the ACCOUNTS a bucket is holding.
 *
 * `tzOffsetMinutes: null` addresses the zone-less bucket — every device that
 * has never told us where it is. See `fallbackOffsetMinutes` for why that is a
 * bucket at all and not simply an audience we decline to reach.
 *
 * Accounts and not devices, which is what closes two holes the device-shaped
 * version had. A page is 200 rows and the day is claimed ONCE per account, so
 * a person whose phones straddled a page boundary had the second page's phones
 * silently dropped; and a phone that has never reported a zone can sit on the
 * same account as one that has, unreachable next to a device we were reaching.
 * `devicesForUsers` re-reads the account and answers both.
 *
 * Paginated rather than collected: a popular time zone is a large fraction of
 * the whole user base, and "every device in Europe/Istanbul" is not a thing one
 * query may return.
 */
export const candidateUsers = internalQuery({
  args: {
    tzOffsetMinutes: v.union(v.number(), v.null()),
    cutoff: v.number(),
    cursor: v.union(v.string(), v.null()),
  },
  returns: v.object({
    userIds: v.array(v.id("users")),
    cursor: v.string(),
    isDone: v.boolean(),
    scanned: v.number(),
  }),
  handler: async (ctx, { tzOffsetMinutes, cutoff, cursor }) => {
    const page = await ctx.db
      .query("userDevices")
      .withIndex("by_tz_offset", (q) =>
        q
          // `null` crosses the function boundary because `undefined` does not
          // survive Convex's argument encoding; the index itself is probed with
          // `undefined`, which is how a missing field is addressed.
          .eq("tzOffsetMinutes", tzOffsetMinutes ?? undefined)
          .gt("lastSeenAt", cutoff),
      )
      .paginate({
        cursor,
        numItems: tzOffsetMinutes === null ? ZONELESS_PAGE : DEVICE_PAGE,
      });
    const seen = new Set<string>();
    // One live-session read per ACCOUNT, not per row: a page is 200 devices
    // and a person's phones sit next to each other in it.
    const liveByUser = new Map<string, Set<string>>();
    const liveFor = async (userId: Id<"users">) => {
      const key = userId.toString();
      let set = liveByUser.get(key);
      if (set === undefined) {
        set = await liveSessionDeviceIds(ctx, userId);
        liveByUser.set(key, set);
      }
      return set;
    };
    const userIds: Array<Id<"users">> = [];
    for (const row of page.page) {
      if (!nudgeableDevice(row)) continue;
      // Signed out on this handset. Checked here as well as in
      // `devicesForUsers` so a stranded row cannot CLAIM the day for an
      // account and then send nothing, which would cost that person the
      // nudge their live phone had coming.
      if (!(await liveFor(row.userId)).has(row.deviceId)) continue;
      const key = row.userId.toString();
      if (seen.has(key)) continue;
      seen.add(key);
      if (
        tzOffsetMinutes === null &&
        (await hasZonedDevice(ctx, row.userId, cutoff))
      ) {
        continue;
      }
      userIds.push(row.userId);
    }
    return {
      userIds,
      cursor: page.continueCursor,
      isDone: page.isDone,
      scanned: page.page.length,
    };
  },
});

/**
 * Every device of [userIds] that this bucket should reach.
 *
 * Called AFTER the claim, on the accounts that won it, so the fan-out is over
 * people who are actually being sent something rather than over everyone the
 * index handed back.
 *
 * A device in a DIFFERENT zone is left out: its own local noon is a different
 * tick, and buzzing it here is exactly the 02:00 notification the whole design
 * exists to avoid. A device with NO zone rides along with the account's zoned
 * phones — that is the best guess available for it, and a far better one than
 * the deployment-wide fallback, which is why the zone-less bucket then declines
 * to serve that account a second time.
 */
export const devicesForUsers = internalQuery({
  args: {
    userIds: v.array(v.id("users")),
    tzOffsetMinutes: v.union(v.number(), v.null()),
    cutoff: v.number(),
  },
  returns: v.array(v.object({ userId: v.id("users"), device: vNudgeDevice })),
  handler: async (ctx, { userIds, tzOffsetMinutes, cutoff }) => {
    const out: Array<{ userId: Id<"users">; device: NudgeDevice }> = [];
    for (const userId of userIds) {
      const rows = await ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", userId))
        .take(DEVICES_PER_USER);
      const live = await liveSessionDeviceIds(ctx, userId);
      for (const row of rows) {
        if (row.lastSeenAt <= cutoff) continue;
        // Signed out on this handset — see [liveSessionDeviceIds]. The
        // 30-day `lastSeenAt` window above already hid most of these, which
        // is why the nudge was the quieter half of the same bug.
        if (!live.has(row.deviceId)) continue;
        if (tzOffsetMinutes === null) {
          if (row.tzOffsetMinutes !== undefined) continue;
        } else if (
          row.tzOffsetMinutes !== undefined &&
          row.tzOffsetMinutes !== tzOffsetMinutes
        ) {
          continue;
        }
        const d = nudgeableDevice(row);
        if (d) out.push({ userId, device: d });
      }
    }
    return out;
  },
});

// ────────────────────────── the claim ──────────────────────────

/**
 * Decide, and commit the decision, for one batch of accounts.
 *
 * Read and write in the same mutation on purpose. Splitting "who still has
 * something to play" from "mark them nudged" would leave a window in which two
 * ticks both answer yes, and the failure that produces — two notifications the
 * same lunchtime — is exactly the one this feature cannot afford.
 *
 * An account that has finished everything is skipped WITHOUT claiming the day.
 * That costs nothing (it will simply be re-checked and skipped again if another
 * of their zones comes round) and keeps the column honest: it records days this
 * account was actually sent something.
 *
 * What comes back is the day's SHAPE, not a sentence — `composeNudge` turns it
 * into words per device, because the words depend on the device's language and
 * the shape does not.
 */
export const claimNudges = internalMutation({
  args: { userIds: v.array(v.id("users")), dayKey: v.string() },
  returns: v.array(
    v.object({
      userId: v.id("users"),
      remaining: v.number(),
      startedNothing: v.boolean(),
      halfDone: v.boolean(),
    }),
  ),
  handler: async (ctx, { userIds, dayKey }) => {
    const claimed: Array<{
      userId: Id<"users">;
      remaining: number;
      startedNothing: boolean;
      halfDone: boolean;
    }> = [];
    for (const userId of userIds) {
      const user = await ctx.db.get(userId);
      if (!user) continue;
      if (user.lastNudgedDayKey === dayKey) continue;

      const puzzle = await ctx.db
        .query("puzzleResults")
        .withIndex("by_user_day", (q) =>
          q.eq("userId", userId).eq("dayKey", dayKey),
        )
        .first();
      // `finishedAt` and not `solved`: running out of guesses is finishing.
      // Somebody who lost today has nothing left to do with the code.
      const codeDone = puzzle?.finishedAt !== undefined;

      // The whole day's boards in one indexed read — [userId, dayKey] is a
      // prefix of `by_user_day_game`, which is why that index has three columns
      // and this has no second query per game.
      const boards = await ctx.db
        .query("gameResults")
        .withIndex("by_user_day_game", (q) =>
          q.eq("userId", userId).eq("dayKey", dayKey),
        )
        .collect();
      const played = new Set(
        boards.filter((b) => b.finishedAt !== undefined).map((b) => b.game),
      );
      const remaining =
        (codeDone ? 0 : 1) + GAMES.filter((g) => !played.has(g)).length;
      if (remaining === 0) continue;

      // "Opened and walked away from", which is not the same as "opened":
      // `start` writes a row the moment a board appears, while `progress` is
      // written by `saveProgress` when the player LEAVES the screen. Reading
      // the row alone would tell somebody still mid-puzzle that they had
      // abandoned it.
      const halfDone =
        boards.some((b) => b.finishedAt === undefined && b.progress !== undefined) ||
        (puzzle !== null &&
          puzzle.finishedAt === undefined &&
          puzzle.guesses.length > 0);
      const startedNothing = puzzle === null && boards.length === 0;

      await ctx.db.patch(userId, { lastNudgedDayKey: dayKey });
      claimed.push({ userId, remaining, startedNothing, halfDone });
    }
    return claimed;
  },
});

// ────────────────────────── the social line ──────────────────────────

/**
 * Friends per account this will look at, and accounts per query call.
 *
 * The product of these two, times the per-friend reads below, is one query's
 * whole budget — Convex caps a query at 16 384 documents, and a cron job that
 * silently started throwing at that ceiling is a worse outcome than a nudge
 * with one fewer sentence in it. 50 × 16 × 6 leaves room to spare.
 */
const SOCIAL_FRIEND_CAP = 50;
const SOCIAL_USERS_PER_QUERY = 16;

/**
 * Stop counting here.
 *
 * "five friends" and "eleven friends" are the same sentence to the person
 * reading it, and the difference costs a linear scan of a friends list to
 * establish. The count exists to say "you are behind", not to be a statistic.
 */
const SOCIAL_MAX = 5;

/** Whether [userId] has finished anything at all today. */
async function playedToday(
  ctx: any,
  userId: Id<"users">,
  dayKey: string,
): Promise<boolean> {
  const puzzle = await ctx.db
    .query("puzzleResults")
    .withIndex("by_user_day", (q: any) =>
      q.eq("userId", userId).eq("dayKey", dayKey),
    )
    .first();
  if (puzzle?.finishedAt !== undefined) return true;
  const boards: Array<Doc<"gameResults">> = await ctx.db
    .query("gameResults")
    .withIndex("by_user_day_game", (q: any) =>
      q.eq("userId", userId).eq("dayKey", dayKey),
    )
    .take(GAMES.length);
  return boards.some((b) => b.finishedAt !== undefined);
}

/**
 * How many of each account's friends have already played today.
 *
 * The one line in this file that is about somebody other than the reader, and
 * the only reason the job reads anything beyond the person it is nudging. It
 * earns that: "three of your friends have already been here today" is the
 * difference between a chore and a game, in an app whose entire daily loop is
 * a scoreboard among friends.
 *
 * Run only over accounts that have ALREADY WON A CLAIM, so nobody pays for this
 * who was not going to be sent something anyway, and capped three ways (above)
 * so it cannot grow into the query that takes the deployment down.
 *
 * `visibility.puzzle` is obeyed, exactly as `games.standings` obeys it. A count
 * looks anonymous and is not: to somebody with three friends, "2 of your
 * friends played" is a statement about specific people, and the person who
 * turned that switch off turned it off for this too.
 */
export const friendsAhead = internalQuery({
  args: { userIds: v.array(v.id("users")), dayKey: v.string() },
  returns: v.array(v.object({ userId: v.id("users"), count: v.number() })),
  handler: async (ctx, { userIds, dayKey }) => {
    const out: Array<{ userId: Id<"users">; count: number }> = [];
    for (const userId of userIds) {
      const friendships = await ctx.db
        .query("friendships")
        .withIndex("by_user", (q) => q.eq("userId", userId))
        .take(SOCIAL_FRIEND_CAP);
      let count = 0;
      for (const f of friendships) {
        if (count >= SOCIAL_MAX) break;
        if (f.status !== "accepted") continue;
        // Read the friend BEFORE their results: an opted-out friend costs one
        // document rather than six.
        const friend = await ctx.db.get(f.friendId);
        if (!friend) continue;
        if ((friend.visibility?.puzzle ?? "friends") === "nobody") continue;
        if (await playedToday(ctx, f.friendId, dayKey)) count += 1;
      }
      out.push({ userId, count });
    }
    return out;
  },
});

// ────────────────────────── the job ──────────────────────────

/**
 * A bucket of the audience: a UTC offset, or `null` for the devices that have
 * never reported one.
 */
type Bucket = number | null;

/**
 * The buckets this tick must serve, and the offset each is reasoned about in.
 *
 * The zone-less bucket rides the fallback offset's own tick, so its catch-up
 * window and its day key come out of the same arithmetic as every real zone's —
 * there is no second schedule to keep in step with this one.
 */
export function bucketsAt(
  now: number,
  fallback: number,
): Array<{ bucket: Bucket; offset: number }> {
  const due = dueOffsetsAt(now);
  const out = due.map((offset) => ({ bucket: offset as Bucket, offset }));
  if (due.includes(fallback)) out.push({ bucket: null, offset: fallback });
  return out;
}

/**
 * One cron tick: find the buckets that are due, and nudge whoever is in them.
 *
 * Scheduled on the quarter hour from crons.ts. A tick whose buckets are all
 * empty — most of them, since only a handful of the 96 daily ticks correspond
 * to a populated offset — costs one index probe each and returns nothing.
 *
 * Each bucket is its own failure boundary. They were a single loop once, and a
 * throw anywhere in it took every bucket after it down with it: one zone's bad
 * page cost an unrelated zone its whole day.
 */
export const run = internalAction({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const now = Date.now();
    const cutoff = now - ACTIVE_WINDOW_DAYS * 86_400_000;
    const fallback = fallbackOffsetMinutes();
    for (const { bucket, offset } of bucketsAt(now, fallback)) {
      const dayKey = dayKeyAt(now, offset);
      const label = bucket === null ? `no-zone@${offset}` : `offset=${offset}`;
      try {
        const { pages, nudged, truncated } = await nudgeBucket(
          ctx,
          bucket,
          cutoff,
          dayKey,
        );
        if (truncated) {
          // Loud rather than silent: a bucket this large means the ceiling
          // needs raising, and the people past it got nothing today.
          console.warn(
            `dailyNudge: ${label} hit the ${MAX_PAGES}-page ceiling — ` +
              `some devices were not reached`,
          );
        }
        if (nudged > 0 || pages > 1) {
          console.log(
            `dailyNudge: ${label} day=${dayKey} pages=${pages} nudged=${nudged}`,
          );
        }
      } catch (e) {
        // Swallowed per bucket, on purpose — see the note above. The next tick
        // is inside the catch-up window and will try this bucket again.
        console.error(
          `dailyNudge: ${label} day=${dayKey} failed: ` +
            `${e instanceof Error ? e.message : String(e)}`,
        );
      }
    }
    return null;
  },
});

/** Page through one bucket, claiming and sending as it goes. */
async function nudgeBucket(
  ctx: any,
  bucket: Bucket,
  cutoff: number,
  dayKey: string,
): Promise<{ pages: number; nudged: number; truncated: boolean }> {
  let cursor: string | null = null;
  let pages = 0;
  let nudged = 0;
  for (;;) {
    const page: {
      userIds: Array<Id<"users">>;
      cursor: string;
      isDone: boolean;
      scanned: number;
    } = await ctx.runQuery(internal.dailyNudge.candidateUsers, {
      tzOffsetMinutes: bucket,
      cutoff,
      cursor,
    });
    nudged += await dispatch(ctx, page.userIds, bucket, cutoff, dayKey);
    pages += 1;
    if (page.isDone) return { pages, nudged, truncated: false };
    if (pages >= MAX_PAGES) return { pages, nudged, truncated: true };
    cursor = page.cursor;
  }
}

/**
 * Claim one batch of accounts, then send to every device the claim covers.
 *
 * Claim first, everything else second. The reverse order would read `by_user`
 * and a friends list for everybody the index returned — including the people
 * who already played today and the ones a catch-up tick is re-reading — and the
 * claim's whole value is that it answers "no" after a single document read.
 *
 * Everything the account owns in this bucket gets the banner: two devices on
 * the same desk are two screens the person may be looking at, and that is the
 * same choice `sendAlert` makes for a chat message. They can be in different
 * LANGUAGES, though, which is why the copy is composed per device down here and
 * not once per account above.
 */
async function dispatch(
  ctx: any,
  userIds: Array<Id<"users">>,
  bucket: Bucket,
  cutoff: number,
  dayKey: string,
): Promise<number> {
  if (userIds.length === 0) return 0;
  const ordinal = dayOrdinal(dayKey);
  let nudged = 0;
  for (let i = 0; i < userIds.length; i += CLAIM_BATCH) {
    const batch = userIds.slice(i, i + CLAIM_BATCH);
    const claimed: Array<{
      userId: Id<"users">;
      remaining: number;
      startedNothing: boolean;
      halfDone: boolean;
    }> = await ctx.runMutation(internal.dailyNudge.claimNudges, {
      userIds: batch,
      dayKey,
    });
    if (claimed.length === 0) continue;

    const claimedIds = claimed.map((c) => c.userId);
    const social = await friendsAheadFor(ctx, claimedIds, dayKey);
    const signalOf = new Map<string, Signals>(
      claimed.map((c) => [
        c.userId.toString(),
        {
          remaining: c.remaining,
          startedNothing: c.startedNothing,
          halfDone: c.halfDone,
          friendsAhead: social.get(c.userId.toString()) ?? 0,
        },
      ]),
    );
    const devices: Array<{ userId: Id<"users">; device: NudgeDevice }> =
      await ctx.runQuery(internal.dailyNudge.devicesForUsers, {
        userIds: claimedIds,
        tzOffsetMinutes: bucket,
        cutoff,
      });

    const targets: Array<{
      userId: Id<"users">;
      device: NudgeDevice;
      spec: AlertSpec;
    }> = [];
    const reached = new Set<string>();
    for (const { userId, device } of devices) {
      const signals = signalOf.get(userId.toString());
      if (!signals) continue;
      reached.add(userId.toString());
      const { title, body } = composeNudge(
        copyFor(device.locale),
        signals,
        ordinal,
      );
      targets.push({
        userId,
        device,
        spec: {
          kind: "daily_games",
          title,
          body,
          // `kind` is the whole payload: it is what iOS, Android and the
          // service worker switch on to open the Feed's games shelf, and
          // there is nothing else this notification needs to carry.
          data: { kind: "daily_games" },
          // Not an unread item. iOS omits the key entirely for this kind and
          // the other two transports drop it too — see `buildApnsBody`.
          badge: 0,
          // Yesterday's nudge, if a phone somehow still holds one, is
          // replaced rather than stacked under today's.
          collapseId: `daily_games:${dayKey}`,
        },
      });
    }
    if (reached.size < claimed.length) {
      // The day was claimed for somebody nothing was then sent to, which burns
      // their nudge until tomorrow. Only reachable as a race — the device rows
      // went stale or were deleted between the two reads — so it is reported
      // rather than repaired.
      console.warn(
        `dailyNudge: day=${dayKey} claimed ${claimed.length} but reached ` +
          `${reached.size}`,
      );
    }
    if (targets.length > 0) {
      await ctx.runAction(internal.push.sendAlertToDevices, { targets });
    }
    nudged += reached.size;
  }
  return nudged;
}

/**
 * The social counts for one batch of claimed accounts, chunked.
 *
 * Chunked because the per-query read budget is what bounds this, not the batch
 * size the claim happened to use — see `SOCIAL_USERS_PER_QUERY`.
 *
 * A failure here loses the social LINE, never the notification: the pool falls
 * back to the lines that need no lookup, and somebody gets "3 left today"
 * instead of "3 of your friends have already been here". A nudge that does not
 * arrive because a friends list was slow would be a bad trade.
 */
async function friendsAheadFor(
  ctx: any,
  userIds: Array<Id<"users">>,
  dayKey: string,
): Promise<Map<string, number>> {
  const out = new Map<string, number>();
  for (let i = 0; i < userIds.length; i += SOCIAL_USERS_PER_QUERY) {
    const chunk = userIds.slice(i, i + SOCIAL_USERS_PER_QUERY);
    try {
      const rows: Array<{ userId: Id<"users">; count: number }> =
        await ctx.runQuery(internal.dailyNudge.friendsAhead, {
          userIds: chunk,
          dayKey,
        });
      for (const r of rows) out.set(r.userId.toString(), r.count);
    } catch (e) {
      console.warn(
        `dailyNudge: friendsAhead failed for ${chunk.length} accounts: ` +
          `${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }
  return out;
}

// ────────────────────────── operational visibility ──────────────────────────

/**
 * Who this job can currently see, and who it cannot.
 *
 * Worth looking at before trusting a quiet day, and worth looking at after a
 * release: a device only reports its zone once its app is new enough to, so the
 * `fallback` count is the size of the fleet still running an older build. They
 * are reached — at noon in `fallbackOffset` rather than their own — and they
 * move to `byZone` on their own the first time their app tells us where it is.
 *
 *   npx convex run dailyNudge:audienceReport
 *
 * Counts are keyed as ARRAYS rather than objects. The first version of this
 * used records, and threw `Field name — has invalid character` on every
 * deployment that had a single device with no locale — so the one command for
 * finding out whether anybody was being missed was itself always broken.
 */
export const audienceReport = internalQuery({
  args: { sinceDays: v.optional(v.number()) },
  returns: v.object({
    /** Rows within the window, whatever state they are in. */
    devices: v.number(),
    /** Holds an APNs or FCM token and neither switch is off. */
    nudgeable: v.number(),
    /** …of those, reached at their OWN local noon. */
    zoned: v.number(),
    /** …of those, reached at `fallbackOffset` because they report no zone. */
    fallback: v.number(),
    fallbackOffset: v.number(),
    /** Silenced by `pushEnabled` or `gameRemindersEnabled`. */
    optedOut: v.number(),
    /** Web and desktop rows — no transport this job will use. See
     * `nudgeableDevice`. */
    noTransport: v.number(),
    byZone: v.array(v.object({ offset: v.number(), devices: v.number() })),
    byLocale: v.array(v.object({ locale: v.string(), devices: v.number() })),
    truncated: v.boolean(),
  }),
  handler: async (ctx, { sinceDays }) => {
    const cutoff = Date.now() - (sinceDays ?? ACTIVE_WINDOW_DAYS) * 86_400_000;
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_last_seen", (q) => q.gt("lastSeenAt", cutoff))
      .take(5000);
    const byZone = new Map<number, number>();
    const byLocale = new Map<string, number>();
    let nudgeable = 0;
    let zoned = 0;
    let fallback = 0;
    let optedOut = 0;
    let noTransport = 0;
    for (const r of rows) {
      if (r.pushEnabled === false || r.gameRemindersEnabled === false) {
        optedOut += 1;
        continue;
      }
      if (!nudgeableDevice(r)) {
        noTransport += 1;
        continue;
      }
      nudgeable += 1;
      if (r.tzOffsetMinutes === undefined) {
        fallback += 1;
      } else {
        zoned += 1;
        byZone.set(r.tzOffsetMinutes, (byZone.get(r.tzOffsetMinutes) ?? 0) + 1);
      }
      const l = r.locale ?? "unknown";
      byLocale.set(l, (byLocale.get(l) ?? 0) + 1);
    }
    return {
      devices: rows.length,
      nudgeable,
      zoned,
      fallback,
      fallbackOffset: fallbackOffsetMinutes(),
      optedOut,
      noTransport,
      byZone: [...byZone.entries()]
        .map(([offset, devices]) => ({ offset, devices }))
        .sort((a, b) => a.offset - b.offset),
      byLocale: [...byLocale.entries()]
        .map(([locale, devices]) => ({ locale, devices }))
        .sort((a, b) => b.devices - a.devices),
      truncated: rows.length === 5000,
    };
  },
});
