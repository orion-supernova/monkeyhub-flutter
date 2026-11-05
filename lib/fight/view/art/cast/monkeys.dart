import 'bruno_art.dart';
import 'cast_art.dart';
import 'pip_art.dart';
import 'razz_art.dart';
import 'sage_art.dart';

/// Registers this family's fighters' art: 4 BRUNO, 5 SAGE, 6 RAZZ, 7 PIP.
void registerMonkeys(Map<int, CastArt> m) {
  for (final a in const <CastArt>[BrunoArt(), SageArt(), RazzArt(), PipArt()]) {
    m[a.id] = a;
  }
}
