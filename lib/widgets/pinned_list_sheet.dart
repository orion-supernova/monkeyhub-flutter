import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/message_preview.dart';
import '../models/room_pin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'message_stamp.dart' show formatClockTime;
import 'remote_image.dart';
import 'user_avatar.dart';
import '../l10n/text_case.dart';

/// Every message pinned in this room, oldest first.
///
/// The banner only ever describes one pin at a time; this is where the rest
/// live. Reachable only from that banner, which itself only exists when there
/// is at least one pin — so there is no loading state to render.
Future<void> showPinnedListSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required String roomId,
  required void Function(RoomPin pin) onJump,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => PinnedListSheet(
      repo: repo,
      api: api,
      roomId: roomId,
      onJump: onJump,
    ),
  );
}

class PinnedListSheet extends StatelessWidget {
  const PinnedListSheet({
    super.key,
    required this.repo,
    required this.api,
    required this.roomId,
    required this.onJump,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;
  final void Function(RoomPin pin) onJump;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Read through to the repository on every build rather than snapshotting,
    // so unpinning from inside this sheet updates it — and so does somebody
    // else unpinning from another device.
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) => _body(context, theme),
    );
  }

  void _jump(BuildContext context, RoomPin pin) {
    // Pop FIRST. Jumping with the sheet still up animates the transcript
    // behind it, so the reader arrives having seen none of the travel.
    Navigator.of(context).pop();
    onJump(pin);
  }

  Future<void> _unpin(RoomPin pin) async {
    HapticFeedback.selectionClick();
    await repo.unpinMessage(roomId, pin.message.id);
  }

  Widget _body(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final pins = repo.pinsFor(roomId);
    // 50 pins do not fit on a phone, and a sheet that grows to the full screen
    // stops reading as a sheet.
    final maxH = MediaQuery.sizeOf(context).height * 0.6;

    // A grouped block of rows, each led by the sender's face (or the photo
    // itself) — the archived sheet's shape, not bare lines of text.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.activeCallPillPinnedHeader),
      subtitle: pins.isEmpty
          ? null
          : l10n.pinnedListSheetCount(pins.length),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: pins.isEmpty
          // The last pin went while this was open. Say so and let the reader
          // dismiss — popping a sheet out from under a finger is worse.
          ? EmptyLine(l10n.activeCallPillNothingPinned)
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                child: SheetGroup(
                  children: [
                    for (final pin in pins)
                      _PinRow(
                        pin: pin,
                        repo: repo,
                        api: api,
                        onTap: () => _jump(context, pin),
                        onUnpin: () => _unpin(pin),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.pin,
    required this.repo,
    required this.api,
    required this.onTap,
    required this.onUnpin,
  });

  final RoomPin pin;
  final ChatRepository repo;
  final ChatApi api;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = pin.message;
    // View-once media has no storage id — the server withholds it — so there is
    // deliberately nothing to show for those beyond the words.
    final hasThumb = !m.viewOnce &&
        m.mediaStorageId != null &&
        (m.type == MessageType.image || m.type == MessageType.video);
    final sender = repo.userById(m.senderId) ??
        ChatUser(
          id: m.senderId,
          username: '',
          name: m.senderName,
          lastSeen: m.createdAt,
        );

    return PersonRow(
      avatar: hasThumb
          ? ClipRRect(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: RemoteImage(
                storageId: m.mediaStorageId!,
                api: api,
                width: kPersonRowAvatar,
                height: kPersonRowAvatar,
                fit: BoxFit.cover,
              ),
            )
          : UserAvatar(
              user: sender,
              size: kPersonRowAvatar,
              api: api,
              showStatus: false,
            ),
      title: m.senderName,
      titleTrailing: Text(formatClockTime(m.createdAt), style: _meta(theme)),
      subtitle: messagePreviewLine(m, hasThumbnail: hasThumb),
      semanticLabel: l10n.activeCallPillJumpToMessageSemanticLabel(
        m.senderName,
      ),
      onTap: onTap,
      trailing: SpringPress(
        onTap: onUnpin,
        haptic: false,
        semanticLabel: l10n.activeCallPillUnpinMessageSemanticLabel(
          m.senderName,
        ),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(
            CupertinoIcons.pin_slash,
            size: 19,
            color: theme.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Small meta text — counts, times, choice names — in the theme's body face
/// at footnote size with tabular figures, never the tracked monospace.
TextStyle _meta(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 13,
      color: theme.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
