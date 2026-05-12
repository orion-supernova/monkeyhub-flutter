import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'room_screen.dart';

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _password = TextEditingController();
  bool _isPrivate = true;
  RoomType _type = RoomType.regular;
  Duration _ttl = const Duration(seconds: 30);
  bool _busy = false;
  String? _error;

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

  Future<void> _create() async {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'name is required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repo.createRoom(
        name: n,
        isPrivate: _isPrivate,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
        type: _type,
        messageLifetime: _type == RoomType.secret ? _ttl : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomScreen(roomId: id, repo: widget.repo, api: widget.api)),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _password.dispose();
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
                Text(
                  _type == RoomType.secret ? 'NOTHING WILL BE KEPT' : 'A SPACE THAT STAYS',
                  style: theme.caption.copyWith(color: theme.accent),
                ),
              ]),
              const SizedBox(height: 24),
              _label(theme, 'NAME'),
              _input(theme, _name, 'name it something honest…'),
              const SizedBox(height: 18),
              _label(theme, 'DESCRIPTION · OPTIONAL'),
              _input(theme, _desc, 'one line about the room…'),
              const SizedBox(height: 22),
              _label(theme, 'VISIBILITY'),
              Row(children: [
                Expanded(
                  child: _seg(
                    theme,
                    active: !_isPrivate,
                    onTap: () => setState(() => _isPrivate = false),
                    icon: theme.visibilityIcon(isPublic: true, size: 14),
                    title: 'public',
                    sub: 'anyone can find it',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _seg(
                    theme,
                    active: _isPrivate,
                    onTap: () => setState(() => _isPrivate = true),
                    icon: theme.visibilityIcon(isPublic: false, size: 14),
                    title: 'private',
                    sub: 'invite only',
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              _label(theme, 'TYPE'),
              Row(children: [
                Expanded(
                  child: _seg(
                    theme,
                    active: _type == RoomType.regular,
                    onTap: () => setState(() => _type = RoomType.regular),
                    icon: Icon(Icons.tag, size: 14, color: theme.inkSoft),
                    title: 'standard',
                    sub: 'messages persist',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _seg(
                    theme,
                    active: _type == RoomType.secret,
                    onTap: () => setState(() => _type = RoomType.secret),
                    icon: theme.hourglassIcon(size: 14, color: theme.accent),
                    title: 'ephemeral',
                    sub: 'auto-deletes',
                    highlight: true,
                  ),
                ),
              ]),
              AnimatedCrossFade(
                duration: theme.motionMed,
                crossFadeState: _type == RoomType.secret ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(height: 22),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        _label(theme, 'MESSAGE LIFE'),
                        const Spacer(),
                        Text(_fmtTtl(_ttl), style: theme.monoLarge.copyWith(color: theme.accent)),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final t in _ttls)
                            GestureDetector(
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isPrivate) ...[
                const SizedBox(height: 22),
                _label(theme, 'PASSWORD · OPTIONAL'),
                _input(theme, _password, 'lock with a passphrase…', obscure: true),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: theme.body.copyWith(color: theme.danger)),
              ],
              const SizedBox(height: 26),
              GestureDetector(
                onTap: _busy ? null : _create,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _busy ? theme.accentSoft : theme.accent,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: _busy
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentInk))
                      : Row(
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

  Widget _label(AppTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: theme.label),
      );

  Widget _input(AppTheme theme, TextEditingController c, String hint, {bool obscure = false}) {
    return Container(
      decoration: theme.inputDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
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

  Widget _seg(AppTheme theme, {
    required bool active,
    required VoidCallback onTap,
    required Widget icon,
    required String title,
    required String sub,
    bool highlight = false,
  }) {
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
