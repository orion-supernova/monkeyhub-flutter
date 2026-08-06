import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// How much decorative motion the app renders.
///
/// Three choices rather than a switch, because the honest answer has three
/// states: follow the OS, always full, always calm. A two-way switch cannot
/// express "I have not chosen", so the first time the system accessibility flag
/// flipped it would silently overwrite the user's decision — see
/// [SettingsStore.motionLevel].
///
/// Each card previews itself. The full card's dots drift; the calm card's sit
/// still. That is the entire difference, and showing it is far more useful than
/// any sentence describing it — particularly in the eleven locales where the
/// sentence is a translation.
class MotionScreen extends StatefulWidget {
  const MotionScreen({super.key});

  @override
  State<MotionScreen> createState() => _MotionScreenState();
}

class _MotionScreenState extends State<MotionScreen> {
  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _set(MotionLevel? v) => SettingsStore.instance.setMotionLevel(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.motionLevel;
    // What "match system" resolves to right now, so the row can say so rather
    // than leaving the user to guess what their phone is set to.
    final systemIsCalm = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.inkSoft,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.motionScreenTitle, style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 18, height: 1, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.motionScreenSubtitle,
                          style: theme.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _MotionCard(
                    label: l10n.motionScreenSystemLabel,
                    sub: systemIsCalm
                        ? l10n.motionScreenSystemSubtitleCalm
                        : l10n.motionScreenSystemSubtitleFull,
                    active: current == null,
                    animated: !systemIsCalm,
                    onTap: () => _set(null),
                  ),
                  const SizedBox(height: 14),
                  _MotionCard(
                    label: l10n.motionScreenFullLabel,
                    sub: l10n.motionScreenFullSubtitle,
                    active: current == MotionLevel.full,
                    animated: true,
                    onTap: () => _set(MotionLevel.full),
                  ),
                  const SizedBox(height: 14),
                  _MotionCard(
                    label: l10n.motionScreenCalmLabel,
                    sub: l10n.motionScreenCalmSubtitle,
                    active: current == MotionLevel.calm,
                    animated: false,
                    onTap: () => _set(MotionLevel.calm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionCard extends StatelessWidget {
  const _MotionCard({
    required this.label,
    required this.sub,
    required this.active,
    required this.animated,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool active;

  /// Whether this card's own preview drifts. Independent of [active] on
  /// purpose — the point is to see what a choice does *before* choosing it.
  final bool animated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      selected: active,
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(
              color: active ? theme.accent : theme.divider,
              width: active ? 1.6 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: theme.label)),
                  if (active)
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.pinnedBannerActiveBadge,
                          style: theme.monoTiny.copyWith(color: theme.accent),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(sub, style: theme.monoTiny),
              const SizedBox(height: 14),
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: theme.surfaceSunken,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                  border: Border.all(color: theme.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: _DriftPreview(animated: animated),
              ),
            ],
          ),
        ),
      ),
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
