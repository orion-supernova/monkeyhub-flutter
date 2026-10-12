/// Seat colours for the in-chat turn games: the board, the game bubble, the
/// player plates and the lobby all read from here, so "you are coral" means
/// the same coral everywhere a match shows up.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../theme/app_theme.dart';

/// Two to four seat colours as FIXED hues whose lightness follows the theme.
///
/// Fixed hues for the same reason [GamePalette] uses them for Queens: a seat
/// colour is an identity, and deriving it from the theme accent would make
/// both players a shade of Rose on the Rose theme. What does follow the theme
/// is the lightness, so the same coral sits a little brighter on a dark
/// background (where a mid coral goes muddy) and a little deeper on a light
/// one (where it washes out against white).
///
/// Seat 0 coral, seat 1 azure, and for Dots' third and fourth players amber
/// and green: four hues spread far enough apart to tell apart with the
/// common colour-vision deficiencies, helped by every board also carrying a
/// shape cue (X and O, a centre dot, a seat initial).
///
/// The party games seat up to eight, so four more follow: violet, teal, pink
/// and olive. Those are told apart by the face in the ring as much as by the
/// ring itself, which is why they could not be the first four.
///
/// [gameId] remaps the two games whose colours are a convention of their own:
///  * `connectfour`: seat 1 is amber, the red-and-yellow of the real toy.
///  * `reversi`: the discs are black and white, and a plate that showed
///    "you are coral" next to a board of black discs would be lying.
/// Pass the game's id wherever a seat colour is shown for that game, so the
/// bubble and the board agree.
@immutable
class SeatPalette {
  SeatPalette(AppTheme theme, {this.gameId})
    : dark = theme.background.computeLuminance() < 0.4 {
    for (var seat = 0; seat < seats; seat++) {
      final base = _base(seat);
      _fills[seat] = base;
      _rims[seat] = _rim(seat, base);
      _inks[seat] = _inkOn(base);
    }
  }

  /// Whether the theme is dark: background luminance under 0.4, the same
  /// threshold [GamePalette] and the preview kit use.
  final bool dark;

  /// The game the colours are for, or null for the plain four-hue set.
  final String? gameId;

  /// How many distinct seat colours there are before they repeat.
  static const seats = 8;

  final List<Color> _fills = List.filled(seats, const Color(0x00000000));
  final List<Color> _rims = List.filled(seats, const Color(0x00000000));
  final List<Color> _inks = List.filled(seats, const Color(0x00000000));

  /// Reversi's two discs. Off-black and off-white rather than pure, the iOS
  /// system greys, so a white disc still has an edge on a white card.
  static const reversiBlack = Color(0xFF1C1C1E);
  static const reversiWhite = Color(0xFFF2F2F7);

  /// The hues, in seat order: coral, azure, amber, green, then violet, teal,
  /// pink and olive for the party games' bigger tables.
  static const _hues = <double>[4, 214, 42, 150, 268, 182, 326, 72];
  static const _saturation = <double>[0.74, 0.80, 0.85, 0.55, 0.62, 0.60, 0.68, 0.48];
  static const _lightDark = <double>[0.60, 0.64, 0.58, 0.55, 0.68, 0.52, 0.66, 0.52];
  static const _lightLight = <double>[0.52, 0.50, 0.52, 0.42, 0.56, 0.38, 0.52, 0.38];

  /// Which of the four hues seat [seat] wears in this game.
  int _hueIndex(int seat) {
    if (gameId == 'connectfour' && seat == 1) return 2;
    return seat % seats;
  }

  Color _base(int seat) {
    if (gameId == 'reversi' && seat < 2) {
      return seat == 0 ? reversiBlack : reversiWhite;
    }
    final i = _hueIndex(seat);
    return HSLColor.fromAHSL(
      1,
      _hues[i],
      _saturation[i],
      dark ? _lightDark[i] : _lightLight[i],
    ).toColor();
  }

  /// A deeper edge in the same hue: what a disc's lip or a piece's groove is
  /// drawn in. Darker in both themes, because an edge that lightens reads as
  /// a highlight, not as the side of a solid thing.
  Color _rim(int seat, Color base) {
    if (gameId == 'reversi' && seat < 2) {
      return seat == 0 ? const Color(0xFF000000) : const Color(0xFFC7C7CC);
    }
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }

  /// White or near-black, whichever reads better on [fill]: amber and a light
  /// green want dark glyphs, coral and azure want white ones.
  static Color _inkOn(Color fill) {
    const light = Color(0xFFFFFFFF);
    const darkInk = Color(0xFF1C1C1E);
    final l = fill.computeLuminance();
    final onLight = (1.05) / (l + 0.05);
    final onDark = (l + 0.05) / (darkInk.computeLuminance() + 0.05);
    return onLight >= onDark ? light : darkInk;
  }

  /// The seat's solid colour: a disc, a mark, a drawn line.
  Color fill(int seat) => _fills[seat % seats];

  /// A deeper edge of [fill], for rims and grooves.
  Color rim(int seat) => _rims[seat % seats];

  /// The colour of a glyph drawn ON [fill] (a crown, a centre dot).
  Color ink(int seat) => _inks[seat % seats];

  /// [fill] at 0.28: a move under the finger that has not been made yet.
  Color ghost(int seat) => fill(seat).withValues(alpha: 0.28);

  /// [fill] faint enough to sit behind text: a claimed box, a plate's tint.
  Color wash(int seat) => fill(seat).withValues(alpha: dark ? 0.22 : 0.16);

  @override
  bool operator ==(Object other) =>
      other is SeatPalette && other.dark == dark && other.gameId == gameId;

  @override
  int get hashCode => Object.hash(dark, gameId);
}
