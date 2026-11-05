// Fixed-point units and global tuning constants for the fight core.
//
// 60 Hz fixed step. Positions are integers: 100 units = 1 px of a 1200 px wide
// stage. Ground is y = 0, y grows upward. Velocities are units per frame.
// Everything stays far inside the signed 32-bit range (the sim also runs on
// Dart web, where ints are JS numbers).

const int fps = 60;
const int unitsPerPx = 100;
const int stageWidthPx = 1200;
const int stageWidth = stageWidthPx * unitsPerPx; // 120000
const int stageCenter = stageWidth ~/ 2;

/// Fighter origin (feet centre) may never go closer than this to a stage edge.
const int wallMargin = 4000;
const int stageMinX = wallMargin;
const int stageMaxX = stageWidth - wallMargin;

/// Round start: fighters this far from the centre.
const int startOffset = 18000;

const int meterBar = 1000;
const int meterBars = 3;
const int meterMax = meterBar * meterBars;
const int superCost = 2 * meterBar;
const int exCost = meterBar;

const int roundFrames = 60 * fps;
const int introFrames = 90;
const int koFrames = 150;
const int superFlashFrames = 40;
const int roundsToWin = 2;

const int inputBufferFrames = 6;
const int dashTapWindow = 10;
const int dashBufferFrames = 4;
const int techWindow = 7;
const int perfectBlockWindow = 4;
const int throwBufferMin = inputBufferFrames - 2; // both buttons within ~3 frames
const int throwRange = 9000;
const int jugglePoints = 6;
const int pushBoxHeight = 14000;
const int eventRingSize = 16;

/// Combo damage scaling in percent, by number of distinct attacks already landed.
const List<int> comboScaling = [100, 100, 80, 70, 60, 50, 40, 30];
const int comboScaleFloor = 30;

int scalePercent(int attacksLanded, int floor) {
  final i = attacksLanded < comboScaling.length ? attacksLanded : comboScaling.length - 1;
  final v = comboScaling[i];
  return v < floor ? floor : v;
}
