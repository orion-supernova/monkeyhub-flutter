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

/**
 * The once-a-day "you haven't played today" nudge.
 *
 * Every other push in this backend is a consequence: somebody sent a message,
 * somebody rang, a guardian has something waiting. This one is the only push
 * the app sends nobody asked for, which is what shapes every decision below.
 *
 * ## Local noon, not a single global blast
 *
 * The cron ticks every fifteen minutes and each tick asks one question — whose
 * wall clock reads 12:00 right now? — answered by an equality probe on
 * `userDevices.by_tz_offset`. So Istanbul is nudged at Istanbul's lunchtime and
 * California at California's, from one job, and nobody is woken at 02:00 for
 * the convenience of a fixed UTC hour.
 *
 * Fifteen minutes rather than hourly because real zones are not all whole
 * hours: India is +5:30, Nepal +5:45, Chatham +12:45. An hourly tick would
 * never land on their noon at all.
 *
 * ## It is sent to people with something left, and to nobody else
 *
 * A reminder to play, delivered to somebody who already played, is the single
 * fastest way to teach a user to swipe this app's notifications away unread.
 * `claimNudges` checks the day's five results — the code puzzle and the four
 * boards — and a finished set is silently skipped.
 *
 * That check also picks the wording: somebody who has not touched the code is
 * asked about the code; somebody who cracked it and left the boards is told
 * exactly that. Two lines, both always true of the person reading them.
 *
 * ## Once per person per day, provably
 *
 * `users.lastNudgedDayKey` is claimed and stamped inside one mutation. A retry,
 * an overlapping deploy, or a person carrying a phone in Auckland and a laptop
 * in Lisbon — whose local noons are two different cron ticks — all find the day
 * already claimed and send nothing.
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
 * this one is not per-account). The table below is the whole vocabulary; it
 * mirrors `lib/l10n/app_*.arb` and must gain a row on the day a thirteenth
 * language ships. `daily_nudge_copy_test.dart` fails if it doesn't.
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
 * Ceiling on pages per tick, so one runaway zone cannot turn a cron job into an
 * unbounded loop. 60 × 200 is 12 000 devices in a single time zone; passing it
 * is logged loudly rather than silently truncated.
 */
const MAX_PAGES = 60;

// ────────────────────────── the copy ──────────────────────────

type NudgeCopy = {
  title: string;
  /** They have not finished today's code puzzle. */
  codeLeft: string;
  /** They cracked the code; boards remain. */
  boardsLeft: string;
};

/**
 * One row per language the app ships, keyed by the same tags
 * `AppLocalizations.supportedLocales` yields, lowercased and hyphenated.
 *
 * Terminology is taken from the ARB files rather than invented here — the
 * puzzle is "şifre" in Turkish and "le code" in French because that is what the
 * game is called on the screen this notification opens. A nudge that names the
 * thing differently from the app reads like it came from somebody else.
 */
const NUDGE_COPY: Record<string, NudgeCopy> = {
  en: {
    title: "today's games",
    codeLeft: "did you crack today's code yet?",
    boardsLeft: "code cracked. today's boards are still waiting.",
  },
  tr: {
    title: "bugünün oyunları",
    codeLeft: "bugünün şifresini çözdün mü?",
    boardsLeft: "şifreyi çözdün. bugünün tahtaları hâlâ seni bekliyor.",
  },
  es: {
    title: "los juegos de hoy",
    codeLeft: "¿ya descifraste el código de hoy?",
    boardsLeft: "código descifrado. los tableros de hoy siguen esperando.",
  },
  fr: {
    title: "les jeux du jour",
    codeLeft: "tu as trouvé le code du jour ?",
    boardsLeft: "code trouvé. les grilles du jour t'attendent encore.",
  },
  pt: {
    title: "os jogos de hoje",
    codeLeft: "já descobriste o código de hoje?",
    boardsLeft: "código descoberto. os tabuleiros de hoje ainda esperam por ti.",
  },
  // Kept apart from `pt` for the same reason the ARB files are: the second
  // person is "você" here and "tu" there, and one file cannot be both.
  "pt-br": {
    title: "os jogos de hoje",
    codeLeft: "já descobriu o código de hoje?",
    boardsLeft:
      "código descoberto. os tabuleiros de hoje ainda esperam por você.",
  },
  sv: {
    title: "dagens spel",
    codeLeft: "har du knäckt dagens kod?",
    boardsLeft: "koden är knäckt. dagens brickor väntar fortfarande.",
  },
  ar: {
    title: "ألعاب اليوم",
    codeLeft: "هل حللت شيفرة اليوم؟",
    boardsLeft: "حللت الشيفرة. ألواح اليوم ما زالت بانتظارك.",
  },
  hi: {
    title: "आज के खेल",
    codeLeft: "आज का कोड तोड़ लिया?",
    boardsLeft: "कोड तोड़ दिया। आज के बोर्ड अब भी बाकी हैं।",
  },
  ja: {
    title: "今日のゲーム",
    codeLeft: "今日のコードはもう解けた？",
    boardsLeft: "コードは解けたね。今日の盤面がまだ残ってる。",
  },
  ko: {
    title: "오늘의 게임",
    codeLeft: "오늘의 코드는 풀었어?",
    boardsLeft: "코드는 풀었네. 오늘의 판이 아직 남아 있어.",
  },
  zh: {
    title: "今日游戏",
    codeLeft: "今天的密码破解了吗？",
    boardsLeft: "密码解开了。今天的题目还在等你。",
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
 * One page of devices whose clock reads noon on this tick.
 *
 * Paginated rather than collected: a popular time zone is a large fraction of
 * the whole user base, and "every device in Europe/Istanbul" is not a thing one
 * query may return.
 */
export const candidates = internalQuery({
  args: {
    tzOffsetMinutes: v.number(),
    cutoff: v.number(),
    cursor: v.union(v.string(), v.null()),
  },
  returns: v.object({
    devices: v.array(
      v.object({ userId: v.id("users"), device: vNudgeDevice }),
    ),
    cursor: v.string(),
    isDone: v.boolean(),
    scanned: v.number(),
  }),
  handler: async (ctx, { tzOffsetMinutes, cutoff, cursor }) => {
    const page = await ctx.db
      .query("userDevices")
      .withIndex("by_tz_offset", (q) =>
        q.eq("tzOffsetMinutes", tzOffsetMinutes).gt("lastSeenAt", cutoff),
      )
      .paginate({ cursor, numItems: DEVICE_PAGE });
    const devices: Array<{ userId: Id<"users">; device: NudgeDevice }> = [];
    for (const row of page.page) {
      const d = nudgeableDevice(row);
      if (d) devices.push({ userId: row.userId, device: d });
    }
    return {
      devices,
      cursor: page.continueCursor,
      isDone: page.isDone,
      scanned: page.page.length,
    };
  },
});

// ────────────────────────── the claim ──────────────────────────

/** Which of the two lines a person should read. */
type Variant = "codeLeft" | "boardsLeft";

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
 */
export const claimNudges = internalMutation({
  args: { userIds: v.array(v.id("users")), dayKey: v.string() },
  returns: v.array(
    v.object({
      userId: v.id("users"),
      variant: v.union(v.literal("codeLeft"), v.literal("boardsLeft")),
    }),
  ),
  handler: async (ctx, { userIds, dayKey }) => {
    const claimed: Array<{ userId: Id<"users">; variant: Variant }> = [];
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
      // Somebody who lost today has nothing left to do with the code and would
      // read "did you crack it?" as the app not having noticed.
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
      const boardsDone = GAMES.every((g) => played.has(g));

      if (codeDone && boardsDone) continue;
      await ctx.db.patch(userId, { lastNudgedDayKey: dayKey });
      claimed.push({ userId, variant: codeDone ? "boardsLeft" : "codeLeft" });
    }
    return claimed;
  },
});

// ────────────────────────── the job ──────────────────────────

/**
 * One cron tick: find the zones at noon, and nudge whoever is in them.
 *
 * Scheduled quarter-hourly from crons.ts. A tick that matches no zone — most of
 * them do not, since only a handful of the 96 daily ticks correspond to a
 * populated offset — costs one index probe that returns nothing.
 */
export const run = internalAction({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const now = Date.now();
    const cutoff = now - ACTIVE_WINDOW_DAYS * 86_400_000;
    for (const offset of noonOffsetsAt(now)) {
      const dayKey = dayKeyAt(now, offset);
      let cursor: string | null = null;
      let pages = 0;
      let sent = 0;
      for (;;) {
        const page: {
          devices: Array<{ userId: Id<"users">; device: NudgeDevice }>;
          cursor: string;
          isDone: boolean;
          scanned: number;
        } = await ctx.runQuery(internal.dailyNudge.candidates, {
          tzOffsetMinutes: offset,
          cutoff,
          cursor,
        });
        sent += await dispatchPage(ctx, page.devices, dayKey);
        pages += 1;
        if (page.isDone) break;
        if (pages >= MAX_PAGES) {
          // Loud rather than silent: a zone this large means the ceiling needs
          // raising, and the people past it got nothing today.
          console.warn(
            `dailyNudge: offset=${offset} hit the ${MAX_PAGES}-page ceiling — ` +
              `some devices were not reached`,
          );
          break;
        }
        cursor = page.cursor;
      }
      console.log(
        `dailyNudge: offset=${offset} day=${dayKey} pages=${pages} nudged=${sent}`,
      );
    }
    return null;
  },
});

/**
 * Claim and send one page.
 *
 * The devices arrive already grouped by nothing at all — a page is whatever the
 * index handed back — so this collects them per account first. Everything an
 * account owns IN THIS ZONE gets the banner: two devices on the same desk are
 * two screens the person may be looking at, and that is the same choice
 * `sendAlert` makes for a chat message.
 */
async function dispatchPage(
  ctx: any,
  devices: Array<{ userId: Id<"users">; device: NudgeDevice }>,
  dayKey: string,
): Promise<number> {
  if (devices.length === 0) return 0;
  const byUser = new Map<string, NudgeDevice[]>();
  for (const { userId, device } of devices) {
    const key = userId.toString();
    const list = byUser.get(key);
    if (list) list.push(device);
    else byUser.set(key, [device]);
  }

  const userIds = [...byUser.keys()];
  let nudged = 0;
  for (let i = 0; i < userIds.length; i += CLAIM_BATCH) {
    const batch = userIds.slice(i, i + CLAIM_BATCH);
    const claimed: Array<{ userId: Id<"users">; variant: Variant }> =
      await ctx.runMutation(internal.dailyNudge.claimNudges, {
        userIds: batch,
        dayKey,
      });
    const targets: Array<{
      userId: Id<"users">;
      device: NudgeDevice;
      spec: AlertSpec;
    }> = [];
    for (const { userId, variant } of claimed) {
      for (const device of byUser.get(userId.toString()) ?? []) {
        const copy = copyFor(device.locale);
        targets.push({
          userId,
          device,
          spec: {
            kind: "daily_games",
            title: copy.title,
            body: copy[variant],
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
    }
    if (targets.length === 0) continue;
    await ctx.runAction(internal.push.sendAlertToDevices, { targets });
    nudged += claimed.length;
  }
  return nudged;
}

// ────────────────────────── operational visibility ──────────────────────────

/**
 * Who this job can currently see, by time zone.
 *
 * Worth looking at before trusting a quiet day: a zone with zero devices is
 * usually not an empty zone, it is a fleet still running a build that has never
 * uploaded an offset (`tzOffsetMinutes` is absent on every row written before
 * this shipped, and such a device is never nudged at all).
 *
 *   npx convex run dailyNudge:audienceReport
 */
export const audienceReport = internalQuery({
  args: { sinceDays: v.optional(v.number()) },
  returns: v.object({
    devices: v.number(),
    reachable: v.number(),
    noZoneReported: v.number(),
    optedOut: v.number(),
    byZone: v.record(v.string(), v.number()),
    byLocale: v.record(v.string(), v.number()),
    truncated: v.boolean(),
  }),
  handler: async (ctx, { sinceDays }) => {
    const cutoff = Date.now() - (sinceDays ?? ACTIVE_WINDOW_DAYS) * 86_400_000;
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_last_seen", (q) => q.gt("lastSeenAt", cutoff))
      .take(5000);
    const byZone: Record<string, number> = {};
    const byLocale: Record<string, number> = {};
    let noZone = 0;
    let optedOut = 0;
    for (const r of rows) {
      if (!nudgeableDevice(r)) {
        if (r.pushEnabled === false || r.gameRemindersEnabled === false) {
          optedOut += 1;
        }
        continue;
      }
      if (r.tzOffsetMinutes === undefined) {
        noZone += 1;
      } else {
        const k = String(r.tzOffsetMinutes);
        byZone[k] = (byZone[k] ?? 0) + 1;
      }
      const l = r.locale ?? "—";
      byLocale[l] = (byLocale[l] ?? 0) + 1;
    }
    return {
      devices: rows.length,
      reachable: Object.values(byZone).reduce((a, b) => a + b, 0),
      noZoneReported: noZone,
      optedOut,
      byZone,
      byLocale,
      truncated: rows.length === 5000,
    };
  },
});
