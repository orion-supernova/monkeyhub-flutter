import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../media/upload_service.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'friend_request_draft_screen.dart';
import 'room_screen.dart';

/// Profile screen.
///
/// Pass [repo] + [api] to enable interactive actions (edit own profile,
/// send/cancel friend requests, open DM). If both are null this renders a
/// read-only view (used as a Phase-1 fallback).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user, this.repo, this.api});
  final ChatUser user;
  final ChatRepository? repo;
  final ChatApi? api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ChatUser? _user;
  bool _loading = false;
  bool _editing = false;
  bool _busy = false;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _bio = TextEditingController();

  bool get _isMe => widget.repo?.userId == widget.user.id;
  ChatUser get _u => _user ?? widget.user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _name.text = widget.user.name;
    _email.text = widget.user.email ?? '';
    _bio.text = widget.user.bio ?? '';
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final fresh = await api.getProfile(widget.user.id);
      if (!mounted || fresh == null) return;
      // Preserve friendship status / requestId from the calling list since
      // users.getProfile doesn't return those.
      setState(() {
        _user = fresh.copyWith(
          friendshipStatus: widget.user.friendshipStatus,
          requestId: widget.user.requestId,
        );
        _name.text = fresh.name;
        _email.text = fresh.email ?? '';
        _bio.text = fresh.bio ?? '';
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo == null) return;
    final id = repo.userId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await api.updateProfile(
        userId: id,
        name: _name.text.trim().isEmpty ? widget.user.username : _name.text.trim(),
        email: _email.text.trim(),
        bio: _bio.text.trim(),
      );
      await _refresh();
      if (mounted) setState(() => _editing = false);
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _friendshipAction() async {
    final repo = widget.repo;
    final api = widget.api;
    if (repo == null || api == null) return;
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      switch (_u.friendshipStatus) {
        case FriendshipStatus.none:
          if (!mounted) return;
          nav.push(MaterialPageRoute(
            builder: (_) => FriendRequestDraftScreen(repo: repo, api: api, target: _u),
          ));
          break;
        case FriendshipStatus.outgoingPending:
          await repo.cancelDirectRequest(_u.id);
          break;
        case FriendshipStatus.incomingPending:
          final roomId = await repo.approveDirectRequest(_u.id);
          if (!mounted) return;
          if (roomId != null) {
            nav.push(MaterialPageRoute(
                builder: (_) => RoomScreen(roomId: roomId, repo: repo, api: api)));
          }
          break;
        case FriendshipStatus.friend:
          final roomId = await repo.openDmWith(_u);
          if (!mounted) return;
          nav.push(MaterialPageRoute(
              builder: (_) => RoomScreen(roomId: roomId, repo: repo, api: api)));
          break;
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo?.userId == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final uploader = UploadService(api);
      final storageId = await uploader.uploadXFile(
        file: File(picked.path),
        contentType: 'image/jpeg',
      );
      await api.updateAvatar(userId: repo!.userId!, storageId: storageId);
      await _refresh();
    } catch (_) {/* silent — user can retry */} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFriend() async {
    final repo = widget.repo;
    if (repo == null) return;
    setState(() => _busy = true);
    try {
      await repo.removeFriend(_u.id);
      if (mounted) {
        setState(() {
          _user = _u.copyWith(friendshipStatus: FriendshipStatus.none);
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _actionLabel() {
    switch (_u.friendshipStatus) {
      case FriendshipStatus.none:
        return 'SEND REQUEST';
      case FriendshipStatus.outgoingPending:
        return 'CANCEL REQUEST';
      case FriendshipStatus.incomingPending:
        return 'APPROVE';
      case FriendshipStatus.friend:
        return 'OPEN DM';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                  ),
                  const Spacer(),
                  if (_isMe && !_editing)
                    GestureDetector(
                      onTap: () => setState(() => _editing = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: theme.chipDecoration(),
                        child: Text('EDIT', style: theme.label),
                      ),
                    ),
                ]),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isMe && !_busy ? _pickAndUploadAvatar : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(user: _u, size: 96, api: widget.api),
                          if (_isMe)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.background, width: 2),
                                ),
                                child: Icon(Icons.camera_alt_outlined,
                                    size: 14, color: theme.accentInk),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_u.displayName, style: theme.displayLarge),
                          const SizedBox(height: 6),
                          Text('@${_u.username}', style: theme.mono.copyWith(color: theme.inkMuted)),
                          if (_u.status != null) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: _u.status == 'online' ? theme.success : theme.inkMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(_u.status!.toUpperCase(), style: theme.monoTiny),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_editing && _isMe)
                  _editForm(theme)
                else
                  _readView(theme),

                if (!_isMe && widget.repo != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Action(
                          label: _busy ? '…' : _actionLabel(),
                          filled: _u.friendshipStatus != FriendshipStatus.outgoingPending,
                          onTap: _busy ? null : _friendshipAction,
                        ),
                      ),
                      if (_u.friendshipStatus == FriendshipStatus.friend) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Action(
                            label: 'UNFRIEND',
                            filled: false,
                            onTap: _busy ? null : _removeFriend,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                if (_loading) ...[
                  const SizedBox(height: 24),
                  Center(child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readView(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_u.bio != null && _u.bio!.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: theme.roomCardDecoration(ephemeral: false, active: false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ABOUT', style: theme.label),
                const SizedBox(height: 8),
                Text('"${_u.bio!}"', style: theme.bodyEmph),
              ],
            ),
          ),
        if (_u.email != null && _u.email!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _kv(theme, 'EMAIL', _u.email!),
        ],
      ],
    );
  }

  Widget _kv(AppTheme theme, String k, String v) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text(k, style: theme.label)),
      Expanded(child: Text(v, style: theme.body)),
    ]);
  }

  Widget _editForm(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(theme, 'NAME'),
        _input(theme, _name, 'how the room will read you'),
        const SizedBox(height: 14),
        _label(theme, 'EMAIL · OPTIONAL'),
        _input(theme, _email, 'only for recovery, never shown'),
        const SizedBox(height: 14),
        _label(theme, 'BIO · OPTIONAL'),
        _input(theme, _bio, 'one line that\'s true today', maxLines: 3),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: _Action(label: _busy ? '…' : 'SAVE', filled: true, onTap: _busy ? null : _save),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Action(
              label: 'CANCEL',
              filled: false,
              onTap: _busy ? null : () => setState(() {
                _editing = false;
                _name.text = _u.name;
                _email.text = _u.email ?? '';
                _bio.text = _u.bio ?? '';
              }),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _label(AppTheme theme, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: theme.label),
      );

  Widget _input(AppTheme theme, TextEditingController c, String hint, {int maxLines = 1}) {
    return Container(
      decoration: theme.inputDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
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

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (onTap == null ? theme.accentSoft : theme.accent)
              : Colors.transparent,
          border: Border.all(color: filled ? theme.accent : theme.divider, width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(label,
            style: theme.label.copyWith(color: filled ? theme.accentInk : theme.ink)),
      ),
    );
  }
}
