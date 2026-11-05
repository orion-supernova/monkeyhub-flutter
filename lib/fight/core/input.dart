// Input bitmask and helpers. Inputs are plain ints so they fit a wire packet.

class Inp {
  static const int left = 1;
  static const int right = 2;
  static const int up = 4;
  static const int down = 8;
  static const int light = 16;
  static const int heavy = 32;
  static const int special = 64;
  static const int roll = 128;
  static const int superBtn = 256;
  static const int all = 511;
  static const int dirs = left | right | up | down;
  static const int buttons = light | heavy | special | roll | superBtn;
}

/// Opposing directions cancel (SOCD neutral); unknown bits are dropped.
int sanitizeInput(int i) {
  i &= Inp.all;
  if ((i & Inp.left) != 0 && (i & Inp.right) != 0) i &= ~(Inp.left | Inp.right);
  if ((i & Inp.up) != 0 && (i & Inp.down) != 0) i &= ~(Inp.up | Inp.down);
  return i;
}

/// Bits newly pressed this frame.
int pressedEdges(int cur, int prev) => cur & ~prev;

bool isPressed(int cur, int prev, int bit) => (cur & bit) != 0 && (prev & bit) == 0;

/// Bit for "toward the opponent" given facing (1 = facing right).
int forwardBit(int face) => face == 1 ? Inp.right : Inp.left;
int backBit(int face) => face == 1 ? Inp.left : Inp.right;

bool holdsForward(int inp, int face) => (inp & forwardBit(face)) != 0;
bool holdsBack(int inp, int face) => (inp & backBit(face)) != 0;
