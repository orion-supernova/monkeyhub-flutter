import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'labeled_field.dart';
import 'remote_image.dart';

/// Confirmation gate shown before joining a public room. Previews the room
/// (avatar, name, description, member count) so a single tap in Discover/Search
/// no longer drops the user straight into a room they never got to look at.
///
/// For a locked room the password field lives inline here, so this one sheet is
/// the whole gate — there's no separate password prompt afterwards.
///
/// Resolves to:
///   * `null` when the user cancels/dismisses.
///   * `(password: null)` when they confirm joining an unlocked room.
///   * `(password: <entered>)` when they confirm joining a locked room.
Future<({String? password})?> showJoinRoomSheet(
  BuildContext context,
  ChatRoom room,
  ChatApi api,
) {
  return showAdaptiveSheet<({String? password})>(
    context,
    builder: (_) => _JoinRoomSheet(room: room, api: api),
  );
}

class _JoinRoomSheet extends StatefulWidget {
  const _JoinRoomSheet({required this.room, required this.api});
  final ChatRoom room;
  final ChatApi api;

  @override
  State<_JoinRoomSheet> createState() => _JoinRoomSheetState();
}

class _JoinRoomSheetState extends State<_JoinRoomSheet> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canJoin => !widget.room.hasPassword || _password.text.isNotEmpty;

  void _join() {
    if (!_canJoin) return;
    Navigator.of(context).pop(
      (password: widget.room.hasPassword ? _password.text : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final room = widget.room;
    final hasAvatar =
        room.avatarStorageId != null && room.avatarStorageId!.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('JOIN ROOM',
                style: theme.label.copyWith(color: theme.accent, letterSpacing: 2)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasAvatar)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                    child: RemoteImage(
                      storageId: room.avatarStorageId!,
                      api: widget.api,
                      width: 48,
                      height: 48,
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      border: Border.all(color: theme.divider),
                    ),
                    child: Icon(Icons.tag, size: 20, color: theme.inkSoft),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.name,
                              style: theme.displayLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.hasPassword) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock_outline,
                                size: 15, color: theme.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${room.memberCount} '
                        '${room.memberCount == 1 ? 'member' : 'members'}',
                        style: theme.monoTiny,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (room.description != null && room.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(room.description!, style: theme.bodySoft),
            ],
            if (room.hasPassword) ...[
              const SizedBox(height: 20),
              const FieldLabel('PASSWORD'),
              ThemedInput(
                controller: _password,
                hint: 'passphrase…',
                obscure: _obscure,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _join(),
                trailing: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: theme.inkMuted,
                    size: 18,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Opacity(
              opacity: _canJoin ? 1 : 0.4,
              child: GestureDetector(
                onTap: _join,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Text(
                    'JOIN',
                    style: theme.label
                        .copyWith(color: theme.accentInk, letterSpacing: 2.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text('cancel',
                    style: theme.bodySoft.copyWith(color: theme.inkMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
