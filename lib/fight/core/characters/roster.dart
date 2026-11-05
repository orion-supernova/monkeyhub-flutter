import '../character_def.dart';
import 'kai.dart';
import 'mojo.dart';
import 'nyx.dart';
import 'tank.dart';
import 'wave2a.dart';
import 'wave2b.dart';

export 'kai.dart' show buildKai;
export 'mojo.dart' show buildMojo;
export 'nyx.dart' show buildNyx;
export 'tank.dart' show buildTank;

final CharacterDef kai = buildKai();
final CharacterDef mojo = buildMojo();
final CharacterDef tank = buildTank();
final CharacterDef nyx = buildNyx();

/// The four starters (one per family), ids 0..3.
final List<CharacterDef> starters = [kai, mojo, tank, nyx];

/// Every fighter in selection order; index == CharacterDef.id:
/// 0..3 the starters, 4..11 monkeys and animals, 12..19 humans and legends.
final List<CharacterDef> roster = [...starters, ...wave2a, ...wave2b];
