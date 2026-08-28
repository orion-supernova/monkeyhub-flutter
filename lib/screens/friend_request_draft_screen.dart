import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../data/chat_repository.dart';
import '../data/request_outcome.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../keyboard/submit_on_enter.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import '../models/friend_request_message.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'room_screen.dart';

/// The draft chat that runs BEFORE a friend request is approved.
///
/// Used in two modes:
///   - **Receiver**: pass an existing [FriendRequest]. The user can read the
///     thread, append a message via [ChatRepository.appendDirectRequestMessage],
///     and Approve / Decline.
///   - **Sender (composing a new request)**: pass [target] but no [req]. The
///     screen lets you pick room type + lifetime + write an initial message,
///     then calls [ChatRepository.createDirectRequest] on first send.
class FriendRequestDraftScreen extends StatefulWidget {
  const FriendRequestDraftScreen({
    super.key,
    required this.repo,
    required this.api,
    this.req,
    this.target,
  }) : assert(req != null || target != null, 'either req or target is required');

  final ChatRepository repo;
  final ChatApi api;
  final FriendRequest? req;
  final ChatUser? target;

  @override
  State<FriendRequestDraftScreen> createState() => _FriendRequestDraftScreenState();
}

class _FriendRequestDraftScreenState extends State<FriendRequestDraftScreen> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  List<FriendRequestMessage> _messages = [];
  Subscription? _messagesSub;

  // Compose-only state (when sending fresh)
  RoomType _roomType = RoomType.regular;
  Duration _ttl = const Duration(seconds: 60);
  String? _newRequestId;
  bool _busy = false;

  /// True once this screen's request has actually been seen in the repository's
  /// live list. A subscription that hasn't delivered yet looks exactly like a
  /// request that has just been answered, so nothing may be concluded from an
  /// absence until presence has been observed at least once.
  bool _sawPending = false;

  /// Set the moment the request stops being pending, so the repository listener
  /// and the local Approve/Decline/Cancel handlers can't both navigate.
  bool _resolved = false;

  /// Runs while the row is gone and no friendship has shown up to explain it.
  /// See [requestAbsenceGrace]: the accept and the friendship arrive on two
  /// different subscriptions, so for a moment an accept is indistinguishable
  /// from a decline. Nothing is concluded until this has expired.
  Timer? _absenceTimer;
  bool _absenceSettled = false;

  /// Whether the draft thread ever carried a message — latched, because
  /// `approveDirectRequest` migrates those messages into the new room and
  /// clears the thread, after which an empty payload no longer distinguishes
  /// "had a conversation" from "never wrote anything". It's the same condition
  /// the backend uses to decide whether approval creates a room at all.
  bool _hadDraftMessages = false;

  static const _ttls = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(hours: 1),
  ];

  String get _requestId => _newRequestId ?? widget.req?.id ?? '';
  ChatUser get _otherUser => widget.req?.user ?? widget.target!;

  @override
  void initState() {
    super.initState();
    // Both request lists on the repository are live Convex subscriptions, so
    // the answer to this request arrives here as an ordinary change
    // notification — see [_onRepoChanged].
    widget.repo.addListener(_onRepoChanged);
    if (widget.req != null) {
      _roomType = widget.req!.roomType;
      _ttl = widget.req!.messageLifetime ?? _ttl;
      _watchMessages();
    }
    // Pull the composer up the moment the screen lands — the user opened this
    // screen to write something, so the keyboard should already be there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocus.requestFocus();
      // First read of the live lists deferred to here: a request already
      // answered before this screen opened resolves by navigating, which is
      // not something [initState] may do.
      _onRepoChanged();
    });
  }

  /// Live draft thread.
  ///
  /// This used to be a 3-second poll that only ran on the receiving side, which
  /// left the sender's half of the exchange frozen the whole time it mattered:
  /// they'd send, and then nothing on the screen ever moved again.
  Future<void> _watchMessages() async {
    final id = _requestId;
    if (id.isEmpty) return;
    try {
      _messagesSub?.cancel();
      _messagesSub = await widget.repo.cv.subscribe(
        'friends:listDirectRequestMessages',
        {'requestId': id},
        onData: (data) {
          if (!mounted) return;
          final list = (data as List?) ?? const [];
          final ms = list
              .map((e) => FriendRequestMessage.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList();
          if (ms.isNotEmpty) _hadDraftMessages = true;
          setState(() => _messages = ms);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        },
        onError: (err) => debugPrint('request messages sub error: $err'),
      );
    } catch (_) {/* live list still resolves the request either way */}
  }

  /// The other side answered — or withdrew — while this screen was open.
  ///
  /// The rule itself lives in `request_outcome.dart`; see there for why an
  /// absent row is not on its own an answer.
  void _onRepoChanged() {
    if (_resolved) return;
    final id = _requestId;
    if (id.isEmpty) return;

    final live = _isIncoming
        ? widget.repo.incomingRequests
        : widget.repo.outgoingRequests;
    final present = live.any((r) => r.id == id);
    if (present) {
      _sawPending = true;
      // The row came back (a reconnect replaying the list, say). Whatever
      // absence was being timed is no longer the absence to judge.
      _absenceTimer?.cancel();
      _absenceTimer = null;
      _absenceSettled = false;
    }

    final outcome = requestOutcome(
      requestId: id,
      otherUserId: _otherUser.id,
      live: live,
      friends: widget.repo.friends,
      sawPending: _sawPending,
      absenceSettled: _absenceSettled,
    );
    if (outcome == RequestOutcome.pending) {
      // Unexplained absence: hold the verdict open long enough for the
      // friends list to deliver the other half of the same transaction.
      if (!present && _sawPending && _absenceTimer == null) {
        _absenceTimer = Timer(requestAbsenceGrace, () {
          _absenceTimer = null;
          _absenceSettled = true;
          _onRepoChanged();
        });
      }
      return;
    }

    _absenceTimer?.cancel();
    _absenceTimer = null;
    _resolved = true;
    _finish(accepted: outcome == RequestOutcome.accepted);
  }

  void _finish({required bool accepted}) {
    _messagesSub?.cancel();
    _messagesSub = null;
    if (!mounted) return;
    // Approval turns a draft thread into a real room, and the messages move
    // with it — so land in the room, exactly where the approver lands. With no
    // messages the backend creates no room, and there is nothing to open.
    if (accepted && _hadDraftMessages) {
      _openAcceptedRoom();
      return;
    }
    final nav = Navigator.of(context);
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    nav.pop();
    toast.show(
      accepted
          ? loc.friendRequestDraftScreenAcceptedSnackbar(_otherUser.displayName)
          : _isIncoming
              ? loc.friendRequestDraftScreenWithdrawnSnackbar
              // Deliberately not "they declined": for a supervised sender the
              // "no" may have come from a grown-up, and the row's absence
              // can't tell the two apart.
              : loc.friendRequestDraftScreenDeclinedSnackbar,
      tone: accepted ? ToastTone.success : ToastTone.neutral,
    );
  }

  Future<void> _openAcceptedRoom() async {
    try {
      // Get-or-create against the same `dm:<key>:<a>:<b>` name approval used,
      // so this returns the room approval just made rather than a second one.
      final roomId = await widget.repo.openDmWith(
        _otherUser,
        roomType: _roomType,
        messageLifetime: _roomType == RoomType.secret ? _ttl : null,
      );
      if (!mounted) return;
      _leaveFor(roomId);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  /// Swaps this screen for [roomId] — the draft is spent once it has a room.
  void _leaveFor(String roomId) {
    final nav = Navigator.of(context);
    if (context.isExpanded) {
      // Desktop: dismiss this full-screen draft and open the room in the
      // chat pane instead of replacing the route.
      nav.pop();
      SettingsStore.instance.setSection(HomeSection.chat);
      UiSelectionStore.instance.selectRoom(roomId);
    } else {
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) =>
              RoomScreen(roomId: roomId, repo: widget.repo, api: widget.api)));
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    final text = _composer.text.trim();
    final isCreating = _newRequestId == null && widget.req == null;
    // Appending to an existing thread still requires text — empty taps are
    // a no-op. Creating a fresh request, however, can fire with no message.
    if (!isCreating && text.isEmpty) return;
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    setState(() => _busy = true);
    _composer.clear();

    try {
      if (isCreating) {
        final id = await widget.repo.createDirectRequest(
          friendId: widget.target!.id,
          roomType: _roomType,
          messageLifetime: _roomType == RoomType.secret ? _ttl : null,
          initialMessage: text.isEmpty ? null : text,
        );
        setState(() => _newRequestId = id);
        // Only now does the sender have a request to watch: the draft thread
        // and the accept/decline that ends it.
        await _watchMessages();
      } else {
        await widget.repo.appendDirectRequestMessage(
          requestId: _requestId,
          content: text,
        );
      }
    } catch (e) {
      // Re-fill composer so user doesn't lose what they typed.
      if (text.isNotEmpty) _composer.text = text;
      // Privacy-preserving error mapping. Block stays under generic
      // "couldn't send" — it must never reveal it's a block.
      final s = e.toString();
      final msg = s.contains('UNBLOCK_FIRST')
          ? loc.friendRequestDraftScreenErrorBlocked
          : s.contains('NOT_ACCEPTING_REQUESTS')
              ? loc.friendRequestDraftScreenErrorNotAccepting
              : loc.friendRequestDraftScreenErrorSendFailed;
      toast.show(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    // Claimed before the round trip: the same accept lands on the live lists a
    // moment later, and [_onRepoChanged] must not navigate on top of this.
    _resolved = true;
    final nav = Navigator.of(context);
    final roomId = await widget.repo.approveDirectRequest(_otherUser.id);
    if (!mounted) return;
    if (roomId != null) {
      _leaveFor(roomId);
    } else {
      nav.pop();
    }
  }

  Future<void> _reject() async {
    _resolved = true;
    final nav = Navigator.of(context);
    await widget.repo.rejectDirectRequest(_otherUser.id);
    if (!mounted) return;
    nav.pop();
  }

  Future<void> _cancel() async {
    _resolved = true;
    final nav = Navigator.of(context);
    await widget.repo.cancelDirectRequest(_otherUser.id);
    if (!mounted) return;
    nav.pop();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChanged);
    _absenceTimer?.cancel();
    _messagesSub?.cancel();
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isIncoming => widget.req != null;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final me = widget.repo.userId ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: theme.backgroundLayer(context)),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  _Header(user: _otherUser, isIncoming: _isIncoming, roomType: _roomType, ttl: _ttl, api: widget.api),
                  if (!_isIncoming && _newRequestId == null) _ComposeConfig(
                    theme: theme,
                    roomType: _roomType,
                    ttl: _ttl,
                    onRoomType: (t) => setState(() => _roomType = t),
                    onTtl: (d) => setState(() => _ttl = d),
                    ttls: _ttls,
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) return _Intro(otherUser: _otherUser, isIncoming: _isIncoming);
                        final m = _messages[i - 1];
                        final isMine = m.userId == me;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              if (!isMine) ...[
                                UserAvatar(user: _otherUser, size: 28, api: widget.api),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: messageMaxWidth(context)),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                    decoration: theme.bubbleDecoration(
                                        isMine: isMine,
                                        ephemeral: _roomType == RoomType.secret,
                                        style: SettingsStore.instance.bubbleStyle),
                                    child: Text(m.content,
                                        style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isIncoming) _ApproveBar(onApprove: _approve, onReject: _reject),
                  if (!_isIncoming && _newRequestId == null)
                    _SendRequestBar(busy: _busy, onSend: _send),
                  _Composer(
                    controller: _composer,
                    focusNode: _composerFocus,
                    onSend: _send,
                    ephemeral: _roomType == RoomType.secret,
                    ttl: _ttl,
                    busy: _busy,
                    requestMode: !_isIncoming && _newRequestId == null,
                  ),
                  if (!_isIncoming && _newRequestId != null) _CancelBar(onCancel: _cancel),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.isIncoming,
    required this.roomType,
    required this.ttl,
    required this.api,
  });
  final ChatUser user;
  final bool isIncoming;
  final RoomType roomType;
  final Duration ttl;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
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
          ),
          const SizedBox(width: 4),
          UserAvatar(user: user, size: 36, api: api),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: theme.displaySmall),
                Row(children: [
                  Text(
                      isIncoming
                          ? AppLocalizations.of(context).friendRequestDraftScreenIncomingRequestLabel
                          : AppLocalizations.of(context).friendRequestDraftScreenNewRequestLabel,
                      style: theme.monoTiny.copyWith(color: theme.accent)),
                  const SizedBox(width: 6),
                  if (roomType == RoomType.secret) EphemeralBadge(ttl: ttl, dense: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.otherUser, required this.isIncoming});
  final ChatUser otherUser;
  final bool isIncoming;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          isIncoming
              ? loc.friendRequestDraftScreenIntroIncoming(otherUser.displayName)
              : loc.friendRequestDraftScreenIntroOutgoing,
          style: theme.bodyEmph,
        ),
        const SizedBox(height: 8),
        Text(
          loc.friendRequestDraftScreenIntroFooter,
          style: theme.bodySoft,
        ),
      ]),
    );
  }
}

class _ComposeConfig extends StatelessWidget {
  const _ComposeConfig({
    required this.theme,
    required this.roomType,
    required this.ttl,
    required this.onRoomType,
    required this.onTtl,
    required this.ttls,
  });
  final AppTheme theme;
  final RoomType roomType;
  final Duration ttl;
  final ValueChanged<RoomType> onRoomType;
  final ValueChanged<Duration> onTtl;
  final List<Duration> ttls;

  String _fmt(BuildContext context, Duration d) {
    final loc = AppLocalizations.of(context);
    if (d.inSeconds < 60) return loc.friendRequestDraftScreenDurationSeconds(d.inSeconds);
    if (d.inMinutes < 60) return loc.friendRequestDraftScreenDurationMinutes(d.inMinutes);
    return loc.friendRequestDraftScreenDurationHours(d.inHours);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.friendRequestDraftScreenRoomTypeLabel, style: theme.label),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in RoomType.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onRoomType(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: theme.chipDecoration(filled: roomType == t),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (t == RoomType.secret) ...[
                        theme.hourglassIcon(size: 10.0, color: roomType == t ? theme.accentInk : theme.accent),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        t == RoomType.secret
                            ? loc.friendRequestDraftScreenRoomTypeEphemeral
                            : loc.friendRequestDraftScreenRoomTypeStandard,
                        style: theme.label.copyWith(
                            color: roomType == t ? theme.accentInk : theme.inkSoft),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
          if (roomType == RoomType.secret) ...[
            const SizedBox(height: 14),
            Row(children: [
              Text(loc.friendRequestDraftScreenLifetimeLabel, style: theme.label),
              const SizedBox(width: 10),
              Text(_fmt(context, ttl), style: theme.monoLarge.copyWith(color: theme.accent)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final t in ttls)
                GestureDetector(
                  onTap: () => onTtl(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: theme.chipDecoration(filled: ttl == t),
                    child: Text(_fmt(context, t),
                        style: theme.label.copyWith(
                            color: ttl == t ? theme.accentInk : theme.inkSoft)),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.ephemeral,
    required this.ttl,
    required this.busy,
    this.focusNode,
    this.requestMode = false,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool ephemeral;
  final Duration ttl;
  final bool busy;
  /// True when this composer is in fresh-outgoing-request mode. Adjusts the
  /// hint so the user understands a message is optional (the SEND REQUEST
  /// button above already fires without one).
  final bool requestMode;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              // No `onSubmitted`: a multi-line TextField never fires it.
              // See lib/keyboard/submit_on_enter.dart.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: theme.body.copyWith(color: theme.ink),
                  cursorColor: theme.accent,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: requestMode
                        ? (ephemeral
                            ? loc.friendRequestDraftScreenHintWhisperOptional
                            : loc.friendRequestDraftScreenHintFirstMessageOptional)
                        : (ephemeral
                            ? loc.friendRequestDraftScreenHintWhisperFades
                            : loc.friendRequestDraftScreenHintStartWith),
                    hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: busy ? null : onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: busy ? theme.accentSoft : theme.accent,
                shape: BoxShape.circle,
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentInk),
                    )
                  : Icon(Icons.north_east, color: theme.accentInk, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproveBar extends StatelessWidget {
  const _ApproveBar({required this.onApprove, required this.onReject});
  final VoidCallback onApprove;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onApprove,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(loc.friendRequestDraftScreenApproveButton,
                    style: theme.label.copyWith(color: theme.accentInk)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onReject,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.divider),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(loc.friendRequestDraftScreenDeclineButton, style: theme.label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.onCancel});
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onCancel,
        child: Text(AppLocalizations.of(context).friendRequestDraftScreenCancelRequestButton,
            style: theme.label.copyWith(color: theme.danger)),
      ),
    );
  }
}

/// Primary CTA in the fresh-outgoing-request flow. Fires whatever's in the
/// composer (text becomes the optional first message; empty sends the
/// request with no message at all).
class _SendRequestBar extends StatelessWidget {
  const _SendRequestBar({required this.busy, required this.onSend});
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: GestureDetector(
        onTap: busy ? null : onSend,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: busy ? theme.accentSoft : theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            boxShadow: busy
                ? null
                : [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: theme.accentInk),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.paperplane_fill, size: 14, color: theme.accentInk),
                    const SizedBox(width: 10),
                    Text(
                      FamilyService.maybeInstance?.isChild == true
                          ? AppLocalizations.of(context).friendRequestDraftScreenAskGrownUpButton
                          : AppLocalizations.of(context).friendRequestDraftScreenSendRequestButton,
                      style: theme.label.copyWith(
                        color: theme.accentInk,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
