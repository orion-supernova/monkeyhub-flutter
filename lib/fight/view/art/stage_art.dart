// Stage dispatcher: one painter per place (see stages/stages.dart), each with
// cached layer Pictures and a few cheap moving parts. Only the active stage
// keeps its Pictures alive.
import 'dart:ui';

import 'art_common.dart';
import 'camera.dart';
import 'stages/aurora_stage.dart';
import 'stages/canyon_stage.dart';
import 'stages/deck_stage.dart';
import 'stages/neon_stage.dart';
import 'stages/rooftop_stage.dart';
import 'stages/stage_base.dart';
import 'stages/stages.dart';
import 'stages/temple_stage.dart';

class StageArt {
  final RooftopStage _roof = RooftopStage();
  final Map<int, StageScene> _scenes = {};
  int _last = 0;

  StageScene _scene(int id) => _scenes.putIfAbsent(id, () => switch (id) {
    1 => TempleStage(),
    2 => NeonStage(),
    3 => AuroraStage(),
    4 => CanyonStage(),
    _ => DeckStage(),
  });

  /// Frees the cached pictures of looks that are not [keep].
  void trim(FightLook keep) {
    _roof.trim(keep);
    for (final s in _scenes.values) {
      s.trim(keep);
    }
  }

  /// Frees everything (the owner is done with this art).
  void dispose() {
    _roof.release();
    for (final s in _scenes.values) {
      s.release();
    }
    _scenes.clear();
  }

  void paint(Canvas c, Size size, FightCamera cam, FightLook look, int frame, [int stage = 0]) {
    final id = fightStageOf(stage);
    if (id != _last) {
      // Leaving a stage frees its Pictures.
      if (_last == 0) {
        _roof.release();
      } else {
        _scenes[_last]?.release();
      }
      _last = id;
    }
    if (id == 0) {
      _roof.paint(c, size, cam, look, frame);
    } else {
      _scene(id).paint(c, size, cam, look, frame);
    }
  }
}
