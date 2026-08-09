import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/location_share.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';

/// What the user picked in the location sheet.
///
/// A duration or the absence of one, rather than a mode plus an optional
/// duration, so "live with no duration" is not a value that can be constructed
/// — which is the shape of the bug this feature must not have.
class LocationShareChoice {
  const LocationShareChoice.now() : duration = null;
  const LocationShareChoice.live(LiveShareDuration this.duration);

  /// Null means one fix, sent once.
  final LiveShareDuration? duration;

  bool get isLive => duration != null;
}

/// Asks whether to send one position or share live, and for how long.
///
/// Deliberately a single sheet rather than a menu that opens a second one. The
/// difference between the two modes is one line of text each, and burying the
/// durations a tap deeper made the safe option (a fixed 15 minutes) the
/// expensive one to reach.
///
/// No "until I turn it off" row. Every duration here ends by itself; the
/// server enforces it and cannot be asked for more. That is the feature.
///
/// [allowLive] is false in a Chamber of Secrets room, where every message
/// carries the room's own self-destruct deadline. Two clocks on one row is a
/// promise the app cannot keep — a 60-second room lifetime would delete an
/// eight-hour share after a minute — so the server refuses live shares there
/// and downgrades them to a static pin. Hiding the rows is what stops the user
/// picking a duration they will not get; the server's refusal is the backstop,
/// not the mechanism.
Future<LocationShareChoice?> showLocationShareSheet(
  BuildContext context, {
  bool allowLive = true,
}) {
  return showAdaptiveSheet<LocationShareChoice>(
    context,
    builder: (_) => _LocationSheet(allowLive: allowLive),
  );
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.allowLive});

  final bool allowLive;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    String durationLabel(LiveShareDuration d) => switch (d) {
          LiveShareDuration.fifteenMinutes => l10n.locationShareFor15Minutes,
          LiveShareDuration.oneHour => l10n.locationShareFor1Hour,
          LiveShareDuration.eightHours => l10n.locationShareFor8Hours,
        };

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + bottomInset),
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: theme.ink),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (context.isCompact) ...[
                Center(
                  child: Container(
                    width: 36,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: theme.inkMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _Row(
                icon: CupertinoIcons.location_fill,
                title: l10n.locationSheetSendCurrent,
                subtitle: l10n.locationSheetSendCurrentDetail,
                onTap: () =>
                    Navigator.of(context).pop(const LocationShareChoice.now()),
              ),
              if (allowLive) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    l10n.locationSheetLiveHeading,
                    style: theme.monoTiny.copyWith(
                      color: theme.inkMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                for (final d in LiveShareDuration.values) ...[
                  _Row(
                    icon: CupertinoIcons.dot_radiowaves_left_right,
                    title: durationLabel(d),
                    // Restated on every row rather than once above them,
                    // because this is the promise the feature makes and each
                    // row is a separate act of making it.
                    subtitle: l10n.locationSheetLiveDetail,
                    onTap: () =>
                        Navigator.of(context).pop(LocationShareChoice.live(d)),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    void fire() {
      HapticFeedback.selectionClick();
      widget.onTap();
    }

    return FocusableTap(
      onTap: fire,
      radius: theme.radiusMd,
      semanticLabel: widget.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: fire,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(color: theme.divider, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 19, color: theme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: theme.body.copyWith(color: theme.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.monoTiny.copyWith(color: theme.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
