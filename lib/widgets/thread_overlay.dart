import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../screens/profile_screen.dart';
import '../theme/theme_scope.dart';
import 'message_action_menu.dart';
import 'message_bubble.dart';
import 'reaction_picker_sheet.dart';
import 'report_sheet.dart';

/// Open the thread view anchored on [currentMessageId]. Fetches the entire
/// conversational thread (ancestors + descendants via `getThread`) and
/// renders the messages as a vertically-scrolling sheet over a frosted
/// scrim — full-size bubbles, no progressive dim. The originally-tapped
/// message gets a persistent accent halo and is centered on first frame.
///
/// Long-press / double-tap on a bubble inside the sheet brings up the
/// regular action menu (Reply / Copy / Profile / Delete / Report). Reply
/// fires [onReply], which the caller uses to arm the main room composer;
/// the overlay then dismisses itself.
///
/// Dismiss: tap the scrim OR tap the close button. Vertical drag scrolls
/// the list and does NOT dismiss.
Future<void> showThreadOverlay({
  required BuildContext context,
  required ChatApi api,
  required ChatRepository repo,
  required String roomId,
  required String currentMessageId,
  required void Function(ChatMessage target) onReply,
}) async {
  final theme = ThemeScope.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);

  List<ChatMessage> chain;
  try {
    chain = await repo.fetchThread(currentMessageId);
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text("couldn't load thread")),
    );
    return;
  }
  if (chain.isEmpty || !context.mounted) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ThreadSheet(
      chain: chain,
      api: api,
      repo: repo,
      focusedMessageId: currentMessageId,
      themeMotion: theme.motionEntrance,
      onReply: onReply,
      onResolve: () {
        if (!completer.isCompleted) completer.complete();
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _ThreadSheet extends StatefulWidget {
  const _ThreadSheet({
    required this.chain,
    required this.api,
    required this.repo,
    required this.focusedMessageId,
    required this.themeMotion,
    required this.onReply,
    required this.onResolve,
  });

  final List<ChatMessage> chain;
  final ChatApi api;
  final ChatRepository repo;
  final String focusedMessageId;
  final Curve themeMotion;
  final void Function(ChatMessage target) onReply;
  final VoidCallback onResolve;

  @override
  State<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<_ThreadSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;
  // Per-message-id GlobalKeys so we can ensureVisible() the focused one and
  // anchor the action menu at the right rect on long-press.
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
    )..forward();

    for (final m in widget.chain) {
      _keys[m.id] = GlobalKey(debugLabel: 'thread-${m.id}');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[widget.focusedMessageId]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve();
  }

  Future<void> _onLongPressBubble(ChatMessage m, ChatUser? author) async {
    final isMine = m.senderId == widget.repo.userId;
    final isPending = m.id.startsWith('tmp_');
    final canReply = !isPending &&
        m.status == MessageStatus.sent &&
        m.type != MessageType.system;
    final anchor = _keys[m.id];
    if (anchor == null) return;
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await showMessageActionMenu(
      context: context,
      anchorKey: anchor,
      isMine: isMine,
      canCopy: m.type == MessageType.text && m.content.isNotEmpty,
      canReply: canReply,
      // hasParent: false — even when the message has a parent we
      // intentionally suppress the View Thread row inside this overlay to
      // prevent recursion. The user already sees the thread.
      hasParent: false,
      bubbleBuilder: (_) => m.isEphemeral
          ? EphemeralMessageBubble(
              message: m,
              now: DateTime.now(),
              currentUserId: widget.repo.userId ?? '',
              api: widget.api,
              author: author,
              useHero: false,
              showReplyIndicator: false,
            )
          : MessageBubble(
              message: m,
              now: DateTime.now(),
              currentUserId: widget.repo.userId ?? '',
              api: widget.api,
              author: author,
              useHero: false,
              showReplyIndicator: false,
            ),
    );
    if (!mounted || result == null) return;
    if (result.emoji != null) {
      await widget.repo.toggleReaction(messageId: m.id, emoji: result.emoji!);
      return;
    }
    if (result.openFullReactionPicker) {
      final emoji = await showReactionPicker(context);
      if (emoji == null || emoji.isEmpty) return;
      await widget.repo.toggleReaction(messageId: m.id, emoji: emoji);
      return;
    }
    switch (result.action!) {
      case MessageAction.reply:
        widget.onReply(m);
        await _dismiss();
        break;
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.content));
        messenger?.showSnackBar(const SnackBar(content: Text('copied')));
        break;
      case MessageAction.viewProfile:
        if (author != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                user: author,
                repo: widget.repo,
                api: widget.api,
              ),
            ),
          );
        }
        break;
      case MessageAction.delete:
        await widget.repo.deleteMessage(m.id);
        break;
      case MessageAction.report:
        if (!context.mounted) return;
        final reason = await showReportSheet(context);
        if (reason == null || reason.isEmpty) return;
        final myId = widget.repo.userId;
        if (myId == null) return;
        try {
          await widget.api.report(
            reporterId: myId,
            targetType: 'message',
            targetId: m.id,
            reason: reason,
          );
        } catch (_) {}
        break;
      case MessageAction.viewThread:
        // Suppressed (hasParent: false above ensures this row isn't shown),
        // but the switch must be exhaustive.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.themeMotion);
    final me = widget.repo.userId ?? '';
    final now = DateTime.now();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Frosted scrim. Tap to dismiss.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: AnimatedBuilder(
                animation: curved,
                builder: (_, _) {
                  final t = curved.value;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 22 * t,
                              sigmaY: 22 * t,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.32 * t),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Scrolling sheet of full-size bubbles. The sheet itself is
          // transparent (no card surface) so the scrim shows through; this
          // keeps the focus on the bubbles and matches the action-menu
          // visual language.
          Positioned.fill(
            child: SafeArea(
              child: AnimatedBuilder(
                animation: curved,
                builder: (_, child) =>
                    Opacity(opacity: curved.value, child: child),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
                  itemCount: widget.chain.length,
                  itemBuilder: (context, i) {
                    final m = widget.chain[i];
                    final author = widget.repo.userById(m.senderId) ??
                        ChatUser(
                          id: m.senderId,
                          username: m.senderName,
                          name: m.senderName,
                        );
                    final isFocused = m.id == widget.focusedMessageId;
                    final isMine = m.senderId == me;
                    final bubble = m.isEphemeral
                        ? EphemeralMessageBubble(
                            message: m,
                            now: now,
                            currentUserId: me,
                            api: widget.api,
                            author: author,
                            useHero: false,
                            // Inline indicators ARE shown inside the thread
                            // overlay — but with onViewThread null so the
                            // branch button hides (no recursion).
                            showReplyIndicator: true,
                            onViewThread: null,
                            onLongPress: () => _onLongPressBubble(m, author),
                            onDoubleTap: () => _onLongPressBubble(m, author),
                          )
                        : MessageBubble(
                            message: m,
                            now: now,
                            currentUserId: me,
                            api: widget.api,
                            author: author,
                            useHero: false,
                            showReplyIndicator: true,
                            onViewThread: null,
                            onLongPress: () => _onLongPressBubble(m, author),
                            onDoubleTap: () => _onLongPressBubble(m, author),
                          );

                    final keyed = KeyedSubtree(key: _keys[m.id], child: bubble);
                    if (!isFocused) return keyed;

                    // Wrap focused message in a halo + accent border. The
                    // halo lives behind the bubble; the border sits in front
                    // so it reads even where the halo is occluded by other
                    // bubbles in the scroll view.
                    return Stack(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.accent
                                        .withValues(alpha: 0.45),
                                    blurRadius: 22,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        keyed,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Close button — only valid dismiss affordance besides scrim tap.
          Positioned(
            top: 0,
            right: 16,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: curved,
                builder: (_, child) =>
                    Opacity(opacity: curved.value, child: child),
                child: _CloseButton(onTap: _dismiss),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.surface.withValues(alpha: 0.55),
                border: Border.all(
                  color: theme.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.close, size: 18, color: theme.ink),
            ),
          ),
        ),
      ),
    );
  }
}
