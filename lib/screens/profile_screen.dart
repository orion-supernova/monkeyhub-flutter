import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../media/upload_service.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/block_choice_sheet.dart';
import '../widgets/capture_protection_toggle.dart';
import '../widgets/labeled_field.dart';
import '../widgets/report_sheet.dart';
import '../widgets/user_avatar.dart';
import 'blocked_users_screen.dart';
import 'friend_request_draft_screen.dart';
import 'fullscreen_image_viewer.dart';
import 'image_crop_screen.dart';
import 'profile_visibility_screen.dart';
import 'release_device_screen.dart';
import 'navigation/open_room.dart';

/// Profile screen.
///
/// Pass [repo] + [api] to enable interactive actions (edit own profile,
/// send/cancel friend requests, open DM). If both are null this renders a
/// read-only view (used as a Phase-1 fallback).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user, this.repo, this.api, this.auth});
  final ChatUser user;
  final ChatRepository? repo;
  final ChatApi? api;

  /// When provided AND viewing one's own profile, an ACCOUNT section
  /// (sign out / delete) is exposed at the bottom.
  final AuthService? auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _avatarSize = 96;

  /// How far the camera badge used to poke past the avatar's edge. Kept so the
  /// badge lands on the same pixels now that it is positioned from a box that
  /// is [_badgeOverhang] larger instead of at a negative offset.
  static const double _badgeOverhang = 2;

  ChatUser? _user;
  bool _loading = false;
  bool _busy = false;
  bool _changingAvatar = false;
  bool _signingOut = false;
  bool _deletingAccount = false;
  bool _confirmDelete = false;

  bool get _isMe => widget.repo?.userId == widget.user.id;
  ChatUser get _u => _user ?? widget.user;

  @override
  void initState() {
    super.initState();
    // Eagerly resolve friendship from the repo so the first frame is correct
    // (chat-context entry points like getMembers don't compute it).
    final resolved = _resolveFriendship(widget.user.id);
    _user = widget.user.copyWith(friendshipStatus: resolved.status, requestId: resolved.requestId);
    // The account type can change underneath an open profile: a guardian
    // graduating this child from their own phone lands over the live family
    // subscription. Everything on the me-view keys off it — the ACCOUNT
    // section, whether visibility is read-only, whether "hand this phone back"
    // is offered — so repaint rather than leaving the supervised UI up.
    widget.auth?.addListener(_onAuth);
    _refresh();
  }

  @override
  void dispose() {
    widget.auth?.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final fresh = await api.getProfile(widget.user.id, viewerUserId: widget.repo?.userId);
      if (!mounted || fresh == null) return;
      // users.getProfile doesn't include friendshipStatus. Resolve it from
      // the repo's live caches (friends + pending requests) instead of
      // trusting the passed-in widget.user — that value is stale when the
      // profile is opened from a chat context (member list, message bubble,
      // DM header) where getMembers didn't compute it.
      final resolved = _resolveFriendship(widget.user.id);
      setState(() {
        _user = fresh.copyWith(friendshipStatus: resolved.status, requestId: resolved.requestId);
      });
    } catch (_) {
    } finally {
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
    final outgoing = repo.outgoingRequests.where((r) => r.user.id == userId).firstOrNull;
    if (outgoing != null) {
      return (status: FriendshipStatus.outgoingPending, requestId: outgoing.id);
    }
    final incoming = repo.incomingRequests.where((r) => r.user.id == userId).firstOrNull;
    if (incoming != null) {
      return (status: FriendshipStatus.incomingPending, requestId: incoming.id);
    }
    return (status: FriendshipStatus.none, requestId: null);
  }

  Future<void> _updateName(String next) async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo == null) return;
    final id = repo.userId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await api.updateProfile(
        userId: id,
        name: next.trim().isEmpty ? widget.user.username : next.trim(),
        email: _u.email ?? '',
      );
      await _refresh();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateEmail(String next) async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo == null) return;
    final id = repo.userId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await api.updateProfile(userId: id, name: _u.name, email: next.trim());
      await _refresh();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndEdit({
    required String title,
    required String currentValue,
    required String hint,
    required Future<void> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = ThemeScope.of(ctx);
        return Dialog(
          backgroundColor: theme.surfaceRaised,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusLg)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.displaySmall),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _Action(label: 'JUST TAPPED', filled: false, onTap: () => Navigator.of(ctx).pop(false)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Action(label: 'CHANGE', filled: true, onTap: () => Navigator.of(ctx).pop(true)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    await _editFieldSheet(
      title: title,
      currentValue: currentValue,
      hint: hint,
      onSave: onSave,
      keyboardType: keyboardType,
    );
  }

  Future<void> _editFieldSheet({
    required String title,
    required String currentValue,
    required String hint,
    required Future<void> Function(String) onSave,
    required TextInputType keyboardType,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final next = await showAdaptiveSheet<String>(
      context,
      builder: (ctx) {
        final theme = ThemeScope.of(ctx);
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: theme.sheetDecoration(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: theme.divider, borderRadius: BorderRadius.circular(2)),
                ),
                Text(title, style: theme.displaySmall),
                const SizedBox(height: 14),
                ThemedInput(
                  controller: controller,
                  hint: hint,
                  keyboardType: keyboardType,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Action(label: 'CANCEL', filled: false, onTap: () => Navigator.of(ctx).pop()),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Action(label: 'SAVE', filled: true, onTap: () => Navigator.of(ctx).pop(controller.text)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (next == null) return;
    await onSave(next);
  }

  Future<void> _signOut() async {
    final auth = widget.auth;
    if (auth == null || _busy) return;
    setState(() {
      _busy = true;
      _signingOut = true;
    });
    final nav = Navigator.of(context);
    try {
      await auth.signOut();
      if (!mounted) return;
      // Pop everything stacked above the home route. The home route is the
      // auth-reactive `_AppHome` in app.dart — once `auth.signOut()` flips
      // `isSignedIn` to false, that home rebuilds to `LoginScreen` on its
      // own. Pushing a fresh `LoginScreen` here would stack a second copy
      // on top of `_AppHome`, so the next `signIn` swap (which happens
      // inside `_AppHome`) would be hidden under that stacked route.
      nav.popUntil((r) => r.isFirst);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _signingOut = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final auth = widget.auth;
    if (auth == null || _busy) return;
    setState(() {
      _busy = true;
      _deletingAccount = true;
    });
    final nav = Navigator.of(context);
    try {
      await auth.deleteAccount();
      if (!mounted) return;
      nav.popUntil((r) => r.isFirst);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deletingAccount = false;
        });
      }
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
          nav.push(
            MaterialPageRoute(
              builder: (_) => FriendRequestDraftScreen(repo: repo, api: api, target: _u),
            ),
          );
          break;
        case FriendshipStatus.outgoingPending:
          await repo.cancelDirectRequest(_u.id);
          break;
        case FriendshipStatus.incomingPending:
          final roomId = await repo.approveDirectRequest(_u.id);
          if (!mounted) return;
          if (roomId != null) {
            openRoom(context, roomId: roomId, repo: repo, api: api);
          }
          break;
        case FriendshipStatus.friend:
          final roomId = await repo.openDmWith(_u);
          if (!mounted) return;
          openRoom(context, roomId: roomId, repo: repo, api: api);
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

  /// A gradient-initials placeholder is not worth a fullscreen route, so the
  /// tap only arms once there is a real image behind it.
  bool get _canViewAvatar =>
      widget.api != null &&
      _u.avatarStorageId != null &&
      _u.avatarStorageId!.isNotEmpty;

  /// Tag shared with the [Hero] around the avatar below. Keyed on the user, not
  /// the storage id, so replacing your picture mid-session doesn't orphan it.
  String get _avatarHeroTag => 'profile-avatar-${_u.id}';

  void _openAvatarFullscreen() {
    if (!_canViewAvatar) return;
    FullscreenImageViewer.openAvatar(
      context,
      storageId: _u.avatarStorageId!,
      api: widget.api!,
      heroTag: _avatarHeroTag,
      sourceSize: _avatarSize,
    );
  }

  Future<void> _openAvatarSheet() async {
    final action = await showAvatarActionSheet(
      context,
      hasAvatar: _u.avatarStorageId != null && _u.avatarStorageId!.isNotEmpty,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case AvatarAction.download:
        await _downloadAvatar();
        break;
      case AvatarAction.capture:
        await _pickAndUploadAvatarFrom(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
        );
        break;
      case AvatarAction.library:
        await _pickAndUploadAvatarFrom(source: ImageSource.gallery);
        break;
    }
  }

  Future<void> _pickAndUploadAvatarFrom({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final api = widget.api;
    final repo = widget.repo;
    if (api == null || repo?.userId == null) return;
    // Spinner covers BOTH phases: picker/camera spin-up (the native UI can
    // take a beat to appear on cold launch) and the upload itself. Clear it
    // on cancel so the avatar returns to normal immediately.
    setState(() {
      _busy = true;
      _changingAvatar = true;
    });
    // imageQuality also normalizes EXIF orientation on Android, which the crop
    // screen relies on — keep it even though the crop re-encodes anyway.
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      preferredCameraDevice: preferredCameraDevice,
    );
    if (picked == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _changingAvatar = false;
        });
      }
      return;
    }
    if (!mounted) return;
    // _busy/_changingAvatar stay set across the crop screen: the avatar keeps
    // its spinner underneath and the sheet can't be reopened behind it.
    final cropped = await ImageCropScreen.open(
      context,
      source: File(picked.path),
      shape: CropShape.circle,
    );
    if (cropped == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _changingAvatar = false;
        });
      }
      return;
    }
    try {
      final uploader = UploadService(api);
      final storageId = await uploader.uploadXFile(
        file: cropped.file,
        contentType: cropped.contentType,
      );
      await api.updateAvatar(userId: repo!.userId!, storageId: storageId);
      await _refresh();
    } catch (_) {
      /* silent — user can retry */
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _changingAvatar = false;
        });
      }
    }
  }

  Future<void> _downloadAvatar() async {
    final api = widget.api;
    final storageId = _u.avatarStorageId;
    if (api == null || storageId == null || storageId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          messenger.showSnackBar(const SnackBar(content: Text('photo permission denied.')));
          return;
        }
      }
      final url = await api.getFileUrl(storageId);
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        throw HttpException('status ${resp.statusCode}');
      }
      await Gal.putImageBytes(resp.bodyBytes, name: 'avatar-${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('saved to photos.')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('couldn\'t save image.')));
    } finally {
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
      info = await api.listSharedRooms(userId: repo!.userId!, otherUserId: _u.id);
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
      await api.blockUser(userId: myId, targetUserId: _u.id, deleteDm: choice == BlockChoice.blockAndDelete);
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
    } catch (_) {
    } finally {
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
      await api.report(reporterId: repo!.userId!, targetType: 'user', targetId: _u.id, reason: reason);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('report sent privately. they won\'t be notified.')));
    } catch (_) {
    } finally {
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
    } catch (_) {
    } finally {
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
            child: AdaptivePageBody(
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
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sized to _avatarSize + _badgeOverhang rather than letting
                    // the Stack take the avatar's 96×96: RenderBox.hitTest bails
                    // before descending when the point is outside `size`, and
                    // Clip.none only affects painting. The badge used to sit at
                    // right/bottom -2, so its outer ~2px was unreachable.
                    SizedBox(
                      width: _avatarSize + _badgeOverhang,
                      height: _avatarSize + _badgeOverhang,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: _avatarSize,
                            height: _avatarSize,
                            child: FocusableTap(
                              onTap: _canViewAvatar ? _openAvatarFullscreen : null,
                              shape: FocusRingShape.circle,
                              semanticLabel: 'view profile picture',
                              child: GestureDetector(
                                onTap: _canViewAvatar ? _openAvatarFullscreen : null,
                                child: Builder(builder: (context) {
                                  final avatar = UserAvatar(
                                    user: _u,
                                    size: _avatarSize,
                                    api: widget.api,
                                    // Own presence is never news, and the dot
                                    // sits exactly where the camera badge goes.
                                    showStatus: !_isMe,
                                  );
                                  // Only the real-image case flies — a gradient
                                  // initials placeholder has nothing to fly to,
                                  // and mounting a Hero for it would leave a
                                  // tag with no counterpart.
                                  if (!_canViewAvatar) return avatar;
                                  return Hero(
                                    tag: _avatarHeroTag,
                                    child: avatar,
                                  );
                                }),
                              ),
                            ),
                          ),
                          if (_changingAvatar)
                            Positioned(
                              left: 0,
                              top: 0,
                              width: _avatarSize,
                              height: _avatarSize,
                              // Must not swallow taps meant for the badge.
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.45),
                                  ),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_isMe)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: FocusableTap(
                                onTap: _busy ? null : _openAvatarSheet,
                                shape: FocusRingShape.circle,
                                semanticLabel: 'change profile picture',
                                child: GestureDetector(
                                  onTap: _busy ? null : _openAvatarSheet,
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
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _isMe && widget.api != null && widget.repo != null
                                ? () => _confirmAndEdit(
                                    title: _u.name.trim().isNotEmpty ? 'change name?' : 'add name?',
                                    currentValue: _u.name,
                                    hint: 'how the room will read you',
                                    onSave: _updateName,
                                  )
                                : null,
                            behavior: HitTestBehavior.opaque,
                            child: Text(_u.displayName, style: theme.displayLarge),
                          ),
                          const SizedBox(height: 6),
                          Text('@${_u.username}', style: theme.mono.copyWith(color: theme.inkMuted)),
                          if (_isMe && widget.api != null && widget.repo != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _confirmAndEdit(
                                title: (_u.email?.isNotEmpty ?? false) ? 'change email?' : 'add email?',
                                currentValue: _u.email ?? '',
                                hint: 'only for recovery, never shown',
                                keyboardType: TextInputType.emailAddress,
                                onSave: _updateEmail,
                              ),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mail_outline, size: 12, color: theme.inkMuted),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      (_u.email?.isNotEmpty ?? false) ? _u.email! : 'add email',
                                      style: theme.mono.copyWith(
                                        color: (_u.email?.isNotEmpty ?? false) ? theme.inkSoft : theme.inkMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (!_isMe) ...[const SizedBox(height: 8), _FriendshipChip(status: _u.friendshipStatus)],
                          if (_u.status != null) ...[
                            const SizedBox(height: 8),
                            Row(children: [Text(_u.status!.toUpperCase(), style: theme.monoTiny)]),
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
                    child: Row(
                      children: [
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
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                if (_isMe) _meView(theme) else _readView(theme),

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
                          onTap: (_busy || (_u.friendshipStatus == FriendshipStatus.none && !_u.acceptsFriendRequests))
                              ? null
                              : _friendshipAction,
                        ),
                      ),
                      if (_u.friendshipStatus == FriendshipStatus.friend) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Action(label: 'UNFRIEND', filled: false, onTap: _busy ? null : _removeFriend),
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
          ),
        ],
      ),
    );
  }

  Widget _readView(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_u.email != null && _u.email!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 70, child: Text('EMAIL', style: theme.label)),
              Expanded(child: Text(_u.email!, style: theme.body)),
            ],
          ),
      ],
    );
  }

  Widget _meView(AppTheme theme) {
    final repo = widget.repo;
    final api = widget.api;
    final canPrivacy = repo != null && api != null;
    // A child has no way out of their own account — no sign out, no delete.
    // That's the point of a supervised device, so the section is absent
    // rather than disabled: a greyed-out SIGN OUT just invites nagging.
    // `AuthService` and the backend both refuse these too, in case a route
    // reaches them another way.
    //
    // What a child DOES get is "hand this phone back" below, which is not an
    // exception to the above: it releases the handset only against a grown-up's
    // release code or password, and is visible precisely because the credential
    // is the real gate. A parent who can't find the button can't use it.
    final canAccount = widget.auth != null && !widget.auth!.isChild;
    final isChildAccount = widget.auth != null && widget.auth!.isChild;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPrivacy) ...[
          _sectionHeader(theme, 'PRIVACY'),
          const SizedBox(height: 12),
          _RowLink(
            label: 'VISIBILITY PREFERENCES',
            icon: Icons.visibility_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileVisibilityScreen(
                  repo: repo,
                  api: api,
                  readOnly: widget.auth?.isChild ?? false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RowLink(
            label: 'BLOCKED USERS',
            icon: Icons.block,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlockedUsersScreen(repo: repo, api: api),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const CaptureProtectionToggle(),
        ],
        if (canAccount) ...[
          const SizedBox(height: 28),
          _sectionHeader(theme, 'ACCOUNT'),
          const SizedBox(height: 10),
          _RowActionTile(label: 'SIGN OUT', danger: false, busy: _signingOut, onTap: _signOut),
          const SizedBox(height: 8),
          _RowActionTile(
            label: _confirmDelete ? 'TAP AGAIN TO CONFIRM DELETE' : 'DELETE ACCOUNT',
            danger: true,
            busy: _deletingAccount,
            onTap: () {
              if (!_confirmDelete) {
                setState(() => _confirmDelete = true);
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _confirmDelete = false);
                });
              } else {
                _deleteAccount();
              }
            },
          ),
        ],
        if (isChildAccount) ...[
          const SizedBox(height: 28),
          _sectionHeader(theme, 'THIS PHONE'),
          const SizedBox(height: 10),
          _RowActionTile(
            label: 'HAND THIS PHONE BACK',
            danger: false,
            busy: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReleaseDeviceScreen(auth: widget.auth!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only a grown-up can do this — it needs their code or password.',
            style: theme.monoTiny.copyWith(color: theme.inkMuted),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(AppTheme theme, String t) => Row(
    children: [
      Text(t, style: theme.label),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: theme.divider)),
    ],
  );
}

class _RowLink extends StatelessWidget {
  const _RowLink({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.inkSoft),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.label)),
            Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _RowActionTile extends StatelessWidget {
  const _RowActionTile({required this.label, required this.danger, required this.busy, required this.onTap});
  final String label;
  final bool danger;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: danger ? theme.danger.withValues(alpha: 0.5) : theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(danger ? Icons.delete_outline : Icons.logout, size: 16, color: danger ? theme.danger : theme.inkSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: theme.label.copyWith(color: danger ? theme.danger : theme.ink)),
            ),
            if (busy)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent)),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.filled, required this.onTap, this.danger = false});
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
          color: filled ? (onTap == null ? theme.accentSoft : accent) : Colors.transparent,
          border: Border.all(
            color: filled ? accent : (danger ? accent.withValues(alpha: 0.45) : theme.divider),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.label.copyWith(
            color: filled ? (danger ? Colors.white : theme.accentInk) : (danger ? accent : theme.ink),
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
          Text(label, style: theme.monoTiny.copyWith(color: color, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

enum AvatarAction { download, capture, library }

Future<AvatarAction?> showAvatarActionSheet(
  BuildContext context, {
  required bool hasAvatar,
}) {
  return showAdaptiveSheet<AvatarAction>(
    context,
    builder: (ctx) {
      final theme = ThemeScope.of(ctx);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: theme.sheetDecoration(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('PROFILE PICTURE', style: theme.label),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.surface,
                    border: Border.all(color: theme.divider),
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Column(
                    children: [
                      if (hasAvatar) ...[
                        _AvatarSheetTile(
                          icon: Icons.download_outlined,
                          label: 'SAVE TO PHOTOS',
                          onTap: () => Navigator.of(ctx).pop(AvatarAction.download),
                        ),
                        Divider(height: 1, color: theme.divider),
                      ],
                      _AvatarSheetTile(
                        icon: Icons.camera_alt_outlined,
                        label: 'TAKE A SELFIE',
                        onTap: () => Navigator.of(ctx).pop(AvatarAction.capture),
                      ),
                      Divider(height: 1, color: theme.divider),
                      _AvatarSheetTile(
                        icon: Icons.photo_library_outlined,
                        label: 'CHOOSE FROM LIBRARY',
                        onTap: () => Navigator.of(ctx).pop(AvatarAction.library),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      border: Border.all(color: theme.divider),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Text('CANCEL', style: theme.label.copyWith(color: theme.inkSoft)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AvatarSheetTile extends StatelessWidget {
  const _AvatarSheetTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Bare GestureDetector, never InkWell — this app renders no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.accent),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.label.copyWith(color: theme.ink))),
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
