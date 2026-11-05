import 'cast_art.dart';
import 'boom_art.dart';
import 'dex_art.dart';
import 'hana_art.dart';
import 'luz_art.dart';

/// Registers this family's fighters' art.
void registerHumans(Map<int, CastArt> m) {
  m[12] = LuzArt();
  m[13] = DexArt();
  m[14] = HanaArt();
  m[15] = BoomArt();
}
