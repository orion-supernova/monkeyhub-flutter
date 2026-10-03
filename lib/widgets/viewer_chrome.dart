import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
                    Text(
                      subtitle!,
                      style: theme.caption.copyWith(
                        fontSize: 13,
                        color: MediaGlass.inkDim,
                        decoration: TextDecoration.none,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ));

    return Stack(
      children: [
        MediaScrim(height: pad.top + 62, fromTop: true),
        Padding(
          padding: EdgeInsets.fromLTRB(8, pad.top + 6, 8, 10),
          child: Row(
            children: [
              GlassIconButton(
                tone: GlassTone.media,
                size: _button,
                icon: CupertinoIcons.xmark,
                semanticLabel: closeLabel ??
                    MaterialLocalizations.of(context).closeButtonTooltip,
                onTap: onClose,
              ),
              Expanded(child: Center(child: middle)),
              // Balances the close so the title sits on the screen's centre.
              if (actions.isEmpty)
                const SizedBox(width: _button)
              else
                Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
        ),
      ],
    );
  }
}
