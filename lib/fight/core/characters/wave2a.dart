import '../character_def.dart';
import 'bao.dart';
import 'bruno.dart';
import 'gale.dart';
import 'pip.dart';
import 'razz.dart';
import 'ryoko.dart';
import 'sage.dart';
import 'vex.dart';

export 'bao.dart' show buildBao;
export 'bruno.dart' show buildBruno;
export 'gale.dart' show buildGale;
export 'pip.dart' show buildPip;
export 'razz.dart' show buildRazz;
export 'ryoko.dart' show buildRyoko;
export 'sage.dart' show buildSage;
export 'vex.dart' show buildVex;

final CharacterDef bruno = buildBruno();
final CharacterDef sage = buildSage();
final CharacterDef razz = buildRazz();
final CharacterDef pip = buildPip();
final CharacterDef ryoko = buildRyoko();
final CharacterDef bao = buildBao();
final CharacterDef vex = buildVex();
final CharacterDef gale = buildGale();

/// Wave 2a: ids 4..11 (index == id once merged into the roster).
final List<CharacterDef> wave2a = [bruno, sage, razz, pip, ryoko, bao, vex, gale];
