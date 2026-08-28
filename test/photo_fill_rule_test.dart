import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/photo_backdrop.dart';

/// What this pins: which pictures a fullscreen viewer is allowed to crop.
///
/// The complaint this rule exists to answer was "the image is not covering
/// fullscreen" — a phone-camera portrait shot letterboxed on a tall phone
/// leaves nearly 40% of the display as dead bands, and that is exactly where
/// every one of these screens puts its close button and its author line. So a
/// portrait shot fills.
///
/// The other half matters just as much and is easier to lose in a refactor: a
/// LANDSCAPE photograph on the same phone survives a fill at about a third of
/// itself, and a square one at under a half. Filling those does not produce a
/// fullscreen photo, it produces a slice — they stay whole and get the blurred
/// backdrop behind them instead. If someone ever "simplifies" this to always
/// cover, this test is what says no.
void main() {
  // A 19.5:9 phone in portrait — an iPhone 16e, which is what the report came
  // from.
  const phone = Size(390, 844);

  test('a phone-camera portrait shot fills the screen', () {
    expect(photoFillsScreen(3 / 4, phone), isTrue);
    expect(photoFillsScreen(9 / 16, phone), isTrue);
  });

  test('a landscape shot is shown whole', () {
    expect(photoFillsScreen(4 / 3, phone), isFalse);
    expect(photoFillsScreen(16 / 9, phone), isFalse);
  });

  test('a square shot is shown whole — a fill would show under half of it', () {
    expect(photoFillsScreen(1, phone), isFalse);
  });

  test('a wide panorama is never filled', () {
    expect(photoFillsScreen(3, phone), isFalse);
  });

  test('the rule is symmetric — a TALL picture on a tall phone fills', () {
    // 1:3 keeps about 72% of itself on a 19.5:9 screen, which is a smaller
    // crop than the portrait shot two tests up. The rule measures the mismatch
    // between the two shapes, not which way round it goes, and a long
    // screenshot on a long screen is genuinely close to the right shape.
    expect(photoFillsScreen(1 / 3, phone), isTrue);
  });

  test('a picture the same shape as the screen fills trivially', () {
    expect(photoFillsScreen(phone.width / phone.height, phone), isTrue);
  });

  test('an unknown or nonsense ratio is shown whole', () {
    // Never wrong, which is the right default while the ratio is still being
    // learned — one frame, usually zero.
    expect(photoFillsScreen(null, phone), isFalse);
    expect(photoFillsScreen(0, phone), isFalse);
    expect(photoFillsScreen(double.nan, phone), isFalse);
    expect(photoFillsScreen(double.infinity, phone), isFalse);
  });

  test('a square viewport fills far more than a tall one does', () {
    // A desktop window or a tablet is much closer to square, so the same
    // landscape picture that is letterboxed on a phone fills there.
    const wide = Size(1200, 900);
    expect(photoFillsScreen(4 / 3, wide), isTrue);
    expect(photoFillsScreen(4 / 3, phone), isFalse);
  });

  test('a degenerate viewport is shown whole rather than dividing by zero', () {
    expect(photoFillsScreen(3 / 4, Size.zero), isFalse);
  });
}
