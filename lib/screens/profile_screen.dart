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
import '../widgets/block_choice_sheet.dart';
import '../widgets/report_sheet.dart';
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
    // Eagerly resolve friendship from the repo so the first frame is correct
    // (chat-context entry points like getMembers don't compute it).
    final resolved = _resolveFriendship(widget.user.id);
    _user = widget.user.copyWith(
      friendshipStatus: resolved.status,
      requestId: resolved.requestId,
    );
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
      final fresh = await api.getProfile(
        widget.user.id,
        viewerUserId: widget.repo?.userId,
      );
      if (!mounted || fresh == null) return;
      // users.getProfile doesn't include friendshipStatus. Resolve it from
      // the repo's live caches (friends + pending requests) instead of
      // trusting the passed-in widget.user — that value is stale when the
      // profile is opened from a chat context (member list, message bubble,
      // DM header) where getMembers didn't compute it.
      final resolved = _resolveFriendship(widget.user.id);
      setState(() {
        _user = fresh.copyWith(
          friendshipStatus: resolved.status,
          requestId: resolved.requestId,
        );
        _name.text = fresh.name;
        _email.text = fresh.email ?? '';
        _bio.text = fresh.bio ?? '';
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({FriendshipStatus status, String? requestId}) _resolveFriendship(String userId) {
    final repo = widget.repo;
    if (repo == null) {
      return (status: widget.user.friendshipStatus, requestId: widget.user.requestId);
    }
    if (repo.friends.any((f) => f.id == userId)) {
      return (status: FriendshipStatus.friend, requestId: null);
    }
    final outgoing = repo.outgoingRequests
        .where((r) => r.user.id == userId)
        .firstOrNull;
    if (outgoing != null) {
      return (status: FriendshipStatus.outgoingPending, requestId: outgoing.id);
    }
    final incoming = repo.incomingRequests
        .where((r) => r.user.id == userId)
        .firstOrNull;
    if (incoming != null) {
      return (status: FriendshipStatus.incomingPending, requestId: incoming.id);
    }
    return (status: FriendshipStatus.none, requestId: null);
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
    final messenger = ScaffoldMessenger.of(context);
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
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_humanizeAction(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Surfaces a friendly, privacy-preserving message for the actions on this
  /// screen. Critically: never reveals that the *other* user has blocked us
  /// (block stays under USER_NOT_FOUND). Not-accepting-requests IS its own
  /// honest code — it's a global toggle, not a personal judgment, and the
  /// SEND REQUEST button is already pre-disabled when we know about it.
  String _humanizeAction(Object e) {
    final s = e.toString();
    if (s.contains('UNBLOCK_FIRST')) {
      return 'you blocked this user — unblock them first.';
    }
    if (s.contains('NOT_ACCEPTING_REQUESTS')) {
      return 'they\'re not accepting friend requests right now.';
    }
    if (s.contains('USER_NOT_FOUND')) return 'this isn\'t possible right now.';
    if (s.contains('ALREADY_FRIENDS')) return 'you\'re already friends.';
    if (s.contains('REQUEST_ALREADY_PENDING')) return 'request already sent.';
    if (s.contains('REQUEST_ALREADY_RECEIVED')) {
      return 'they already sent you a request — check requests.';
    }
    return 'couldn\'t complete that.';
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

  Future<void> _confirmBlock() async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo?.userId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    // Fetch shared-room context so the confirm sheet can tailor copy.
    setState(() => _busy = true);
    SharedRoomsInfo info;
    try {
      info = await api.listSharedRooms(
        userId: repo!.userId!,
        otherUserId: _u.id,
      );
    } catch (_) {
      info = SharedRoomsInfo(groupRooms: const [], hasDm: false);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final choice = await showBlockChoiceSheet(
      context,
      displayName: _u.displayName,
      isFriend: _u.friendshipStatus == FriendshipStatus.friend,
      sharedGroupRooms: info.groupRooms,
      hasDm: info.hasDm,
      api: api,
    );
    if (choice == BlockChoice.cancel || !mounted) return;
    final myId = repo!.userId;
    if (myId == null) return;
    setState(() => _busy = true);
    try {
      await api.blockUser(
        userId: myId,
        targetUserId: _u.id,
        deleteDm: choice == BlockChoice.blockAndDelete,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            choice == BlockChoice.blockAndDelete
                ? 'blocked & DM wiped. they won\'t be notified.'
                : 'blocked. they won\'t be notified.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReport() async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo?.userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showReportSheet(context);
    if (reason == null || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await api.report(
        reporterId: repo!.userId!,
        targetType: 'user',
        targetId: _u.id,
        reason: reason,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('report sent privately. they won\'t be notified.')),
      );
    } catch (_) {} finally {
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
                          if (!_isMe) ...[
                            const SizedBox(height: 8),
                            _FriendshipChip(status: _u.friendshipStatus),
                          ],
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
                if (!_isMe && _u.isRedacted) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: theme.surfaceSunken,
                      border: Border(left: BorderSide(color: theme.accent, width: 2)),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Row(children: [
                      Icon(Icons.visibility_off_outlined, size: 14, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _u.friendshipStatus == FriendshipStatus.friend
                              ? 'some fields are hidden by their settings.'
                              : 'limited view — they share more with friends.',
                          style: theme.monoTiny.copyWith(color: theme.accent),
                        ),
                      ),
                    ]),
                  ),
                ],
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
                          label: _busy
                              ? '…'
                              : (_u.friendshipStatus == FriendshipStatus.none && !_u.acceptsFriendRequests
                                  ? 'NOT ACCEPTING REQUESTS'
                                  : _actionLabel()),
                          filled: _u.friendshipStatus != FriendshipStatus.outgoingPending,
                          onTap: (_busy ||
                                  (_u.friendshipStatus == FriendshipStatus.none && !_u.acceptsFriendRequests))
                              ? null
                              : _friendshipAction,
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Action(
                          label: 'BLOCK',
                          filled: false,
                          onTap: _busy ? null : _confirmBlock,
                          danger: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Action(
                          label: 'REPORT',
                          filled: false,
                          onTap: _busy ? null : _confirmReport,
                          danger: true,
                        ),
                      ),
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
  const _Action({
    required this.label,
    required this.filled,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final accent = danger ? theme.danger : theme.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (onTap == null ? theme.accentSoft : accent)
              : Colors.transparent,
          border: Border.all(color: filled ? accent : (danger ? accent.withValues(alpha: 0.45) : theme.divider), width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.label.copyWith(
            color: filled
                ? (danger ? Colors.white : theme.accentInk)
                : (danger ? accent : theme.ink),
          ),
        ),
      ),
    );
  }
}

class _FriendshipChip extends StatelessWidget {
  const _FriendshipChip({required this.status});
  final FriendshipStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final (label, icon, color) = switch (status) {
      FriendshipStatus.friend => ('FRIENDS', Icons.check_circle_outline, theme.success),
      FriendshipStatus.outgoingPending => ('REQUEST PENDING', Icons.schedule, theme.accent),
      FriendshipStatus.incomingPending => ('INCOMING REQUEST', Icons.markunread_mailbox_outlined, theme.accent),
      FriendshipStatus.none => ('NOT CONNECTED', Icons.person_outline, theme.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.monoTiny.copyWith(color: color, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}
