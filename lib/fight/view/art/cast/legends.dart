import 'cast_art.dart';
import 'ember_art.dart';
import 'golem_art.dart';
import 'kage_art.dart';
import 'unit7_art.dart';

/// Registers this family's fighters' art (filled in per character).
void registerLegends(Map<int, CastArt> m) {
  m[16] = const Unit7Art();
  m[17] = const KageArt();
  m[18] = const EmberArt();
  m[19] = const GolemArt();
}
