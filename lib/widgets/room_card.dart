import 'package:flutter/material.dart';
import '../models/room.dart';
import '../data/mock_store.dart';
import '../theme/theme_scope.dart';
import 'visibility_badge.dart';
import 'user_avatar.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  final Room room;
  final VoidCallback onTap;

  String _ago(DateTime then) {
    final d = DateTime.now().difference(then);
    if (d.inSeconds < 30) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final lastMsg = store.lastMessageFor(room);
    final lastAuthor = lastMsg == null ? null : store.userById(lastMsg.authorId);
    final members = room.memberIds.map(store.userById).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VisibilityBadge(isPublic: room.isPublic, dense: true),
                      if (room.isEphemeral) EphemeralBadge(ttl: room.ttl!, dense: true),
                    ],
                  ),
                ),
                if (lastMsg != null)
                  Text(_ago(lastMsg.createdAt), style: theme.monoTiny),
              ],
            ),
            const SizedBox(height: 12),
            Text(room.name, style: theme.displayMedium),
            if (room.topic != null) ...[
              const SizedBox(height: 4),
              Text(room.topic!.toLowerCase(), style: theme.bodySoft),
            ],
            const SizedBox(height: 14),
            if (lastMsg != null && lastAuthor != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lastAuthor.name.split(' ').first.toLowerCase()} —',
                    style: theme.caption.copyWith(color: theme.accent),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastMsg.text,
                      style: theme.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  height: 26,
                  width: members.length.clamp(1, 4) * 18.0 + 8,
                  child: Stack(
                    children: [
                      for (var i = 0; i < members.take(4).length; i++)
                        Positioned(
                          left: i * 16.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.background, width: 1.5),
                            ),
                            child: UserAvatar(user: members[i], size: 24),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${room.memberIds.length} inside', style: theme.caption),
                const Spacer(),
                if (room.isEphemeral)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      theme.hourglassIcon(size: 12, color: theme.accent),
                      const SizedBox(width: 6),
                      Text('messages fade', style: theme.monoTiny.copyWith(color: theme.accent)),
                    ],
                  )
                else
                  Text('↗ enter', style: theme.monoTiny),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
