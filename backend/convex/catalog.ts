/**
 * Everything bananas can unlock, by catalog id. THE truth for ids, prices,
 * bundles and what is free; `lib/games/catalog.dart` mirrors it (ids must match
 * exactly, and `lifelines:mine` returns [LIST_PRICES] so a price change needs
 * no app release). Design: docs/design/bananas-and-unlocks.html.
 *
 * Pure: no db, no ctx. Ownership is a `string[]` of SINGLE item ids on the
 * owner's `lifelines` row; buying a bundle stores its members, never the
 * bundle id.
 */

/** Fighter key by `CharacterDef.id`. Humans (0, 12..15) are free. */
export const FIGHTER_KEYS = [
  "kai", "mojo", "tank", "nyx", "bruno", "sage", "razz", "pip", "ryoko", "bao",
  "vex", "gale", "luz", "dex", "hana", "boom", "unit7", "kage", "ember", "golem",
] as const;

export const FREE_FIGHTERS: ReadonlySet<number> = new Set([0, 12, 13, 14, 15]);
const LEGENDS: ReadonlySet<number> = new Set([3, 16, 17, 18, 19]);

/** Stage key by stage id. Rooftop (0) is free. */
export const STAGE_KEYS = [
  "rooftop", "temple", "neon", "aurora", "canyon", "deck",
] as const;
export const FREE_STAGE = 0;

/** Chat games anyone can send. Every other registry id is an unlock. */
export const FREE_GAMES: ReadonlySet<string> = new Set([
  "tictactoe", "connectfour", "dots", "fight",
]);

const GAME_PRICES: Record<string, number> = {
  checkers: 80,
  reversi: 80,
  chess: 150,
  imposter: 120,
  liarsdice: 120,
  race: 120,
};

/** Single items, id -> list price. */
export const SINGLES: Readonly<Record<string, number>> = (() => {
  const out: Record<string, number> = {};
  FIGHTER_KEYS.forEach((key, id) => {
    if (!FREE_FIGHTERS.has(id)) out[`fighter.${key}`] = LEGENDS.has(id) ? 90 : 60;
  });
  STAGE_KEYS.forEach((key, id) => {
    if (id !== FREE_STAGE) out[`stage.${key}`] = 40;
  });
  out["look.painted"] = 120;
  out["look.pixel"] = 120;
  for (const [g, p] of Object.entries(GAME_PRICES)) out[`game.${g}`] = p;
  return out;
})();

const idsWhere = (test: (id: string, price: number) => boolean): string[] =>
  Object.entries(SINGLES)
    .filter(([id, price]) => test(id, price))
    .map(([id]) => id);

/** Bundles: list price and the singles they unlock. */
export const BUNDLES: Readonly<
  Record<string, { price: number; members: string[] }>
> = {
  "bundle.animals": {
    price: 450,
    members: idsWhere((id, p) => id.startsWith("fighter.") && p === 60),
  },
  "bundle.legends": {
    price: 340,
    members: idsWhere((id, p) => id.startsWith("fighter.") && p === 90),
  },
  "bundle.stages": { price: 150, members: idsWhere((id) => id.startsWith("stage.")) },
  "bundle.looks": { price: 180, members: idsWhere((id) => id.startsWith("look.")) },
  "bundle.fist": {
    price: 990,
    members: idsWhere(
      (id) =>
        id.startsWith("fighter.") ||
        id.startsWith("stage.") ||
        id.startsWith("look."),
    ),
  },
  "bundle.gamenight": {
    price: 490,
    members: idsWhere((id) => id.startsWith("game.")),
  },
};

/** Every list price (singles and bundles), as `lifelines:mine` returns it. */
export const LIST_PRICES: Readonly<Record<string, number>> = {
  ...SINGLES,
  ...Object.fromEntries(Object.entries(BUNDLES).map(([k, b]) => [k, b.price])),
};

/** RevenueCat product id -> bananas. */
export const PACKS: Readonly<Record<string, number>> = {
  "monkeyhub.bananas.handful": 80,
  "monkeyhub.bananas.basket": 450,
  "monkeyhub.bananas.crate": 1000,
  "monkeyhub.bananas.tree": 2200,
  "monkeyhub.bananas.jungle": 6000,
};

/** Accounts created before this get the launch gift. */
export const LAUNCH_AT = Date.parse("2026-12-01");
export const LAUNCH_GIFT = 150;

/** The most a first free pick can be worth (any single fighter or stage). */
export const FIRST_PICK_MAX = 90;

export const isKnownItem = (id: string) => id in LIST_PRICES;
export const isBundle = (id: string) => id in BUNDLES;

type Owned = Iterable<string> | undefined | null;
const asSet = (owned: Owned): Set<string> => new Set(owned ?? []);

/** The singles [id] unlocks: itself, or a bundle's members. */
export function membersOf(id: string): string[] {
  return BUNDLES[id]?.members ?? (id in SINGLES ? [id] : []);
}

/** True when [id] is a single already owned, or a bundle with nothing left to buy. */
export function isOwnedItem(owned: Owned, id: string): boolean {
  const set = asSet(owned);
  const members = membersOf(id);
  return members.length > 0 && members.every((m) => set.has(m));
}

/**
 * What [id] costs [owned]'s owner now. A single is its list price; a bundle is
 * `ceil(price * unownedSinglesSum / allSinglesSum)` ("complete the set"), 0
 * when nothing is left to buy. Null for an unknown id.
 */
export function itemPrice(id: string, owned?: Owned): number | null {
  const single = SINGLES[id];
  if (single !== undefined) return asSet(owned).has(id) ? 0 : single;
  const bundle = BUNDLES[id];
  if (!bundle) return null;
  const set = asSet(owned);
  let all = 0;
  let unowned = 0;
  for (const m of bundle.members) {
    all += SINGLES[m];
    if (!set.has(m)) unowned += SINGLES[m];
  }
  return unowned === 0 ? 0 : Math.ceil((bundle.price * unowned) / all);
}

export const isFreeGame = (game: string) => !(`game.${game}` in SINGLES);

/** Free, or [owned] holds `game.<game>`. */
export const ownsGame = (owned: Owned, game: string) =>
  isFreeGame(game) || asSet(owned).has(`game.${game}`);

/** `fighter.<key>` for a locked fighter id; null when free or unknown. */
export function fighterItem(id: number): string | null {
  const key = FIGHTER_KEYS[id];
  return key !== undefined && !FREE_FIGHTERS.has(id) ? `fighter.${key}` : null;
}

/** `stage.<key>` for a locked stage id; null when free or unknown. */
export function stageItem(id: number): string | null {
  const key = STAGE_KEYS[id];
  return key !== undefined && id !== FREE_STAGE ? `stage.${key}` : null;
}

export const ownsFighter = (owned: Owned, id: number) => {
  const item = fighterItem(id);
  return item === null || asSet(owned).has(item);
};

export const ownsStage = (owned: Owned, id: number) => {
  const item = stageItem(id);
  return item === null || asSet(owned).has(item);
};

/** First free pick: a SINGLE fighter or stage worth at most [FIRST_PICK_MAX]. */
export function firstPickEligible(id: string): boolean {
  return (
    (id.startsWith("fighter.") || id.startsWith("stage.")) &&
    (SINGLES[id] ?? Infinity) <= FIRST_PICK_MAX
  );
}

const GAME_NAMES: Record<string, string> = {
  checkers: "Checkers",
  reversi: "Reversi",
  chess: "Chess",
  imposter: "Imposter",
  liarsdice: "Liar's Dice",
  race: "Puzzle Race",
};

/** A short English name for pushes ("Golem", "Neon stage", "Chess"). */
export function itemLabel(id: string): string {
  const [kind, key = ""] = id.split(".");
  const cap = key.charAt(0).toUpperCase() + key.slice(1);
  switch (kind) {
    case "fighter":
      return cap;
    case "stage":
      return `${cap} stage`;
    case "look":
      return `${cap} look`;
    case "game":
      return GAME_NAMES[key] ?? cap;
    default:
      return `${cap} bundle`;
  }
}
