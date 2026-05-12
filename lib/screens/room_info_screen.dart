import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../media/upload_service.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/remote_image.dart';
import '../widgets/user_avatar.dart';

class RoomInfoScreen extends StatefulWidget {
  const RoomInfoScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
  });
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends State<RoomInfoScreen> {
  static const _ttlOptions = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(hours: 1),
  ];

  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _newPassword = TextEditingController();

  bool _isPrivate = true;
  Duration? _ttl;
  bool _loaded = false;
  bool _saving = false;
  bool _leaving = false;
  bool _deleting = false;
  String? _error;
  List<ChatUser> _members = const [];

  ChatRoom? get _room => widget.repo.roomById(widget.roomId);
  bool get _isOwner =>
      (widget.repo.userId ?? '') == (_room?.createdBy ?? '__none__');

  @override
  void initState() {
    super.initState();
    _hydrate();
    widget.repo.addListener(_onRepo);
  }

  void _onRepo() {
    if (!mounted) return;
    setState(() {});
  }

  void _hydrate() {
    final r = _room;
    if (r == null) return;
    _name.text = r.name;
    _desc.text = r.description ?? '';
    _isPrivate = r.isPrivate;
    _ttl = r.messageLifetime;
    _loaded = true;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final ms = await widget.api.getMembers(widget.roomId);
      if (!mounted) return;
      setState(() => _members = ms);
    } catch (_) {/* offline — leave empty */}
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepo);
    _name.dispose();
    _desc.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateRoom(
        roomId: r.id,
        userId: me,
        name: n,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        isPrivate: _isPrivate,
        messageLifetime: r.isEphemeral ? _ttl : null,
      );
      if (_isOwner && _newPassword.text.isNotEmpty) {
        await widget.api.updateRoomPassword(
          roomId: r.id,
          userId: me,
          password: _newPassword.text,
        );
        _newPassword.clear();
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _humanize(e);
      });
    }
  }

  Future<void> _clearPassword() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateRoomPassword(roomId: r.id, userId: me);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('password cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _humanize(e);
      });
    }
  }

  Future<void> _changeAvatar() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uploader = UploadService(widget.api);
      final storageId =
          await uploader.uploadXFile(file: File(picked.path), contentType: 'image/jpeg');
      await widget.api.updateRoomAvatar(
        roomId: r.id,
        userId: me,
        storageId: storageId,
      );
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _humanize(e);
      });
    }
  }

  Future<void> _leave() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final ok = await _confirm(
      title: 'leave room?',
      body: 'you can rejoin if it stays open.',
      confirm: 'LEAVE',
    );
    if (!ok) return;
    setState(() {
      _leaving = true;
      _error = null;
    });
    try {
      await widget.api.leaveRoom(roomId: r.id, userId: me);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _leaving = false;
        _error = _humanize(e);
      });
    }
  }

  Future<void> _delete() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final ok = await _confirm(
      title: 'delete room?',
      body: 'every message in here goes with it. this is permanent.',
      confirm: 'DELETE',
      destructive: true,
    );
    if (!ok) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.api.deleteRoom(roomId: r.id, userId: me);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = _humanize(e);
      });
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirm,
    bool destructive = false,
  }) async {
    final theme = ThemeScope.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.displayMedium),
              const SizedBox(height: 8),
              Text(body, style: theme.bodySoft),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('CANCEL', style: theme.label.copyWith(color: theme.inkSoft)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: destructive ? theme.danger : theme.accent,
                        borderRadius: BorderRadius.circular(theme.radiusMd),
                      ),
                      child: Text(
                        confirm,
                        style: theme.label.copyWith(
                          color: destructive ? Colors.white : theme.accentInk,
                          letterSpacing: 2,
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
    );
    return res ?? false;
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('ROOM_EXISTS')) return 'a room with that name already exists';
    if (s.contains('NOT_OWNER')) return 'only the owner can do that';
    if (s.contains('NOT_AUTHORIZED')) return 'you don\'t have permission';
    if (s.contains('ROOM_NAME_REQUIRED')) return 'name is required';
    if (s.contains('ROOM_NOT_FOUND')) return 'this room is gone';
    return s.replaceFirst('Exception: ', '');
  }

  String _fmtTtl(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final r = _room;
    if (r == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(child: Text('room gone', style: theme.bodySoft)),
      );
    }
    if (!_loaded) _hydrate();
    final busy = _saving || _leaving || _deleting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _header(theme, r),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _avatarBlock(theme, r),
                        const SizedBox(height: 26),
                        _label(theme, 'NAME'),
                        _input(theme, _name, 'room name'),
                        const SizedBox(height: 18),
                        _label(theme, 'DESCRIPTION'),
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
                        if (r.isEphemeral) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            _label(theme, 'MESSAGE LIFE'),
                            const Spacer(),
                            if (_ttl != null)
                              Text(_fmtTtl(_ttl!), style: theme.monoLarge.copyWith(color: theme.accent)),
                          ]),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final t in _ttlOptions)
                                GestureDetector(
                                  onTap: () => setState(() => _ttl = t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: theme.chipDecoration(filled: _ttl == t),
                                    child: Text(
                                      _fmtTtl(t),
                                      style: theme.label.copyWith(
                                        color: _ttl == t ? theme.accentInk : theme.inkSoft,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (_isOwner) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            _label(theme, 'PASSWORD'),
                            const Spacer(),
                            if (r.hasPassword)
                              GestureDetector(
                                onTap: busy ? null : _clearPassword,
                                child: Text(
                                  'CLEAR',
                                  style: theme.monoTiny.copyWith(color: theme.danger),
                                ),
                              ),
                          ]),
                          _input(
                            theme,
                            _newPassword,
                            r.hasPassword ? 'set a new passphrase…' : 'lock with a passphrase…',
                            obscure: true,
                          ),
                        ],
                        const SizedBox(height: 28),
                        _label(theme, 'MEMBERS · ${_members.length}'),
                        const SizedBox(height: 6),
                        _membersList(theme, r),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          Text(_error!, style: theme.body.copyWith(color: theme.danger)),
                          const SizedBox(height: 14),
                        ],
                        _saveButton(theme, busy),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: _dangerButton(
                              theme,
                              label: _leaving ? 'LEAVING…' : 'LEAVE ROOM',
                              onTap: busy ? null : _leave,
                            ),
                          ),
                          if (_isOwner) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _dangerButton(
                                theme,
                                label: _deleting ? 'DELETING…' : 'DELETE',
                                onTap: busy ? null : _delete,
                                filled: true,
                              ),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppTheme theme, ChatRoom r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROOM SETTINGS', style: theme.monoTiny),
                const SizedBox(height: 2),
                Text(r.name, style: theme.displayMedium, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarBlock(AppTheme theme, ChatRoom r) {
    final size = 92.0;
    final hasAvatar = r.avatarStorageId != null && r.avatarStorageId!.isNotEmpty;
    return Center(
      child: GestureDetector(
        onTap: _saving ? null : _changeAvatar,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: theme.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasAvatar
                  ? RemoteImage(
                      storageId: r.avatarStorageId!,
                      api: widget.api,
                      width: size,
                      height: size,
                      borderRadius: BorderRadius.circular(size),
                    )
                  : Center(
                      child: Icon(Icons.tag, color: theme.inkMuted, size: 32),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAvatar ? 'CHANGE AVATAR' : 'ADD AVATAR',
              style: theme.monoTiny.copyWith(color: theme.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _membersList(AppTheme theme, ChatRoom r) {
    if (_members.isEmpty) {
      return Text('loading members…', style: theme.bodySoft);
    }
    final ordered = [..._members]..sort((a, b) {
      final aOwner = a.id == r.createdBy ? 0 : 1;
      final bOwner = b.id == r.createdBy ? 0 : 1;
      if (aOwner != bOwner) return aOwner - bOwner;
      return a.displayName.compareTo(b.displayName);
    });
    return Column(
      children: [
        for (final m in ordered)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                UserAvatar(user: m, size: 32, api: widget.api),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.displayName, style: theme.body),
                      Text('@${m.username}', style: theme.monoTiny),
                    ],
                  ),
                ),
                if (m.id == r.createdBy)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: theme.chipDecoration(filled: true),
                    child: Text('OWNER', style: theme.monoTiny.copyWith(color: theme.accentInk)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _saveButton(AppTheme theme, bool busy) {
    return GestureDetector(
      onTap: busy ? null : _save,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy ? theme.accentSoft : theme.accent,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentInk),
              )
            : Text(
                'SAVE',
                style: theme.label.copyWith(color: theme.accentInk, letterSpacing: 2.2),
              ),
      ),
    );
  }

  Widget _dangerButton(
    AppTheme theme, {
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? theme.danger : Colors.transparent,
          border: Border.all(color: theme.danger, width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.label.copyWith(
            color: filled ? Colors.white : theme.danger,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _label(AppTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: theme.label),
      );

  Widget _input(AppTheme theme, TextEditingController c, String hint,
      {bool obscure = false}) {
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
            color: active ? theme.ink.withValues(alpha: 0.35) : theme.divider,
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
