import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/people_picker.dart';
import '../../widgets/sheet_kit.dart';
import 'calls_directory.dart';

/// The "+" at the end of the favourites row: your friends, minus the people
/// already pinned and minus system accounts (the log bot has no phone).
/// Tapping a person pins them and closes the sheet, the same one-tap shape as
/// the new-call picker.
Future<void> showAddFavouriteSheet(
  BuildContext context, {
  required CallsDirectory directory,
  required ChatApi api,
  required Set<String> pinned,
  required void Function(ChatUser person) onPick,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _AddFavouriteSheet(
      directory: directory,
      api: api,
      pinned: pinned,
      onPick: onPick,
    ),
  );
}

class _AddFavouriteSheet extends StatelessWidget {
  const _AddFavouriteSheet({
    required this.directory,
    required this.api,
    required this.pinned,
    required this.onPick,
  });
  final CallsDirectory directory;
  final ChatApi api;
  final Set<String> pinned;
  final void Function(ChatUser person) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friends = directory.friends
        .where((f) => !f.isSystem && !pinned.contains(f.id))
        .toList(growable: false);
    return SheetFrame(
      title: l10n.callsTabFavAddTitle,
      maxHeightFraction: 0.92,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      scrollsUnderInset: true,
      child: PeoplePicker(
        bottomPadding: 16 + sheetBottomInset(MediaQuery.of(context)),
        people: friends,
        api: api,
        onPick: (u) {
          Navigator.of(context).pop();
          onPick(u);
        },
        hintText: l10n.callsTabNewCallSearch,
        emptyLabel: l10n.callsTabFavPickerEmpty,
        noMatchLabel: l10n.callsTabNewCallNoMatch,
      ),
    );
  }
}
