import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';

enum BlockChoice { cancel, blockOnly, blockAndDelete }

Future<BlockChoice> showBlockChoiceSheet(
  BuildContext context, {
  required String displayName,
  required bool isFriend,
  required List<ChatRoom> sharedGroupRooms,
  required bool hasDm,
  required ChatApi api,
}) async {
  final res = await showModalBottomSheet<BlockChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _BlockChoiceSheet(
      displayName: displayName,
      isFriend: isFriend,
      sharedGroupRooms: sharedGroupRooms,
      hasDm: hasDm,
      api: api,
    ),
  );
  return res ?? BlockChoice.cancel;
}

class _BlockChoiceSheet extends StatefulWidget {
  const _BlockChoiceSheet({
    required this.displayName,
    required this.isFriend,
    required this.sharedGroupRooms,
    required this.hasDm,
    required this.api,
  });
  final String displayName;
  final bool isFriend;
  final List<ChatRoom> sharedGroupRooms;
  final bool hasDm;
  final ChatApi api;

  @override
  State<_BlockChoiceSheet> createState() => _BlockChoiceSheetState();
}

class _BlockChoiceSheetState extends State<_BlockChoiceSheet> {
  bool _showSharedList = false;

  String _subtitle() {
    final parts = <String>['they won\'t be notified.'];
    if (widget.isFriend) {
      parts.add(
        'you\'re currently friends — blocking removes the friendship, so to reconnect later you\'d have to send a new friend request.',
      );
    } else {
      parts.add('they\'ll disappear from your search and can\'t message you.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final shared = widget.sharedGroupRooms;

    return Container(
      decoration: theme.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: SingleChildScrollView(
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
            Text('BLOCK',
                style: theme.label.copyWith(color: theme.danger, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('block ${widget.displayName}?', style: theme.displayMedium),
            const SizedBox(height: 6),
            Text(_subtitle(), style: theme.bodySoft),

            // ─────────────────── Shared rooms warning ───────────────────
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
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
                          'you share ${shared.length} ${shared.length == 1 ? "room" : "rooms"} with them',
                          style: theme.label.copyWith(color: theme.accent, letterSpacing: 1.2),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showSharedList = !_showSharedList),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            _showSharedList ? 'HIDE' : 'VIEW',
                            style: theme.monoTiny.copyWith(color: theme.accent),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'these rooms stay untouched. you can leave any of them yourself from each room\'s settings.',
                      style: theme.monoTiny,
                    ),
                    if (_showSharedList) ...[
                      const SizedBox(height: 10),
                      for (final r in shared)
                        _SharedRoomRow(room: r, api: widget.api, theme: theme),
                    ],
                  ],
                ),
              ),
            ],

            // ─────────────────── Choices ───────────────────
            const SizedBox(height: 16),
            _ChoiceTile(
              color: theme.danger,
              icon: Icons.block,
              title: 'BLOCK',
              sub: widget.isFriend
                  ? 'remove friendship and block. existing chat history stays in your archive.'
                  : 'they\'re hidden from search and can\'t reach you.',
              onTap: () => Navigator.of(context).pop(BlockChoice.blockOnly),
            ),
            if (widget.hasDm) ...[
              const SizedBox(height: 10),
              _ChoiceTile(
                color: theme.danger,
                filled: true,
                icon: Icons.delete_sweep,
                title: 'BLOCK & DELETE DM',
                sub:
                    'also wipes your DM with them — every message, reaction, and media file is gone.',
                onTap: () => Navigator.of(context).pop(BlockChoice.blockAndDelete),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(BlockChoice.cancel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                  child: Text(
                    'CANCEL',
                    style: theme.label.copyWith(color: theme.inkMuted, letterSpacing: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedRoomRow extends StatelessWidget {
  const _SharedRoomRow({required this.room, required this.api, required this.theme});
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.filled = false,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.12) : theme.surface,
          border: Border.all(color: color.withValues(alpha: filled ? 0.6 : 0.35), width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? color.withValues(alpha: 0.22) : color.withValues(alpha: 0.12),
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
    );
  }
}
