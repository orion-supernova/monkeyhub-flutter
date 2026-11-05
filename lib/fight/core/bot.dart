// Difficulty-parameterised AI. Produces one input per frame from a state.
// It keeps its own seeded integer PRNG and plan queue; it never touches the
// sim state, so it is not part of rollback (run it on one peer, or on both
// with the same seed and feed it only confirmed state).

import 'character_def.dart';
import 'fight_state.dart';
import 'input.dart';
import 'move_def.dart';
import 'units.dart';

enum BotLevel { easy, normal, hard }

class FightBot {
  final BotLevel level;
  int _rng;
  final List<int> _q = [];
  bool _interruptible = true;
  int _seenSerial = -1, _seenAt = 0, _cancelSerial = -1, _projSeen = -1, _projSeenAt = 0;

  FightBot({required int seed, this.level = BotLevel.normal}) : _rng = seed % 2147483647 + 1;

  int get _delay => level == BotLevel.easy ? 16 : (level == BotLevel.normal ? 9 : 4);
  int get _blockRate => level == BotLevel.easy ? 45 : (level == BotLevel.normal ? 72 : 93);
  int get _comboRate => level == BotLevel.easy ? 30 : (level == BotLevel.normal ? 65 : 92);
  int get _aaRate => level == BotLevel.easy ? 25 : (level == BotLevel.normal ? 55 : 85);
  int get _techRate => level == BotLevel.easy ? 15 : (level == BotLevel.normal ? 50 : 85);
  int get _exRate => level == BotLevel.easy ? 5 : (level == BotLevel.normal ? 20 : 40);

  int _r(int n) {
    _rng = (_rng * 1664525 + 1013904223) % 4294967296;
    return (_rng ~/ 65536) % n;
  }

  void reset() {
    _q.clear();
    _seenSerial = -1;
    _cancelSerial = -1;
  }

  int decide(FightState s, int me) {
    if (s.phase != Phase.fight || s.superFlash > 0) {
      _q.clear();
      return 0;
    }
    final p = s.p[me];
    final o = s.p[1 - me];
    final c = s.chars[me];
    final oc = s.chars[1 - me];
    final fwd = forwardBit(p.face);
    final back = backBit(p.face);
    final dist = (o.x - p.x).abs();

    switch (p.state) {
      case St.grabbed:
        _q.clear();
        return (p.inp == 0 && _r(100) < _techRate) ? (Inp.light | Inp.heavy) : 0;
      case St.blockstun:
        _q.clear();
        return back | (p.crouchBlock ? Inp.down : 0);
      case St.airstun:
        _q.clear();
        return (level == BotLevel.hard && p.y < 6000 && p.vy < 0) ? Inp.roll : 0;
      case St.hitstun:
      case St.techd:
      case St.landing:
      case St.getup:
      case St.down:
      case St.ko:
      case St.prejump:
        _q.clear();
        return 0;
      case St.jump:
        if (c.airDashFrames > 0 && _q.isNotEmpty) return _q.removeAt(0);
        if (!p.airUsed && dist < 16000 && o.y < 20000 && _r(100) < 30) return _r(2) == 0 ? Inp.heavy : Inp.light;
        // Air mobility (characters without it never reach these branches).
        if (c.airJumps > p.airJumpsUsed && p.y > 6000 && p.vy < 400 && _r(100) < 7) return Inp.up;
        if (c.airDashFrames > 0 && !p.airDashUsed && p.airDashT == 0 && p.y > 4000 && dist > 14000 && _r(100) < 6) {
          _q.addAll([0, fwd, 0, fwd]);
          _interruptible = true;
          return fwd;
        }
        return 0;
      case St.move:
        return _inMove(s, me, c);
    }

    // Actionable (idle, walk, crouch, dash, roll...).
    final actionable = p.state == St.idle || p.state == St.walk || p.state == St.crouch;
    final threat = _threat(s, me, p, o, c, oc, dist);
    if (threat != 0 && actionable && _r(100) < _blockRate) {
      _q.clear();
      _interruptible = false;
      final low = threat == 2;
      final hold = back | (low ? Inp.down : 0);
      for (var i = 0; i < 9; i++) {
        _q.add(hold);
      }
      return _q.removeAt(0);
    }
    if (_q.isNotEmpty) return _q.removeAt(0);
    if (!actionable) return 0;

    _interruptible = true;
    // Anti-air.
    if (o.y > 3000 && o.vy <= 400 && dist < 20000 && _r(100) < _aaRate) {
      return _antiAir(p, c);
    }
    if (p.meter >= superCost && _r(100) < (level == BotLevel.easy ? 3 : 8) && _superRange(c, dist)) {
      return Inp.superBtn;
    }
    final zone = dist < 11000 ? 0 : (dist < 30000 ? 1 : 2);
    final r = _r(100);
    if (zone == 0) return _close(p, o, c, r, fwd, back);
    if (zone == 1) return _mid(p, o, c, r, fwd, back, dist);
    return _far(p, o, c, r, fwd, back);
  }

  bool _superRange(CharacterDef c, int dist) {
    switch (c.key) {
      case 'tank':
        return dist < 8500;
      case 'nyx':
        return dist < 70000;
      case 'sage':
        return dist < 60000;
      default:
        return dist < 22000;
    }
  }

  // 0 none, 1 block standing, 2 block crouching.
  int _threat(FightState s, int me, Fighter p, Fighter o, CharacterDef c, CharacterDef oc, int dist) {
    if (o.state == St.move) {
      final m = oc.moves[o.moveId];
      if (o.serial != _seenSerial) {
        _seenSerial = o.serial;
        _seenAt = s.frame;
      }
      if (m.windows.isNotEmpty && !m.grab && s.frame - _seenAt >= _delay && o.sf < m.startup + m.active) {
        var reach = 0;
        for (final w in m.windows) {
          final r = w.box.x + w.box.w;
          if (r > reach) reach = r;
        }
        if (dist < reach + c.pushHalf + 3500) return m.height == BlockHeight.low ? 2 : 1;
      }
    }
    for (final e in s.projectiles) {
      if (e.owner == me) continue;
      final ahead = (e.x - p.x) * p.face > 0;
      if (!ahead || (e.x - p.x).abs() > 24000) continue;
      if (e.serial != _projSeen) {
        _projSeen = e.serial;
        _projSeenAt = s.frame;
      }
      if (s.frame - _projSeenAt >= _delay) return 1;
    }
    return 0;
  }

  int _antiAir(Fighter p, CharacterDef c) {
    final stand = (p.inp & Inp.down) == 0;
    if (stand && (c.key == 'kai' || c.key == 'tank' || _antiAirKeys.contains(c.key))) {
      _queueSpecial(Inp.up, p, false);
      return _q.removeAt(0);
    }
    return Inp.heavy;
  }

  int _inMove(FightState s, int me, CharacterDef c) {
    final p = s.p[me];
    if (_q.isNotEmpty && !_interruptible) return _q.removeAt(0);
    final m = c.moves[p.moveId];
    if (p.contact == 0 || p.serial == _cancelSerial || p.sf < m.startup) return _q.isNotEmpty ? _q.removeAt(0) : 0;
    _cancelSerial = p.serial;
    if (_r(100) >= _comboRate) return 0;
    if ((m.cancelMask & (1 << MoveClass.superMove.index)) != 0 && p.meter >= superCost && _r(100) < 40) {
      return Inp.superBtn;
    }
    if (m.chainButton != 0 && _r(100) < 70) return m.chainButton;
    if ((m.cancelMask & (1 << MoveClass.special.index)) != 0) {
      final dir = _comboSpecialDir(c);
      _queueSpecial(dir, p, p.meter >= exCost && _r(100) < _exRate);
      return _q.removeAt(0);
    }
    return 0;
  }

  // Direction of the special each character uses as a combo ender.
  int _comboSpecialDir(CharacterDef c) {
    // Inp.right is a "forward" marker, resolved against facing in _queueSpecial.
    if (_comboFwdKeys.contains(c.key)) return Inp.right;
    return (c.key == 'kai' || c.key == 'mojo') ? Inp.right : 0;
  }

  /// Queue "special with direction" so the direction is still held when the
  /// move is eventually read out of the input buffer.
  void _queueSpecial(int dir, Fighter p, bool ex) {
    var d = dir;
    if (d == Inp.right) d = forwardBit(p.face);
    _q.clear();
    _interruptible = false;
    _q.add(d | Inp.special | (ex ? Inp.heavy : 0));
    for (var i = 0; i < 5; i++) {
      _q.add(d);
    }
  }

  // Special slots (Slot.*) the newer characters prefer, by range. Zoners keep
  // their projectiles for range, rushdown characters for the close game.
  static const Map<String, List<int>> _closeSlots = {
    'bruno': [0, 1, 2, 1],
    'sage': [3, 2, 0],
    'razz': [0, 1, 3, 2, 1],
    'pip': [1, 2, 3],
    'ryoko': [0, 2, 3, 1],
    'bao': [0, 2, 3, 0],
    'vex': [1, 0, 3, 2],
    'gale': [2, 0, 3],
  };
  static const Map<String, List<int>> _midSlots = {
    'bruno': [1, 3, 2],
    'sage': [0, 1, 0],
    'razz': [1, 2, 1],
    'pip': [0, 1, 3],
    'ryoko': [1, 2, 1],
    'bao': [1, 0, 2],
    'vex': [0, 1, 3, 2],
    'gale': [1, 3, 0],
  };
  static const Map<String, List<int>> _farSlots = {
    'sage': [0, 1, 0],
    'pip': [0, 0, 3],
    'vex': [0, 2, 0],
    'gale': [0, 0, 3],
    'ryoko': [1],
    'razz': [1],
    'bruno': [],
  };
  static const Set<String> _antiAirKeys = {'bruno', 'ryoko', 'bao', 'razz', 'sage'};
  static const Set<String> _comboFwdKeys = {'bruno', 'ryoko', 'razz', 'pip'};

  void _slotSpecial(Map<String, List<int>> table, CharacterDef c, Fighter p) {
    final slots = table[c.key] ?? const [0, 1, 2, 3];
    final slot = slots.isEmpty ? 0 : slots[_r(slots.length)];
    final dir = slot == Slot.forward ? Inp.right : (slot == Slot.down ? Inp.down : (slot == Slot.up ? Inp.up : 0));
    _queueSpecial(dir, p, p.meter >= exCost && _r(100) < _exRate);
  }

  void _walk(int dir, int frames) {
    _q.clear();
    _interruptible = true;
    for (var i = 0; i < frames; i++) {
      _q.add(dir);
    }
  }

  int _tap(int dir, Fighter p) {
    // forward, release, forward -> dash
    _q.clear();
    _interruptible = true;
    _q.addAll([0, dir, 0, dir, dir, dir, dir]);
    return dir;
  }

  int _close(Fighter p, Fighter o, CharacterDef c, int r, int fwd, int back) {
    if (r < 22) return Inp.light;
    if (r < 32) return Inp.heavy;
    if (r < 42) return Inp.light | Inp.heavy;
    if (r < 52) {
      _q.add(Inp.down);
      return Inp.down | Inp.light;
    }
    if (r < 60) return Inp.down | Inp.heavy;
    if (r < 68) return fwd | Inp.heavy;
    if (r < 80) {
      switch (c.key) {
        case 'kai':
          _queueSpecial(Inp.right, p, p.meter >= exCost && _r(100) < _exRate);
          break;
        case 'mojo':
          _queueSpecial(Inp.right, p, false);
          break;
        case 'tank':
          _queueSpecial(Inp.right, p, p.meter >= exCost && _r(100) < _exRate);
          break;
        case 'nyx':
          _queueSpecial(Inp.up, p, false); // Eclipse counter stance
          break;
        default:
          _slotSpecial(_closeSlots, c, p);
      }
      return _q.removeAt(0);
    }
    if (r < 88) return Inp.roll;
    _walk(back, 8);
    return _q.removeAt(0);
  }

  int _mid(Fighter p, Fighter o, CharacterDef c, int r, int fwd, int back, int dist) {
    if (r < 30) {
      _walk(fwd, 10);
      return _q.removeAt(0);
    }
    if (r < 42) return _tap(fwd, p);
    if (r < 55) return dist < 17000 ? Inp.heavy : fwd;
    if (r < 75) {
      switch (c.key) {
        case 'kai':
          _queueSpecial(r < 65 ? Inp.right : Inp.down, p, false);
          break;
        case 'mojo':
          _queueSpecial(r < 65 ? Inp.right : 0, p, false);
          break;
        case 'tank':
          _queueSpecial(0, p, p.meter >= exCost && _r(100) < _exRate);
          break;
        case 'nyx':
          _queueSpecial(r < 65 ? Inp.right : 0, p, p.meter >= exCost && _r(100) < _exRate);
          break;
        default:
          _slotSpecial(_midSlots, c, p);
      }
      return _q.removeAt(0);
    }
    if (r < 80) {
      _q.clear();
      _q.addAll([fwd | Inp.up, fwd | Inp.up]);
      return _q.removeAt(0);
    }
    _walk(fwd, 8);
    return _q.removeAt(0);
  }

  int _far(Fighter p, Fighter o, CharacterDef c, int r, int fwd, int back) {
    switch (c.key) {
      case 'kai':
      case 'nyx':
        if (r < 45) {
          _queueSpecial(0, p, p.meter >= exCost && _r(100) < _exRate);
          return _q.removeAt(0);
        }
        if (c.key == 'nyx' && r < 60) {
          _queueSpecial(Inp.down, p, false);
          return _q.removeAt(0);
        }
        break;
      case 'mojo':
        if (r < 25) {
          _queueSpecial(Inp.down, p, false); // Banana Peel
          return _q.removeAt(0);
        }
        if (r < 40) {
          _queueSpecial(0, p, false);
          return _q.removeAt(0);
        }
        if (r < 50) {
          _queueSpecial(Inp.up, p, false); // Canopy Dive
          return _q.removeAt(0);
        }
        break;
      case 'tank':
        if (r < 20) return _tap(fwd, p);
        break;
      default:
        final slots = _farSlots[c.key];
        if (slots != null && slots.isNotEmpty && r < 40) {
          _slotSpecial(_farSlots, c, p);
          return _q.removeAt(0);
        }
        if (r < 60) return _tap(fwd, p);
    }
    _walk(fwd, 14);
    return _q.removeAt(0);
  }
}
