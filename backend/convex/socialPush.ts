import { internalAction, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import type { AlertSpec } from "./push";
import { liveSessionDeviceIds } from "./sessionCore";
import { MAX_GUESSES } from "./puzzle";
import { levelOf } from "./visibility";

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
export type SocialCopy = {
  /** An untagged moment with no caption of its own to show. */
  highlight: string;
  /** More than one moment from the same person today. `{count}` is how many. */
  more: string;
  /** A solved daily game. `{game}` is its name, `{time}` the clock. */
  gameSolved: string;
  /** A surrendered one. `{game}` is its name. */
  gameGaveUp: string;
  /** The code puzzle, cracked. `{score}` is guesses over the limit: "3/6". */
  codeSolved: string;
  /** The code puzzle, out of guesses. */
  codeFailed: string;
  /**
   * Someone commented on the recipient's highlight. Followed by the comment
   * itself, quoted, when it has words.
   */
  commented: string;
  /** Someone answered the recipient's comment (or their reply in a thread). */
  replied: string;
  /** A reaction on the recipient's highlight. `{emoji}` is the reaction. */
  reacted: string;
  /** A reaction on the recipient's comment. `{emoji}` is the reaction. */
  reactedComment: string;
  /** The five point tags, as the composer spells them. */
  tags: Record<string, string>;
  /** The nine daily games, as their tiles spell them. */
  games: Record<string, string>;
};

const SOCIAL_COPY: Record<string, SocialCopy> = {
  en: {
    highlight: "shared a highlight",
    more: "{count} new things today",
    gameSolved: "finished {game} in {time}",
    gameGaveUp: "gave up on {game}",
    codeSolved: "cracked the code in {score}",
    codeFailed: "couldn’t crack today’s code",
    commented: "commented on your highlight",
    replied: "replied to your comment",
    reacted: "reacted {emoji} to your highlight",
    reactedComment: "reacted {emoji} to your comment",
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
      flow: "flow",
      futoshiki: "futoshiki",
      nonogram: "nonogram",
      minesweeper: "minesweeper",
      starbattle: "star battle",
      patches: "patches",
    },
  },
  tr: {
    highlight: "bir an paylaştı",
    more: "bugün {count} yeni şey",
    gameSolved: "{game} oyununu {time} içinde bitirdi",
    gameGaveUp: "{game} oyununda pes etti",
    codeSolved: "şifreyi {score} denemede çözdü",
    codeFailed: "bugünkü şifreyi çözemedi",
    commented: "öne çıkanına yorum yaptı",
    replied: "yorumuna yanıt verdi",
    reacted: "öne çıkanına {emoji} tepkisi verdi",
    reactedComment: "yorumuna {emoji} tepkisi verdi",
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
      flow: "akış",
      futoshiki: "futoshiki",
      nonogram: "nonogram",
      minesweeper: "mayın tarlası",
      starbattle: "yıldız savaşı",
      patches: "yamalar",
    },
  },
  es: {
    highlight: "ha publicado un momento",
    more: "{count} cosas nuevas hoy",
    gameSolved: "terminó {game} en {time}",
    gameGaveUp: "se rindió en {game}",
    codeSolved: "descifró el código en {score}",
    codeFailed: "no pudo descifrar el código de hoy",
    commented: "comentó tu momento",
    replied: "respondió a tu comentario",
    reacted: "reaccionó con {emoji} a tu momento",
    reactedComment: "reaccionó con {emoji} a tu comentario",
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
      flow: "flujo",
      futoshiki: "futoshiki",
      nonogram: "nonograma",
      minesweeper: "buscaminas",
      starbattle: "batalla de estrellas",
      patches: "parches",
    },
  },
  fr: {
    highlight: "a publié un moment",
    more: "{count} nouveautés aujourd’hui",
    gameSolved: "a fini {game} en {time}",
    gameGaveUp: "a abandonné {game}",
    codeSolved: "a déchiffré le code en {score}",
    codeFailed: "n’a pas réussi à déchiffrer le code du jour",
    commented: "a commenté ton moment fort",
    replied: "a répondu à ton commentaire",
    reacted: "a réagi {emoji} à ton moment fort",
    reactedComment: "a réagi {emoji} à ton commentaire",
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
      flow: "flux",
      futoshiki: "futoshiki",
      nonogram: "nonogramme",
      minesweeper: "démineur",
      starbattle: "bataille d’étoiles",
      patches: "patchs",
    },
  },
  pt: {
    highlight: "publicou um momento",
    more: "{count} coisas novas hoje",
    gameSolved: "terminou {game} em {time}",
    gameGaveUp: "desistiu de {game}",
    codeSolved: "decifrou o código em {score}",
    codeFailed: "não conseguiu decifrar o código de hoje",
    commented: "comentou o teu destaque",
    replied: "respondeu ao teu comentário",
    reacted: "reagiu com {emoji} ao teu destaque",
    reactedComment: "reagiu com {emoji} ao teu comentário",
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
      flow: "fluxo",
      futoshiki: "futoshiki",
      nonogram: "nonograma",
      minesweeper: "caça-minas",
      starbattle: "batalha de estrelas",
      patches: "retalhos",
    },
  },
  "pt-br": {
    highlight: "publicou um momento",
    more: "{count} coisas novas hoje",
    gameSolved: "terminou {game} em {time}",
    gameGaveUp: "desistiu de {game}",
    codeSolved: "decifrou o código em {score}",
    codeFailed: "não conseguiu decifrar o código de hoje",
    commented: "comentou no seu destaque",
    replied: "respondeu ao seu comentário",
    reacted: "reagiu com {emoji} ao seu destaque",
    reactedComment: "reagiu com {emoji} ao seu comentário",
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
      flow: "fluxo",
      futoshiki: "futoshiki",
      nonogram: "nonograma",
      minesweeper: "campo minado",
      starbattle: "batalha de estrelas",
      patches: "retalhos",
    },
  },
  sv: {
    highlight: "lade upp ett ögonblick",
    more: "{count} nya saker idag",
    gameSolved: "klarade {game} på {time}",
    gameGaveUp: "gav upp {game}",
    codeSolved: "knäckte koden på {score}",
    codeFailed: "knäckte inte dagens kod",
    commented: "kommenterade din höjdpunkt",
    replied: "svarade på din kommentar",
    reacted: "reagerade med {emoji} på din höjdpunkt",
    reactedComment: "reagerade med {emoji} på din kommentar",
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
      flow: "flöde",
      futoshiki: "futoshiki",
      nonogram: "nonogram",
      minesweeper: "minröjning",
      starbattle: "stjärnstrid",
      patches: "lappar",
    },
  },
  ar: {
    highlight: "نشر لحظة",
    more: "{count} أشياء جديدة اليوم",
    gameSolved: "أنهى {game} في {time}",
    gameGaveUp: "استسلم في {game}",
    codeSolved: "فكّ الرمز في {score}",
    codeFailed: "لم يتمكن من فكّ رمز اليوم",
    commented: "علّق على لقطتك المميزة",
    replied: "ردّ على تعليقك",
    reacted: "تفاعل بـ {emoji} مع لقطتك المميزة",
    reactedComment: "تفاعل بـ {emoji} مع تعليقك",
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
      flow: "تدفّق",
      futoshiki: "فوتوشيكي",
      nonogram: "نونوغرام",
      minesweeper: "كاسحة الألغام",
      starbattle: "معركة النجوم",
      patches: "الرُّقَع",
    },
  },
  hi: {
    highlight: "एक पल साझा किया",
    more: "आज {count} नई चीज़ें",
    gameSolved: "{game} को {time} में पूरा किया",
    gameGaveUp: "{game} छोड़ दिया",
    codeSolved: "{score} में कोड तोड़ दिया",
    codeFailed: "आज का कोड नहीं तोड़ पाया",
    commented: "आपकी हाइलाइट पर कमेंट किया",
    replied: "आपके कमेंट का जवाब दिया",
    reacted: "आपकी हाइलाइट पर {emoji} रिएक्शन दिया",
    reactedComment: "आपके कमेंट पर {emoji} रिएक्शन दिया",
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
      flow: "फ़्लो",
      futoshiki: "फ़ुतोशिकी",
      nonogram: "नोनोग्राम",
      minesweeper: "माइनस्वीपर",
      starbattle: "स्टार बैटल",
      patches: "पैचेस",
    },
  },
  ja: {
    highlight: "ハイライトを投稿しました",
    more: "今日の新着 {count} 件",
    gameSolved: "{game}を{time}でクリアしました",
    gameGaveUp: "{game}をあきらめました",
    codeSolved: "{score}でコードを解読しました",
    codeFailed: "今日のコードを解読できませんでした",
    commented: "あなたのハイライトにコメントしました",
    replied: "あなたのコメントに返信しました",
    reacted: "あなたのハイライトに{emoji}でリアクションしました",
    reactedComment: "あなたのコメントに{emoji}でリアクションしました",
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
      flow: "フロー",
      futoshiki: "不等式",
      nonogram: "ノノグラム",
      minesweeper: "マインスイーパー",
      starbattle: "スターバトル",
      patches: "パッチ",
    },
  },
  ko: {
    highlight: "하이라이트를 올렸어요",
    more: "오늘 새 소식 {count}개",
    gameSolved: "{game}을(를) {time}에 끝냈어요",
    gameGaveUp: "{game}을(를) 포기했어요",
    codeSolved: "{score} 만에 코드를 풀었어요",
    codeFailed: "오늘의 코드를 풀지 못했어요",
    commented: "회원님의 하이라이트에 댓글을 남겼어요",
    replied: "회원님의 댓글에 답글을 남겼어요",
    reacted: "회원님의 하이라이트에 {emoji} 반응을 남겼어요",
    reactedComment: "회원님의 댓글에 {emoji} 반응을 남겼어요",
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
      flow: "플로우",
      futoshiki: "후토시키",
      nonogram: "노노그램",
      minesweeper: "지뢰 찾기",
      starbattle: "스타 배틀",
      patches: "패치",
    },
  },
  zh: {
    highlight: "发布了一个瞬间",
    more: "今天有 {count} 条新动态",
    gameSolved: "用 {time} 完成了{game}",
    gameGaveUp: "放弃了{game}",
    codeSolved: "用 {score} 破解了密码",
    codeFailed: "没能破解今天的密码",
    commented: "评论了你的精彩瞬间",
    replied: "回复了你的评论",
    reacted: "用 {emoji} 回应了你的精彩瞬间",
    reactedComment: "用 {emoji} 回应了你的评论",
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
      flow: "管道",
      futoshiki: "不等号",
      nonogram: "数织",
      minesweeper: "扫雷",
      starbattle: "星战",
      patches: "拼布",
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
 *
 * Truncating, not rounding, because `formatGameTime` truncates: an 11.7s solve
 * is the 0:11 the stopwatch stopped on and the 0:11 the standings row shows,
 * so a push saying 0:12 reads as a different, worse time than the one the
 * player just watched themselves set. Exported so `socialPush.test.ts` can
 * hold it to that, since the drift between the two was invisible for as long
 * as nothing compared them.
 */
export function formatDuration(ms: number | undefined): string {
  const total = Math.max(0, Math.floor((ms ?? 0) / 1000));
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
    const r = await recipientOf(ctx, friendId);
    if (r) out.push(r);
  }
  return out;
}

/**
 * One person's reachable devices, or null when none of them is.
 *
 * Split out of [audienceOf] for the comment push, whose audience is a named
 * person or two rather than a friend list.
 */
async function recipientOf(
  ctx: any,
  userId: Id<"users">,
): Promise<Recipient | null> {
  const rows: Array<Doc<"userDevices">> = await ctx.db
    .query("userDevices")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .take(DEVICES_PER_USER);
  if (rows.length === 0) return null;
  // Signed out on this handset. A `userDevices` row outlives the session
  // whenever the client could not delete it, and telling somebody about
  // their friend's photo on an account that phone can no longer open is
  // exactly the complaint `push._loadAlertTargets` documents.
  const live = await liveSessionDeviceIds(ctx, userId);
  const devices: SocialDevice[] = [];
  for (const r of rows) {
    if (!live.has(r.deviceId)) continue;
    const d = reachableDevice(r);
    if (d) devices.push(d);
  }
  return devices.length > 0 ? { userId, devices } : null;
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
  if (levelOf(actor, "avatar") === "nobody") return null;
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
 * Always says what happened first. A bare caption under a name is
 * indistinguishable from a chat message — that is how this used to read — so
 * the caption is quoted AFTER the action ("shared a highlight: “…”"), and a
 * point leads with its tag. Only when they have posted more than once today
 * does the count displace both, because by then the row is standing for
 * several things and quoting one of them is misleading.
 */
export function momentLine(copy: SocialCopy, plan: any): string {
  if (plan.countToday > 1) {
    return fill(copy.more, { count: String(plan.countToday) });
  }
  const tagLabel = plan.tag ? (copy.tags[plan.tag] ?? plan.tag) : null;
  const caption = typeof plan.caption === "string" ? plan.caption.trim() : "";
  const lead = tagLabel ?? copy.highlight;
  return caption ? `${lead}: “${caption}”` : lead;
}

// ────────────────────────── a comment ──────────────────────────

/**
 * Who hears about one comment, and what each of them is told.
 *
 * At most two people, never the commenter: the moment's author ("commented on
 * your highlight"), and — for a reply — whoever wrote the comment being
 * answered ("replied to your comment"). The author of a highlight who is also
 * the person being answered hears it once, as a reply, which is the more
 * specific of the two.
 *
 * Each recipient is re-checked against what `momentComments.list` would show
 * them, so a push never announces a comment its reader cannot open — the
 * supervised-account rule in particular, under which a child's comment is not
 * visible to a stranger and a stranger's is not visible to a child.
 *
 * Sent as `friend_moment`, not a kind of its own. That kind already routes a
 * tap to the moment's viewer on iOS, Android and the web, already rides the
 * social channel, carries no badge and obeys `friendActivityEnabled`; a new
 * kind would have to be taught to three native layers to do exactly the same.
 * Collapsed per moment and recipient, so a lively thread is one row in the
 * shade that keeps its latest line.
 */
export const _commentAudience = internalQuery({
  args: { commentId: v.id("momentComments") },
  returns: v.any(),
  handler: async (ctx, { commentId }) => {
    const c = await ctx.db.get(commentId);
    if (!c) return null;
    const m = await ctx.db.get(c.momentId);
    if (!m) return null;
    const commenter = await ctx.db.get(c.userId);
    if (!commenter) return null;

    const wanted = new Map<string, "commented" | "replied">();
    if (c.parentId !== undefined) {
      const parent = await ctx.db.get(c.parentId);
      // Replying to a reply answers that reply's author; replying to the root
      // answers the root's.
      const answered = c.replyToUserId ?? parent?.userId;
      if (answered) wanted.set(answered.toString(), "replied");
    }
    if (!wanted.has(m.userId.toString())) {
      wanted.set(m.userId.toString(), "commented");
    }
    wanted.delete(c.userId.toString());
    if (wanted.size === 0) return null;

    const commenterIsChild = commenter.accountType === "child";
    const friendsOfCommenter = new Set<string>(
      (
        await ctx.db
          .query("friendships")
          .withIndex("by_user", (q: any) => q.eq("userId", c.userId))
          .collect()
      )
        .filter((f: any) => f.status === "accepted")
        .map((f: any) => f.friendId.toString()),
    );

    const recipients: Array<Recipient & { line: string; face: boolean }> = [];
    for (const [id, line] of wanted) {
      const isAuthor = id === m.userId.toString();
      const friend = friendsOfCommenter.has(id);
      const reader = await ctx.db.get(id as Id<"users">);
      if (!reader) continue;
      // The child rule, both directions — see `momentComments.list`.
      if (!isAuthor && !friend) {
        if (commenterIsChild || reader.accountType === "child") continue;
      }
      if (!isAuthor) {
        // Still allowed to see the moment at all: a friendship ended, or the
        // author made their highlights private, since they commented.
        const link = await ctx.db
          .query("friendships")
          .withIndex("by_pair", (q: any) =>
            q.eq("userId", reader._id).eq("friendId", m.userId),
          )
          .first();
        if (!link || link.status !== "accepted") continue;
        const author = await ctx.db.get(m.userId);
        const vis = author?.visibility ?? {};
        const allowed =
          m.tag === undefined ? vis.feed !== "nobody" : vis.points !== "nobody";
        if (!allowed) continue;
      }
      const r = await recipientOf(ctx, reader._id);
      if (!r) continue;
      // Per recipient, unlike `actorFace` elsewhere in this file: these
      // readers are not all the commenter's friends, so "friends" means yes
      // for some of them and no for others.
      const level = levelOf(commenter, "avatar");
      const face = level === "public" || (level === "friends" && friend);
      recipients.push({ ...r, line, face });
    }
    if (recipients.length === 0) return null;

    return {
      momentId: m._id,
      authorId: m.userId,
      commenterName: commenter.name ?? commenter.username ?? c.userName,
      commenterAvatarUrl: commenter.avatarStorageId
        ? await ctx.storage.getUrl(commenter.avatarStorageId)
        : null,
      text: c.text ?? null,
      alt: c.alt ?? null,
      recipients,
    };
  },
});

/** Tells the people a comment is addressed to. Scheduled by `momentComments.add`. */
export const sendCommentPush = internalAction({
  args: { commentId: v.id("momentComments") },
  returns: v.null(),
  handler: async (ctx, { commentId }) => {
    const plan: any = await ctx.runQuery(internal.socialPush._commentAudience, {
      commentId,
    });
    if (!plan) return null;

    const targets: Array<{
      userId: Id<"users">;
      device: SocialDevice;
      spec: AlertSpec;
    }> = [];
    for (const r of plan.recipients) {
      for (const device of r.devices as SocialDevice[]) {
        const copy = socialCopyFor(device.locale);
        targets.push({
          userId: r.userId,
          device,
          spec: {
            kind: "friend_moment",
            title: plan.commenterName,
            body: commentLine(copy, r.line, plan),
            data: {
              kind: "friend_moment",
              momentId: plan.momentId.toString(),
              authorId: plan.authorId.toString(),
              // Opens the card with its conversation up — see app.dart.
              focus: "comments",
              ...(r.face && plan.commenterAvatarUrl
                ? { senderAvatarUrl: plan.commenterAvatarUrl }
                : {}),
            },
            badge: 0,
            collapseId: `moment_comment:${plan.momentId}:${r.userId}`,
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
 * "commented on your highlight: “nice!”" — what happened first, then the words,
 * the same order `momentLine` uses. A sticker brings its emoji; a GIF has
 * nothing worth quoting and stands on the action alone.
 */
export function commentLine(
  copy: SocialCopy,
  line: "commented" | "replied",
  plan: { text: string | null; alt: string | null },
): string {
  const lead = copy[line];
  const text = typeof plan.text === "string" ? plan.text.trim() : "";
  if (text) return `${lead}: “${text}”`;
  if (plan.alt) return `${lead}: ${plan.alt}`;
  return lead;
}

// ────────────────────────── a reaction ──────────────────────────

/**
 * Who hears about one reaction on a highlight or on a comment under one: the
 * person who posted the thing reacted to, and only them. Null to stay silent —
 * the reaction was taken back before this ran, it was their own, or the
 * reactor is somebody the recipient would not be shown (the supervised-account
 * rule, see `momentComments.list`).
 *
 * Sent as `friend_moment` for the reason `_commentAudience` gives, collapsed
 * per (thing, reactor) so changing 👍 to ❤️ updates one row rather than
 * stacking two. A comment reaction carries `focus: "comments"`, so the tap
 * opens the card with the conversation up.
 */
export const _reactionAudience = internalQuery({
  args: {
    momentReactionId: v.optional(v.id("momentReactions")),
    commentReactionId: v.optional(v.id("momentCommentReactions")),
  },
  returns: v.any(),
  handler: async (ctx, { momentReactionId, commentReactionId }) => {
    const r: any = momentReactionId
      ? await ctx.db.get(momentReactionId)
      : commentReactionId
        ? await ctx.db.get(commentReactionId)
        : null;
    if (!r) return null;
    const m = await ctx.db.get(r.momentId as Id<"moments">);
    if (!m) return null;
    let recipientId: Id<"users"> = m.userId;
    let commentKey = "";
    if (commentReactionId) {
      const c = await ctx.db.get(r.commentId as Id<"momentComments">);
      if (!c) return null;
      recipientId = c.userId;
      commentKey = c._id.toString();
    }
    if (recipientId === r.userId) return null;

    const reactor = await ctx.db.get(r.userId as Id<"users">);
    const reader = await ctx.db.get(recipientId);
    if (!reactor || !reader) return null;
    const link = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", recipientId).eq("friendId", reactor._id),
      )
      .first();
    const friend = !!link && link.status === "accepted";
    if (!friend && (reactor.accountType === "child" || reader.accountType === "child")) {
      return null;
    }
    const recipient = await recipientOf(ctx, recipientId);
    if (!recipient) return null;
    const level = levelOf(reactor, "avatar");
    const face = level === "public" || (level === "friends" && friend);

    return {
      momentId: m._id,
      authorId: m.userId,
      reactorId: reactor._id,
      reactorName: reactor.name ?? reactor.username ?? r.userName ?? "",
      reactorAvatarUrl:
        face && reactor.avatarStorageId
          ? await ctx.storage.getUrl(reactor.avatarStorageId)
          : null,
      emoji: r.emoji,
      onComment: commentReactionId !== undefined,
      commentKey,
      recipient,
    };
  },
});

/** Scheduled by `feed.react` and `momentComments.react` on a NEW reaction. */
export const sendReactionPush = internalAction({
  args: {
    momentReactionId: v.optional(v.id("momentReactions")),
    commentReactionId: v.optional(v.id("momentCommentReactions")),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const plan: any = await ctx.runQuery(
      internal.socialPush._reactionAudience,
      args,
    );
    if (!plan) return null;
    const targets: Array<{
      userId: Id<"users">;
      device: SocialDevice;
      spec: AlertSpec;
    }> = [];
    for (const device of plan.recipient.devices as SocialDevice[]) {
      const copy = socialCopyFor(device.locale);
      targets.push({
        userId: plan.recipient.userId,
        device,
        spec: {
          kind: "friend_moment",
          title: plan.reactorName,
          body: fill(plan.onComment ? copy.reactedComment : copy.reacted, {
            emoji: plan.emoji,
          }),
          data: {
            kind: "friend_moment",
            momentId: plan.momentId.toString(),
            authorId: plan.authorId.toString(),
            ...(plan.onComment ? { focus: "comments" } : {}),
            ...(plan.reactorAvatarUrl
              ? { senderAvatarUrl: plan.reactorAvatarUrl }
              : {}),
          },
          badge: 0,
          collapseId: plan.onComment
            ? `comment_reaction:${plan.commentKey}:${plan.reactorId}`
            : `moment_reaction:${plan.momentId}:${plan.reactorId}`,
        },
      });
    }
    if (targets.length > 0) {
      await ctx.runAction(internal.push.sendAlertToDevices, { targets });
    }
    return null;
  },
});

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
            // Per player per day, not per game. Somebody who finishes all nine
            // and shares each one is one row that keeps updating to their most
            // recent result — nine rows from one person in one afternoon is
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

// ────────────────────────── a shared code puzzle ──────────────────────────

/**
 * Everything one shared code-puzzle result needs, in a single query.
 *
 * The code puzzle's half of [_gameAudience], and gated identically: a finished
 * row, the player still exists, their `visibility.puzzle` is not "nobody"
 * (`puzzle.shareResult` refuses loudly on that; this is the check a future
 * caller cannot forget), and somebody reachable to tell.
 */
export const _puzzleAudience = internalQuery({
  args: { userId: v.id("users"), dayKey: v.string() },
  returns: v.any(),
  handler: async (ctx, { userId, dayKey }) => {
    const row = await ctx.db
      .query("puzzleResults")
      .withIndex("by_user_day", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey),
      )
      .first();
    if (!row) return null;
    if (!row.solved && row.guesses.length < MAX_GUESSES) return null;

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
      solved: row.solved,
      guessCount: row.guesses.length,
      recipients,
    };
  },
});

/**
 * Tells a player's friends how today's code went, because they asked.
 *
 * Same kind, same tap target and the same per-player-per-day collapse row as
 * [sendGameResultPush]: from a friend's side these are all "how they did on
 * today's games", and a code result arriving as a different kind of banner —
 * one the shade would not fold together with the rest of that person's day —
 * would read as a different product.
 */
export const sendPuzzleResultPush = internalAction({
  args: { userId: v.id("users"), dayKey: v.string() },
  returns: v.null(),
  handler: async (ctx, { userId, dayKey }) => {
    const plan: any = await ctx.runQuery(internal.socialPush._puzzleAudience, {
      userId,
      dayKey,
    });
    if (!plan) return null;

    const score = `${plan.guessCount}/${MAX_GUESSES}`;
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
            kind: "game_result",
            title: plan.playerName,
            body: plan.solved
              ? fill(copy.codeSolved, { score })
              : copy.codeFailed,
            data: {
              kind: "game_result",
              game: "code",
              dayKey: plan.dayKey,
              playerId: plan.playerId.toString(),
              ...(plan.playerAvatarUrl
                ? { senderAvatarUrl: plan.playerAvatarUrl }
                : {}),
            },
            badge: 0,
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
