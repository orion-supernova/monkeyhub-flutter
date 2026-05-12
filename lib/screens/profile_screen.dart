import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'room_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final isMe = user.id == store.me.id;
    final isFriend = store.friendIds.contains(user.id);
    final sharedRooms = store.rooms.where((r) => r.memberIds.contains(user.id) && r.memberIds.contains(store.me.id)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                    ),
                    const Spacer(),
                    if (!isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: theme.chipDecoration(),
                        child: Text('• • •', style: theme.label),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatar(user: user, size: 96),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: theme.displayLarge),
                          const SizedBox(height: 6),
                          Text(user.handle, style: theme.mono.copyWith(color: theme.inkMuted)),
                          const SizedBox(height: 10),
                          VisibilityBadge(isPublic: user.isPublic, dense: false),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (user.bio != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: theme.roomCardDecoration(ephemeral: false, active: false),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ABOUT', style: theme.label),
                        const SizedBox(height: 8),
                        Text('"${user.bio!}"', style: theme.bodyEmph),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (!isMe)
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileAction(
                          label: isFriend ? 'FRIENDS' : 'SEND REQUEST',
                          icon: isFriend ? Icons.check : Icons.person_add_alt_1,
                          filled: !isFriend,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileAction(
                          label: 'MESSAGE',
                          icon: Icons.north_east,
                          filled: false,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 28),
                Row(children: [
                  Text('SHARED ROOMS · ${sharedRooms.length}', style: theme.label),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, color: theme.divider)),
                ]),
                const SizedBox(height: 12),
                if (sharedRooms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text('nothing shared yet', style: theme.bodySoft),
                  )
                else
                  Column(
                    children: [
                      for (final r in sharedRooms)
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(roomId: r.id))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: theme.roomCardDecoration(ephemeral: r.isEphemeral, active: false),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: theme.surfaceSunken,
                                    borderRadius: BorderRadius.circular(theme.radiusMd),
                                  ),
                                  child: r.isEphemeral
                                      ? theme.hourglassIcon(size: 12, color: theme.accent)
                                      : Icon(Icons.tag, size: 12, color: theme.inkSoft),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(r.name, style: theme.displaySmall)),
                                VisibilityBadge(isPublic: r.isPublic, dense: true),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                if (isMe) ...[
                  const SizedBox(height: 28),
                  Row(children: [
                    Text('YOUR VISIBILITY', style: theme.label),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1, color: theme.divider)),
                  ]),
                  const SizedBox(height: 12),
                  _VisibilityToggle(user: user),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.label, required this.icon, required this.filled, required this.onTap});
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? theme.accent : Colors.transparent,
          border: Border.all(color: filled ? theme.accent : theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: filled ? theme.accentInk : theme.ink),
            const SizedBox(width: 8),
            Text(label, style: theme.label.copyWith(color: filled ? theme.accentInk : theme.ink)),
          ],
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatefulWidget {
  const _VisibilityToggle({required this.user});
  final User user;
  @override
  State<_VisibilityToggle> createState() => _VisibilityToggleState();
}

class _VisibilityToggleState extends State<_VisibilityToggle> {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isPublic = widget.user.isPublic;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              MockStore.instance.setUserVisibility(widget.user, true);
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: isPublic ? theme.surfaceRaised : theme.surfaceSunken,
                border: Border.all(color: isPublic ? theme.accent : theme.divider, width: isPublic ? 1.4 : 1),
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: Row(children: [
                theme.visibilityIcon(isPublic: true, size: 14),
                const SizedBox(width: 8),
                Text('public', style: theme.displaySmall.copyWith(fontSize: 16, color: isPublic ? theme.ink : theme.inkSoft)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              MockStore.instance.setUserVisibility(widget.user, false);
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: !isPublic ? theme.surfaceRaised : theme.surfaceSunken,
                border: Border.all(color: !isPublic ? theme.accent : theme.divider, width: !isPublic ? 1.4 : 1),
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: Row(children: [
                theme.visibilityIcon(isPublic: false, size: 14),
                const SizedBox(width: 8),
                Text('private', style: theme.displaySmall.copyWith(fontSize: 16, color: !isPublic ? theme.ink : theme.inkSoft)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
