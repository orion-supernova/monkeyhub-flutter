import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/user.dart';
import '../models/room.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

class DiscoverPanel extends StatefulWidget {
  const DiscoverPanel({super.key});
  @override
  State<DiscoverPanel> createState() => _DiscoverPanelState();
}

class _DiscoverPanelState extends State<DiscoverPanel> {
  final TextEditingController _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final people = store.searchUsers(_query);
    final rooms = store.searchRooms(_query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search field
        Container(
          decoration: theme.inputDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.inkMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q,
                  style: theme.body.copyWith(color: theme.ink),
                  cursorColor: theme.accent,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'search people, handles, rooms…',
                    hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () { _q.clear(); setState(() => _query = ''); },
                  child: Icon(Icons.close, color: theme.inkMuted, size: 16),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('PRIVATE PROFILES ARE HIDDEN FROM SEARCH', style: theme.monoTiny),
            const Spacer(),
            theme.visibilityIcon(isPublic: false, size: 10),
          ],
        ),
        const SizedBox(height: 22),

        // People carousel
        _SectionHeader(label: 'PEOPLE · OPEN PROFILES', count: people.length),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: people.isEmpty
              ? Center(child: Text('nobody by that name', style: theme.bodySoft))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PersonCard(user: people[i]),
                ),
        ),
        const SizedBox(height: 26),

        // Rooms section
        _SectionHeader(label: 'ROOMS · PUBLIC ONLY', count: rooms.length),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('no rooms found', style: theme.bodySoft)),
          )
        else
          Column(
            children: [
              for (final r in rooms) _DiscoverRoomTile(room: r),
            ],
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: theme.label),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: theme.divider)),
        const SizedBox(width: 8),
        Text('$count', style: theme.monoTiny),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.user});
  final User user;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(user: user))),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: false, active: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(user: user, size: 38),
            const SizedBox(height: 10),
            Text(user.name, style: theme.displaySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(user.handle, style: theme.monoTiny),
            const Spacer(),
            VisibilityBadge(isPublic: user.isPublic, dense: true),
          ],
        ),
      ),
    );
  }
}

class _DiscoverRoomTile extends StatelessWidget {
  const _DiscoverRoomTile({required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(roomId: room.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: theme.accentSoft,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              alignment: Alignment.center,
              child: room.isEphemeral
                  ? theme.hourglassIcon(size: 14, color: theme.accent)
                  : Icon(Icons.tag, size: 14, color: theme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: theme.displaySmall),
                  const SizedBox(height: 2),
                  if (room.description != null)
                    Text(room.description!.toLowerCase(), style: theme.bodySoft, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${room.memberIds.length}', style: theme.monoLarge),
            const SizedBox(width: 4),
            Text('IN', style: theme.monoTiny),
          ],
        ),
      ),
    );
  }
}
