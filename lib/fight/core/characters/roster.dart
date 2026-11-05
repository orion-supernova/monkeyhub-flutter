import '../character_def.dart';
import 'kai.dart';
import 'mojo.dart';
import 'nyx.dart';
import 'tank.dart';

export 'kai.dart' show buildKai;
export 'mojo.dart' show buildMojo;
export 'nyx.dart' show buildNyx;
export 'tank.dart' show buildTank;

final CharacterDef kai = buildKai();
final CharacterDef mojo = buildMojo();
final CharacterDef tank = buildTank();
final CharacterDef nyx = buildNyx();

/// Roster in selection order; index == CharacterDef.id.
final List<CharacterDef> roster = [kai, mojo, tank, nyx];
