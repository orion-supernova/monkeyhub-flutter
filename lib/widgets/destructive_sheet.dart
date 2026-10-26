import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'remote_image.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

/// Building blocks shared by the sheets that ask "are you sure?" before
/// destroying something — blocking a user, and taking a contact away from a
/// child. Both need the same tile and the same shared-room row, and both are
/// destructive enough that the two should never drift apart visually.

/// The drag handle every bottom sheet in this family opens with.
///
/// Not a second grabber: it IS [SheetHandle], plus 8pt below for the hand-
/// placed panels (`SheetSurface`, the child-policy sheet) that have no bar
/// under it. New sheets use [SheetFrame], which places the handle itself.
@Deprecated('Use SheetHandle (or SheetFrame, which places it).')
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: SheetHandle(),
      );
}

/// A plain "are you sure?" over the same furniture as its richer siblings.
///
/// Use when there's nothing to enumerate — no shared rooms, no message counts,
/// just a decision that has to be stated plainly and confirmed. When there IS
/// a blast radius worth listing, prefer a purpose-built sheet like
/// `showRemoveContactSheet` that actually names what dies.
///
/// A sunlit emblem over the headline ([icon], a warning triangle by default),
/// what it means, the answer as a solid capsule and Cancel on a raised one of
/// its own. [destructive] false is for a question that does not destroy
/// anything (a permission prompt): an accent emblem and button, and no
/// "cannot be undone".
///
/// Returns true only if the confirm button was tapped.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String headline,
  required String body,
  required String confirmLabel,
  IconData? icon,
  bool destructive = true,
}) async {
  final res = await showAdaptiveSheet<bool>(
    context,
    builder: (ctx) => _ConfirmSheet(
      headline: headline,
      body: body,
      confirmLabel: confirmLabel,
      icon: icon ??
          (destructive
              ? CupertinoIcons.exclamationmark_triangle_fill
              : CupertinoIcons.info_circle_fill),
      destructive: destructive,
    ),
  );
  return res ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.headline,
    required this.body,
    required this.confirmLabel,
    required this.icon,
    required this.destructive,
  });

  final String headline;
  final String body;
  final String confirmLabel;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SheetPanel(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              DialogHeader(
                emblem: DialogEmblem(
                  icon: icon,
                  tone: destructive ? theme.danger : theme.accent,
                ),
                title: headline,
                message: body,
                note: destructive
                    ? sentenceCaseOf(context, l10n.destructiveSheetCannotBeUndone)
                    : null,
              ),
              // The weight lands on the answer: a heavy impact for one that
              // destroys, none for backing out.
              SheetActionButton(
                label: confirmLabel,
                destructive: destructive,
                haptic: false,
                onTap: () {
                  if (destructive) HapticFeedback.heavyImpact();
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: 10),
              // Autofocused so Enter on a freshly opened sheet backs out
              // rather than destroys: the desktop convention.
              DialogCancelButton(
                label: l10n.destructiveSheetCancelButtonLabel,
                autofocus: true,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
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
    // A grouped row, iOS-style: the outcome's colour lives in the icon tile
    // and the title, not in a ring around the whole thing. The heavier choice
    // gets a soft wash of its colour behind it rather than a thicker border.
    return SpringPress(
      onTap: onTap,
      autofocus: autofocus,
      semanticLabel: title,
      focusRadius: groupedRadius(theme),
      scale: 0.98,
      haptic: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: filled
              ? Color.alphaBlend(
                  color.withValues(alpha: 0.12),
                  sheetGroupFill(theme),
                )
              : sheetGroupFill(theme),
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sentenceCaseOf(context, title),
                    style: theme.bodyEmph.copyWith(
                      color: color,
                      fontSize: 17,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: groupedSubtitleStyle(theme)),
                ],
              ),
            ),
          ],
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
              child: Icon(CupertinoIcons.number, size: 12, color: theme.inkSoft),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              room.name,
              style: groupedTitleStyle(theme).copyWith(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${room.memberCount}',
            style: groupedMetaStyle(theme).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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
    // A grouped block: what survives, said in a sentence, with the rooms one
    // tap away. No accent stripe — the reassurance is in the words.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: sheetGroupFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(CupertinoIcons.person_2_fill, size: 16, color: theme.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sentenceCaseOf(context, widget.headline),
                style: theme.bodyEmph.copyWith(
                  fontSize: 15,
                  fontStyle: FontStyle.normal,
                  color: theme.ink,
                ),
              ),
            ),
            TextLinkButton(
              onTap: () => setState(() => _expanded = !_expanded),
              fontSize: 15,
              label: _expanded
                  ? AppLocalizations.of(context).destructiveSheetHideLabel
                  : AppLocalizations.of(context).destructiveSheetViewLabel,
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            widget.note,
            style: groupedFooterStyle(theme),
          ),
          AnimatedSize(
            duration: theme.motionFast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        for (final r in widget.rooms)
                          SharedRoomRow(room: r, api: widget.api, theme: theme),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
