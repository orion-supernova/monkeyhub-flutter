import '../fight/view/art/stages/stages.dart' show fightStageName;
import '../games/catalog.dart';
import '../l10n/generated/app_localizations.dart';

/// A catalog id as a person reads it: `fighter.golem` is GOLEM, `stage.neon`
/// is the stage's own translated name, `game.chess` is the chat game's name.
///
/// Fighters keep their roster spelling (uppercase), which is how the fighter
/// picker prints them and is the same in every language.
String bananaItemName(AppLocalizations l10n, String id) {
  final dot = id.indexOf('.');
  if (dot < 0) return l10n.bananasItemFallback;
  final key = id.substring(dot + 1);
  switch (id.substring(0, dot)) {
    case 'fighter':
      return kFighterKeys.contains(key) ? key.toUpperCase() : l10n.bananasItemFallback;
    case 'stage':
      final i = kStageKeys.indexOf(key);
      return i < 0 ? l10n.bananasItemFallback : fightStageName(l10n, i);
    case 'look':
      return switch (key) {
        'cartoon' => l10n.fightLookCartoon,
        'painted' => l10n.fightLookPainted,
        'pixel' => l10n.fightLookPixel,
        _ => l10n.bananasItemFallback,
      };
    case 'game':
      return switch (key) {
        'checkers' => l10n.chatGameNameCheckers,
        'reversi' => l10n.chatGameNameReversi,
        'chess' => l10n.chatGameNameChess,
        'imposter' => l10n.chatGameNameImposter,
        'liarsdice' => l10n.chatGameNameLiarsDice,
        'race' => l10n.chatGameNameRace,
        _ => l10n.bananasItemFallback,
      };
    case 'bundle':
      return switch (key) {
        'animals' => l10n.bananasBundleAnimals,
        'legends' => l10n.bananasBundleLegends,
        'stages' => l10n.bananasBundleStages,
        'looks' => l10n.bananasBundleLooks,
        'fist' => l10n.bananasBundleFist,
        'gamenight' => l10n.bananasBundleGamenight,
        _ => l10n.bananasItemFallback,
      };
  }
  return l10n.bananasItemFallback;
}

/// The small line under an item's name: what kind of thing it is.
String bananaItemKind(AppLocalizations l10n, String id) {
  return switch (id.split('.').first) {
    'fighter' => l10n.bananasKindFighter,
    'stage' => l10n.bananasKindStage,
    'look' => l10n.bananasKindLook,
    'game' => l10n.bananasKindGame,
    'bundle' => l10n.bananasKindBundle,
    _ => '',
  };
}
