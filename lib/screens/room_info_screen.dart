import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../media/image_raster.dart';
import '../media/upload_service.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import '../widgets/remote_image.dart';
import '../widgets/steady_hero.dart';
import '../widgets/user_avatar.dart';
import 'fullscreen_image_viewer.dart';
import 'image_crop_screen.dart';
import 'profile_screen.dart';

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
  Subscription? _membersSub;
  String _membersSig = '';
  ChatRoom? _lastObservedRoom;

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
    final r = _room;
    // Repo fires for typing/messages/read-receipts which don't affect this
    // screen — naïvely rebuilding on every notify caused scroll stutter
    // because each frame during a drag triggered a full settings rebuild.
    // Only setState when fields actually rendered here change.
    if (_isSameRelevantFields(r, _lastObservedRoom)) {
      _lastObservedRoom = r;
      return;
    }
    _lastObservedRoom = r;
    setState(() {});
  }

  bool _isSameRelevantFields(ChatRoom? a, ChatRoom? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.name == b.name &&
        a.description == b.description &&
        a.avatarStorageId == b.avatarStorageId &&
        a.isPrivate == b.isPrivate &&
        a.hasPassword == b.hasPassword &&
        a.messageLifetime == b.messageLifetime &&
        a.createdBy == b.createdBy &&
        a.memberCount == b.memberCount;
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
    // Live subscription so presence (status/lastSeen) and any member-list
    // changes propagate without needing the screen to be re-opened.
    //
    // Convex re-fires this whenever any roomMembers row in the room is
    // written — including read-receipts (`markRoomRead` patches lastReadAt),
    // which can fire often during active chat. We don't render lastReadAt
    // here, so a content-signature dedup avoids gratuitous rebuilds. Without
    // it, rebuilds during overscroll fight the bounce physics and the
    // scroll view visibly jitters at top/bottom edges.
    try {
      _membersSub?.cancel();
      _membersSub = await widget.repo.cv.subscribe(
        'rooms:getMembers',
        {'roomId': widget.roomId},
        onData: (data) {
          if (!mounted) return;
          final list = (data as List?) ?? const [];
          final fresh = list
              .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
          final sig = _signatureFor(fresh);
          if (sig == _membersSig) return;
          _membersSig = sig;
          setState(() => _members = fresh);
        },
        onError: (err) => debugPrint('members sub error: $err'),
      );
    } catch (_) {/* offline — leave empty */}
  }

  /// Stable string fingerprint over the fields this screen actually renders.
  /// Order-insensitive so reorders from the server don't trigger a rebuild
  /// (the screen sorts members locally for display).
  String _signatureFor(List<ChatUser> users) {
    final parts = users
        .map((u) =>
            '${u.id}|${u.status ?? ''}|${u.lastSeen?.millisecondsSinceEpoch ?? 0}|${u.name}|${u.avatarStorageId ?? ''}|${u.role ?? ''}')
        .toList()
      ..sort();
    return parts.join(';');
  }

  @override
  void dispose() {
    _membersSub?.cancel();
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
      imageQuality: pickerImageQuality,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    // Crop before anything is marked in-flight, so cancelling here needs no
    // state reset at all.
    final cropped = await ImageCropScreen.open(
      context,
      source: bytes,
      shape: CropShape.circle,
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uploader = UploadService(widget.api);
      final storageId = await uploader.uploadFile(
        bytes: cropped.bytes,
        contentType: cropped.contentType,
      );
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

    // A DM has no name/visibility/password of its own — it's just the two
    // people. Resolve the other person so we show their name and avatar
    // instead of the internal "dm:regular:<id>:<id>" key.
    final peer = r.isDm ? _dmPeer() : null;
    final title = peer?.displayName ?? r.name;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: Column(
              children: [
                _header(theme, r, title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _avatarBlock(theme, r, peer),
                        const SizedBox(height: 26),
                        // Name/visibility don't apply to a 1:1 DM — the room is
                        // just the two people.
                        if (!r.isDm) ...[
                          LabeledField(
                            label: 'NAME',
                            controller: _name,
                            hint: 'room name',
                          ),
                          const SizedBox(height: 18),
                        ],
                        LabeledField(
                          label: 'DESCRIPTION',
                          controller: _desc,
                          hint: 'one line about the room…',
                        ),
                        if (!r.isDm) ...[
                          const SizedBox(height: 22),
                          const FieldLabel('VISIBILITY'),
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
                        ],
                        if (r.isEphemeral) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            const FieldLabel('MESSAGE LIFE'),
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
                        if (_isOwner && !r.isDm) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            const FieldLabel('PASSWORD'),
                            const Spacer(),
                            if (r.hasPassword)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.accent.withValues(alpha: 0.12),
                                  border: Border.all(color: theme.accent, width: 1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 10, color: theme.accent),
                                    const SizedBox(width: 5),
                                    Text('LOCKED', style: theme.monoTiny.copyWith(color: theme.accent)),
                                  ],
                                ),
                              )
                            else
                              Text('NONE', style: theme.monoTiny.copyWith(color: theme.inkMuted)),
                          ]),
                          if (r.hasPassword) ...[
                            const SizedBox(height: 6),
                            Text(
                              'this room is protected. the existing passphrase isn\'t shown for security — enter a new one to replace it.',
                              style: theme.bodySoft.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                          ],
                          PasswordField(
                            controller: _newPassword,
                            hint: r.hasPassword
                                ? 'replace passphrase…'
                                : 'lock with a passphrase…',
                          ),
                          if (r.hasPassword) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: busy ? null : _clearPassword,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: theme.danger.withValues(alpha: 0.55), width: 1),
                                    borderRadius: BorderRadius.circular(theme.radiusMd),
                                  ),
                                  child: Text(
                                    'REMOVE PASSWORD',
                                    style: theme.monoTiny.copyWith(color: theme.danger, letterSpacing: 1.4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 28),
                        FieldLabel('MEMBERS · ${_members.length}'),
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
          ),
        ],
      ),
    );
  }

  /// The other participant in a DM, resolved from the live member list (which
  /// is populated for any DM, unlike the friends-only cache). Null while members
  /// are still loading or for non-DM rooms.
  ChatUser? _dmPeer() {
    final me = widget.repo.userId;
    for (final m in _members) {
      if (m.id != me) return m;
    }
    final room = _room;
    return room == null ? null : widget.repo.otherUserFor(room);
  }

  Widget _header(AppTheme theme, ChatRoom r, String title) {
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
                Text(r.isDm ? 'CONVERSATION' : 'ROOM SETTINGS', style: theme.monoTiny),
                const SizedBox(height: 2),
                Text(title, style: theme.displayMedium, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Diameter of the avatar at the top of this screen.
  static const _avatarSize = 92.0;

  /// How far the camera badge hangs past the avatar's circle.
  static const _badgeOverhang = 2.0;

  void _openAvatarFullscreen({
    required String storageId,
    required Object heroTag,
  }) {
    FullscreenImageViewer.openAvatar(
      context,
      storageId: storageId,
      api: widget.api,
      heroTag: heroTag,
      sourceSize: _avatarSize,
    );
  }

  Widget _avatarBlock(AppTheme theme, ChatRoom r, ChatUser? peer) {
    const size = _avatarSize;
    // A DM shows the other person's avatar, and it isn't editable — you can't
    // rename or re-skin someone else.
    if (r.isDm) {
      final peerStorageId = peer?.avatarStorageId;
      // A gradient-initials placeholder isn't worth a fullscreen route, so the
      // tap only arms once there's a real picture behind it.
      final canViewPeer = peerStorageId != null && peerStorageId.isNotEmpty;
      return Center(
        child: Column(
          children: [
            if (peer != null)
              Builder(builder: (context) {
                final avatar = UserAvatar(user: peer, size: size, api: widget.api);
                if (!canViewPeer) return avatar;
                final heroTag = 'room-info-peer-avatar-${peer.id}';
                return FocusableTap(
                  onTap: () => _openAvatarFullscreen(
                    storageId: peerStorageId,
                    heroTag: heroTag,
                  ),
                  shape: FocusRingShape.circle,
                  semanticLabel: 'view profile picture',
                  child: GestureDetector(
                    onTap: () => _openAvatarFullscreen(
                      storageId: peerStorageId,
                      heroTag: heroTag,
                    ),
                    child: SteadyHero(tag: heroTag, child: avatar),
                  ),
                );
              })
            else
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: theme.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.divider),
                ),
                child: Icon(Icons.person_outline, color: theme.inkMuted, size: 32),
              ),
            if (peer != null) ...[
              const SizedBox(height: 8),
              Text('@${peer.username}', style: theme.monoTiny),
            ],
          ],
        ),
      );
    }
    final hasAvatar = r.avatarStorageId != null && r.avatarStorageId!.isNotEmpty;
    final heroTag = 'room-info-avatar-${r.id}';
    final Widget picture = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? SteadyHero(
              tag: heroTag,
              child: RemoteImage(
                storageId: r.avatarStorageId!,
                api: widget.api,
                width: size,
                height: size,
                borderRadius: BorderRadius.circular(size),
              ),
            )
          : Center(
              child: Icon(Icons.tag, color: theme.inkMuted, size: 32),
            ),
    );
    return Center(
      // The picture is for looking at; editing lives on the badge. Tapping the
      // image itself used to open the picker, which meant a room's avatar was
      // the one picture in the app you could never actually see.
      child: SizedBox(
        width: size + _badgeOverhang,
        height: size + _badgeOverhang,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: hasAvatar
                  ? FocusableTap(
                      onTap: () => _openAvatarFullscreen(
                        storageId: r.avatarStorageId!,
                        heroTag: heroTag,
                      ),
                      shape: FocusRingShape.circle,
                      semanticLabel: 'view room picture',
                      child: GestureDetector(
                        onTap: () => _openAvatarFullscreen(
                          storageId: r.avatarStorageId!,
                          heroTag: heroTag,
                        ),
                        child: picture,
                      ),
                    )
                  : picture,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: FocusableTap(
                onTap: _saving ? null : _changeAvatar,
                shape: FocusRingShape.circle,
                semanticLabel: hasAvatar ? 'change room picture' : 'add room picture',
                child: GestureDetector(
                  onTap: _saving ? null : _changeAvatar,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.background, width: 2),
                    ),
                    child: Icon(Icons.camera_alt_outlined, size: 14, color: theme.accentInk),
                  ),
                ),
              ),
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
    final me = widget.repo.userId;
    return Column(
      children: [
        for (final m in ordered)
          GestureDetector(
            onTap: m.id == me
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          user: m,
                          repo: widget.repo,
                          api: widget.api,
                        ),
                      ),
                    ),
            behavior: HitTestBehavior.opaque,
            child: Padding(
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
                  if (m.id != me) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
                  ],
                ],
              ),
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

  Widget _seg(AppTheme theme, {
    required bool active,
    required VoidCallback onTap,
    required Widget icon,
    required String title,
    required String sub,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          // Active uses the accent color across border + faint fill so the
          // selected state reads clearly on every theme, independent of
          // surfaceRaised/surfaceSunken contrast.
          color: active ? theme.accent.withValues(alpha: 0.12) : theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          // Constant border width — switching width between states caused a
          // 0.8px layout shift on toggle.
          border: Border.all(
            color: active ? theme.accent : theme.divider,
            width: 1.4,
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
                  Text(
                    title,
                    style: theme.displaySmall.copyWith(
                      color: active ? theme.accent : theme.inkSoft,
                      fontSize: 16,
                    ),
                  ),
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
