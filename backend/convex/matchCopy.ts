/**
 * Push copy for in-chat games, in the recipient's language.
 *
 * Chat message pushes go out in nobody's language because they ARE somebody's
 * words. These are the app speaking — "your move", "time ran out" — so they
 * follow the recipient's handset locale the way `socialPush` and the reaction
 * banner do. `{name}` is the other player and `{game}` the game's name in the
 * same language.
 */

export type MatchCopyKey =
  | "yourMove"
  | "reminder"
  | "nudge"
  | "theyWon"
  | "youWon"
  | "draw";

type Copy = { names: Record<string, string> } & Record<MatchCopyKey, string>;

const COPY: Record<string, Copy> = {
  en: {
    names: { tictactoe: "Tic-tac-toe", connectfour: "Connect Four", reversi: "Reversi", checkers: "Checkers", dots: "Dots and Boxes", chess: "Chess" },
    yourMove: "{name} played. Your move in {game}.",
    reminder: "Still your move in {game} with {name}. Play before time runs out.",
    nudge: "{name} is waiting for your move in {game}.",
    theyWon: "{name} won {game}.",
    youWon: "You won {game} against {name}!",
    draw: "{game} with {name} ended in a draw.",
  },
  tr: {
    names: { tictactoe: "XOX", connectfour: "Dörtlü", reversi: "Reversi", checkers: "Dama", dots: "Kutu Kapmaca", chess: "Satranç" },
    yourMove: "{name} hamlesini yaptı. {game} oyununda sıra sende.",
    reminder: "{name} ile {game} oyununda hâlâ sıra sende. Süre dolmadan oyna.",
    nudge: "{name}, {game} oyununda hamleni bekliyor.",
    theyWon: "{name}, {game} oyununu kazandı.",
    youWon: "{game} oyununda {name} karşısında kazandın!",
    draw: "{name} ile {game} oyunu berabere bitti.",
  },
  ar: {
    names: { tictactoe: "إكس أو", connectfour: "أربعة في صف", reversi: "ريفرسي", checkers: "الداما", dots: "النقاط والمربعات", chess: "الشطرنج" },
    yourMove: "لعب {name}. دورك في {game}.",
    reminder: "ما زال دورك في {game} مع {name}. العب قبل انتهاء الوقت.",
    nudge: "{name} ينتظر حركتك في {game}.",
    theyWon: "فاز {name} في {game}.",
    youWon: "فزت في {game} على {name}!",
    draw: "انتهت {game} مع {name} بالتعادل.",
  },
  es: {
    names: { tictactoe: "Tres en raya", connectfour: "Conecta 4", reversi: "Reversi", checkers: "Damas", dots: "Puntos y cajas", chess: "Ajedrez" },
    yourMove: "{name} ya jugó. Te toca en {game}.",
    reminder: "Sigue siendo tu turno en {game} con {name}. Juega antes de que se acabe el tiempo.",
    nudge: "{name} está esperando tu jugada en {game}.",
    theyWon: "{name} ganó en {game}.",
    youWon: "¡Ganaste a {name} en {game}!",
    draw: "{game} con {name} terminó en empate.",
  },
  fr: {
    names: { tictactoe: "Morpion", connectfour: "Puissance 4", reversi: "Reversi", checkers: "Dames", dots: "Pipopipette", chess: "Échecs" },
    yourMove: "{name} a joué. À vous dans {game}.",
    reminder: "C’est toujours à vous dans {game} avec {name}. Jouez avant la fin du temps.",
    nudge: "{name} attend votre coup dans {game}.",
    theyWon: "{name} a gagné {game}.",
    youWon: "Vous avez battu {name} à {game} !",
    draw: "{game} avec {name} s’est terminé par une égalité.",
  },
  hi: {
    names: { tictactoe: "टिक-टैक-टो", connectfour: "कनेक्ट फ़ोर", reversi: "रिवर्सी", checkers: "चेकर्स", dots: "डॉट्स एंड बॉक्सेस", chess: "शतरंज" },
    yourMove: "{name} ने चाल चली। {game} में आपकी बारी।",
    reminder: "{name} के साथ {game} में अब भी आपकी बारी है। समय खत्म होने से पहले खेलें।",
    nudge: "{name} {game} में आपकी चाल का इंतज़ार कर रहे हैं।",
    theyWon: "{name} ने {game} जीता।",
    youWon: "आपने {game} में {name} को हराया!",
    draw: "{name} के साथ {game} बराबरी पर खत्म हुआ।",
  },
  ja: {
    names: { tictactoe: "まるばつ", connectfour: "四目並べ", reversi: "リバーシ", checkers: "チェッカー", dots: "ドット・アンド・ボックス", chess: "チェス" },
    yourMove: "{name}さんが指しました。{game}であなたの番です。",
    reminder: "{name}さんとの{game}はまだあなたの番です。時間切れになる前にどうぞ。",
    nudge: "{name}さんが{game}であなたの手を待っています。",
    theyWon: "{name}さんが{game}で勝ちました。",
    youWon: "{game}で{name}さんに勝ちました！",
    draw: "{name}さんとの{game}は引き分けでした。",
  },
  ko: {
    names: { tictactoe: "틱택토", connectfour: "사목", reversi: "리버시", checkers: "체커", dots: "점과 상자", chess: "체스" },
    yourMove: "{name}님이 두었어요. {game}에서 내 차례예요.",
    reminder: "{name}님과의 {game}에서 아직 내 차례예요. 시간이 끝나기 전에 두세요.",
    nudge: "{name}님이 {game}에서 내 수를 기다리고 있어요.",
    theyWon: "{name}님이 {game}에서 이겼어요.",
    youWon: "{game}에서 {name}님을 이겼어요!",
    draw: "{name}님과의 {game}은 무승부로 끝났어요.",
  },
  "pt-br": {
    names: { tictactoe: "Jogo da velha", connectfour: "Lig 4", reversi: "Reversi", checkers: "Damas", dots: "Pontinhos", chess: "Xadrez" },
    yourMove: "{name} jogou. Sua vez em {game}.",
    reminder: "Ainda é a sua vez em {game} com {name}. Jogue antes que o tempo acabe.",
    nudge: "{name} está esperando sua jogada em {game}.",
    theyWon: "{name} venceu em {game}.",
    youWon: "Você venceu {name} em {game}!",
    draw: "{game} com {name} terminou empatado.",
  },
  pt: {
    names: { tictactoe: "Jogo do galo", connectfour: "4 em linha", reversi: "Reversi", checkers: "Damas", dots: "Pontos e quadrados", chess: "Xadrez" },
    yourMove: "{name} jogou. É a tua vez em {game}.",
    reminder: "Ainda é a tua vez em {game} com {name}. Joga antes que o tempo acabe.",
    nudge: "{name} está à espera da tua jogada em {game}.",
    theyWon: "{name} ganhou em {game}.",
    youWon: "Ganhaste a {name} em {game}!",
    draw: "{game} com {name} terminou empatado.",
  },
  sv: {
    names: { tictactoe: "Tre i rad", connectfour: "Fyra i rad", reversi: "Reversi", checkers: "Dam", dots: "Prickar och lådor", chess: "Schack" },
    yourMove: "{name} har gjort sitt drag. Din tur i {game}.",
    reminder: "Det är fortfarande din tur i {game} med {name}. Spela innan tiden tar slut.",
    nudge: "{name} väntar på ditt drag i {game}.",
    theyWon: "{name} vann {game}.",
    youWon: "Du vann {game} mot {name}!",
    draw: "{game} med {name} slutade oavgjort.",
  },
  zh: {
    names: { tictactoe: "井字棋", connectfour: "四子棋", reversi: "黑白棋", checkers: "跳棋", dots: "点格棋", chess: "国际象棋" },
    yourMove: "{name} 已落子。{game} 轮到你了。",
    reminder: "和 {name} 的 {game} 仍轮到你。请在时间用完前落子。",
    nudge: "{name} 正在等你在 {game} 中落子。",
    theyWon: "{name} 赢得了 {game}。",
    youWon: "你在 {game} 中赢了 {name}！",
    draw: "和 {name} 的 {game} 以平局结束。",
  },
};

function copyFor(tag: string | undefined): Copy {
  if (!tag) return COPY.en;
  const norm = tag.toLowerCase().replace(/_/g, "-");
  return COPY[norm] ?? COPY[norm.split("-")[0]] ?? COPY.en;
}

/** [game]'s name in [locale], falling back to English, then to the id. */
export function gameNameFor(locale: string | undefined, game: string): string {
  return copyFor(locale).names[game] ?? COPY.en.names[game] ?? game;
}

/** One line of push copy, filled in. */
export function matchLine(
  locale: string | undefined,
  key: MatchCopyKey,
  game: string,
  name: string,
): string {
  return copyFor(locale)
    [key].replace("{game}", gameNameFor(locale, game))
    .replace("{name}", name);
}

/** Every locale the table covers, for the test that pins it complete. */
export const MATCH_COPY_LOCALES = Object.keys(COPY);
export const MATCH_COPY_TABLE = COPY;
