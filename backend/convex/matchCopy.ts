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
  | "started"
  | "yourMove"
  | "reminder"
  | "nudge"
  | "theyWon"
  | "youWon"
  | "draw"
  | "takebackAsked"
  | "takebackGiven";

type Copy = { names: Record<string, string> } & Record<MatchCopyKey, string>;

const COPY: Record<string, Copy> = {
  en: {
    names: { tictactoe: "Tic-tac-toe", connectfour: "Connect Four", reversi: "Reversi", checkers: "Checkers", dots: "Dots and Boxes", chess: "Chess" },
    started: "{name} started {game} and played. Your move.",
    yourMove: "{name} played. Your move in {game}.",
    reminder: "Still your move in {game} with {name}. Play before time runs out.",
    nudge: "{name} is waiting for your move in {game}.",
    theyWon: "{name} won {game}.",
    youWon: "You won {game} against {name}!",
    draw: "{game} with {name} ended in a draw.",
    takebackAsked: "{name} asked to take back their last move in {game}.",
    takebackGiven: "{name} let you take back your move. Your move in {game}.",
  },
  tr: {
    names: { tictactoe: "XOX", connectfour: "Dörtlü", reversi: "Reversi", checkers: "Dama", dots: "Kutu Kapmaca", chess: "Satranç" },
    started: "{name} {game} oyunu başlattı ve ilk hamlesini yaptı. Sıra sende.",
    yourMove: "{name} hamlesini yaptı. {game} oyununda sıra sende.",
    reminder: "{name} ile {game} oyununda hâlâ sıra sende. Süre dolmadan oyna.",
    nudge: "{name}, {game} oyununda hamleni bekliyor.",
    theyWon: "{name}, {game} oyununu kazandı.",
    youWon: "{game} oyununda {name} karşısında kazandın!",
    draw: "{name} ile {game} oyunu berabere bitti.",
    takebackAsked: "{name}, {game} oyununda son hamlesini geri almak istiyor.",
    takebackGiven: "{name} hamleni geri almana izin verdi. {game} oyununda sıra sende.",
  },
  ar: {
    names: { tictactoe: "إكس أو", connectfour: "أربعة في صف", reversi: "ريفرسي", checkers: "الداما", dots: "النقاط والمربعات", chess: "الشطرنج" },
    started: "بدأ {name} {game} ولعب. دورك.",
    yourMove: "لعب {name}. دورك في {game}.",
    reminder: "ما زال دورك في {game} مع {name}. العب قبل انتهاء الوقت.",
    nudge: "{name} ينتظر حركتك في {game}.",
    theyWon: "فاز {name} في {game}.",
    youWon: "فزت في {game} على {name}!",
    draw: "انتهت {game} مع {name} بالتعادل.",
    takebackAsked: "طلب {name} التراجع عن آخر حركة في {game}.",
    takebackGiven: "سمح لك {name} بالتراجع عن حركتك. دورك في {game}.",
  },
  es: {
    names: { tictactoe: "Tres en raya", connectfour: "Conecta 4", reversi: "Reversi", checkers: "Damas", dots: "Puntos y cajas", chess: "Ajedrez" },
    started: "{name} empezó {game} y ya jugó. Te toca.",
    yourMove: "{name} ya jugó. Te toca en {game}.",
    reminder: "Sigue siendo tu turno en {game} con {name}. Juega antes de que se acabe el tiempo.",
    nudge: "{name} está esperando tu jugada en {game}.",
    theyWon: "{name} ganó en {game}.",
    youWon: "¡Ganaste a {name} en {game}!",
    draw: "{game} con {name} terminó en empate.",
    takebackAsked: "{name} pidió deshacer su última jugada en {game}.",
    takebackGiven: "{name} te dejó deshacer tu jugada. Te toca en {game}.",
  },
  fr: {
    names: { tictactoe: "Morpion", connectfour: "Puissance 4", reversi: "Reversi", checkers: "Dames", dots: "Pipopipette", chess: "Échecs" },
    started: "{name} a lancé {game} et a joué. À vous.",
    yourMove: "{name} a joué. À vous dans {game}.",
    reminder: "C’est toujours à vous dans {game} avec {name}. Jouez avant la fin du temps.",
    nudge: "{name} attend votre coup dans {game}.",
    theyWon: "{name} a gagné {game}.",
    youWon: "Vous avez battu {name} à {game} !",
    draw: "{game} avec {name} s’est terminé par une égalité.",
    takebackAsked: "{name} demande à annuler son dernier coup dans {game}.",
    takebackGiven: "{name} te laisse annuler ton coup. À toi de jouer dans {game}.",
  },
  hi: {
    names: { tictactoe: "टिक-टैक-टो", connectfour: "कनेक्ट फ़ोर", reversi: "रिवर्सी", checkers: "चेकर्स", dots: "डॉट्स एंड बॉक्सेस", chess: "शतरंज" },
    started: "{name} ने {game} शुरू किया और चाल चली। आपकी बारी।",
    yourMove: "{name} ने चाल चली। {game} में आपकी बारी।",
    reminder: "{name} के साथ {game} में अब भी आपकी बारी है। समय खत्म होने से पहले खेलें।",
    nudge: "{name} {game} में आपकी चाल का इंतज़ार कर रहे हैं।",
    theyWon: "{name} ने {game} जीता।",
    youWon: "आपने {game} में {name} को हराया!",
    draw: "{name} के साथ {game} बराबरी पर खत्म हुआ।",
    takebackAsked: "{name} {game} में अपनी पिछली चाल वापस लेना चाहते हैं।",
    takebackGiven: "{name} ने तुम्हें अपनी चाल वापस लेने दी। {game} में तुम्हारी बारी।",
  },
  ja: {
    names: { tictactoe: "まるばつ", connectfour: "四目並べ", reversi: "リバーシ", checkers: "チェッカー", dots: "ドット・アンド・ボックス", chess: "チェス" },
    started: "{name}さんが{game}を始めて指しました。あなたの番です。",
    yourMove: "{name}さんが指しました。{game}であなたの番です。",
    reminder: "{name}さんとの{game}はまだあなたの番です。時間切れになる前にどうぞ。",
    nudge: "{name}さんが{game}であなたの手を待っています。",
    theyWon: "{name}さんが{game}で勝ちました。",
    youWon: "{game}で{name}さんに勝ちました！",
    draw: "{name}さんとの{game}は引き分けでした。",
    takebackAsked: "{name}さんが{game}で直前の手を戻したいそうです。",
    takebackGiven: "{name}さんが手を戻すのを許可しました。{game}であなたの番です。",
  },
  ko: {
    names: { tictactoe: "틱택토", connectfour: "사목", reversi: "리버시", checkers: "체커", dots: "점과 상자", chess: "체스" },
    started: "{name}님이 {game}을 시작하고 두었어요. 내 차례예요.",
    yourMove: "{name}님이 두었어요. {game}에서 내 차례예요.",
    reminder: "{name}님과의 {game}에서 아직 내 차례예요. 시간이 끝나기 전에 두세요.",
    nudge: "{name}님이 {game}에서 내 수를 기다리고 있어요.",
    theyWon: "{name}님이 {game}에서 이겼어요.",
    youWon: "{game}에서 {name}님을 이겼어요!",
    draw: "{name}님과의 {game}은 무승부로 끝났어요.",
    takebackAsked: "{name}님이 {game}에서 마지막 수를 무르고 싶어 해요.",
    takebackGiven: "{name}님이 수 무르기를 허락했어요. {game}에서 내 차례예요.",
  },
  "pt-br": {
    names: { tictactoe: "Jogo da velha", connectfour: "Lig 4", reversi: "Reversi", checkers: "Damas", dots: "Pontinhos", chess: "Xadrez" },
    started: "{name} começou {game} e jogou. Sua vez.",
    yourMove: "{name} jogou. Sua vez em {game}.",
    reminder: "Ainda é a sua vez em {game} com {name}. Jogue antes que o tempo acabe.",
    nudge: "{name} está esperando sua jogada em {game}.",
    theyWon: "{name} venceu em {game}.",
    youWon: "Você venceu {name} em {game}!",
    draw: "{game} com {name} terminou empatado.",
    takebackAsked: "{name} pediu para voltar a última jogada em {game}.",
    takebackGiven: "{name} deixou você voltar sua jogada. Sua vez em {game}.",
  },
  pt: {
    names: { tictactoe: "Jogo do galo", connectfour: "4 em linha", reversi: "Reversi", checkers: "Damas", dots: "Pontos e quadrados", chess: "Xadrez" },
    started: "{name} começou {game} e jogou. É a tua vez.",
    yourMove: "{name} jogou. É a tua vez em {game}.",
    reminder: "Ainda é a tua vez em {game} com {name}. Joga antes que o tempo acabe.",
    nudge: "{name} está à espera da tua jogada em {game}.",
    theyWon: "{name} ganhou em {game}.",
    youWon: "Ganhaste a {name} em {game}!",
    draw: "{game} com {name} terminou empatado.",
    takebackAsked: "{name} pediu para anular a última jogada em {game}.",
    takebackGiven: "{name} deixou-te anular a tua jogada. É a tua vez em {game}.",
  },
  sv: {
    names: { tictactoe: "Tre i rad", connectfour: "Fyra i rad", reversi: "Reversi", checkers: "Dam", dots: "Prickar och lådor", chess: "Schack" },
    started: "{name} startade {game} och har gjort sitt drag. Din tur.",
    yourMove: "{name} har gjort sitt drag. Din tur i {game}.",
    reminder: "Det är fortfarande din tur i {game} med {name}. Spela innan tiden tar slut.",
    nudge: "{name} väntar på ditt drag i {game}.",
    theyWon: "{name} vann {game}.",
    youWon: "Du vann {game} mot {name}!",
    draw: "{game} med {name} slutade oavgjort.",
    takebackAsked: "{name} vill ta tillbaka sitt senaste drag i {game}.",
    takebackGiven: "{name} lät dig ta tillbaka ditt drag. Din tur i {game}.",
  },
  zh: {
    names: { tictactoe: "井字棋", connectfour: "四子棋", reversi: "黑白棋", checkers: "跳棋", dots: "点格棋", chess: "国际象棋" },
    started: "{name} 开始了 {game} 并已落子。轮到你了。",
    yourMove: "{name} 已落子。{game} 轮到你了。",
    reminder: "和 {name} 的 {game} 仍轮到你。请在时间用完前落子。",
    nudge: "{name} 正在等你在 {game} 中落子。",
    theyWon: "{name} 赢得了 {game}。",
    youWon: "你在 {game} 中赢了 {name}！",
    draw: "和 {name} 的 {game} 以平局结束。",
    takebackAsked: "{name} 想在 {game} 中悔一步棋。",
    takebackGiven: "{name} 同意你悔棋。轮到你在 {game} 中走了。",
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
