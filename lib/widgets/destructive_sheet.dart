import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'remote_image.dart';

/// Building blocks shared by the sheets that ask "are you sure?" before
/// destroying something — blocking a user, and taking a contact away from a
/// child. Both need the same tile and the same shared-room row, and both are
/// destructive enough that the two should never drift apart visually.

/// The drag handle every bottom sheet in this family opens with.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    // Meaningless once dismiss-by-drag isn't a thing — the desktop popover
    // closes via barrier tap / Esc, not a drag gesture.
    if (!context.isCompact) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.inkMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A plain "are you sure?" over the same furniture as its richer siblings.
///
/// Use when there's nothing to enumerate — no shared rooms, no message counts,
/// just a decision that has to be stated plainly and confirmed. When there IS
/// a blast radius worth listing, prefer a purpose-built sheet like
/// `showRemoveContactSheet` that actually names what dies.
///
/// Returns true only if the destructive option was tapped.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String headline,
  required String body,
  required String confirmLabel,
}) async {
  final res = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _ConfirmSheet(
      headline: headline,
      body: body,
      confirmLabel: confirmLabel,
    ),
  );
  return res ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.headline,
    required this.body,
    required this.confirmLabel,
  });
  final String headline;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(headline, style: theme.label.copyWith(color: theme.danger)),
          const SizedBox(height: 10),
          Text(body, style: theme.bodySoft),
          const SizedBox(height: 20),
          ChoiceTile(
            color: theme.danger,
            icon: Icons.warning_amber_rounded,
            title: confirmLabel,
            sub: AppLocalizations.of(context).destructiveSheetCannotBeUndone,
            filled: true,
            onTap: () {
              // "Cannot be undone" should weigh something in the hand too.
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: 10),
          // Autofocused so Enter on a freshly-opened destructive sheet cancels
          // rather than deletes — matching the macOS/Windows convention. Tab
          // once to reach the destructive option.
          FocusableTap(
            onTap: () => Navigator.of(context).pop(false),
            autofocus: true,
            semanticLabel:
                AppLocalizations.of(context).destructiveSheetCancelSemanticLabel,
            radius: theme.radiusMd,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(
                    AppLocalizations.of(context).destructiveSheetCancelButtonLabel,
                    style: theme.label.copyWith(color: theme.inkMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable outcome in a destructive sheet: an icon, a title, and a line
/// spelling out exactly what it does.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.filled = false,
    this.autofocus = false,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  /// Use for the most destructive option, so it reads as the heavier choice.
  final bool filled;

  /// Whether this tile takes keyboard focus when the sheet opens. Destructive
  /// sheets autofocus their CANCEL instead — see the sheet builders.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      autofocus: autofocus,
      semanticLabel: title,
      radius: theme.radiusMd,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.12) : theme.surface,
          border: Border.all(
              color: color.withValues(alpha: filled ? 0.6 : 0.35), width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled
                    ? color.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.label.copyWith(color: color)),
                  const SizedBox(height: 3),
                  Text(sub, style: theme.monoTiny),
                ],
              ),
            ),
            Icon(Icons.arrow_outward, size: 14, color: theme.inkMuted),
          ],
        ),
      ),
      ),
    );
  }
}

/// A room in the "you also share these" list.
class SharedRoomRow extends StatelessWidget {
  const SharedRoomRow({
    super.key,
    required this.room,
    required this.api,
    required this.theme,
  });
  final ChatRoom room;
  final ChatApi api;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (room.avatarStorageId != null)
            ClipOval(
              child: RemoteImage(
                storageId: room.avatarStorageId!,
                api: api,
                width: 22,
                height: 22,
                borderRadius: BorderRadius.circular(11),
              ),
            )
          else
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: theme.divider),
              ),
              child: Icon(Icons.tag, size: 12, color: theme.inkSoft),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              room.name,
              style: theme.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${room.memberCount}', style: theme.monoTiny),
        ],
      ),
    );
  }
}

/// The collapsible "they also share N rooms" panel. Same in both sheets: the
/// rooms are not affected, and saying so is the whole point of showing them.
class SharedRoomsPanel extends StatefulWidget {
  const SharedRoomsPanel({
    super.key,
    required this.rooms,
    required this.api,
    required this.headline,
    required this.note,
  });

  final List<ChatRoom> rooms;
  final ChatApi api;
  final String headline;
  final String note;

  @override
  State<SharedRoomsPanel> createState() => _SharedRoomsPanelState();
}

class _SharedRoomsPanelState extends State<SharedRoomsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        border: Border(left: BorderSide(color: theme.accent, width: 2)),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.group_outlined, size: 14, color: theme.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.headline,
                style: theme.label
                    .copyWith(color: theme.accent, letterSpacing: 1.2),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  _expanded
                      ? AppLocalizations.of(context).destructiveSheetHideLabel
                      : AppLocalizations.of(context).destructiveSheetViewLabel,
                  style: theme.monoTiny.copyWith(color: theme.accent),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(widget.note, style: theme.monoTiny),
          if (_expanded) ...[
            const SizedBox(height: 10),
            for (final r in widget.rooms)
              SharedRoomRow(room: r, api: widget.api, theme: theme),
          ],
        ],
      ),
    );
  }
}
