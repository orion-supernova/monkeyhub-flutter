import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// Gold, silver and bronze, top to bottom of each disc.
const _kMedals = [
  [Color(0xFFFFD86B), Color(0xFFF0A81E)],
  [Color(0xFFE4E7EC), Color(0xFFA9AFB8)],
  [Color(0xFFF2B48A), Color(0xFFC77A44)],
];

/// A place on a scoreboard: gold, silver or bronze for the podium, a quiet
/// numbered disc for everyone after. Every board draws its ranks with this,
/// so first place looks the same on the leaderboard as on a game's results.
class MedalDisc extends StatelessWidget {
  const MedalDisc({
    super.key,
    required this.rank,
    required this.medal,
    this.size = 28,
    this.border,
  });

  final int rank;

  /// Whether this place earns a medal at all. A gave-up row at the top of an
  /// otherwise empty board is first, but did not win anything.
  final bool medal;

  final double size;

  /// A ring in this colour around the disc: on the podium it sits over an
  /// avatar, and the ring in the card's own fill cuts it out like a coin.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final colors = medal && rank >= 1 && rank <= 3 ? _kMedals[rank - 1] : null;
    final ring = border;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: colors == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
        color: colors == null ? quietFill(theme) : null,
        border: ring == null ? null : Border.all(color: ring, width: 2),
      ),
      child: Text(
        '$rank',
        style: groupedMetaStyle(theme).copyWith(
          fontSize: size < 26 ? 12 : null,
          fontWeight: FontWeight.w700,
          height: 1,
          color: colors == null ? theme.inkMuted : const Color(0xFF3A2A00),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
