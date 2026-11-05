import 'animals.dart';
import 'cast_art.dart';
import 'humans.dart';
import 'legends.dart';
import 'monkeys.dart';

export 'cast_art.dart';

/// Art for every fighter beyond the original four, by CharacterDef.id.
/// Built once, on first use; each family file registers its own.
final Map<int, CastArt> castArt = () {
  final m = <int, CastArt>{};
  registerMonkeys(m); // 4 BRUNO, 5 SAGE, 6 RAZZ, 7 PIP
  registerAnimals(m); // 8 RYOKO, 9 BAO, 10 VEX, 11 GALE
  registerHumans(m); // 12 LUZ, 13 DEX, 14 HANA, 15 BOOM
  registerLegends(m); // 16 UNIT-7, 17 KAGE, 18 EMBER, 19 GOLEM
  return m;
}();
