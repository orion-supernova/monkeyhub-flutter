import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/room.dart';
import '../theme/theme_scope.dart';
import 'room_screen.dart';

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _topic = TextEditingController();
  RoomVisibility _visibility = RoomVisibility.private;
  RoomType _type = RoomType.standard;
  Duration _ttl = const Duration(seconds: 30);

  static const _ttls = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(hours: 1),
  ];

  String _fmtTtl(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }

  void _create() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final r = MockStore.instance.createRoom(
      name: n,
      visibility: _visibility,
      type: _type,
      ttl: _type == RoomType.ephemeral ? _ttl : null,
      description: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
    );
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(roomId: r.id)));
  }

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: theme.inkMuted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Text('new room', style: theme.displayLarge),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Icon(Icons.close, color: theme.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 14, height: 1, color: theme.accent),
                const SizedBox(width: 8),
                Text(_type == RoomType.ephemeral ? 'NOTHING WILL BE KEPT' : 'A SPACE THAT STAYS', style: theme.caption.copyWith(color: theme.accent)),
              ]),
              const SizedBox(height: 24),

              _Label(text: 'NAME'),
              _InputBox(controller: _name, hint: 'name it something honest…'),
              const SizedBox(height: 18),

              _Label(text: 'TOPIC · OPTIONAL'),
              _InputBox(controller: _topic, hint: 'one line about the room…'),
              const SizedBox(height: 22),

              _Label(text: 'VISIBILITY'),
              Row(children: [
                Expanded(
                  child: _SegmentTile(
                    active: _visibility == RoomVisibility.public,
                    onTap: () => setState(() => _visibility = RoomVisibility.public),
                    icon: theme.visibilityIcon(isPublic: true, size: 14),
                    title: 'public',
                    sub: 'anyone can find it',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegmentTile(
                    active: _visibility == RoomVisibility.private,
                    onTap: () => setState(() => _visibility = RoomVisibility.private),
                    icon: theme.visibilityIcon(isPublic: false, size: 14),
                    title: 'private',
                    sub: 'invite only',
                  ),
                ),
              ]),
              const SizedBox(height: 22),

              _Label(text: 'TYPE'),
              Row(children: [
                Expanded(
                  child: _SegmentTile(
                    active: _type == RoomType.standard,
                    onTap: () => setState(() => _type = RoomType.standard),
                    icon: Icon(Icons.tag, size: 14, color: theme.inkSoft),
                    title: 'standard',
                    sub: 'messages persist',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegmentTile(
                    active: _type == RoomType.ephemeral,
                    onTap: () => setState(() => _type = RoomType.ephemeral),
                    icon: theme.hourglassIcon(size: 14, color: theme.accent),
                    title: 'ephemeral',
                    sub: 'auto-deletes',
                    highlight: true,
                  ),
                ),
              ]),

              AnimatedCrossFade(
                duration: theme.motionMed,
                crossFadeState: _type == RoomType.ephemeral ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(height: 22),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        _Label(text: 'MESSAGE LIFE'),
                        const Spacer(),
                        Text(_fmtTtl(_ttl), style: theme.monoLarge.copyWith(color: theme.accent)),
                      ]),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final t in _ttls)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _ttl = t),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: theme.chipDecoration(filled: _ttl == t),
                                  child: Text(
                                    _fmtTtl(t),
                                    style: theme.label.copyWith(color: _ttl == t ? theme.accentInk : theme.inkSoft),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),
              GestureDetector(
                onTap: _create,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                    boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('OPEN THE ROOM', style: theme.label.copyWith(color: theme.accentInk, letterSpacing: 2.2)),
                      const SizedBox(width: 10),
                      Icon(Icons.north_east, size: 14, color: theme.accentInk),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: theme.label),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: theme.inputDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        style: theme.body.copyWith(color: theme.ink),
        cursorColor: theme.accent,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: theme.body.copyWith(color: theme.inkMuted),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.active,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.sub,
    this.highlight = false,
  });

  final bool active;
  final VoidCallback onTap;
  final Widget icon;
  final String title;
  final String sub;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = active ? theme.ink : theme.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: active ? theme.surfaceRaised : theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(
            color: active ? (highlight ? theme.accent : theme.ink.withValues(alpha: 0.35)) : theme.divider,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: Center(child: icon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.displaySmall.copyWith(color: ink, fontSize: 16)),
                  Text(sub, style: theme.monoTiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
