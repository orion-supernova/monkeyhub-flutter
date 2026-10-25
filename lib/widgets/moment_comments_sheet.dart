import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'report_sheet.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart' show Subscription;
import '../backend/feed_api.dart';
import '../data/settings_store.dart';
import '../expressions/expression_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../data/profile_overlay.dart';
import '../models/chat_user.dart';
import '../models/expression_item.dart';
import '../models/family.dart';
import '../models/message_reaction.dart';
import '../models/moment.dart';
import '../models/moment_comment.dart';
import '../models/reaction_limits.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'chat_composer.dart';
import 'expressions/expression_bubble.dart' show GifMessageTile;
import 'expressions/expression_media.dart' show StickerArt;
import 'expressions/expression_panel.dart';
import 'moment_reactions.dart';
import 'reaction_bubble.dart' show ReactionRow;
import 'reaction_limit_notice.dart';
import 'reaction_picker_sheet.dart';
import 'sheet_kit.dart';
import 'user_avatar.dart';

/// The emoji a double tap on a comment leaves: Instagram's "like".
const String _kLike = '❤️';

/// Opens [moment]'s conversation in a tall sheet.
///
/// The card viewer's door (a point has no photograph to swipe up on). The
/// full-screen stage hosts [MomentConversation] in its own swipe-up panel
/// instead.
Future<void> showMomentComments(
  BuildContext context, {
  required Moment moment,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
  ValueChanged<int>? onCount,
  void Function(ChatUser user)? onOpenProfile,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (ctx) {
      final theme = ThemeScope.of(ctx);
      return Container(
        height: MediaQuery.sizeOf(ctx).height * 0.86,
        decoration: BoxDecoration(
          color: sheetFill(theme),
          borderRadius: BorderRadius.circular(sheetRadius(theme)),
        ),
        child: Column(
          children: [
            const SheetHandle(),
            SheetBar(
              title: sentenceCaseOf(
                ctx,
                AppLocalizations.of(ctx).momentCommentsTitle,
              ),
              leading: const SheetCloseButton(),
            ),
            Expanded(
              child: MomentConversation(
                moment: moment,
                api: api,
                feedApi: feedApi,
                userId: userId,
                onCount: onCount,
                onOpenProfile: onOpenProfile == null
                    ? null
                    : (u) {
                        Navigator.of(ctx).pop();
                        onOpenProfile(u);
                      },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// How many replies a thread shows without a toggle. Past this, it folds
/// behind "View N replies".
const kMomentInlineReplies = 3;

/// A highlight's comments: the thread list over the app's own message
/// composer, with the composer's inline emoji / GIF / sticker panel.
///
/// What a comment may be is Instagram's answer: words, a sticker or a GIF,
/// never a photo (see `momentComments` in schema.ts). Replies nest ONE level,
/// with a leading "@name" when they answer a reply, and every comment takes
/// emoji reactions under the same five-per-person cap as the highlight.
///
/// Owns the one live subscription it reads, for as long as it is mounted.
/// The composer is the room's ([ChatComposerLiquid] / [ChatComposerClassic],
/// chosen by the same chat-style setting), so commenting feels like typing
/// anywhere else in the app.
class MomentConversation extends StatefulWidget {
  /// A fixed conversation for design previews, which have no backend to
  /// subscribe to. Null everywhere else.
  @visibleForTesting
  static List<MomentComment>? debugComments;

  /// Thread roots a design preview opens up front. Null opens the first.
  @visibleForTesting
  static Set<String>? debugExpanded;

  const MomentConversation({
    super.key,
    required this.moment,
    required this.api,
    required this.feedApi,
    required this.userId,
    this.onCount,
    this.header,
    this.focus,
    this.onPullDown,
    this.onPullEnd,
    this.onOpenProfile,
  });

  /// A commenter's face or name was tapped. Null leaves them inert.
  final void Function(ChatUser user)? onOpenProfile;

  final Moment moment;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  /// Told the comment count on every delivery.
  final ValueChanged<int>? onCount;

  /// Drawn above the list: the stage puts the big reaction row here.
  final Widget? header;

  /// The composer's focus node, when the host wants to raise the keyboard
  /// itself (the stage does, when its comment bar is tapped). Owned by the
  /// host when given.
  final FocusNode? focus;

  /// A downward drag that the list could not use because it was already at
  /// the top, in logical pixels. How the stage's panel follows a finger
  /// pulling it closed from anywhere, Instagram's way.
  final ValueChanged<double>? onPullDown;

  /// That drag ended, with its vertical velocity.
  final ValueChanged<double>? onPullEnd;

  @override
  State<MomentConversation> createState() => _MomentConversationState();
}

/// A comment this device has sent and the subscription has not echoed yet.
class _Pending {
  _Pending(this.comment);
  final MomentComment comment;

  /// The server's id once the mutation answered; the echo carrying it is what
  /// retires this row.
  String? realId;
}

class _MomentConversationState extends State<MomentConversation> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focus ?? (_ownFocus ??= FocusNode());

  /// Whether the composer's emoji / GIF / sticker panel is up; the header
  /// steps aside for it.
  bool _expressionsOpen = false;

  Subscription? _sub;

  /// Null until the first delivery: the spinner, not "no comments yet".
  List<MomentComment>? _commentList;
  List<MomentComment>? get _comments => _commentList;
  set _comments(List<MomentComment>? v) {
    _commentList = v;
    // An open who-reacted sheet follows its comment, so yours lands there.
    final live = _liveReactors;
    if (live == null) return;
    final c = _find(live.commentId);
    if (c != null) live.reactors.value = c.reactors;
  }

  /// The comment whose who-reacted sheet is open, and its reactors as they
  /// change.
  ({String commentId, ValueNotifier<List<MomentReactor>> reactors})?
      _liveReactors;
  final _pending = <_Pending>[];
  int _tmp = 0;

  /// Thread roots whose replies are showing.
  final _expanded = <String>{};

  MomentComment? _replyTo;

  /// Whether the drag now in progress is pulling the host closed rather than
  /// scrolling the list.
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    final fixture = MomentConversation.debugComments;
    if (fixture != null) {
      _comments = fixture;
      final open = MomentConversation.debugExpanded;
      if (open != null) {
        _expanded.addAll(open);
      } else if (fixture.isNotEmpty) {
        _expanded.add(fixture.first.id);
      }
      return;
    }
    unawaited(_subscribe());
  }

  Future<void> _subscribe() async {
    try {
      final sub = await widget.feedApi.subscribeComments(
        userId: widget.userId,
        momentId: widget.moment.id,
        onData: _onData,
      );
      if (!mounted) {
        sub.cancel();
        return;
      }
      _sub = sub;
    } catch (_) {
      // Offline at open: show the empty state rather than a spinner forever.
      if (mounted) setState(() => _comments ??= const []);
    }
  }

  void _onData(List<MomentComment>? comments) {
    if (!mounted) return;
    // Gone, or no longer ours to see: a deleted highlight, an unfriending.
    if (comments == null) {
      setState(() => _comments = const []);
      return;
    }
    final ids = {for (final c in comments) c.id};
    widget.onCount?.call(comments.length);
    setState(() {
      _comments = comments;
      _pending.removeWhere((p) => p.realId != null && ids.contains(p.realId));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ownFocus?.dispose();
    super.dispose();
  }

  // ── writing ──────────────────────────────────────────────────────────────

  void _startReply(MomentComment target) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyTo = target;
      _expanded.add(target.parentId ?? target.id);
    });
    _focus.requestFocus();
  }

  /// Posts what [MomentCommentComposer] hands over, on screen first.
  Future<bool> _submit({String? text, ExpressionItem? item}) async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final replyTo = _replyTo;
    final words = text;

    final pending = _Pending(
      MomentComment(
        id: 'tmp_${_tmp++}',
        userId: widget.userId,
        userName: '',
        createdAt: DateTime.now(),
        isAuthor: widget.moment.mine,
        mine: true,
        canDelete: false,
        parentId: replyTo == null ? null : (replyTo.parentId ?? replyTo.id),
        replyToName: replyTo != null &&
                replyTo.parentId != null &&
                replyTo.userId != widget.userId
            ? replyTo.userName
            : null,
        text: words,
        expression: item,
      ),
    );
    setState(() {
      _pending.add(pending);
      _replyTo = null;
    });
    try {
      pending.realId = await widget.feedApi.comment(
        userId: widget.userId,
        momentId: widget.moment.id,
        text: words,
        replyToId: replyTo?.id,
        expression: item,
      );
      // The echo may already have landed before the id did.
      final ids = {for (final c in _comments ?? const <MomentComment>[]) c.id};
      if (mounted && ids.contains(pending.realId)) {
        setState(() => _pending.remove(pending));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _pending.remove(pending);
        _replyTo ??= replyTo;
      });
      // The language filter is a refusal, not a failure: say why.
      if (isFilterBlockedError(e)) {
        toast.show(l10n.messageFilterBlocked);
      } else {
        toast.show(l10n.momentCommentFailed, tone: ToastTone.danger);
      }
      return false;
    }
  }

  // ── reacting ─────────────────────────────────────────────────────────────

  /// Replaces one comment in the held list: the optimistic half of a
  /// reaction. The next delivery overwrites it with the truth either way.
  void _patch(String id, MomentComment Function(MomentComment c) f) {
    final list = _comments;
    if (list == null) return;
    setState(() {
      _comments = [for (final c in list) c.id == id ? f(c) : c];
    });
  }

  MomentComment _withReaction(MomentComment c, String emoji, bool on) {
    final counts = {...c.reactionCounts};
    final mine = {...c.myReactions};
    if (on) {
      mine.add(emoji);
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    } else {
      mine.remove(emoji);
      final n = (counts[emoji] ?? 1) - 1;
      n <= 0 ? counts.remove(emoji) : counts[emoji] = n;
    }
    return MomentComment(
      id: c.id,
      userId: c.userId,
      userName: c.userName,
      userAvatarStorageId: c.userAvatarStorageId,
      parentId: c.parentId,
      replyToName: c.replyToName,
      text: c.text,
      expression: c.expression,
      createdAt: c.createdAt,
      isAuthor: c.isAuthor,
      mine: c.mine,
      canDelete: c.canDelete,
      reactionCounts: counts,
      myReactions: mine,
      reactors: on
          ? [
              ...c.reactors,
              MomentReactor(emoji: emoji, userId: widget.userId, name: ''),
            ]
          : [
              for (final r in c.reactors)
                if (!(r.emoji == emoji && r.userId == widget.userId)) r,
            ],
    );
  }

  Future<void> _toggle(MomentComment c, String emoji) async {
    if (c.id.startsWith('tmp_')) return;
    final had = c.myReactions.contains(emoji);
    // The cap, said before anything is sent. See reaction_limits.dart.
    if (!had && c.myReactions.length >= kMaxMomentReactionsPerPerson) {
      await showReactionLimitNotice(
        context,
        surface: ReactionLimitSurface.moment,
      );
      return;
    }
    HapticFeedback.selectionClick();
    _patch(c.id, (x) => _withReaction(x, emoji, !had));
    try {
      if (had) {
        await widget.feedApi.unreactComment(
          userId: widget.userId,
          commentId: c.id,
          emoji: emoji,
        );
      } else {
        await widget.feedApi.reactToComment(
          userId: widget.userId,
          commentId: c.id,
          emoji: emoji,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _patch(c.id, (x) => _withReaction(x, emoji, had));
      if (e.toString().contains(kReactionLimitError)) {
        await showReactionLimitNotice(
          context,
          surface: ReactionLimitSurface.moment,
        );
      }
    }
  }

  MomentComment? _find(String id) {
    for (final c in _comments ?? const <MomentComment>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _reactWithAny(MomentComment c) async {
    final pick = await pickReaction(context, selected: c.myReactions);
    if (pick == null || !mounted) return;
    final now = _find(c.id) ?? c;
    // From the grid, choosing one you already left changes nothing; the strip
    // over it is where one is taken back.
    if (pick.remove != now.myReactions.contains(pick.emoji)) return;
    await _toggle(now, pick.emoji);
  }

  /// Tap or long-press a chip. The sheet is where yours is added or taken
  /// back, since a chip tap no longer toggles.
  Future<void> _showReactors(MomentComment c, String emoji) async {
    final live = ValueNotifier(c.reactors);
    _liveReactors = (commentId: c.id, reactors: live);
    await showMomentReactions(
      context,
      reactors: c.reactors,
      live: live,
      api: widget.api,
      viewerId: widget.userId,
      initialEmoji: emoji,
      onOpenProfile: widget.onOpenProfile,
      onToggle: c.id.startsWith('tmp_')
          ? null
          : (e) => _toggle(_find(c.id) ?? c, e),
    );
    if (identical(_liveReactors?.reactors, live)) _liveReactors = null;
    live.dispose();
  }

  // ── the menu ─────────────────────────────────────────────────────────────

  Future<void> _menu(MomentComment c) async {
    if (c.id.startsWith('tmp_')) return;
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    final choice = await showIosActionSheet<String>(
      context,
      actions: [
        IosSheetAction(
          label: l10n.momentCommentReply,
          value: 'reply',
          icon: CupertinoIcons.arrowshape_turn_up_left,
        ),
        IosSheetAction(
          label: l10n.reactionBubblePickerTitle,
          value: 'react',
          icon: CupertinoIcons.smiley,
        ),
        if (c.canDelete)
          IosSheetAction(
            label: l10n.momentCommentDelete,
            value: 'delete',
            destructive: true,
            icon: CupertinoIcons.trash,
          ),
        if (c.userId != widget.userId)
          IosSheetAction(
            label: l10n.messageActionMenuReportLabel,
            value: 'report',
            destructive: true,
            icon: CupertinoIcons.flag,
          ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'reply':
        _startReply(c);
      case 'react':
        await _reactWithAny(c);
      case 'delete':
        await _delete(c);
      case 'report':
        await fileReport(
          context,
          api: widget.api,
          reporterId: widget.userId,
          target: ReportTarget.comment,
          targetId: c.id,
        );
    }
  }

  Future<void> _delete(MomentComment c) async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final ok = await showIosActionSheet<bool>(
      context,
      message: l10n.momentCommentDeleteConfirm,
      actions: [
        IosSheetAction(
          label: l10n.momentCommentDeleteConfirmButton,
          value: true,
          destructive: true,
        ),
      ],
    );
    if (ok != true || !mounted) return;
    final before = _comments;
    // Gone at once, replies with it; the next delivery agrees.
    setState(() {
      _comments = [
        for (final x in before ?? const <MomentComment>[])
          if (x.id != c.id && !(c.parentId == null && x.parentId == c.id)) x,
      ];
      if (_replyTo?.id == c.id || _replyTo?.parentId == c.id) _replyTo = null;
    });
    try {
      await widget.feedApi.deleteComment(
        userId: widget.userId,
        commentId: c.id,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _comments = before);
      toast.show(l10n.momentCommentFailed, tone: ToastTone.danger);
    }
  }

  // ── layout ───────────────────────────────────────────────────────────────

  /// Turns a drag the list cannot use (it is already at the top) into a pull
  /// on the host, and back.
  bool _onScroll(ScrollNotification n) {
    final pull = widget.onPullDown;
    if (pull == null) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _pulling = true;
      pull(-n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        _pulling &&
        n.dragDetails != null) {
      // Pushing back up mid pull closes the gap before the list moves.
      final d = n.scrollDelta ?? 0;
      if (d > 0) pull(-d);
    } else if (n is ScrollEndNotification && _pulling) {
      _pulling = false;
      widget.onPullEnd?.call(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _layout);
  }

  Widget _layout(BuildContext context, BoxConstraints box) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final replyTo = _replyTo;
    // While the expression panel is up the header steps aside: the panel
    // needs the room, and the header is one tap away again.
    final header = _expressionsOpen ? null : widget.header;
    return Column(
      children: [
        ?header,
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: _body(context),
          ),
        ),
        MomentCommentComposer(
          focus: _focus,
          hint: replyTo == null
              ? l10n.momentCommentHint
              : l10n.momentCommentReplyHint(replyTo.nameIn(context)),
          // Budgeted against THIS widget's box, not the screen: hosted in a
          // sheet it is shorter than the window, and a panel sized for the
          // window overflowed it.
          maxPanel: box.maxHeight - MomentCommentComposer.reserve,
          onSubmit: _submit,
          onExpressionsChanged: (open) {
            if (open != _expressionsOpen) {
              setState(() => _expressionsOpen = open);
            }
          },
          above: replyTo == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.momentCommentReplyingTo(replyTo.nameIn(context)),
                          style: theme.caption.copyWith(color: theme.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FocusableTap(
                        onTap: () => setState(() => _replyTo = null),
                        semanticLabel: l10n.momentCommentCancelReply,
                        shape: FocusRingShape.circle,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _replyTo = null),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 18,
                              color: theme.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final comments = _comments;
    // Clamping, not bouncing: a pull past the top has to reach the host as an
    // overscroll, which a bouncing list swallows into its own stretch.
    const physics = ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
    if (comments == null) {
      return ListView(
        physics: physics,
        children: const [
          SizedBox(height: 120),
          Center(child: CupertinoActivityIndicator()),
        ],
      );
    }
    final all = [...comments, for (final p in _pending) p.comment];
    if (all.isEmpty) {
      return ListView(
        physics: physics,
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
        children: [
          Icon(CupertinoIcons.chat_bubble_2, size: 40, color: theme.inkMuted),
          const SizedBox(height: 12),
          Text(
            sentenceCaseOf(context, l10n.momentCommentsEmptyTitle),
            style: theme.bodyEmph.copyWith(color: theme.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.momentCommentsEmptyBody,
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final roots = [for (final c in all) if (c.parentId == null) c];
    final repliesOf = <String, List<MomentComment>>{};
    for (final c in all) {
      final p = c.parentId;
      if (p != null) repliesOf.putIfAbsent(p, () => []).add(c);
    }

    // Every thread hangs off one rail: it leaves the root's face, runs down
    // past its replies, and turns into the last thing in the thread (the last
    // reply, or the "View / Hide replies" toggle).
    final rows = <Widget>[];
    for (final root in roots) {
      final replies = repliesOf[root.id] ?? const <MomentComment>[];
      rows.add(_row(root, rail: replies.isEmpty ? null : MomentRail.start));
      if (replies.isEmpty) continue;
      // A short thread just shows: a "View 1 reply" chip costs a tap to save
      // one row. Only a longer one folds behind the toggle.
      final folds = replies.length > kMomentInlineReplies;
      final open = !folds ||
          _expanded.contains(root.id) ||
          // Your own reply in flight is always shown: sending one into a
          // collapsed thread would look like it went nowhere.
          replies.any((r) => r.id.startsWith('tmp_'));
      if (open) {
        for (final (i, r) in replies.indexed) {
          final last = !folds && i == replies.length - 1;
          rows.add(_row(r, rail: last ? MomentRail.end : MomentRail.through));
        }
      }
      if (folds) {
        rows.add(_ThreadToggle(
          label: open
              ? l10n.momentCommentHideReplies
              : l10n.momentCommentViewReplies(replies.length),
          onTap: () => setState(() {
            open ? _expanded.remove(root.id) : _expanded.add(root.id);
          }),
        ));
      }
    }

    return ListView(
      physics: physics,
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  Widget _row(MomentComment c, {MomentRail? rail}) {
    return _CommentRow(
      key: ValueKey(c.id),
      comment: c,
      rail: rail,
      api: widget.api,
      userId: widget.userId,
      sending: c.id.startsWith('tmp_'),
      onReply: () => _startReply(c),
      onLongPress: () => _menu(c),
      onLike: () => _toggle(c, _kLike),
      onToggle: (e) => _toggle(c, e),
      onShowReactors: (e) => _showReactors(c, e),
      onOpenProfile: widget.onOpenProfile == null || c.mine
          ? null
          : () => widget.onOpenProfile!(
                profileUser(
                  context,
                  userId: c.userId,
                  username: c.userName,
                  name: c.userName,
                  avatarStorageId: c.userAvatarStorageId,
                ),
              ),
    );
  }
}

/// The comment composer: the app's own message composer
/// ([ChatComposerLiquid] / [ChatComposerClassic], by the chat-style setting)
/// with its inline emoji / GIF / sticker panel, riding the keyboard.
///
/// One widget for both places a comment is written, the conversation and the
/// story's reply overlay, so the two cannot drift apart. The host decides
/// what a submit means through [onSubmit]; this clears the field on send and
/// gives the words back if the host reports failure.
class MomentCommentComposer extends StatefulWidget {
  const MomentCommentComposer({
    super.key,
    required this.hint,
    required this.onSubmit,
    required this.maxPanel,
    this.focus,
    this.above,
    this.onExpressionsChanged,
    this.floor,
  });

  /// The solid colour under the composer and its panel. Null takes the
  /// sheet's own fill; the story passes black.
  final Color? floor;

  /// What the host must leave above the composer for its own content when
  /// working out [maxPanel]: the composer itself and a sliver of list.
  static const double reserve = 132;

  final String hint;

  /// Posts words or a sticker / GIF; true when it went.
  final Future<bool> Function({String? text, ExpressionItem? item}) onSubmit;

  /// The tallest the expression panel may stand in this host.
  final double maxPanel;

  /// Owned by the host when given, so it can raise the keyboard itself.
  final FocusNode? focus;

  /// Drawn right above the field: the "Replying to" line.
  final Widget? above;

  /// The expression panel opened (true) or closed.
  final ValueChanged<bool>? onExpressionsChanged;

  @override
  State<MomentCommentComposer> createState() => _MomentCommentComposerState();
}

class _MomentCommentComposerState extends State<MomentCommentComposer> {
  final _field = TextEditingController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focus ?? (_ownFocus ??= FocusNode());
  final _expressions = ExpressionPanelController();
  bool _reportedOpen = false;

  @override
  void initState() {
    super.initState();
    _expressions.addListener(_onExpressions);
    _focus.addListener(_onFocus);
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    _expressions.removeListener(_onExpressions);
    _expressions.dispose();
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _field.dispose();
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _onExpressions() {
    if (!mounted) return;
    setState(() {});
    final open = _expressions.isOpen;
    if (open != _reportedOpen) {
      _reportedOpen = open;
      widget.onExpressionsChanged?.call(open);
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) _expressions.dismiss();
  }

  void _sendText() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    _field.clear();
    widget.onSubmit(text: text).then((ok) {
      // Give the words back rather than making them retype a paragraph.
      if (!ok && mounted && _field.text.isEmpty) _field.text = text;
    });
  }

  void _sendExpression(ExpressionItem item, {String? query}) {
    final store = ExpressionStore.instance;
    store.noteUsed(item);
    _expressions.noteSent();
    final slug = item.ref;
    if (item.source == ExpressionSource.klipy && slug != null) {
      unawaited(store.klipy?.registerShare(item.kind, slug, query: query));
    }
    unawaited(widget.onSubmit(item: item));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    // The panel takes the keyboard's exact height; see room_screen.build.
    _expressions.noteKeyboardInset(media.viewInsets.bottom);
    final keyboard = media.viewInsets.bottom;
    final panelUp = _expressions.isOpen;
    final searching = panelUp && _expressions.searching;
    final room = widget.maxPanel.clamp(200.0, double.infinity);
    final safeBottom = panelUp || keyboard > 0 ? 0.0 : media.padding.bottom;
    final classic = SettingsStore.instance.chatStyle == ChatStyle.classic;
    _expressions.setLayout(
      expanded: room,
      // Searching, the composer folds away and its row is the panel's too.
      room: room + ExpressionPanelController.composerRow,
      keyboardInset: keyboard,
      resting: (media.size.height * 0.45).clamp(200.0, room),
    );
    // A solid floor, never glass over whatever is behind: on a story the
    // composer used to sit on the photograph and read as floating in it.
    //
    // Its own BackdropGroup, and that is the part that makes the floor stick.
    // The glass here is grouped glass, which samples ONE shared snapshot of
    // the backdrop per group, taken at the group's first filter. Inside a host
    // that already has a group (the story stage does, for its top bar) that
    // snapshot was taken before this floor was painted, so the field showed
    // the photograph through a black box. A group of our own takes its
    // snapshot here, over the floor, in every host.
    return BackdropGroup(
      child: ColoredBox(
      color: widget.floor ?? sheetFill(theme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The composer rides the keyboard; with the expression panel up
          // the keyboard is down and the panel pads the safe area itself.
          ComposerSearchTakeover(
            controller: _expressions,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: panelUp ? 0 : keyboard),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?widget.above,
                  if (classic)
                    ChatComposerClassic(
                      controller: _field,
                      focusNode: _focus,
                      ephemeral: false,
                      hint: widget.hint,
                      onSend: _sendText,
                      padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + safeBottom),
                      onExpressions: () => _expressions.toggle(_focus),
                      expressionsOpen:
                          _expressions.isOpen && !_expressions.closing,
                      onFieldTap: _expressions.dismiss,
                    )
                  else
                    ChatComposerLiquid(
                      controller: _field,
                      focusNode: _focus,
                      ephemeral: false,
                      hint: widget.hint,
                      onSend: _sendText,
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + safeBottom),
                      onExpressions: () => _expressions.toggle(_focus),
                      expressionsOpen:
                          _expressions.isOpen && !_expressions.closing,
                      onFieldTap: _expressions.dismiss,
                    ),
                ],
              ),
            ),
          ),
          if (panelUp)
            // Searching, the search keyboard is up under the panel; nothing
            // here sits in a Scaffold that would lift it, so it is lifted
            // by hand.
            Padding(
              padding: EdgeInsets.only(bottom: searching ? keyboard : 0),
              child: ExpressionPanel(
                controller: _expressions,
                composer: _field,
                onSend: _sendExpression,
                height: _expressions.currentHeight,
                bottomPadding: searching ? 0 : media.padding.bottom,
                keyboardInset: searching ? 0 : keyboard,
                onSearchFocusChanged: _expressions.setSearching,
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// "View 5 replies" / "Hide replies": the last stop on its thread's rail,
/// which turns into the words the way it turns into a reply's face.
class _ThreadToggle extends StatelessWidget {
  const _ThreadToggle({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return MomentThreadRail(
      rail: MomentRail.end,
      elbowY: _height / 2,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: _kReplyInset,
          end: 16,
          bottom: 6,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FocusableTap(
            onTap: onTap,
            semanticLabel: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                height: _height,
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: theme.caption.copyWith(
                      color: theme.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── the thread rail ─────────────────────────────────────────────────────────
//
// One geometry, shared by every row on a rail so the segments meet: rows are
// separate list children, each painting its own stretch of the line.

const double _kRowTop = 8;
const double _kRootAvatar = 34;
const double _kReplyAvatar = 24;

/// The rail runs down the middle of the root's face.
const double _kRailX = 16 + _kRootAvatar / 2;

/// Where a reply's face (and the toggle's words) start.
const double _kReplyInset = 56;

/// The elbow's turn, and the breath it leaves before the face it points at.
const double _kElbowRadius = 12;
const double _kElbowGap = 5;

/// Where a row sits on its thread's rail.
enum MomentRail {
  /// A root with replies: the rail leaves from under its face.
  start,

  /// A reply with more of the thread below: the rail turns into it and runs
  /// on past.
  through,

  /// The thread's last stop: the rail turns into it and ends.
  end,
}

/// Paints [rail]'s stretch of a thread's line behind [child]. The elbow into
/// a reply or toggle sits at [elbowY] from the row's top. Mirrors under RTL.
class MomentThreadRail extends StatelessWidget {
  const MomentThreadRail({
    super.key,
    required this.rail,
    required this.child,
    this.elbowY = _kRowTop + _kReplyAvatar / 2,
  });

  final MomentRail rail;
  final double elbowY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return CustomPaint(
      painter: _RailPainter(
        rail: rail,
        elbowY: elbowY,
        color: theme.divider,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
      child: child,
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.rail,
    required this.elbowY,
    required this.color,
    required this.rtl,
  });

  final MomentRail rail;
  final double elbowY;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double v) => rtl ? size.width - v : v;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      // Butt, not round: the divider is translucent, and round caps from two
      // rows overlapping at their seam would print a darker bead there.
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    // One path per row, so where the elbow peels off the line the two
    // strokes share one coverage mask instead of doubling up.
    final path = Path();
    if (rail == MomentRail.start) {
      path
        ..moveTo(x(_kRailX), _kRowTop + _kRootAvatar + 6)
        ..lineTo(x(_kRailX), size.height);
    } else {
      const r = _kElbowRadius;
      path
        ..moveTo(x(_kRailX), 0)
        ..lineTo(x(_kRailX), elbowY - r)
        ..arcToPoint(
          Offset(x(_kRailX + r), elbowY),
          radius: const Radius.circular(r),
          clockwise: rtl,
        )
        ..lineTo(x(_kReplyInset - _kElbowGap), elbowY);
      if (rail == MomentRail.through) {
        path
          ..moveTo(x(_kRailX), elbowY - r)
          ..lineTo(x(_kRailX), size.height);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.rail != rail ||
      old.elbowY != elbowY ||
      old.color != color ||
      old.rtl != rtl;
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    super.key,
    required this.comment,
    required this.rail,
    required this.api,
    required this.userId,
    required this.sending,
    required this.onReply,
    required this.onLongPress,
    required this.onLike,
    required this.onToggle,
    required this.onShowReactors,
    required this.onOpenProfile,
  });

  /// Opens the commenter's profile from their face or name.
  final VoidCallback? onOpenProfile;

  final MomentComment comment;

  /// Where this row sits on its thread's rail; null for a root on its own.
  final MomentRail? rail;
  final ChatApi api;
  final String userId;
  final bool sending;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback onLike;
  final void Function(String emoji) onToggle;
  final void Function(String emoji) onShowReactors;

  Widget _railed(Widget child) {
    final r = rail;
    return r == null ? child : MomentThreadRail(rail: r, child: child);
  }

  static String _ago(BuildContext context, DateTime at) {
    final l10n = AppLocalizations.of(context);
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.momentActivityJustNow;
    if (d.inHours < 1) return l10n.momentActivityMinutesAgo(d.inMinutes);
    if (d.inHours < 24) return l10n.momentActivityHoursAgo(d.inHours);
    // Your own archive keeps highlights forever, and their conversations.
    return MaterialLocalizations.of(context).formatShortMonthDay(at);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final c = comment;
    final reply = c.isReply;
    final item = c.expression;
    final name = c.mine && c.userName.isEmpty
        ? sentenceCaseOf(context, l10n.momentRailYouLabel)
        : c.nameIn(context);
    // The chat's own reaction chips, fed the comment's reactors.
    final reactions = [
      for (final (i, r) in c.reactors.indexed)
        MessageReaction(
          id: '${c.id}-$i',
          messageId: c.id,
          userId: r.userId,
          emoji: r.emoji,
          createdAt: c.createdAt,
        ),
    ];

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileTap(
          onTap: onOpenProfile,
          label: name,
          child: UserAvatar(
            user: profileUser(
              context,
              userId: c.userId,
              username: c.userName,
              name: name,
              avatarStorageId: c.userAvatarStorageId,
            ),
            api: api,
            size: reply ? _kReplyAvatar : _kRootAvatar,
            showStatus: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _ProfileTap(
                      onTap: onOpenProfile,
                      label: name,
                      child: Text(
                        name,
                        style: theme.bodyEmph.copyWith(fontSize: 14, color: theme.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (c.isAuthor) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.momentCommentAuthorBadge,
                        style: theme.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    _ago(context, c.createdAt),
                    style: theme.caption.copyWith(color: theme.inkMuted),
                  ),
                ],
              ),
              if ((c.text?.isNotEmpty ?? false) || c.replyToName != null) ...[
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      if (c.replyToName != null)
                        TextSpan(
                          // Isolated, so a Latin "@name" opening an RTL
                          // line keeps its "@" in front of the name.
                          text: '\u2068@${c.replyToName}\u2069 ',
                          style: TextStyle(
                            color: theme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (c.text != null) TextSpan(text: c.text),
                    ],
                  ),
                  style: theme.body.copyWith(fontSize: 15, color: theme.ink),
                ),
              ],
              if (item != null) ...[
                const SizedBox(height: 6),
                Semantics(
                  label: item.title ??
                      (item.isSticker
                          ? l10n.momentCommentStickerAlt
                          : l10n.momentCommentGifAlt),
                  child: item.isSticker
                      ? StickerArt(item: item, size: 96, api: api)
                      : GifMessageTile(
                          item: item,
                          maxWidth: 200,
                          radius: BorderRadius.circular(16),
                        ),
                ),
              ],
              if (reactions.isNotEmpty)
                ReactionRow(
                  reactions: reactions,
                  currentUserId: userId,
                  onToggle: onToggle,
                  onShowReactors: onShowReactors,
                ),
              if (!sending)
                FocusableTap(
                  onTap: onReply,
                  semanticLabel: l10n.momentCommentReply,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onReply,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2, right: 12),
                      child: Text(
                        l10n.momentCommentReply,
                        style: theme.caption.copyWith(
                          color: theme.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Opacity(
      opacity: sending ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        // Instagram's double tap to like, on a comment as on a photo.
        onDoubleTap: sending || comment.myReactions.contains(_kLike)
            ? null
            : onLike,
        child: _railed(
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              reply ? _kReplyInset : 16,
              _kRowTop,
              16,
              6,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// A face or a name that opens its owner's profile, or [child] unchanged when
/// there is nowhere to go (your own, or a host that lends no profile route).
class _ProfileTap extends StatelessWidget {
  const _ProfileTap({
    required this.onTap,
    required this.label,
    required this.child,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    if (tap == null) return child;
    return FocusableTap(
      onTap: tap,
      semanticLabel: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: child,
      ),
    );
  }
}
