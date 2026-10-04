import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'glass_buttons.dart';
import 'liquid_glass.dart';
import 'media_filmstrip.dart' show MediaScrim;

/// The top bar every full-screen media viewer wears — the photo viewer, the
/// video viewer, the gallery pager and the view-once viewer — so all four look
/// and behave as one: the close where Photos keeps it (top left), a centred
/// title or [center] widget, trailing [actions], and a scrim so white glass
/// and text stay legible over a bright sky.
///
/// Positioning and fading stay with the caller, which knows its own dismiss
/// gesture; this is only the bar.
class ViewerTopBar extends StatelessWidget {
  const ViewerTopBar({
    super.key,
    required this.onClose,
    this.closeLabel,
    this.title,
    this.subtitle,
    this.center,
    this.actions = const [],
  });

  final VoidCallback onClose;

  /// Screen-reader label for the close. Defaults to the platform's "Close".
  final String? closeLabel;
  final String? title;
  final String? subtitle;

  /// Replaces the title column — e.g. the view-once badge.
  final Widget? center;
  final List<Widget> actions;

  static const double _button = 40;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    final Widget? middle = center ??
        (title == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyEmph.copyWith(
                      color: MediaGlass.ink,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (subtitle != null)
                    // The body face at 13 in near-white — the caption slot
                    // was tracked mono at low contrast on a character
                    // theme, nearly gone over a bright sky.
                    Text(
                      subtitle!,
                      maxLines: 1,
                      style: theme.body.copyWith(
                        fontSize: 13,
                        height: 1.25,
                        color: MediaGlass.ink.withValues(alpha: 0.85),
                        decoration: TextDecoration.none,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ));
    // The title is centred on the SCREEN, like a sheet bar's: inset by the
    // wider side's chrome on both sides, so two trailing actions no longer
    // shove it left of centre.
    final side = _button * (actions.isEmpty ? 1 : actions.length) + 8;

    return Stack(
      children: [
        MediaScrim(height: pad.top + 62, fromTop: true),
        Padding(
          padding: EdgeInsets.fromLTRB(8, pad.top + 6, 8, 10),
          child: SizedBox(
            height: _button,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (middle != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: middle,
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  // The shared media ×, 17pt glyph like every close.
                  child: GlassCloseButton(
                    tone: GlassTone.media,
                    semanticLabel: closeLabel,
                    onTap: onClose,
                  ),
                ),
                if (actions.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
