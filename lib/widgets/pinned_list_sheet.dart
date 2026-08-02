import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../models/enums.dart';
import '../models/message_preview.dart';
import '../models/room_pin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'message_stamp.dart' show formatClockTime;
import 'remote_image.dart';

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
    final pins = repo.pinsFor(roomId);
    // 50 pins do not fit on a phone, and a sheet that grows to the full screen
    // stops reading as a sheet.
    final maxH = MediaQuery.sizeOf(context).height * 0.6;

    return Container(
      decoration: theme.sheetDecoration(),
      padding: EdgeInsets.fromLTRB(
          22, 14, 22, 22 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(
            pins.isEmpty ? 'PINNED' : 'PINNED · ${pins.length}',
            textAlign: TextAlign.center,
            style: theme.label.copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 14),
          if (pins.isEmpty)
            // The last pin went while this was open. Say so and let the reader
            // dismiss — popping a sheet out from under a finger is worse.
            Text(
              'nothing pinned anymore',
              textAlign: TextAlign.center,
              style: theme.bodySoft,
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: pins.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, i) => _PinRow(
                  pin: pins[i],
                  api: api,
                  onTap: () => _jump(context, pins[i]),
                  onUnpin: () => _unpin(pins[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.pin,
    required this.api,
    required this.onTap,
    required this.onUnpin,
  });

  final RoomPin pin;
  final ChatApi api;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = pin.message;
    // View-once media has no storage id — the server withholds it — so there is
    // deliberately nothing to show for those beyond the words.
    final hasThumb = !m.viewOnce &&
        m.mediaStorageId != null &&
        (m.type == MessageType.image || m.type == MessageType.video);

    return Row(
      children: [
        Expanded(
          child: _Tappable(
            onTap: onTap,
            semanticLabel: 'Jump to message from ${m.senderName}',
            radius: theme.radiusMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasThumb) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: RemoteImage(
                          storageId: m.mediaStorageId!,
                          api: api,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodyEmph,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatClockTime(m.createdAt),
                              style: theme.monoTiny.copyWith(
                                color: theme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          messagePreviewLine(m, hasThumbnail: hasThumb),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySoft.copyWith(color: theme.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _Tappable(
          onTap: onUnpin,
          semanticLabel: 'Unpin message from ${m.senderName}',
          radius: theme.radiusSm,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              CupertinoIcons.pin_slash,
              size: 18,
              color: theme.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// [FocusableTap] registers no gesture recognizer of its own, so the bare
/// [GestureDetector] inside is what actually receives the pointer. Both carry
/// the handler; wrapping alone would render a row that does nothing.
///
/// Never an InkWell — this app draws no ink anywhere.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.onTap,
    required this.semanticLabel,
    required this.radius,
    required this.child,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      radius: radius,
      semanticLabel: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
