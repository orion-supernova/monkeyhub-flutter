import '../character_def.dart';
import 'boom.dart';
import 'dex.dart';
import 'ember.dart';
import 'golem.dart';
import 'hana.dart';
import 'kage.dart';
import 'luz.dart';
import 'unit7.dart';

export 'boom.dart' show buildBoom;
export 'dex.dart' show buildDex;
export 'ember.dart' show buildEmber;
export 'golem.dart' show buildGolem;
export 'hana.dart' show buildHana;
export 'kage.dart' show buildKage;
export 'luz.dart' show buildLuz;
export 'unit7.dart' show buildUnit7;

final CharacterDef luz = buildLuz();
final CharacterDef dex = buildDex();
final CharacterDef hana = buildHana();
final CharacterDef boom = buildBoom();
final CharacterDef unit7 = buildUnit7();
final CharacterDef kage = buildKage();
final CharacterDef ember = buildEmber();
final CharacterDef golem = buildGolem();

/// Wave 2b: ids 12-19, in selection order.
final List<CharacterDef> wave2b = [luz, dex, hana, boom, unit7, kage, ember, golem];
