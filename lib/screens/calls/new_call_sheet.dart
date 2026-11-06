import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/call_models.dart';
import '../../keyboard/focusable_tap.dart' show FocusRingShape;
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/people_picker.dart';
import '../../widgets/sheet_kit.dart';
import '../../widgets/spring_press.dart';
import 'calls_directory.dart';

/// The new-call picker: your friends, each with a voice and a video button,
/// the way Telegram's "New Call" works. Tapping a row is a voice call; one tap
/// either way, no select-then-confirm step.
///
/// ONE person per call. A call to several people needs a group room, and a
/// group room cannot be conjured here: `rooms:create` makes an empty room and
/// every member comes in through an invitation they must accept
/// (`roomInvitations:invite`), so there is nothing to ring yet. Calling a group
/// is done from the group's own chat header.
Future<void> showNewCallSheet(
  BuildContext context, {
  required CallsDirectory directory,
  required ChatApi api,
  required void Function(ChatUser person, CallMediaKind kind) onStart,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _NewCallSheet(directory: directory, api: api, onStart: onStart),
  );
}

class _NewCallSheet extends StatelessWidget {
  const _NewCallSheet({
    required this.directory,
    required this.api,
    required this.onStart,
  });
  final CallsDirectory directory;
  final ChatApi api;
  final void Function(ChatUser person, CallMediaKind kind) onStart;

  void _start(BuildContext context, ChatUser person, CallMediaKind kind) {
    Navigator.of(context).pop();
    onStart(person, kind);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Real people only: the log bot is a friend so its thread is reachable,
    // but it has no phone to ring.
    final friends =
        directory.friends.where((f) => !f.isSystem).toList(growable: false);
    // The New Chat sheet's shape: nearly full height and FIXED, the list runs
    // to the card's edge and scrolls clear of it. A fixed-height box inside a
    // shrink-to-fit sheet is what used to cut the list off mid-row over a
    // band of nothing.
    return SheetFrame(
      title: l10n.callsTabNewCall,
      maxHeightFraction: 0.92,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      scrollsUnderInset: true,
      child: PeoplePicker(
        bottomPadding: 16 + sheetBottomInset(MediaQuery.of(context)),
        people: friends,
        api: api,
        onPick: (u) => _start(context, u, CallMediaKind.audio),
        hintText: l10n.callsTabNewCallSearch,
        emptyLabel: l10n.callsTabNewCallEmpty,
        noMatchLabel: l10n.callsTabNewCallNoMatch,
        trailingFor: (u) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CallGlyphButton(
              icon: CupertinoIcons.phone_fill,
              label: l10n.callsTabVoiceCall,
              onTap: () => _start(context, u, CallMediaKind.audio),
            ),
            const SizedBox(width: 8),
            _CallGlyphButton(
              icon: CupertinoIcons.videocam_fill,
              label: l10n.callsTabVideoCall,
              onTap: () => _start(context, u, CallMediaKind.video),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round accent-tinted call button at a row's end.
class _CallGlyphButton extends StatelessWidget {
  const _CallGlyphButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Semantics(
      button: true,
      label: label,
      child: SpringPress(
        onTap: onTap,
        scale: 0.88,
        focusShape: FocusRingShape.circle,
        // Drawn 38pt, tappable 44pt.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: theme.accent),
            ),
          ),
        ),
      ),
    );
  }
}
