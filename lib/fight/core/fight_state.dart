import 'character_def.dart';
import 'units.dart';

/// Fighter state machine states.
class St {
  static const int idle = 0;
  static const int walk = 1;
  static const int crouch = 2;
  static const int prejump = 3;
  static const int jump = 4;
  static const int move = 5; // playing a MoveDef (moveId)
  static const int hitstun = 6;
  static const int blockstun = 7;
  static const int airstun = 8; // launched / juggled
  static const int down = 9; // lying after a knockdown
  static const int getup = 10;
  static const int grabbed = 11;
  static const int dash = 12;
  static const int backdash = 13;
  static const int roll = 14;
  static const int landing = 15;
  static const int ko = 16;
  static const int techd = 17; // throw teched
}

class Phase {
  static const int intro = 0;
  static const int fight = 1;
  static const int ko = 2; // round over, showing the result
  static const int over = 3; // match over
}

/// Event kinds for the renderer / audio. They live in the state so a rollback
/// reproduces them.
class Ev {
  static const int hit = 0;
  static const int block = 1;
  static const int perfectBlock = 2;
  static const int counterHit = 3;
  static const int throwHit = 4;
  static const int throwTech = 5;
  static const int ko = 6;
  static const int projectileSpawn = 7;
  static const int superFlash = 8;
  static const int wallBounce = 9;
  static const int land = 10;
  static const int roll = 11;
  static const int dash = 12;
  static const int clash = 13;
  static const int armor = 14;
  static const int trap = 15;
  static const int counterTrigger = 16;
  static const int groundBounce = 17;
  static const int roundEnd = 18;
}

class FightEvent {
  final int frame, kind, x, y, player, value;
  const FightEvent(this.frame, this.kind, this.x, this.y, this.player, this.value);
}

class Fighter {
  int x = 0, y = 0, vx = 0, vy = 0;
  int face = 1;
  int health, meter = 0;
  int state = St.idle;
  int sf = 0; // frames in the current state / move frame
  int moveId = -1;
  int stun = 0, stop = 0;
  int hitMask = 0;
  int contact = 0; // 0 none, 1 hit, 2 blocked (current move)
  int armorLeft = 0;
  int serial = 0; // unique id of the current attack instance
  int prev = 0, inp = 0;
  int bufLight = 0, bufHeavy = 0, bufSpecial = 0, bufRoll = 0, bufSuper = 0;
  int tapFwd = 0, tapBack = 0, dashFwdBuf = 0, dashBackBuf = 0;
  int guardAge = 99;
  bool crouchBlock = false;
  // Combo bookkeeping (on the victim).
  int comboHits = 0, comboAttacks = 0, comboDamage = 0, lastSerial = -1;
  int juggleLeft = 0;
  bool juggleLocked = false, kdWall = false, kdGround = false, bounced = false;
  int slow = 0;
  bool quickRise = false, airUsed = false;
  int grabTimer = 0, grabBy = -1;
  int landLag = 0, jumpDir = 0;
  int wins = 0;

  Fighter(this.health);

  Fighter copy() {
    final f = Fighter(health);
    f.x = x; f.y = y; f.vx = vx; f.vy = vy; f.face = face; f.meter = meter;
    f.state = state; f.sf = sf; f.moveId = moveId; f.stun = stun; f.stop = stop;
    f.hitMask = hitMask; f.contact = contact; f.armorLeft = armorLeft; f.serial = serial;
    f.prev = prev; f.inp = inp;
    f.bufLight = bufLight; f.bufHeavy = bufHeavy; f.bufSpecial = bufSpecial; f.bufRoll = bufRoll; f.bufSuper = bufSuper;
    f.tapFwd = tapFwd; f.tapBack = tapBack; f.dashFwdBuf = dashFwdBuf; f.dashBackBuf = dashBackBuf;
    f.guardAge = guardAge; f.crouchBlock = crouchBlock;
    f.comboHits = comboHits; f.comboAttacks = comboAttacks; f.comboDamage = comboDamage; f.lastSerial = lastSerial;
    f.juggleLeft = juggleLeft; f.juggleLocked = juggleLocked; f.kdWall = kdWall; f.kdGround = kdGround; f.bounced = bounced;
    f.slow = slow; f.quickRise = quickRise; f.airUsed = airUsed;
    f.grabTimer = grabTimer; f.grabBy = grabBy; f.landLag = landLag; f.jumpDir = jumpDir; f.wins = wins;
    return f;
  }

  bool get grounded => y == 0 && vy == 0;
  bool get inCombo => state == St.hitstun || state == St.airstun || state == St.down;
}

class Projectile {
  final int owner, proj, serial;
  int x, y, vx, vy, life, hits;
  Projectile(this.owner, this.proj, this.serial, this.x, this.y, this.vx, this.vy, this.life, this.hits);
  Projectile copy() => Projectile(owner, proj, serial, x, y, vx, vy, life, hits);
}

class Trap {
  final int owner, trap;
  int x, life, arm;
  Trap(this.owner, this.trap, this.x, this.life, this.arm);
  Trap copy() => Trap(owner, trap, x, life, arm);
}

class _Hasher {
  int h = 2166136261;
  void i(int v) {
    var u = v % 4294967296;
    for (var k = 0; k < 4; k++) {
      final b = u % 256;
      u = u ~/ 256;
      final lo = h % 256;
      h = h - lo + (lo ^ b);
      h = ((h % 256) * 16777216 + h * 403) % 4294967296;
    }
  }

  void b(bool v) => i(v ? 1 : 0);
}

class FightState {
  final List<CharacterDef> chars;
  int frame = 0;
  int rng;
  int phase = Phase.intro;
  int phaseTimer = introFrames;
  int timer = roundFrames;
  int round = 1;
  int superFlash = 0;
  int superBy = -1;
  int serial = 0;
  int roundWinner = -1; // last finished round: 0, 1, 2 = draw, -1 none
  int matchWinner = -1; // set in Phase.over: 0, 1, 2 = draw
  bool timeOver = false;
  List<Fighter> p;
  List<Projectile> projectiles;
  List<Trap> traps;
  List<FightEvent> events;

  FightState._(this.chars, this.rng, this.p, this.projectiles, this.traps, this.events);

  factory FightState.initial({required int seed, required CharacterDef p1, required CharacterDef p2}) {
    final s = FightState._([p1, p2], seed % 2147483647 + 1, [Fighter(p1.maxHealth), Fighter(p2.maxHealth)], [], [], []);
    s.placeFighters();
    return s;
  }

  void placeFighters() {
    p[0].x = stageCenter - startOffset;
    p[1].x = stageCenter + startOffset;
    p[0].face = 1;
    p[1].face = -1;
  }

  /// Seeded integer PRNG (LCG, products stay below 2^53). Returns 0..65535.
  int nextRand() {
    rng = (rng * 1664525 + 1013904223) % 4294967296;
    return rng ~/ 65536;
  }

  void addEvent(int kind, int x, int y, int player, [int value = 0]) {
    events.add(FightEvent(frame, kind, x, y, player, value));
    if (events.length > eventRingSize) events.removeAt(0);
  }

  FightState copy() {
    final s = FightState._(chars, rng, [p[0].copy(), p[1].copy()], [for (final e in projectiles) e.copy()],
        [for (final t in traps) t.copy()], List<FightEvent>.of(events));
    s.frame = frame; s.phase = phase; s.phaseTimer = phaseTimer; s.timer = timer; s.round = round;
    s.superFlash = superFlash; s.superBy = superBy; s.serial = serial; s.roundWinner = roundWinner;
    s.matchWinner = matchWinner; s.timeOver = timeOver;
    return s;
  }

  int checksum() {
    final h = _Hasher();
    h.i(frame); h.i(rng); h.i(phase); h.i(phaseTimer); h.i(timer); h.i(round);
    h.i(superFlash); h.i(superBy); h.i(serial); h.i(roundWinner); h.i(matchWinner); h.b(timeOver);
    for (final f in p) {
      h.i(f.x); h.i(f.y); h.i(f.vx); h.i(f.vy); h.i(f.face); h.i(f.health); h.i(f.meter);
      h.i(f.state); h.i(f.sf); h.i(f.moveId); h.i(f.stun); h.i(f.stop); h.i(f.hitMask); h.i(f.contact);
      h.i(f.armorLeft); h.i(f.serial); h.i(f.prev); h.i(f.inp);
      h.i(f.bufLight); h.i(f.bufHeavy); h.i(f.bufSpecial); h.i(f.bufRoll); h.i(f.bufSuper);
      h.i(f.tapFwd); h.i(f.tapBack); h.i(f.dashFwdBuf); h.i(f.dashBackBuf);
      h.i(f.guardAge); h.b(f.crouchBlock);
      h.i(f.comboHits); h.i(f.comboAttacks); h.i(f.comboDamage); h.i(f.lastSerial); h.i(f.juggleLeft);
      h.b(f.juggleLocked); h.b(f.kdWall); h.b(f.kdGround); h.b(f.bounced);
      h.i(f.slow); h.b(f.quickRise); h.b(f.airUsed); h.i(f.grabTimer); h.i(f.grabBy);
      h.i(f.landLag); h.i(f.jumpDir); h.i(f.wins);
    }
    h.i(projectiles.length);
    for (final e in projectiles) {
      h.i(e.owner); h.i(e.proj); h.i(e.serial); h.i(e.x); h.i(e.y); h.i(e.vx); h.i(e.vy); h.i(e.life); h.i(e.hits);
    }
    h.i(traps.length);
    for (final t in traps) {
      h.i(t.owner); h.i(t.trap); h.i(t.x); h.i(t.life); h.i(t.arm);
    }
    h.i(events.length);
    for (final e in events) {
      h.i(e.frame); h.i(e.kind); h.i(e.x); h.i(e.y); h.i(e.player); h.i(e.value);
    }
    return h.h;
  }
}
