// The deterministic simulation step. Integer maths only.
//
// step() order per frame: read inputs -> (phase handling) -> fighters ->
// entities -> strike resolution -> pushboxes/walls -> round end.

import 'character_def.dart';
import 'fight_state.dart';
import 'input.dart';
import 'move_def.dart';
import 'units.dart';

// Roll template shared by every character.
const int rollTotal = 34;
const int rollInvStart = 2;
const int rollInvEnd = 15; // exclusive: frames 2..14
const int rollMoveStart = 2;
const int rollMoveEnd = 23;
const int _backdashInvEnd = 7;
const int _specialBit = 1 << 1; // MoveClass.special
const int _superBit = 1 << 2; // MoveClass.superMove

void step(FightState s, int input1, int input2) {
  s.frame++;
  _readInput(s, 0, input1);
  _readInput(s, 1, input2);
  switch (s.phase) {
    case Phase.intro:
      s.phaseTimer--;
      if (s.phaseTimer <= 0) s.phase = Phase.fight;
      return;
    case Phase.over:
      return;
    case Phase.ko:
      _koPhase(s);
      return;
  }
  if (s.superFlash > 0) {
    s.superFlash--;
    return;
  }
  s.timer--;
  _updateFighter(s, 0);
  if (!(s.superFlash == superFlashFrames && s.superBy == 0)) _updateFighter(s, 1);
  _updateProjectiles(s);
  _resolveStrikes(s);
  _updateTraps(s);
  _separate(s);
  _checkRoundEnd(s);
}

// ---------------------------------------------------------------- input

void _readInput(FightState s, int i, int raw) {
  final p = s.p[i];
  final cur = sanitizeInput(raw);
  final edges = pressedEdges(cur, p.inp);
  p.prev = p.inp;
  p.inp = cur;
  if (p.stop <= 0 && s.superFlash <= 0 && s.phase == Phase.fight) {
    if (p.bufLight > 0) p.bufLight--;
    if (p.bufHeavy > 0) p.bufHeavy--;
    if (p.bufSpecial > 0) p.bufSpecial--;
    if (p.bufRoll > 0) p.bufRoll--;
    if (p.bufSuper > 0) p.bufSuper--;
    if (p.tapFwd > 0) p.tapFwd--;
    if (p.tapBack > 0) p.tapBack--;
    if (p.dashFwdBuf > 0) p.dashFwdBuf--;
    if (p.dashBackBuf > 0) p.dashBackBuf--;
  }
  if ((edges & Inp.light) != 0) p.bufLight = inputBufferFrames;
  if ((edges & Inp.heavy) != 0) p.bufHeavy = inputBufferFrames;
  if ((edges & Inp.special) != 0) p.bufSpecial = inputBufferFrames;
  if ((edges & Inp.roll) != 0) p.bufRoll = inputBufferFrames;
  if ((edges & Inp.superBtn) != 0) p.bufSuper = inputBufferFrames;
  if ((edges & forwardBit(p.face)) != 0) {
    if (p.tapFwd > 0) {
      p.dashFwdBuf = dashBufferFrames;
      p.tapFwd = 0;
    } else {
      p.tapFwd = dashTapWindow;
    }
  }
  if ((edges & backBit(p.face)) != 0) {
    if (p.tapBack > 0) {
      p.dashBackBuf = dashBufferFrames;
      p.tapBack = 0;
    } else {
      p.tapBack = dashTapWindow;
    }
  }
}

void _clearBuffers(Fighter p) {
  p.bufLight = 0;
  p.bufHeavy = 0;
  p.bufSpecial = 0;
  p.bufRoll = 0;
  p.bufSuper = 0;
}

// ---------------------------------------------------------------- fighters

bool _actionable(Fighter p) => p.state == St.idle || p.state == St.walk || p.state == St.crouch;

int _walkSpeed(Fighter p, int v) => p.slow > 0 ? v * 60 ~/ 100 : v;

void _updateFighter(FightState s, int i) {
  final p = s.p[i];
  final def = s.chars[i];
  if (p.stop > 0) {
    p.stop--;
    return;
  }
  if (p.slow > 0) p.slow--;
  if (_actionable(p) && holdsBack(p.inp, p.face)) {
    if (p.guardAge < 99) p.guardAge++;
  } else {
    p.guardAge = 0;
  }
  switch (p.state) {
    case St.idle:
    case St.walk:
    case St.crouch:
      _neutral(s, i);
      break;
    case St.prejump:
      p.sf++;
      if (p.sf >= def.prejump) {
        p.state = St.jump;
        p.sf = 0;
        p.airUsed = false;
        p.airJumpsUsed = 0;
        p.airDashT = 0;
        p.airDashUsed = false;
        p.vy = def.jumpVy;
        p.vx = p.jumpDir * def.jumpVx;
      }
      break;
    case St.jump:
      p.sf++;
      if (!p.airUsed && (p.bufHeavy > 0 || p.bufLight > 0)) {
        p.airUsed = true;
        p.airDashT = 0;
        _startMove(s, i, p.bufHeavy > 0 ? N.jumpHeavy : N.jumpLight);
      } else {
        _airMobility(s, i);
      }
      break;
    case St.move:
      _updateMove(s, i);
      break;
    case St.hitstun:
    case St.blockstun:
    case St.techd:
      p.stun--;
      if (p.stun <= 0) {
        if (p.state == St.hitstun) _endCombo(p);
        p.state = St.idle;
        p.sf = 0;
        _neutral(s, i);
      }
      break;
    case St.down:
      p.stun--;
      if (p.stun <= 0) {
        p.state = St.getup;
        p.sf = 0;
      }
      break;
    case St.getup:
      p.sf++;
      if (p.sf >= (p.quickRise ? 8 : 14)) {
        p.quickRise = false;
        p.state = St.idle;
        p.sf = 0;
        _neutral(s, i);
      }
      break;
    case St.landing:
      p.sf++;
      if (p.sf >= p.landLag) {
        p.state = St.idle;
        p.sf = 0;
        _neutral(s, i);
      }
      break;
    case St.dash:
      p.sf++;
      if (p.sf >= 8 && (p.bufLight > 0 || p.bufHeavy > 0 || p.bufSpecial > 0 || p.bufSuper > 0)) {
        p.state = St.idle;
        p.vx = 0;
        _neutral(s, i);
      } else if (p.sf >= def.dashFrames) {
        p.state = St.idle;
        p.vx = 0;
        _neutral(s, i);
      } else {
        p.vx = p.face * def.dashSpeed;
      }
      break;
    case St.backdash:
      p.sf++;
      if (p.sf >= def.backdashFrames) {
        p.state = St.idle;
        p.vx = 0;
        _neutral(s, i);
      } else {
        p.vx = -p.face * def.backdashSpeed;
      }
      break;
    case St.roll:
      p.sf++;
      if (p.sf >= rollTotal) {
        p.state = St.idle;
        p.vx = 0;
        _neutral(s, i);
      } else if (p.sf >= rollMoveStart && p.sf < rollMoveEnd) {
        p.vx = p.jumpDir * (p.jumpDir == p.face ? def.rollSpeed : def.rollBackSpeed);
      } else {
        p.vx = 0;
      }
      break;
    case St.grabbed:
      _updateGrabbed(s, i);
      break;
    default:
      break; // airstun, ko: physics only
  }
  _physics(s, i);
}

/// Double jump (fresh up press) and air dash (double-tap fwd/back). Both are
/// off unless the character defines them, so older fighters are untouched.
void _airMobility(FightState s, int i) {
  final p = s.p[i];
  final def = s.chars[i];
  if (p.airDashT > 0) {
    p.airDashT--;
    if (p.airDashT > 0) {
      p.vx = p.face * p.airDashDir * def.airDashSpeed;
      p.vy = def.gravity; // gravity is applied right after: net vertical speed 0
    } else {
      p.vx = p.face * p.airDashDir * def.jumpVx;
      p.vy = 0;
    }
    return;
  }
  if (def.airJumps > 0 && p.airJumpsUsed < def.airJumps && p.y > 0 && isPressed(p.inp, p.prev, Inp.up)) {
    p.airJumpsUsed++;
    p.airDashT = 0;
    p.vy = def.jumpVy * 85 ~/ 100;
    p.vx = ((p.inp & Inp.right) != 0 ? 1 : ((p.inp & Inp.left) != 0 ? -1 : 0)) * def.jumpVx;
    s.addEvent(Ev.dash, p.x, p.y, i, 2);
    return;
  }
  if (def.airDashFrames > 0 && !p.airDashUsed && p.y > 0 && (p.dashFwdBuf > 0 || p.dashBackBuf > 0)) {
    p.airDashDir = p.dashFwdBuf > 0 ? 1 : -1;
    p.airDashUsed = true;
    p.airDashT = def.airDashFrames;
    p.dashFwdBuf = 0;
    p.dashBackBuf = 0;
    p.vx = p.face * p.airDashDir * def.airDashSpeed;
    p.vy = def.gravity;
    s.addEvent(Ev.dash, p.x, p.y, i, 3 * p.airDashDir);
  }
}

void _endCombo(Fighter p) {
  p.comboHits = 0;
  p.comboAttacks = 0;
  p.comboDamage = 0;
  p.lastSerial = -1;
  p.juggleLeft = 0;
  p.juggleLocked = false;
  p.kdWall = false;
  p.kdGround = false;
  p.bounced = false;
}

bool _wantsSuper(Fighter p) =>
    p.bufSuper > 0 || (p.bufSpecial > 0 && (p.inp & Inp.heavy) != 0 && (p.inp & Inp.light) != 0);

/// Reach added to throws and command grabs for wide bodies. Ranges were
/// tuned on KAI (push half-width 3500); without this two heavyweights
/// standing as close as their bodies allow are already out of grab range
/// (TANK, BOOM and GOLEM could never grab each other). Narrow fighters keep
/// the base range: being small is not a grab nerf.
int _bodyReach(CharacterDef a, CharacterDef d) {
  final extra = (a.pushHalf - kBaseHalf) + (d.pushHalf - kBaseHalf);
  return extra > 0 ? extra : 0;
}

const int kBaseHalf = 3500;

bool _inThrowRange(FightState s, int i) {
  final p = s.p[i], o = s.p[1 - i];
  return (o.x - p.x).abs() <= throwRange + _bodyReach(s.chars[i], s.chars[1 - i]) && o.y < 3000;
}

void _neutral(FightState s, int i) {
  final p = s.p[i];
  final o = s.p[1 - i];
  final def = s.chars[i];
  if (o.x != p.x) p.face = o.x > p.x ? 1 : -1;
  final inp = p.inp;
  if (_wantsSuper(p) && p.meter >= superCost) {
    _startSuper(s, i);
    return;
  }
  if (p.bufLight >= throwBufferMin && p.bufHeavy >= throwBufferMin && _inThrowRange(s, i)) {
    _startMove(s, i, N.throwMove);
    return;
  }
  if (p.bufSpecial > 0 && _startSpecial(s, i)) return;
  if (p.bufRoll > 0) {
    _startRoll(s, i);
    return;
  }
  final down = (inp & Inp.down) != 0;
  if (p.bufHeavy > 0) {
    _startMove(s, i, down ? N.crouchHeavy : (holdsForward(inp, p.face) ? N.fwdHeavy : N.standHeavy));
    return;
  }
  if (p.bufLight > 0) {
    _startMove(s, i, down ? N.crouchLight : N.standLight);
    return;
  }
  if ((inp & Inp.up) != 0) {
    p.state = St.prejump;
    p.sf = 0;
    p.vx = 0;
    p.jumpDir = (inp & Inp.right) != 0 ? 1 : ((inp & Inp.left) != 0 ? -1 : 0);
    p.dashFwdBuf = 0;
    p.dashBackBuf = 0;
    return;
  }
  if (p.dashFwdBuf > 0) {
    p.state = St.dash;
    p.sf = 0;
    p.dashFwdBuf = 0;
    p.dashBackBuf = 0;
    p.vx = p.face * def.dashSpeed;
    s.addEvent(Ev.dash, p.x, p.y, i, 1);
    return;
  }
  if (p.dashBackBuf > 0) {
    p.state = St.backdash;
    p.sf = 0;
    p.dashFwdBuf = 0;
    p.dashBackBuf = 0;
    p.vx = -p.face * def.backdashSpeed;
    s.addEvent(Ev.dash, p.x, p.y, i, -1);
    return;
  }
  if (down) {
    p.state = St.crouch;
    p.vx = 0;
    return;
  }
  if ((inp & (Inp.left | Inp.right)) != 0) {
    final dir = (inp & Inp.right) != 0 ? 1 : -1;
    p.state = St.walk;
    p.vx = dir * _walkSpeed(p, dir == p.face ? def.walkFwd : def.walkBack);
    return;
  }
  p.state = St.idle;
  p.vx = 0;
}

bool _startSpecial(FightState s, int i) {
  final p = s.p[i];
  final def = s.chars[i];
  final inp = p.inp;
  final slot = (inp & Inp.down) != 0
      ? Slot.down
      : ((inp & Inp.up) != 0 ? Slot.up : (holdsForward(inp, p.face) ? Slot.forward : Slot.neutral));
  var id = def.specials[slot];
  if ((inp & Inp.heavy) != 0 && def.exSpecials[slot] >= 0 && p.meter >= exCost) {
    id = def.exSpecials[slot];
    p.meter -= exCost;
  }
  _startMove(s, i, id);
  return true;
}

void _startRoll(FightState s, int i) {
  final p = s.p[i];
  p.state = St.roll;
  p.sf = 0;
  p.moveId = -1;
  _clearBuffers(p);
  p.jumpDir = holdsBack(p.inp, p.face) ? -p.face : p.face;
  p.vx = 0;
  s.addEvent(Ev.roll, p.x, p.y, i, p.jumpDir);
}

void _startSuper(FightState s, int i) {
  final p = s.p[i];
  p.meter -= superCost;
  s.superFlash = superFlashFrames;
  s.superBy = i;
  s.addEvent(Ev.superFlash, p.x, p.y + 10000, i);
  _startMove(s, i, s.chars[i].superMove);
}

void _startMove(FightState s, int i, int id) {
  final p = s.p[i];
  final m = s.chars[i].moves[id];
  p.state = St.move;
  p.moveId = id;
  p.sf = 0;
  p.hitMask = 0;
  p.contact = 0;
  p.armorLeft = m.armorHits;
  p.serial = ++s.serial;
  _clearBuffers(p);
  if (p.grounded) p.vx = 0;
  _applyMoveFrame(s, i, m);
}

void _applyMoveFrame(FightState s, int i, MoveDef m) {
  final p = s.p[i];
  final o = s.p[1 - i];
  final f = p.sf;
  for (final st in m.steps) {
    if (st.frame != f) continue;
    if (st.teleport == 1) {
      final dir = o.x >= p.x ? 1 : -1;
      var nx = o.x + dir * st.tpOffset;
      if (nx < stageMinX) nx = stageMinX;
      if (nx > stageMaxX) nx = stageMaxX;
      p.x = nx;
    }
    if (st.faceOpponent && o.x != p.x) p.face = o.x > p.x ? 1 : -1;
    if (st.vx != null) p.vx = p.face * st.vx!;
    if (st.vy != null) p.vy = st.vy!;
  }
  for (final ps in m.projectiles) {
    if (ps.frame != f) continue;
    final pd = s.chars[i].projectiles[ps.proj];
    if (s.projectiles.length >= 8) continue;
    s.projectiles.add(Projectile(i, ps.proj, ++s.serial, p.x + p.face * ps.x, p.y + ps.y, p.face * pd.vx, pd.vy, pd.life, pd.hits));
    s.addEvent(Ev.projectileSpawn, p.x + p.face * ps.x, p.y + ps.y, i, ps.proj);
  }
  for (final ts in m.traps) {
    if (ts.frame != f) continue;
    final td = s.chars[i].traps[ts.trap];
    s.traps.removeWhere((t) => t.owner == i);
    s.traps.add(Trap(i, ts.trap, p.x + p.face * ts.x, td.life, td.arm));
  }
}

void _updateMove(FightState s, int i) {
  final p = s.p[i];
  final m = s.chars[i].moves[p.moveId];
  p.sf++;
  if (p.sf >= m.total) {
    p.moveId = -1;
    if (!p.grounded) {
      p.state = St.jump;
      p.airUsed = true;
    } else {
      p.state = St.idle;
      p.vx = 0;
      p.sf = 0;
      _neutral(s, i);
    }
    return;
  }
  _applyMoveFrame(s, i, m);
  _tryCancel(s, i, m);
}

void _tryCancel(FightState s, int i, MoveDef m) {
  final p = s.p[i];
  if (p.sf < m.startup) return;
  final ok = (p.contact == 1 && m.cancelHit) || (p.contact == 2 && m.cancelBlock) || (p.contact == 0 && m.cancelWhiff);
  if (!ok) return;
  if ((m.cancelMask & _superBit) != 0 && _wantsSuper(p) && p.meter >= superCost) {
    _startSuper(s, i);
    return;
  }
  if ((m.cancelMask & _specialBit) != 0 && p.bufSpecial > 0 && p.grounded) {
    _startSpecial(s, i);
    return;
  }
  if (m.chainButton != 0 && p.contact != 0) {
    final buffered = m.chainButton == Inp.light ? p.bufLight : p.bufHeavy;
    if (buffered > 0) {
      _startMove(s, i, m.chainInto);
    }
  }
}

void _updateGrabbed(FightState s, int i) {
  final p = s.p[i];
  final a = s.p[p.grabBy];
  if (a.state != St.move) {
    p.state = St.idle;
    p.grabBy = -1;
    return;
  }
  if (p.bufLight > 0 && p.bufHeavy > 0) {
    final dir = a.x <= p.x ? 1 : -1;
    for (final f in [p, a]) {
      f.state = St.techd;
      f.stun = 18;
      f.moveId = -1;
      f.stop = 0;
      f.sf = 0;
    }
    p.vx = dir * 650;
    a.vx = -dir * 650;
    p.grabBy = -1;
    s.addEvent(Ev.throwTech, (p.x + a.x) ~/ 2, 8000, i, 0);
    return;
  }
  p.grabTimer--;
  if (p.grabTimer <= 0) {
    final ai = p.grabBy;
    final m = s.chars[ai].moves[a.moveId];
    p.grabBy = -1;
    _resolveGrab(s, ai, 1 - ai, _strikeFromMove(m, m.windows[0], a, p, a.serial));
  }
}

// ---------------------------------------------------------------- physics

void _physics(FightState s, int i) {
  final p = s.p[i];
  final def = s.chars[i];
  if (p.y > 0 || p.vy > 0) {
    p.vy -= def.gravity;
    p.y += p.vy;
    p.x += p.vx;
    if (p.y <= 0 && p.vy <= 0) {
      p.y = 0;
      p.vy = 0;
      _land(s, i);
    }
  } else {
    p.x += p.vx;
    if (p.state == St.hitstun || p.state == St.blockstun || p.state == St.techd || p.state == St.down || p.state == St.ko) {
      p.vx = p.vx * 82 ~/ 100;
    }
  }
}

void _land(FightState s, int i) {
  final p = s.p[i];
  p.airJumpsUsed = 0;
  p.airDashT = 0;
  p.airDashUsed = false;
  switch (p.state) {
    case St.jump:
      p.state = St.idle;
      p.vx = 0;
      p.sf = 0;
      s.addEvent(Ev.land, p.x, 0, i);
      break;
    case St.move:
      final m = s.chars[i].moves[p.moveId];
      p.moveId = -1;
      p.vx = 0;
      p.sf = 0;
      if (m.landRecovery > 0) {
        p.state = St.landing;
        p.landLag = m.landRecovery;
      } else {
        p.state = St.idle;
      }
      s.addEvent(Ev.land, p.x, 0, i);
      break;
    case St.airstun:
      if (p.kdGround && !p.bounced) {
        p.bounced = true;
        p.vy = 800;
        s.addEvent(Ev.groundBounce, p.x, 0, i);
        break;
      }
      s.addEvent(Ev.land, p.x, 0, i);
      p.vx = 0;
      p.sf = 0;
      if (p.health <= 0) {
        p.state = St.ko;
      } else {
        p.quickRise = (p.inp & Inp.roll) != 0;
        p.state = St.down;
        p.stun = p.quickRise ? 6 : 32;
        _endCombo(p);
      }
      break;
    case St.ko:
      p.vx = 0;
      break;
    default:
      p.vx = 0;
      break;
  }
}

// ---------------------------------------------------------------- geometry

List<Box> _hurtBoxes(Fighter d, CharacterDef c) {
  if (d.state == St.move) {
    final m = c.moves[d.moveId];
    if (m.hurt != null) return m.hurt!;
  }
  if (!d.grounded) return c.airHurt;
  if (d.state == St.crouch || (d.state == St.blockstun && d.crouchBlock)) return c.crouchHurt;
  if (d.state == St.move && c.moves[d.moveId].pose == Pose.crouch) return c.crouchHurt;
  return c.standHurt;
}

class _Rect {
  int l, r, b, t;
  _Rect(this.l, this.r, this.b, this.t);
  bool overlaps(_Rect o) => l < o.r && r > o.l && b < o.t && t > o.b;
}

_Rect _rectOf(Fighter f, Box bx) {
  int l, r;
  if (f.face == 1) {
    l = f.x + bx.x;
    r = l + bx.w;
  } else {
    r = f.x - bx.x;
    l = r - bx.w;
  }
  final b = f.y + bx.y;
  return _Rect(l, r, b, b + bx.h);
}

/// First hurtbox of [d] overlapping [r], or null.
_Rect? _hitsHurt(Fighter d, CharacterDef dc, _Rect r) {
  for (final hb in _hurtBoxes(d, dc)) {
    final h = _rectOf(d, hb);
    if (h.overlaps(r)) return h;
  }
  return null;
}

int _invMask(Fighter d, CharacterDef dc) {
  switch (d.state) {
    case St.move:
      return dc.moves[d.moveId].invAt(d.sf);
    case St.roll:
      return d.sf >= rollInvStart && d.sf < rollInvEnd ? (Inv.strike | Inv.projectile) : 0;
    case St.backdash:
      return d.sf >= 1 && d.sf < _backdashInvEnd ? (Inv.strike | Inv.projectile) : 0;
    case St.down:
    case St.getup:
    case St.ko:
    case St.grabbed:
      return Inv.strike | Inv.projectile | Inv.throwing;
  }
  return 0;
}

bool _throwable(Fighter d) {
  if (!d.grounded) return false;
  switch (d.state) {
    case St.idle:
    case St.walk:
    case St.crouch:
    case St.prejump:
    case St.move:
    case St.dash:
    case St.backdash:
    case St.roll:
    case St.landing:
      return true;
  }
  return false;
}

// ---------------------------------------------------------------- strikes

class _Strike {
  int dmg = 0, chip = 0, hitstun = 0, blockstun = 0, hitstop = 0, pushback = 0, launch = 0;
  int juggleCost = 1, meterGain = 0, scaleFloor = comboScaleFloorDefault, serial = 0, dir = 1;
  BlockHeight height = BlockHeight.mid;
  bool knockdown = false, wallBounce = false, groundBounce = false, finisher = true;
  bool proj = false, grab = false, techable = false;
  int hx = 0, hy = 0;
}

_Strike _strikeFromMove(MoveDef m, HitWindow w, Fighter a, Fighter d, int serial) {
  final k = _Strike();
  k.dmg = w.damage >= 0 ? w.damage : m.damage;
  k.chip = m.chip;
  k.hitstun = m.hitstun;
  k.blockstun = m.blockstun;
  k.hitstop = w.stop >= 0 ? w.stop : m.hitstop;
  k.pushback = m.pushback;
  k.launch = m.launch;
  k.juggleCost = m.juggleCost;
  k.meterGain = m.meterGain;
  k.scaleFloor = m.scaleFloor;
  k.serial = serial;
  k.dir = a.x <= d.x ? 1 : -1;
  if (a.x == d.x) k.dir = a.face;
  k.height = m.height;
  k.finisher = w.finisher;
  k.knockdown = m.knockdown && w.finisher;
  k.wallBounce = m.wallBounce && w.finisher;
  k.groundBounce = m.groundBounce && w.finisher;
  k.grab = m.grab;
  k.techable = m.techable;
  if (!w.finisher) k.pushback = m.pushback ~/ 4;
  return k;
}

class _Pending {
  final int ai, di, window, kind; // kind: 0 hit, 1 block, 2 armor, 3 counter stance, 4 grab
  final bool counter;
  final _Strike k;
  _Pending(this.ai, this.di, this.window, this.kind, this.counter, this.k);
}

bool _canBlock(Fighter d, int ax, BlockHeight h) {
  if (!d.grounded) return false;
  if (d.state != St.idle && d.state != St.walk && d.state != St.crouch && d.state != St.blockstun) return false;
  final away = ax > d.x ? Inp.left : (ax < d.x ? Inp.right : backBit(d.face));
  if ((d.inp & away) == 0) return false;
  final crouching = (d.inp & Inp.down) != 0;
  switch (h) {
    case BlockHeight.unblockable:
      return false;
    case BlockHeight.low:
      return crouching;
    case BlockHeight.high:
      return !crouching;
    case BlockHeight.mid:
      return true;
  }
}

/// Can strike [k] connect with [d] at all (juggle limits, states)?
bool _juggleOk(Fighter d, _Strike k) {
  if (d.juggleLocked) return false;
  if (d.state == St.airstun && k.juggleCost > d.juggleLeft) return false;
  return true;
}

Box _grabBox(Box b, int extra) => extra == 0 ? b : Box(b.x, b.y, b.w + extra, b.h);

_Pending? _detectMove(FightState s, int ai) {
  final a = s.p[ai];
  if (a.state != St.move) return null;
  final di = 1 - ai;
  final d = s.p[di];
  final m = s.chars[ai].moves[a.moveId];
  final dc = s.chars[di];
  for (var k = 0; k < m.windows.length; k++) {
    final w = m.windows[k];
    if (a.sf < w.start || a.sf >= w.end || (a.hitMask & (1 << k)) != 0) continue;
    final inv = _invMask(d, dc);
    if (m.grab) {
      if ((inv & Inv.throwing) != 0 || !_throwable(d)) continue;
    } else {
      if ((inv & Inv.strike) != 0) continue;
      if (m.groundedOnly && !d.grounded) continue;
    }
    final box = m.grab ? _grabBox(w.box, _bodyReach(s.chars[ai], dc)) : w.box;
    final hit = _hitsHurt(d, dc, _rectOf(a, box));
    if (hit == null) continue;
    final st = _strikeFromMove(m, w, a, d, a.serial);
    if (!m.grab && !_juggleOk(d, st)) continue;
    final ar = _rectOf(a, box);
    st.hx = (_max(ar.l, hit.l) + _min(ar.r, hit.r)) ~/ 2;
    st.hy = (_max(ar.b, hit.b) + _min(ar.t, hit.t)) ~/ 2;
    int kind;
    var counter = false;
    if (m.grab) {
      kind = 4;
    } else {
      final dm = d.state == St.move ? dc.moves[d.moveId] : null;
      if (dm != null && dm.counterAt(d.sf)) {
        kind = 3;
      } else if (dm != null && dm.armorAt(d.sf) && d.armorLeft > 0) {
        kind = 2;
      } else if (_canBlock(d, a.x, m.height)) {
        kind = 1;
      } else {
        kind = 0;
        counter = dm != null && d.sf < dm.startup;
      }
    }
    return _Pending(ai, di, k, kind, counter, st);
  }
  return null;
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

void _resolveStrikes(FightState s) {
  final h0 = _detectMove(s, 0);
  final h1 = _detectMove(s, 1);
  if (h0 != null) _applyPending(s, h0);
  if (h1 != null) _applyPending(s, h1);
  _projectileHits(s);
}

void _applyPending(FightState s, _Pending h) {
  final a = s.p[h.ai];
  a.hitMask |= 1 << h.window;
  _applyStrike(s, h.ai, h.di, h.k, h.kind, h.counter);
}

/// Shared by moves, projectiles and traps. Kinds: 0 hit, 1 block, 2 armor,
/// 3 counter stance, 4 grab.
void _applyStrike(FightState s, int ai, int di, _Strike k, int kind, bool counter) {
  final a = s.p[ai];
  final d = s.p[di];
  switch (kind) {
    case 3: // counter stance triggered: no damage, the defender answers
      final dm = s.chars[di].moves[d.moveId];
      s.addEvent(Ev.counterTrigger, k.hx, k.hy, di);
      _startMove(s, di, dm.counterMove);
      a.stop = 8;
      d.stop = 8;
      return;
    case 4:
      if (k.techable) {
        d.state = St.grabbed;
        d.grabTimer = techWindow;
        d.grabBy = ai;
        d.moveId = -1;
        d.sf = 0;
        d.vx = 0;
        d.stop = 0;
        _clearBuffers(d);
        a.stop = techWindow;
        a.contact = 1;
      } else {
        a.contact = 1;
        _resolveGrab(s, ai, di, k);
      }
      return;
    case 2:
      d.armorLeft--;
      var dmg = k.dmg * 50 ~/ 100;
      d.health -= dmg;
      if (d.health < 1) d.health = 1;
      d.meter = _min(meterMax, d.meter + dmg * 6 ~/ 10);
      a.meter = _min(meterMax, a.meter + k.meterGain);
      d.stop = k.hitstop;
      if (!k.proj) {
        a.stop = k.hitstop;
        a.contact = 1;
      }
      s.addEvent(Ev.armor, k.hx, k.hy, di, dmg);
      return;
    case 1:
      final perfect = d.guardAge <= perfectBlockWindow && d.state != St.blockstun;
      d.crouchBlock = (d.inp & Inp.down) != 0;
      d.state = St.blockstun;
      d.stun = perfect ? _max(1, k.blockstun ~/ 2) : k.blockstun;
      d.sf = 0;
      d.moveId = -1;
      d.vx = k.dir * k.pushback;
      if (k.chip > 0 && !perfect) {
        d.health -= k.chip;
        if (d.health < 1) d.health = 1;
      }
      d.stop = k.hitstop;
      a.meter = _min(meterMax, a.meter + k.meterGain ~/ 2);
      d.meter = _min(meterMax, d.meter + (perfect ? 120 : 10));
      if (!k.proj) {
        a.stop = k.hitstop;
        a.contact = 2;
      }
      s.addEvent(perfect ? Ev.perfectBlock : Ev.block, k.hx, k.hy, di, perfect ? 1 : 0);
      return;
  }
  // Hit.
  final wasAir = !d.grounded;
  final idx = d.lastSerial == k.serial ? d.comboAttacks - 1 : d.comboAttacks;
  final pct = scalePercent(idx < 0 ? 0 : idx, k.scaleFloor);
  if (d.lastSerial != k.serial) {
    d.comboAttacks++;
    d.lastSerial = k.serial;
  }
  var dmg = k.dmg * pct ~/ 100;
  if (counter) dmg = dmg * 12 ~/ 10;
  if (dmg < 1 && k.dmg > 0) dmg = 1;
  d.health -= dmg;
  if (d.health < 0) d.health = 0;
  d.comboHits++;
  d.comboDamage += dmg;
  final launchIt = k.finisher && (k.launch > 0 || k.knockdown || wasAir);
  if (launchIt || (!k.finisher && wasAir)) {
    if (d.state == St.airstun) {
      d.juggleLeft -= k.juggleCost;
      if (d.juggleLeft <= 0) d.juggleLocked = true;
    } else {
      d.juggleLeft = jugglePoints;
      d.juggleLocked = false;
    }
    d.state = St.airstun;
    if (launchIt) {
      d.vy = k.launch > 0 ? k.launch : (wasAir ? 700 : 600);
      d.vx = k.dir * k.pushback;
      d.kdWall = k.wallBounce;
      d.kdGround = k.groundBounce;
      d.bounced = false;
    } else {
      d.vy = 320;
      d.vx = k.dir * k.pushback;
    }
  } else {
    d.state = St.hitstun;
    d.stun = k.hitstun + (counter ? 4 : 0);
    d.vx = k.dir * k.pushback;
  }
  d.sf = 0;
  d.moveId = -1;
  final stop = k.hitstop + (counter ? 2 : 0);
  d.stop = stop;
  if (!k.proj) {
    a.stop = stop;
    a.contact = 1;
  }
  a.meter = _min(meterMax, a.meter + k.meterGain);
  d.meter = _min(meterMax, d.meter + dmg * 6 ~/ 10);
  s.addEvent(counter ? Ev.counterHit : Ev.hit, k.hx, k.hy, ai, dmg);
}

void _resolveGrab(FightState s, int ai, int di, _Strike k) {
  final a = s.p[ai];
  final d = s.p[di];
  final pct = scalePercent(d.comboAttacks, k.scaleFloor);
  d.comboAttacks++;
  d.lastSerial = k.serial;
  final dmg = _max(1, k.dmg * pct ~/ 100);
  d.health -= dmg;
  if (d.health < 0) d.health = 0;
  d.comboHits++;
  d.comboDamage += dmg;
  d.state = St.airstun;
  d.moveId = -1;
  d.sf = 0;
  d.vy = k.launch > 0 ? k.launch : 700;
  d.vx = k.dir * k.pushback;
  d.juggleLeft = jugglePoints;
  d.juggleLocked = false;
  d.kdWall = false;
  d.kdGround = false;
  d.bounced = false;
  d.stop = 8;
  a.stop = 8;
  a.meter = _min(meterMax, a.meter + k.meterGain);
  d.meter = _min(meterMax, d.meter + dmg * 6 ~/ 10);
  s.addEvent(Ev.throwHit, (a.x + d.x) ~/ 2, 8000, ai, dmg);
}

// ---------------------------------------------------------------- entities

void _updateProjectiles(FightState s) {
  for (final e in s.projectiles) {
    e.x += e.vx;
    e.y += e.vy;
    e.life--;
  }
  // Clashes.
  for (var i = 0; i < s.projectiles.length; i++) {
    final a = s.projectiles[i];
    if (a.life <= 0) continue;
    for (var j = i + 1; j < s.projectiles.length; j++) {
      final b = s.projectiles[j];
      if (b.life <= 0 || a.owner == b.owner) continue;
      final pa = s.chars[a.owner].projectiles[a.proj];
      final pb = s.chars[b.owner].projectiles[b.proj];
      if (!_projRect(a, pa).overlaps(_projRect(b, pb))) continue;
      s.addEvent(Ev.clash, (a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2, a.owner);
      if (pa.priority >= pb.priority) b.life = 0;
      if (pb.priority >= pa.priority) a.life = 0;
      if (a.life <= 0) break;
    }
  }
  s.projectiles.removeWhere((e) => e.life <= 0 || e.hits <= 0 || e.x < -8000 || e.x > stageWidth + 8000 || e.y < -2000);
}

_Rect _projRect(Projectile e, ProjectileDef d) => _Rect(e.x - d.w ~/ 2, e.x + d.w ~/ 2, e.y, e.y + d.h);

void _projectileHits(FightState s) {
  for (final e in s.projectiles) {
    if (e.hits <= 0) continue;
    final pd = s.chars[e.owner].projectiles[e.proj];
    final di = 1 - e.owner;
    final d = s.p[di];
    final dc = s.chars[di];
    if ((_invMask(d, dc) & Inv.projectile) != 0) continue;
    final r = _projRect(e, pd);
    final hit = _hitsHurt(d, dc, r);
    if (hit == null) continue;
    final k = _Strike();
    k.dmg = pd.damage;
    k.chip = pd.chip;
    k.hitstun = pd.hitstun;
    k.blockstun = pd.blockstun;
    k.hitstop = pd.hitstop;
    k.pushback = pd.pushback;
    k.height = pd.height;
    k.knockdown = pd.knockdown;
    k.meterGain = pd.meterGain;
    k.serial = e.serial;
    k.dir = e.vx >= 0 ? 1 : -1;
    k.proj = true;
    k.hx = (_max(r.l, hit.l) + _min(r.r, hit.r)) ~/ 2;
    k.hy = (_max(r.b, hit.b) + _min(r.t, hit.t)) ~/ 2;
    if (!_juggleOk(d, k)) continue;
    int kind;
    final dm = d.state == St.move ? dc.moves[d.moveId] : null;
    if (dm != null && dm.armorAt(d.sf) && d.armorLeft > 0) {
      kind = 2;
    } else if (_canBlock(d, e.x, pd.height)) {
      kind = 1;
    } else {
      kind = 0;
    }
    e.hits--;
    _applyStrike(s, e.owner, di, k, kind, dm != null && d.sf < dm.startup && kind == 0);
  }
  s.projectiles.removeWhere((e) => e.hits <= 0);
}

void _updateTraps(FightState s) {
  for (final t in s.traps) {
    t.life--;
    if (t.arm > 0) t.arm--;
  }
  for (final t in s.traps) {
    if (t.arm > 0 || t.life <= 0) continue;
    final td = s.chars[t.owner].traps[t.trap];
    final di = 1 - t.owner;
    final d = s.p[di];
    final dc = s.chars[di];
    if (!d.grounded) continue;
    switch (d.state) {
      case St.down:
      case St.getup:
      case St.ko:
      case St.airstun:
      case St.grabbed:
        continue;
    }
    if ((_invMask(d, dc) & Inv.strike) != 0) continue;
    final r = _Rect(t.x - td.w ~/ 2, t.x + td.w ~/ 2, 0, td.h);
    if (_hitsHurt(d, dc, r) == null) continue;
    if (td.kind == TrapKind.slow) {
      if (d.slow < td.slowFrames) d.slow = td.slowFrames;
      if (d.state == St.walk) d.vx = d.vx * 60 ~/ 100;
      s.addEvent(Ev.trap, t.x, 0, t.owner, 1);
    } else {
      final k = _Strike();
      k.dmg = td.damage;
      k.knockdown = true;
      k.pushback = 300;
      k.height = BlockHeight.unblockable;
      k.hitstop = 8;
      k.serial = ++s.serial;
      k.proj = true;
      k.dir = d.x >= t.x ? 1 : -1;
      k.hx = t.x;
      k.hy = 1500;
      _applyStrike(s, t.owner, di, k, 0, false);
      s.addEvent(Ev.trap, t.x, 0, t.owner, 0);
    }
    if (td.consume) t.life = 0;
  }
  s.traps.removeWhere((t) => t.life <= 0);
}

// ---------------------------------------------------------------- bodies

bool _solid(Fighter f) {
  switch (f.state) {
    case St.down:
    case St.getup:
    case St.ko:
    case St.grabbed:
      return false;
    case St.roll:
      return !(f.jumpDir == f.face && f.sf < rollMoveEnd);
  }
  return true;
}

void _separate(FightState s) {
  final a = s.p[0];
  final b = s.p[1];
  if (_solid(a) && _solid(b) && (a.y - b.y).abs() < pushBoxHeight) {
    final need = s.chars[0].pushHalf + s.chars[1].pushHalf;
    var dx = b.x - a.x;
    var ov = need - dx.abs();
    if (ov > 0) {
      var dir = dx > 0 ? 1 : -1;
      if (dx == 0) dir = (s.nextRand() & 1) == 0 ? 1 : -1;
      final h = ov ~/ 2;
      a.x -= dir * h;
      b.x += dir * (ov - h);
      _walls(s);
      dx = b.x - a.x;
      ov = need - dx.abs();
      if (ov > 0) {
        // Still overlapping: a wall ate one side, push the free one.
        if (a.x <= stageMinX || a.x >= stageMaxX) {
          b.x += dir * ov;
        } else {
          a.x -= dir * ov;
        }
      }
    }
  }
  _walls(s);
}

void _walls(FightState s) {
  for (var i = 0; i < 2; i++) {
    final p = s.p[i];
    final o = s.p[1 - i];
    if (p.x < stageMinX) {
      final over = stageMinX - p.x;
      p.x = stageMinX;
      _wallHit(s, i, over, -1, o);
    } else if (p.x > stageMaxX) {
      final over = p.x - stageMaxX;
      p.x = stageMaxX;
      _wallHit(s, i, over, 1, o);
    }
  }
  for (final p in s.p) {
    if (p.x < stageMinX) p.x = stageMinX;
    if (p.x > stageMaxX) p.x = stageMaxX;
  }
}

void _wallHit(FightState s, int i, int over, int side, Fighter o) {
  final p = s.p[i];
  if (p.state == St.airstun) {
    if (p.kdWall && p.vx * side > 0) {
      p.kdWall = false;
      final mag = _max(p.vx.abs(), 450);
      p.vx = -side * mag;
      p.vy = 650;
      p.juggleLeft += 2;
      p.juggleLocked = false;
      s.addEvent(Ev.wallBounce, p.x, p.y + 8000, i);
    } else if (p.vx * side > 0) {
      p.vx = 0;
    }
  } else if (p.state == St.hitstun || p.state == St.blockstun) {
    // Corner pushback: the attacker is shoved back instead.
    o.x -= side * over;
  }
}

// ---------------------------------------------------------------- rounds

void _checkRoundEnd(FightState s) {
  final a = s.p[0];
  final b = s.p[1];
  final d0 = a.health <= 0;
  final d1 = b.health <= 0;
  if (!d0 && !d1 && s.timer > 0) return;
  int winner;
  if (d0 && d1) {
    winner = 2;
  } else if (d0) {
    winner = 1;
  } else if (d1) {
    winner = 0;
  } else {
    s.timeOver = true;
    winner = a.health == b.health ? 2 : (a.health > b.health ? 0 : 1);
  }
  if (winner == 2) {
    a.wins++;
    b.wins++;
  } else {
    s.p[winner].wins++;
  }
  s.roundWinner = winner;
  for (var i = 0; i < 2; i++) {
    final p = s.p[i];
    if (p.health > 0) continue;
    if (p.state != St.airstun) {
      p.state = St.airstun;
      p.vy = 900;
      p.vx = (p.x <= s.p[1 - i].x ? -1 : 1) * 500;
    }
    p.moveId = -1;
    p.stop = 0;
    s.addEvent(Ev.ko, p.x, p.y + 8000, i);
  }
  s.addEvent(Ev.roundEnd, (a.x + b.x) ~/ 2, 0, winner, s.timeOver ? 1 : 0);
  s.phase = Phase.ko;
  s.phaseTimer = koFrames;
  s.projectiles.clear();
  s.traps.clear();
  s.superFlash = 0;
}

void _koPhase(FightState s) {
  s.phaseTimer--;
  for (var i = 0; i < 2; i++) {
    final p = s.p[i];
    if (p.stop > 0) {
      p.stop--;
      continue;
    }
    if (p.y > 0 || p.vy > 0 || p.state == St.ko || p.state == St.airstun) _physics(s, i);
  }
  _walls(s);
  if (s.phaseTimer > 0) return;
  final a = s.p[0];
  final b = s.p[1];
  if (a.wins >= roundsToWin || b.wins >= roundsToWin) {
    s.phase = Phase.over;
    s.matchWinner = a.wins == b.wins ? 2 : (a.wins > b.wins ? 0 : 1);
    return;
  }
  s.round++;
  for (var i = 0; i < 2; i++) {
    final old = s.p[i];
    final f = Fighter(s.chars[i].maxHealth);
    f.wins = old.wins;
    f.meter = old.meter;
    f.prev = old.prev;
    f.inp = old.inp;
    s.p[i] = f;
  }
  s.placeFighters();
  s.timer = roundFrames;
  s.timeOver = false;
  s.roundWinner = -1;
  s.superFlash = 0;
  s.phase = Phase.intro;
  s.phaseTimer = introFrames;
}
