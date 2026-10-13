import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

/// What sits where the composer would, in a room whose posting policy lets
/// members post nothing (`RoomPostingPolicy.canPost == false`): the
/// `MonkeyHub Logs` feed today.
///
/// Quiet on purpose. It is not an error and not a call to action, just the
/// answer to "why is there no text field?", so it is one line of muted text
/// with a lock, in the composer's slot and roughly its height, so the
/// transcript above sits where it would in any other room.
///
/// [glass] matches the liquid composer, which floats a glass bar over the
/// transcript; the classic style draws it flat. [bottomInset] is the home
/// indicator's room in the liquid style, where the composer adds it itself.
class ReadOnlyComposerFooter extends StatelessWidget {
  const ReadOnlyComposerFooter({
    super.key,
    this.glass = false,
    this.bottomInset = 0,
  });

  final bool glass;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final text = AppLocalizations.of(context).roomReadOnlyFooter;
    final line = Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.lock_fill, size: 14, color: theme.inkMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          ),
        ],
      ),
    );
    final body = glass
        ? GlassSurface(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(child: line),
          )
        : Center(child: line);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: glass
            ? EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: body,
      ),
    );
  }
}
