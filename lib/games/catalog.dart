/// Everything bananas can unlock, by catalog id.
///
/// The Dart side of `backend/convex/catalog.ts`, which is the truth: the ids
/// must match it exactly, and the server's price list (returned by
/// `lifelines:mine`, see `BananaWallet.prices`) wins over [CatalogItem.price]
/// when the two differ. Design: docs/design/bananas-and-unlocks.html.
///
/// Free things are not in the catalog at all: the 5 human fighters, the
/// Rooftop stage, the Cartoon look, and the chat games Tic-tac-toe, Connect
/// Four, Dots and Jungle Fist. [isFreeGame] and friends answer for them.
library;

import '../fight/view/art/art_common.dart' show FightLook;

enum CatalogKind { fighter, stage, look, game, bundle }

class CatalogItem {
  const CatalogItem(this.id, this.kind, this.price, {this.members = const []});

  /// Wire id, e.g. `fighter.golem`, `stage.neon`, `game.chess`,
  /// `bundle.animals`.
  final String id;
  final CatalogKind kind;

  /// Bananas, as shipped. The server's list wins (`BananaWallet.priceOf`).
  final int price;

  /// For a bundle: the single items it unlocks.
  final List<String> members;

  bool get isBundle => kind == CatalogKind.bundle;
}

// ── Jungle Fist ─────────────────────────────────────────────────────────────

/// Fighter key by `CharacterDef.id`. Humans (0, 12..15) are free.
const List<String> kFighterKeys = [
  'kai', 'mojo', 'tank', 'nyx', 'bruno', 'sage', 'razz', 'pip', 'ryoko', 'bao',
  'vex', 'gale', 'luz', 'dex', 'hana', 'boom', 'unit7', 'kage', 'ember', 'golem',
];

/// The free starter cast: every human.
const Set<int> kFreeFighters = {0, 12, 13, 14, 15};

const Set<int> _legends = {3, 16, 17, 18, 19};

/// Stage key by stage id. Rooftop (0) is free.
const List<String> kStageKeys = [
  'rooftop', 'temple', 'neon', 'aurora', 'canyon', 'deck',
];

const int kFreeStage = 0;

// ── Chat games ──────────────────────────────────────────────────────────────

/// Chat games anyone can send. Every other registry id is an unlock.
const Set<String> kFreeGames = {'tictactoe', 'connectfour', 'dots', 'fight'};

/// Locked chat games by wire id (turn and party registries).
const Map<String, int> _gamePrices = {
  'checkers': 80,
  'reversi': 80,
  'chess': 150,
  'imposter': 120,
  'liarsdice': 120,
  'race': 120,
};

// ── The list ────────────────────────────────────────────────────────────────

String fighterItemId(int fighterId) => 'fighter.${kFighterKeys[fighterId]}';
String stageItemId(int stageId) => 'stage.${kStageKeys[stageId]}';
String lookItemId(FightLook look) => 'look.${look.name}';
String gameItemId(String game) => 'game.$game';

bool isFreeFighter(int fighterId) => kFreeFighters.contains(fighterId);
bool isFreeStage(int stageId) => stageId == kFreeStage;
bool isFreeLook(FightLook look) => look == FightLook.cartoon;
bool isFreeGame(String game) => !_gamePrices.containsKey(game);

final List<CatalogItem> _singles = [
  for (var i = 0; i < kFighterKeys.length; i++)
    if (!isFreeFighter(i))
      CatalogItem(fighterItemId(i), CatalogKind.fighter, _legends.contains(i) ? 90 : 60),
  for (var i = 1; i < kStageKeys.length; i++)
    CatalogItem(stageItemId(i), CatalogKind.stage, 40),
  const CatalogItem('look.painted', CatalogKind.look, 120),
  const CatalogItem('look.pixel', CatalogKind.look, 120),
  for (final e in _gamePrices.entries)
    CatalogItem(gameItemId(e.key), CatalogKind.game, e.value),
];

List<String> _ids(bool Function(CatalogItem) test) => [
  for (final i in _singles)
    if (test(i)) i.id,
];

final List<CatalogItem> _bundles = [
  CatalogItem('bundle.animals', CatalogKind.bundle, 450,
      members: _ids((i) => i.kind == CatalogKind.fighter && i.price == 60)),
  CatalogItem('bundle.legends', CatalogKind.bundle, 340,
      members: _ids((i) => i.kind == CatalogKind.fighter && i.price == 90)),
  CatalogItem('bundle.stages', CatalogKind.bundle, 150,
      members: _ids((i) => i.kind == CatalogKind.stage)),
  CatalogItem('bundle.looks', CatalogKind.bundle, 180,
      members: _ids((i) => i.kind == CatalogKind.look)),
  CatalogItem('bundle.fist', CatalogKind.bundle, 990,
      members: _ids((i) =>
          i.kind == CatalogKind.fighter ||
          i.kind == CatalogKind.stage ||
          i.kind == CatalogKind.look)),
  CatalogItem('bundle.gamenight', CatalogKind.bundle, 490,
      members: _ids((i) => i.kind == CatalogKind.game)),
];

/// Every unlockable, singles then bundles.
final List<CatalogItem> kCatalog = [..._singles, ..._bundles];

final Map<String, CatalogItem> _byId = {for (final i in kCatalog) i.id: i};

CatalogItem? catalogItem(String id) => _byId[id];

/// The smallest bundle containing [itemId], for the "save with the pack" hint.
CatalogItem? bundleFor(String itemId) {
  CatalogItem? best;
  for (final b in _bundles) {
    if (!b.members.contains(itemId)) continue;
    if (best == null || b.members.length < best.members.length) best = b;
  }
  return best;
}

/// The most a first free pick can be worth (any single fighter or stage).
const int kFirstPickMax = 90;

/// Bananas per banana pack, by RevenueCat package id. The server credits from
/// its own copy (`catalog.ts` `PACKS`), never from this.
const Map<String, int> kPackBananas = {
  'handful': 80,
  'basket': 450,
  'crate': 1000,
  'tree': 2200,
  'jungle': 6000,
};
