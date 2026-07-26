import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
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
      final nav = Navigator.of(context);
      if (context.isExpanded) {
        // Desktop: dismiss the sheet and open the new room in the chat pane.
        SettingsStore.instance.setSection(HomeSection.chat);
        UiSelectionStore.instance.selectRoom(id);
        nav.pop();
      } else {
        nav.pop();
        nav.push(
          MaterialPageRoute(
              builder: (_) =>
                  RoomScreen(roomId: id, repo: widget.repo, api: widget.api)),
        );
      }
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
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: theme.sheetDecoration(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: DefaultTextStyle(
                style: theme.body.copyWith(color: theme.ink),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Meaningless once dismiss-by-drag isn't a thing — the
                      // desktop popover closes via barrier tap / Esc, not a
                      // drag gesture.
                      if (context.isCompact)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.inkMuted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('new room', style: theme.displayLarge),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Container(
                                    width: 18,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: theme.accent,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _type == RoomType.secret
                                        ? 'NOTHING WILL BE KEPT'
                                        : 'A SPACE THAT STAYS',
                                    style: theme.caption.copyWith(
                                      color: theme.accent,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.surfaceSunken,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.divider),
                              ),
                              child: Icon(CupertinoIcons.xmark, color: theme.inkSoft, size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      LabeledField(
                        label: 'NAME',
                        controller: _name,
                        hint: 'name it something honest…',
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 18),
                      LabeledField(
                        label: 'DESCRIPTION · OPTIONAL',
                        controller: _desc,
                        hint: 'one line about the room…',
                        textInputAction: TextInputAction.done,
                        // Same guard as the CTA, so Enter can't create a room
                        // the button is currently refusing to.
                        onSubmitted: (_) => _busy ? null : _create(),
                      ),
                      const SizedBox(height: 22),
                      const FieldLabel('VISIBILITY'),
                      Row(children: [
                        Expanded(
                          child: _seg(
                            theme,
                            active: !_isPrivate,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isPrivate = false);
                            },
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
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isPrivate = true);
                            },
                            icon: theme.visibilityIcon(isPublic: false, size: 14),
                            title: 'private',
                            sub: 'invite only',
                          ),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      const FieldLabel('TYPE'),
                      Row(children: [
                        Expanded(
                          child: _seg(
                            theme,
                            active: _type == RoomType.regular,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _type = RoomType.regular);
                            },
                            icon: Icon(CupertinoIcons.number, size: 14, color: theme.inkSoft),
                            title: 'standard',
                            sub: 'messages persist',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _seg(
                            theme,
                            active: _type == RoomType.secret,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _type = RoomType.secret);
                            },
                            icon: theme.hourglassIcon(size: 14, color: theme.accent),
                            title: 'ephemeral',
                            sub: 'auto-deletes',
                            highlight: true,
                          ),
                        ),
                      ]),
                      AnimatedCrossFade(
                        duration: theme.motionMed,
                        crossFadeState: _type == RoomType.secret
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox(height: 22),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                const FieldLabel('MESSAGE LIFE'),
                                const Spacer(),
                                Text(_fmtTtl(_ttl),
                                    style: theme.monoLarge.copyWith(color: theme.accent)),
                              ]),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final t in _ttls)
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _ttl = t);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 9),
                                        decoration: theme.chipDecoration(filled: _ttl == t),
                                        child: Text(
                                          _fmtTtl(t),
                                          style: theme.label.copyWith(
                                              color: _ttl == t
                                                  ? theme.accentInk
                                                  : theme.inkSoft),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Password is independent of visibility: a public room
                      // can be discoverable yet locked, a private room can be
                      // hidden yet open. Show the field for both.
                      const SizedBox(height: 22),
                      PasswordField(
                        label: 'PASSWORD · OPTIONAL',
                        controller: _password,
                        hint: 'lock with a passphrase…',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: theme.surfaceSunken,
                            border: Border(
                                left: BorderSide(color: theme.danger, width: 2)),
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                          ),
                          child: Text(_error!,
                              style: theme.body.copyWith(color: theme.danger)),
                        ),
                      ],
                      const SizedBox(height: 26),
                      FocusableTap(
                        onTap: _busy ? null : _create,
                        enabled: !_busy,
                        semanticLabel: 'Open the room',
                        radius: theme.radiusLg,
                        child: GestureDetector(
                        onTap: _busy ? null : _create,
                        child: AnimatedContainer(
                          duration: theme.motionFast,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _busy ? theme.accentSoft : theme.accent,
                            borderRadius: BorderRadius.circular(theme.radiusLg),
                            boxShadow: _busy
                                ? null
                                : [
                                    BoxShadow(
                                      color: theme.accent.withValues(alpha: 0.3),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: _busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: theme.accentInk),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('OPEN THE ROOM',
                                        style: theme.label.copyWith(
                                            color: theme.accentInk,
                                            letterSpacing: 2.4)),
                                    const SizedBox(width: 10),
                                    Icon(CupertinoIcons.arrow_up_right,
                                        size: 14, color: theme.accentInk),
                                  ],
                                ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
