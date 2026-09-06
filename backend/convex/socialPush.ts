import { internalAction, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import type { AlertSpec } from "./push";
import { liveSessionDeviceIds } from "./sessionCore";

/**
 * Friend activity — the two pushes another PERSON causes on your phone.
 *
 * `notifications.ts` sends what somebody said to you. `dailyNudge.ts` sends the
 * one thing nobody asked for. This file sends the third case, which is neither:
 * somebody you follow did something on their own board, and you would want to
 * know. Two kinds, one audience, one fan-out:
 *
 *   * `friend_moment` — they posted a highlight or scored a point. Automatic,
 *     because a board nobody is told about is a board nobody opens.
 *   * `game_result`   — they finished a daily game and CHOSE to tell you. Never
 *     automatic; `games.shareResult` is reached only by a tap on the result
 *     card, and only once per result (`gameResults.sharedAt`).
 *
 * ## Why this is not `push.sendAlert`
 *
 * Every word of both is ours, so the language is a property of the HANDSET and
 * not of the account — the same rule `dailyNudge.ts` follows and for the same
 * reason. That means composing per device and handing finished specs to
 * `push.sendAlertToDevices`, rather than composing per recipient in
 * `push.sendAlert`. A chat message goes the other way because its text is a
 * person's own words and is not ours to translate.
 *
 * ## Three gates, and none of them is optional
 *
 * 1. **The friendship** must be `accepted`. Read off `friendships.by_user`,
 *    which is complete on its own because an accepted friendship is always two
 *    directed rows (see `feed.friendIdsOf`).
 * 2. **The author's own visibility setting**, resolved from the SAME keys the
 *    read paths use — `feed` for an untagged highlight, `points` for a tagged
 *    one, `puzzle` for a game result. A push is a read path with a louder
 *    surface, and a notification about a row the recipient then cannot open is
 *    strictly worse than silence.
 * 3. **The recipient's own switches** — `pushEnabled` for "reach this device at
 *    all", and `friendActivityEnabled` for "…including for this". Separate
 *    because this is the only class of push in the app whose VOLUME is set by
 *    other people, and quieting twelve chatty friends must not cost you the
 *    twelve people talking to you.
 *
 * ## One row in the shade, and it counts up
 *
 * Every moment sends. They share a `collapseId` of
 * `friend_moment:<author>:<dayKey>`, which each transport honours as "replace
 * what is already displayed" — the `apns-collapse-id` header on iOS, the
 * notification tag on Android, the `Topic` header on web. So a friend who
 * posts five times today produces five deliveries and ONE row, whose text
 * counts up ("3 new things today") instead of five rows saying nearly the same
 * thing. The count is read fresh per send off `moments.by_user_day`, so it is
 * right even when a delivery is dropped.
 */

// ────────────────────────── the copy ──────────────────────────

/**
 * What one language needs to say either notification.
 *
 * Mirrors `lib/l10n/app_*.arb`, and the tag and game names below are LIFTED
 * from it rather than re-translated: `momentTagJinx` and `gameQueensName` are
 * already on the screen this notification opens, and a banner that calls it
 * something else reads as a different product. `social_push_copy_test.dart`
 * fails if a language is missing, and fails too if its tag or game table is
 * short — a half-filled row would silently fall back to English for one tag
 * only, which is the kind of thing nobody notices for a year.
 */
type SocialCopy = {
  /** An untagged moment with no caption of its own to show. */
  highlight: string;
  /** More than one moment from the same person today. `{count}` is how many. */
  more: string;
  /** A solved daily game. `{game}` is its name, `{time}` the clock. */
  gameSolved: string;
  /** A surrendered one. `{game}` is its name. */
  gameGaveUp: string;
  /** The five point tags, as the composer spells them. */
  tags: Record<string, string>;
  /** The four daily games, as their tiles spell them. */
  games: Record<string, string>;
};

const SOCIAL_COPY: Record<string, SocialCopy> = {
  en: {
    highlight: "added a highlight",
    more: "{count} new things today",
    gameSolved: "finished {game} in {time}",
    gameGaveUp: "gave up on {game}",
    tags: {
      fate: "FATE",
      jinx: "JINX",
      luck: "LUCK",
      calledIt: "CALLED IT",
      npc: "NPC",
    },
    games: {
      queens: "queens",
      tango: "tango",
      zip: "zip",
      sudoku: "mini sudoku",
    },
  },
  tr: {
    highlight: "bir kare ekledi",
    more: "bugün {count} yeni şey",
    gameSolved: "{game} oyununu {time} içinde bitirdi",
    gameGaveUp: "{game} oyununda pes etti",
    tags: {
      fate: "TESADÜF",
      jinx: "KERİZLİK",
      luck: "ŞANS",
      calledIt: "DEMİŞTİM",
      npc: "NPC",
    },
    games: {
      queens: "kraliçeler",
      tango: "tango",
      zip: "zip",
      sudoku: "mini sudoku",
    },
  },
  es: {
    highlight: "añadió un momento",
    more: "{count} cosas nuevas hoy",
    gameSolved: "terminó {game} en {time}",
    gameGaveUp: "se rindió en {game}",
    tags: {
      fate: "DESTINO",
      jinx: "GAFE",
      luck: "SUERTE",
      calledIt: "LO DIJE",
      npc: "NPC",
    },
    games: {
      queens: "reinas",
      tango: "tango",
      zip: "zip",
      sudoku: "mini sudoku",
    },
  },
  fr: {
    highlight: "a ajouté un moment",
    more: "{count} nouveautés aujourd’hui",
    gameSolved: "a fini {game} en {time}",
    gameGaveUp: "a abandonné {game}",
    tags: {
      fate: "DESTIN",
      jinx: "POISSE",
      luck: "CHANCE",
      calledIt: "JE L’AVAIS DIT",
      npc: "PNJ",
    },
    games: {
      queens: "reines",
      tango: "tango",
      zip: "zip",
      sudoku: "mini sudoku",
    },
  },
  pt: {
    highlight: "adicionou um momento",
    more: "{count} coisas novas hoje",
    gameSolved: "terminou {game} em {time}",
    gameGaveUp: "desistiu de {game}",
    tags: {
      fate: "DESTINO",
      jinx: "AZAR",
      luck: "SORTE",
      calledIt: "EU AVISEI",
      npc: "NPC",
    },
    games: {
      queens: "rainhas",
      tango: "tango",
      zip: "zip",
      sudoku: "mini sudoku",
    },
  },
  "pt-br": {
    highlight: "adicionou um momento",
    more: "{count} coisas novas hoje",
    gameSolved: "terminou {game} em {time}",
    gameGaveUp: "desistiu de {game}",
    tags: {
      fate: "DESTINO",
      jinx: "AZAR",
      luck: "SORTE",
      calledIt: "EU AVISEI",
      npc: "NPC",
    },
    games: {
      queens: "rainhas",
      tango: "tango",
      zip: "zip",
      sudoku: "mini sudoku",
    },
  },
  sv: {
    highlight: "lade upp ett ögonblick",
    more: "{count} nya saker idag",
    gameSolved: "klarade {game} på {time}",
    gameGaveUp: "gav upp {game}",
    tags: {
      fate: "ÖDE",
      jinx: "OTUR",
      luck: "TUR",
      calledIt: "VAD VAR DET JAG SA",
      npc: "NPC",
    },
    games: {
      queens: "damer",
      tango: "tango",
      zip: "zip",
      sudoku: "minisudoku",
    },
  },
  ar: {
    highlight: "أضاف لحظة",
    more: "{count} أشياء جديدة اليوم",
    gameSolved: "أنهى {game} في {time}",
    gameGaveUp: "استسلم في {game}",
    tags: {
      fate: "مصادفة",
      jinx: "نحس",
      luck: "حظ",
      calledIt: "قلت لكم",
      npc: "NPC",
    },
    games: {
      queens: "الملكات",
      tango: "تانغو",
      zip: "زِب",
      sudoku: "سودوكو مصغّر",
    },
  },
  hi: {
    highlight: "एक पल जोड़ा",
    more: "आज {count} नई चीज़ें",
    gameSolved: "{game} को {time} में पूरा किया",
    gameGaveUp: "{game} छोड़ दिया",
    tags: {
      fate: "संयोग",
      jinx: "अपनी करनी",
      luck: "किस्मत",
      calledIt: "मैंने कहा था",
      npc: "NPC",
    },
    games: {
      queens: "क्वीन्स",
      tango: "टैंगो",
      zip: "ज़िप",
      sudoku: "मिनी सुडोकु",
    },
  },
  ja: {
    highlight: "ハイライトを追加しました",
    more: "今日の新着 {count} 件",
    gameSolved: "{game}を{time}でクリアしました",
    gameGaveUp: "{game}をあきらめました",
    tags: {
      fate: "偶然",
      jinx: "自爆",
      luck: "幸運",
      calledIt: "言ったとおり",
      npc: "NPC",
    },
    games: {
      queens: "クイーンズ",
      tango: "タンゴ",
      zip: "ジップ",
      sudoku: "ミニ数独",
    },
  },
  ko: {
    highlight: "하이라이트를 올렸어요",
    more: "오늘 새 소식 {count}개",
    gameSolved: "{game}을(를) {time}에 끝냈어요",
    gameGaveUp: "{game}을(를) 포기했어요",
    tags: {
      fate: "우연",
      jinx: "자충수",
      luck: "행운",
      calledIt: "내가 그랬지",
      npc: "NPC",
    },
    games: {
      queens: "퀸즈",
      tango: "탱고",
      zip: "집",
      sudoku: "미니 스도쿠",
    },
  },
  zh: {
    highlight: "发了一条动态",
    more: "今天有 {count} 条新动态",
    gameSolved: "用 {time} 完成了{game}",
    gameGaveUp: "放弃了{game}",
    tags: {
      fate: "巧合",
      jinx: "自作自受",
      luck: "走运",
      calledIt: "我就说吧",
      npc: "NPC",
    },
    games: {
      queens: "皇后",
      tango: "探戈",
      zip: "连线",
      sudoku: "迷你数独",
    },
  },
};

/**
 * The copy for one device's language.
 *
 * Same fallback ladder as `dailyNudge.copyFor`, spelled out again rather than
 * shared: the two tables have different shapes, and a generic over both would
 * be a type parameter standing where a two-line function does.
 */
export function socialCopyFor(tag: string | undefined): SocialCopy {
  if (!tag) return SOCIAL_COPY.en;
  const norm = tag.toLowerCase().replace(/_/g, "-");
  return SOCIAL_COPY[norm] ?? SOCIAL_COPY[norm.split("-")[0]] ?? SOCIAL_COPY.en;
}

/** Exposed for `social_push_copy_test.dart`, which checks the table's shape. */
export const SOCIAL_COPY_TABLE = SOCIAL_COPY;

function fill(line: string, vars: Record<string, string>): string {
  return line.replace(/\{(\w+)\}/g, (whole, key) => vars[key] ?? whole);
}

/**
 * `m:ss`, matching `formatGameTime` in lib/games — the same clock the result
 * card and the standings row already show. An hour-long board reads "63:07"
 * rather than growing an hours field nobody will ever see.
 */
function formatDuration(ms: number | undefined): string {
  const total = Math.max(0, Math.round((ms ?? 0) / 1000));
  const mins = Math.floor(total / 60);
  const secs = total % 60;
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

// ────────────────────────── the audience ──────────────────────────

/**
 * How many friends either push will fan out over.
 *
 * The same 200 `feed.board` and `games.standings` already cap themselves at,
 * and deliberately the same number: an audience larger than the board that
 * shows the thing would be notifying people about a row they cannot see.
 */
const MAX_FANOUT = 200;

/** Device rows read per recipient. See `dailyNudge.DEVICES_PER_USER`. */
const DEVICES_PER_USER = 50;

type SocialDevice = {
  deviceRowId: Id<"userDevices">;
  deviceId: string;
  platform: string;
  apnsToken?: string;
  apnsEnv?: "sandbox" | "production";
  fcmToken?: string;
  web?: { endpoint: string; p256dh: string; auth: string };
  locale?: string;
};

/**
 * Whether this device should be told, and what the sender needs if so.
 *
 * **Web IS included here**, unlike the daily nudge, and the difference is not
 * an oversight. The nudge excluded browsers because it is a scheduled
 * broadcast whose audience would have silently become "whoever left a tab
 * open", with the people it missed indistinguishable from the people who
 * ignored it. These two are CONSEQUENCES — somebody just did something — which
 * is the same shape as a chat message, and chat messages have always gone to
 * the web. A browser that is listening gets told; one that is not was not
 * reachable by anything else either.
 *
 * `voipToken` is deliberately never read, exactly as in
 * `push._loadAlertTargets`: it belongs to a different APNs topic, and sending
 * an alert to it clears a good credential and stops that phone ringing.
 */
function reachableDevice(r: Doc<"userDevices">): SocialDevice | null {
  // `undefined` means enabled on both switches — every row written before
  // either field existed.
  if (r.pushEnabled === false) return null;
  if (r.friendActivityEnabled === false) return null;
  const web =
    r.webEndpoint && r.webP256dh && r.webAuth
      ? { endpoint: r.webEndpoint, p256dh: r.webP256dh, auth: r.webAuth }
      : undefined;
  if (!r.apnsToken && !r.fcmToken && !web) return null;
  return {
    deviceRowId: r._id,
    deviceId: r.deviceId,
    platform: r.platform,
    apnsToken: r.apnsToken,
    apnsEnv: r.apnsEnv,
    fcmToken: r.fcmToken,
    web,
    locale: r.locale,
  };
}

type Recipient = { userId: Id<"users">; devices: SocialDevice[] };

/**
 * Everyone who should hear about something [actorId] did, with their devices.
 *
 * One indexed read per friend, which is the same cost `feed.board` already
 * pays per render and is bounded by [MAX_FANOUT]. A friend who signed out on
 * every handset they own costs one read and contributes nothing.
 */
async function audienceOf(
  ctx: any,
  actorId: Id<"users">,
): Promise<Recipient[]> {
  const links = await ctx.db
    .query("friendships")
    .withIndex("by_user", (q: any) => q.eq("userId", actorId))
    .collect();
  const friendIds: Id<"users">[] = links
    .filter((f: any) => f.status === "accepted")
    .slice(0, MAX_FANOUT)
    .map((f: any) => f.friendId);

  const out: Recipient[] = [];
  for (const friendId of friendIds) {
    const rows: Array<Doc<"userDevices">> = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q: any) => q.eq("userId", friendId))
      .take(DEVICES_PER_USER);
    if (rows.length === 0) continue;
    // Signed out on this handset. A `userDevices` row outlives the session
    // whenever the client could not delete it, and telling somebody about
    // their friend's photo on an account that phone can no longer open is
    // exactly the complaint `push._loadAlertTargets` documents.
    const live = await liveSessionDeviceIds(ctx, friendId);
    const devices: SocialDevice[] = [];
    for (const r of rows) {
      if (!live.has(r.deviceId)) continue;
      const d = reachableDevice(r);
      if (d) devices.push(d);
    }
    if (devices.length > 0) out.push({ userId: friendId, devices });
  }
  return out;
}

/**
 * The actor's face, if this audience may see it.
 *
 * Resolved ONCE rather than per recipient, which is sound here in a way it is
 * not for a chat message: `visibility.avatar` distinguishes "public",
 * "friends" and "nobody", and every person in this audience is already an
 * accepted friend. So the three-way setting collapses to one boolean, and the
 * per-recipient lens `rooms.ts` builds would answer the same thing 200 times.
 *
 * A face still rides in the shared `data` block only because of that. The day
 * this audience grows a non-friend, it moves to a `perUser` override the way
 * `senderAvatarUrl` does everywhere else.
 */
async function actorFace(ctx: any, actor: any): Promise<string | null> {
  if (!actor?.avatarStorageId) return null;
  if ((actor.visibility?.avatar ?? "nobody") === "nobody") return null;
  return await ctx.storage.getUrl(actor.avatarStorageId);
}

// ────────────────────────── a posted moment ──────────────────────────

/**
 * Everything one moment's fan-out needs, in a single query.
 *
 * Returns `null` for every reason there is nothing to send — the row is gone,
 * the author is gone, the author has that half of their board switched off, or
 * nobody is reachable. The action treats them identically, so they are not
 * worth distinguishing on the way out.
 */
export const _momentAudience = internalQuery({
  args: { momentId: v.id("moments") },
  returns: v.any(),
  handler: async (ctx, { momentId }) => {
    const m = await ctx.db.get(momentId);
    // Posted and deleted before this action ran. `runAfter(0)` makes that a
    // narrow window rather than an impossible one.
    if (!m) return null;
    const author = await ctx.db.get(m.userId);
    if (!author) return null;

    // The SAME keys `feed.canSeeMoment` reads, and the same defaults: absent
    // means "friends" for both, because a board nobody opted into is a dead
    // board. A tagged row is a point and obeys `points`; an untagged one is a
    // highlight and obeys `feed`.
    const vis = author.visibility ?? {};
    const allowed =
      m.tag === undefined ? vis.feed !== "nobody" : vis.points !== "nobody";
    if (!allowed) return null;

    const recipients = await audienceOf(ctx, m.userId);
    if (recipients.length === 0) return null;

    // How many they have posted today, read fresh rather than counted by the
    // caller. This is what the collapsed row counts up to, and reading it here
    // means a delivery that was dropped does not leave the count short.
    const today = await ctx.db
      .query("moments")
      .withIndex("by_user_day", (q: any) =>
        q.eq("userId", m.userId).eq("dayKey", m.dayKey),
      )
      .collect();

    return {
      authorId: m.userId,
      authorName: m.authorName || m.authorUsername,
      authorAvatarUrl: await actorFace(ctx, author),
      dayKey: m.dayKey,
      tag: m.tag ?? null,
      caption: m.caption ?? null,
      countToday: today.length,
      recipients,
    };
  },
});

/**
 * Tells an author's friends they posted.
 *
 * Scheduled by `feed.post` with `runAfter(0)` — off the mutation's own
 * transaction, so a push that cannot be assembled never costs the person their
 * post. Everything that decides WHETHER to send lives in `_momentAudience`
 * above; this composes the words and hands the specs on.
 */
export const sendMomentPush = internalAction({
  args: { momentId: v.id("moments") },
  returns: v.null(),
  handler: async (ctx, { momentId }) => {
    const plan: any = await ctx.runQuery(internal.socialPush._momentAudience, {
      momentId,
    });
    if (!plan) return null;

    const targets: Array<{
      userId: Id<"users">;
      device: SocialDevice;
      spec: AlertSpec;
    }> = [];

    for (const r of plan.recipients as Recipient[]) {
      for (const device of r.devices) {
        const copy = socialCopyFor(device.locale);
        targets.push({
          userId: r.userId,
          device,
          spec: {
            kind: "friend_moment",
            // The author's name, exactly as a chat push titles itself with the
            // sender's. What they did goes in the body, which is where the
            // caption goes too when there is one.
            title: plan.authorName,
            body: momentLine(copy, plan),
            data: {
              kind: "friend_moment",
              // What the tap opens. Every platform carries it through to
              // `onOpenMoment`, and the Feed opens this row's viewer rather
              // than merely raising the app on today's board.
              momentId: momentId.toString(),
              authorId: plan.authorId.toString(),
              ...(plan.authorAvatarUrl
                ? { senderAvatarUrl: plan.authorAvatarUrl }
                : {}),
            },
            // Not an unread item; there is no list to clear. See
            // `push.UNBADGED_KINDS`.
            badge: 0,
            // One row per author per day, counting up. Every send after the
            // first REPLACES the row already on screen rather than stacking a
            // near-identical one under it.
            collapseId: `friend_moment:${plan.authorId}:${plan.dayKey}`,
          },
        });
      }
    }
    if (targets.length > 0) {
      await ctx.runAction(internal.push.sendAlertToDevices, { targets });
    }
    return null;
  },
});

/**
 * The one line under the author's name.
 *
 * Ordered by what is actually news. A caption is the author's own words and
 * beats anything we could write; a tag is the point of a point and comes with
 * the caption when there is one; and only when they have posted more than once
 * today does the count displace both, because by then the row is standing for
 * several things and quoting one of them is misleading.
 */
function momentLine(copy: SocialCopy, plan: any): string {
  if (plan.countToday > 1) {
    return fill(copy.more, { count: String(plan.countToday) });
  }
  const tagLabel = plan.tag ? (copy.tags[plan.tag] ?? plan.tag) : null;
  const caption = typeof plan.caption === "string" ? plan.caption.trim() : "";
  if (tagLabel && caption) return `${tagLabel} — ${caption}`;
  if (tagLabel) return tagLabel;
  if (caption) return caption;
  return copy.highlight;
}

// ────────────────────────── a shared game result ──────────────────────────

/**
 * The audience for a result its player asked us to share.
 *
 * Gated on `visibility.puzzle`, which is the switch `games.standings` already
 * obeys — deliberately not a thirteenth setting, for the reason spelled out
 * there. `games.shareResult` checks it too and refuses loudly so the player
 * hears about it; this check is the one that cannot be got wrong from a future
 * caller.
 */
export const _gameAudience = internalQuery({
  args: { userId: v.id("users"), dayKey: v.string(), game: v.string() },
  returns: v.any(),
  handler: async (ctx, { userId, dayKey, game }) => {
    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game),
      )
      .first();
    if (!row || row.finishedAt === undefined) return null;

    const player = await ctx.db.get(userId);
    if (!player) return null;
    if ((player.visibility?.puzzle ?? "friends") === "nobody") return null;

    const recipients = await audienceOf(ctx, userId);
    if (recipients.length === 0) return null;

    return {
      playerId: userId,
      playerName: player.name ?? player.username ?? "",
      playerAvatarUrl: await actorFace(ctx, player),
      dayKey,
      game,
      solved: row.solved,
      durationMs: row.durationMs ?? null,
      recipients,
    };
  },
});

/**
 * Tells a player's friends how they did, because they asked us to.
 *
 * The only push in this file a person deliberately triggers, which is what
 * lets it be louder than the moment one in exactly one respect: it names the
 * game and the time in the body rather than deferring to anything the player
 * wrote, because there is nothing they wrote — the whole message is the result.
 */
export const sendGameResultPush = internalAction({
  args: { userId: v.id("users"), dayKey: v.string(), game: v.string() },
  returns: v.null(),
  handler: async (ctx, { userId, dayKey, game }) => {
    const plan: any = await ctx.runQuery(internal.socialPush._gameAudience, {
      userId,
      dayKey,
      game,
    });
    if (!plan) return null;

    const targets: Array<{
      userId: Id<"users">;
      device: SocialDevice;
      spec: AlertSpec;
    }> = [];

    for (const r of plan.recipients as Recipient[]) {
      for (const device of r.devices) {
        const copy = socialCopyFor(device.locale);
        const gameName = copy.games[plan.game] ?? plan.game;
        targets.push({
          userId: r.userId,
          device,
          spec: {
            kind: "game_result",
            title: plan.playerName,
            body: plan.solved
              ? fill(copy.gameSolved, {
                  game: gameName,
                  time: formatDuration(plan.durationMs ?? undefined),
                })
              : fill(copy.gameGaveUp, { game: gameName }),
            data: {
              kind: "game_result",
              // The tap opens the games shelf, and these say which board and
              // which day so it can land on the right standings rather than on
              // the hub in general.
              game: plan.game,
              dayKey: plan.dayKey,
              playerId: plan.playerId.toString(),
              ...(plan.playerAvatarUrl
                ? { senderAvatarUrl: plan.playerAvatarUrl }
                : {}),
            },
            badge: 0,
            // Per player per day, not per game. Somebody who finishes all four
            // and shares each one is one row that keeps updating to their most
            // recent result — four rows from one person in one afternoon is
            // the behaviour this feature would be turned off over.
            collapseId: `game_result:${plan.playerId}:${plan.dayKey}`,
          },
        });
      }
    }
    if (targets.length > 0) {
      await ctx.runAction(internal.push.sendAlertToDevices, { targets });
    }
    return null;
  },
});
