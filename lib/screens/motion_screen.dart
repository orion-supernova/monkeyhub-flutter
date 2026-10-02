import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';

/// How much decorative motion the app renders.
///
/// Three states rather than a switch, because the honest answer has three:
/// follow the OS, always full, always calm. They are laid out the way iOS lays
/// out Appearance — a "Match device" switch, and under it the two looks as
/// pictures — so "I have not chosen" stays expressible and the first flip of
/// the system flag never overwrites a decision (see
/// [SettingsStore.motionLevel]).
///
/// Each picture previews itself: the full one's dots drift, the calm one's sit
/// still. That is the entire difference, and showing it beats any sentence —
/// particularly in the eleven locales where the sentence is a translation.
class MotionScreen extends StatelessWidget {
  const MotionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final level = SettingsStore.instance.motionLevel;
        final deviceCalm = MediaQuery.disableAnimationsOf(context);
        // What is on screen right now, chosen or inherited.
        final effective =
            level ?? (deviceCalm ? MotionLevel.calm : MotionLevel.full);
        void set(MotionLevel? v) {
          pickFeedback();
          SettingsStore.instance.setMotionLevel(v);
        }

        return SettingsPage(
          title: l10n.settingsHubMotion,
          children: [
            GroupedSection(
              children: [
                GroupedRow.toggle(
                  icon: CupertinoIcons.device_phone_portrait,
                  tone: TileTone.gray,
                  title: l10n.motionMatchDevice,
                  subtitle: deviceCalm
                      ? l10n.motionMatchDeviceCalmSub
                      : l10n.motionMatchDeviceFullSub,
                  value: level == null,
                  // Turning it off pins what is showing now, so the switch
                  // never changes the look by itself.
                  onChanged: (follow) => set(follow ? null : effective),
                ),
              ],
            ),
            PreviewChoiceTiles<MotionLevel>(
              selected: effective,
              aspectRatio: 1.1,
              onChanged: set,
              choices: [
                PreviewChoice(
                  value: MotionLevel.full,
                  label: l10n.settingsScreenValueMotionFull,
                  preview: const _DriftPreview(animated: true),
                ),
                PreviewChoice(
                  value: MotionLevel.calm,
                  label: l10n.settingsScreenValueMotionCalm,
                  preview: const _DriftPreview(animated: false),
                ),
              ],
            ),
            GroupedFooter(
              effective == MotionLevel.full
                  ? l10n.motionFullSub
                  : l10n.motionCalmSub,
            ),
          ],
        );
      },
    );
  }
}

/// Three dots drifting at different rates — the parallax field in miniature.
///
/// When [animated] is false no ticker is created at all. That is the point
/// being demonstrated: calm motion is not the same animation played slower, it
/// is the animation not running.
class _DriftPreview extends StatefulWidget {
  const _DriftPreview({required this.animated});

  final bool animated;

  /// Widget tests cannot `pumpAndSettle` against a repeating controller — it
  /// never settles and the whole suite (which runs in ~10s) hangs instead of
  /// failing. Any test pumping this screen sets this false.
  @visibleForTesting
  static bool debugAnimate = true;

  @override
  State<_DriftPreview> createState() => _DriftPreviewState();
}

class _DriftPreviewState extends State<_DriftPreview>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _DriftPreview old) {
    super.didUpdateWidget(old);
    if (old.animated != widget.animated) _sync();
  }

  void _sync() {
    final wanted = widget.animated && _DriftPreview.debugAnimate;
    if (wanted && _ctrl == null) {
      // A raw literal rather than a theme token: this is self-contained
      // internal mechanics with no relationship to the app's interaction
      // timing, which is the sanctioned exception to the token rule.
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3600),
      )..repeat();
    } else if (!wanted && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ctrl = _ctrl;
    if (ctrl == null) {
      return _DriftPaint(t: 0, accent: theme.accent, soft: theme.accentSoft);
    }
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) =>
          _DriftPaint(t: ctrl.value, accent: theme.accent, soft: theme.accentSoft),
    );
  }
}

class _DriftPaint extends StatelessWidget {
  const _DriftPaint({
    required this.t,
    required this.accent,
    required this.soft,
  });

  final double t;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _DriftPainter(t: t, accent: accent, soft: soft),
      size: Size.infinite,
    ),
  );
}

class _DriftPainter extends CustomPainter {
  _DriftPainter({required this.t, required this.accent, required this.soft});

  final double t;
  final Color accent;
  final Color soft;

  static const _rates = [0.18, 0.34, 0.62];
  static const _ys = [0.30, 0.55, 0.75];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      // Wraps at 1.0 so the loop has no visible seam.
      final x = ((t * _rates[i] * 4 + i * 0.31) % 1.0) * (size.width + 60) - 30;
      canvas.drawCircle(
        Offset(x, size.height * _ys[i]),
        14.0 + i * 5,
        Paint()
          ..color = (i.isEven ? accent : soft).withValues(alpha: 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) =>
      old.t != t || old.accent != accent || old.soft != soft;
}
