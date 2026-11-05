import 'cast_art.dart';
import 'bao_art.dart';
import 'gale_art.dart';
import 'ryoko_art.dart';
import 'vex_art.dart';

/// Registers this family's fighters' art.
void registerAnimals(Map<int, CastArt> m) {
  final ryoko = RyokoArt();
  m[ryoko.id] = ryoko;
  final bao = BaoArt();
  m[bao.id] = bao;
  final vex = VexArt();
  m[vex.id] = vex;
  final gale = GaleArt();
  m[gale.id] = gale;
}
