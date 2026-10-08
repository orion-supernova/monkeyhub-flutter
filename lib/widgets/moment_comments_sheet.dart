import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart' show Subscription;
import '../backend/feed_api.dart';
import '../expressions/expression_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/expression_item.dart';
import '../models/moment.dart';
import '../models/moment_comment.dart';
import '../models/reaction_limits.dart';
import '../theme/interaction.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'expressions/expression_bubble.dart' show GifMessageTile;
import 'expressions/expression_media.dart' show StickerArt;
import 'expressions/expression_panel.dart';
import 'ios_kit.dart' show quietFill;
import 'moment_reactor_sheet.dart';
import 'reaction_limit_notice.dart';
import 'reaction_picker_sheet.dart';
import 'remote_image.dart';
import 'sheet_kit.dart';

/// The emoji a heart tap leaves — Instagram's one-tap "like" on a comment.
/// Any other emoji goes through the long-press menu's picker.
const String _kLike = '❤️';

/// Opens [moment]'s comments.
///
/// What a comment may be is Instagram's answer: words, a sticker or a GIF —
/// never a photo, which would be a second highlight posted onto somebody
/// else's (see `momentComments` in schema.ts). Replies nest ONE level, with a
/// leading "@name" when they answer a reply, and every comment takes emoji
/// reactions under the same five-per-person cap as the highlight itself.
///
/// The conversation is live while the sheet is open and only then: the sheet
/// owns the one subscription it reads, and closing it closes that.
Future<void> showMomentComments(
  BuildContext context, {
  required Moment moment,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,

  /// Told how many comments there are on every delivery, so the pill that
  /// opened this can keep up without a board round trip.
  ValueChanged<int>? onCount,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => MomentCommentsSheet(
      moment: moment,
      api: api,
      feedApi: feedApi,
      userId: userId,
      onCount: onCount,
    ),
  );
}

/// Public only so the design preview can mount it without a route; open it
/// with [showMomentComments].
class MomentCommentsSheet extends StatefulWidget {
  /// A fixed conversation for design previews, which have no backend to
  /// subscribe to. Null everywhere else.
  @visibleForTesting
  static List<MomentComment>? debugComments;

  const MomentCommentsSheet({
    super.key,
    required this.moment,
    required this.api,
    required this.feedApi,
    required this.userId,
    this.onCount,
  });

  final Moment moment;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;
  final ValueChanged<int>? onCount;

  @override
  State<MomentCommentsSheet> createState() => MomentCommentsSheetState();
}

/// A comment this device has sent and the subscription has not echoed yet.
class _Pending {
  _Pending(this.comment);
  final MomentComment comment;

  /// The server's id once the mutation answered — the echo carrying it is
  /// what retires this row.
  String? realId;
}

class MomentCommentsSheetState extends State<MomentCommentsSheet> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  Subscription? _sub;

  /// Null until the first delivery — the spinner, not "no comments yet".
  List<MomentComment>? _comments;
  final _pending = <_Pending>[];
  int _tmp = 0;

  /// Thread roots whose replies are showing.
  final _expanded = <String>{};

  MomentComment? _replyTo;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onText);
    final fixture = MomentCommentsSheet.debugComments;
    if (fixture != null) {
      _comments = fixture;
      _expanded.add(fixture.first.id);
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
      // Offline at open. The sheet still works as a composer; the
      // subscription registry re-binds a live query on reconnect, but one
      // that never registered has nothing to re-bind — show the empty state
      // rather than a spinner forever.
      if (mounted) setState(() => _comments ??= const []);
    }
  }

  void _onData(List<MomentComment>? comments) {
    if (!mounted) return;
    // Gone, or no longer ours to see — a deleted highlight, an unfriending.
    if (comments == null) {
      Navigator.of(context).maybePop();
      return;
    }
    final ids = {for (final c in comments) c.id};
    widget.onCount?.call(comments.length);
    setState(() {
      _comments = comments;
      _pending.removeWhere((p) => p.realId != null && ids.contains(p.realId));
    });
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _sub?.cancel();
    _field.removeListener(_onText);
    _field.dispose();
    _focus.dispose();
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

  Future<void> _send({ExpressionItem? item}) async {
    final text = _field.text.trim();
    if (item == null && text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final replyTo = _replyTo;
    // A picture goes on its own and leaves whatever is half-typed in the
    // field; words go and take the field with them.
    final words = item == null ? text : null;

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
    HapticFeedback.lightImpact();
    setState(() {
      _pending.add(pending);
      _replyTo = null;
      if (words != null) _field.clear();
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        // Give the words back rather than making them retype a paragraph.
        if (words != null && _field.text.isEmpty) _field.text = words;
        _replyTo ??= replyTo;
      });
      toast.show(l10n.momentCommentFailed, tone: ToastTone.danger);
    }
  }

  Future<void> _pickExpression() async {
    // The panel's emoji tab types straight into this field; GIFs and stickers
    // come back here and go out as a comment of their own. No "make a
    // sticker": that flow pushes a full-screen route over a sheet that would
    // then be underneath it.
    final picked = await showAdaptiveSheet<(ExpressionItem, String?)>(
      context,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          decoration: BoxDecoration(
            color: sheetFill(ThemeScope.of(ctx)),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(sheetTopRadius(ThemeScope.of(ctx))),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: ExpressionPanel(
            composer: _field,
            height: 420 + bottom,
            bottomPadding: bottom,
            onSend: (item, {query}) => Navigator.of(ctx).pop((item, query)),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final (item, query) = picked;
    final store = ExpressionStore.instance;
    store.noteUsed(item);
    final slug = item.ref;
    if (item.source == ExpressionSource.klipy && slug != null) {
      unawaited(store.klipy?.registerShare(item.kind, slug, query: query));
    }
    await _send(item: item);
  }

  // ── reacting ─────────────────────────────────────────────────────────────

  /// Replaces one comment in the held list — the optimistic half of a
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
    // The cap, said before anything is sent — see reaction_limits.dart.
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

  Future<void> _reactWithAny(MomentComment c) async {
    final pick = await pickReaction(context, selected: c.myReactions);
    if (pick == null || !mounted) return;
    final mineNow = _find(c.id)?.myReactions ?? c.myReactions;
    // From the grid, choosing one you already left changes nothing; the
    // strip over it is where one is taken back.
    if (pick.remove != mineNow.contains(pick.emoji)) return;
    await _toggle(_find(c.id) ?? c, pick.emoji);
  }

  MomentComment? _find(String id) {
    for (final c in _comments ?? const <MomentComment>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _showReactors(MomentComment c, String emoji) {
    final l10n = AppLocalizations.of(context);
    showMomentReactorSheet(
      context,
      emoji: emoji,
      names: [
        for (final r in c.reactors)
          if (r.emoji == emoji)
            r.userId == widget.userId ? l10n.momentRailYouLabel : r.name,
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.momentCommentsTitle),
      maxHeightFraction: 0.88,
      padding: EdgeInsets.zero,
      footer: _composer(context),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final comments = _comments;
    if (comments == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final all = [...comments, for (final p in _pending) p.comment];
    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      );
    }

    final roots = [for (final c in all) if (c.parentId == null) c];
    final repliesOf = <String, List<MomentComment>>{};
    for (final c in all) {
      final p = c.parentId;
      if (p != null) repliesOf.putIfAbsent(p, () => []).add(c);
    }

    final rows = <Widget>[];
    for (final root in roots) {
      rows.add(_row(root));
      final replies = repliesOf[root.id] ?? const <MomentComment>[];
      if (replies.isEmpty) continue;
      final open = _expanded.contains(root.id) ||
          // Your own reply in flight is always shown — sending one into a
          // collapsed thread would look like it went nowhere.
          replies.any((r) => r.id.startsWith('tmp_'));
      if (open) {
        for (final r in replies) {
          rows.add(_row(r));
        }
      }
      rows.add(_ThreadToggle(
        label: open
            ? l10n.momentCommentHideReplies
            : l10n.momentCommentViewReplies(replies.length),
        onTap: () => setState(() {
          open ? _expanded.remove(root.id) : _expanded.add(root.id);
        }),
      ));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  Widget _row(MomentComment c) {
    return _CommentRow(
      key: ValueKey(c.id),
      comment: c,
      api: widget.api,
      sending: c.id.startsWith('tmp_'),
      onReply: () => _startReply(c),
      onLongPress: () => _menu(c),
      onLike: () => _toggle(c, _kLike),
      onToggle: (e) => _toggle(c, e),
      onShowReactors: (e) => _showReactors(c, e),
    );
  }

  Widget _composer(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final replyTo = _replyTo;
    final canSend = _field.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.momentCommentReplyingTo(replyTo.userName),
                    style: theme.caption.copyWith(color: theme.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _IconTap(
                  icon: CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: theme.inkMuted,
                  semanticLabel: l10n.momentCommentCancelReply,
                  onTap: () => setState(() => _replyTo = null),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SheetTextField(
                controller: _field,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                hint: replyTo == null
                    ? l10n.momentCommentHint
                    : l10n.momentCommentReplyHint(replyTo.userName),
                trailing: _IconTap(
                  icon: CupertinoIcons.smiley,
                  size: 22,
                  color: theme.inkMuted,
                  semanticLabel: l10n.momentCommentExpressions,
                  onTap: _pickExpression,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: theme.motionFast,
              opacity: canSend ? 1 : 0.4,
              child: _IconTap(
                icon: CupertinoIcons.arrow_up_circle_fill,
                size: 34,
                color: theme.accent,
                semanticLabel: l10n.momentCommentSend,
                onTap: canSend ? () => _send() : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "View 3 replies" / "Hide replies", indented under the thread it opens —
/// Instagram's short rule then the words.
class _ThreadToggle extends StatelessWidget {
  const _ThreadToggle({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 0, 16, 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FocusableTap(
          onTap: onTap,
          semanticLabel: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 24, height: 1, color: theme.divider),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.caption.copyWith(
                      color: theme.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    super.key,
    required this.comment,
    required this.api,
    required this.sending,
    required this.onReply,
    required this.onLongPress,
    required this.onLike,
    required this.onToggle,
    required this.onShowReactors,
  });

  final MomentComment comment;
  final ChatApi api;
  final bool sending;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback onLike;
  final void Function(String emoji) onToggle;
  final void Function(String emoji) onShowReactors;

  static String _ago(BuildContext context, DateTime at) {
    final l10n = AppLocalizations.of(context);
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.momentActivityJustNow;
    if (d.inHours < 1) return l10n.momentActivityMinutesAgo(d.inMinutes);
    if (d.inHours < 24) return l10n.momentActivityHoursAgo(d.inHours);
    // Your own archive keeps highlights forever, and their conversations
    // with them.
    return MaterialLocalizations.of(context).formatShortMonthDay(at);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final c = comment;
    final reply = c.isReply;
    final liked = c.myReactions.contains(_kLike);
    final likes = c.reactionCounts[_kLike] ?? 0;
    final others = [
      for (final e in c.reactionCounts.keys)
        if (e != _kLike) e,
    ];
    final item = c.expression;

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentAvatar(comment: c, api: api, size: reply ? 24 : 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.mine && c.userName.isEmpty
                          ? sentenceCaseOf(context, l10n.momentRailYouLabel)
                          : c.userName,
                      style: theme.bodyEmph.copyWith(fontSize: 14, color: theme.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              if (c.text != null && c.text!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      if (c.replyToName != null)
                        TextSpan(
                          text: '@${c.replyToName} ',
                          style: TextStyle(
                            color: theme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      TextSpan(text: c.text),
                    ],
                  ),
                  style: theme.body.copyWith(fontSize: 15, color: theme.ink),
                ),
              ] else if (c.replyToName != null) ...[
                const SizedBox(height: 2),
                Text(
                  '@${c.replyToName}',
                  style: theme.body.copyWith(
                    fontSize: 15,
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                  ),
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
                          maxWidth: 180,
                          radius: BorderRadius.circular(14),
                        ),
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!sending)
                    _TextTap(label: l10n.momentCommentReply, onTap: onReply),
                  for (final e in others)
                    _MiniReaction(
                      key: ValueKey(e),
                      emoji: e,
                      count: c.reactionCounts[e] ?? 0,
                      mine: c.myReactions.contains(e),
                      onTap: () => onToggle(e),
                      onLongPress: () => onShowReactors(e),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (!sending)
          _LikeButton(
            liked: liked,
            count: likes,
            onTap: onLike,
            onLongPress: likes > 0 ? () => onShowReactors(_kLike) : null,
          ),
      ],
    );

    return Opacity(
      opacity: sending ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        // Instagram's double-tap to like, on the comment as on a photo.
        onDoubleTap: sending || liked ? null : onLike,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(reply ? 58 : 16, 8, 8, 6),
          child: body,
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.comment,
    required this.api,
    required this.size,
  });

  final MomentComment comment;
  final ChatApi api;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final id = comment.userAvatarStorageId;
    final name = comment.userName;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: quietFill(theme)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: id == null
          ? Text(
              name.isEmpty ? '·' : name.characters.first.toUpperCase(),
              style: theme.bodyEmph.copyWith(
                fontSize: size * 0.42,
                color: theme.inkSoft,
              ),
            )
          : RemoteImage(
              storageId: id,
              api: api,
              fit: BoxFit.cover,
              width: size,
              height: size,
              borderRadius: BorderRadius.zero,
            ),
    );
  }
}

/// The heart at the trailing edge, with its count under it — Instagram's
/// comment like, which is a ❤️ reaction here.
class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.momentCommentLike,
      selected: liked,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                key: ValueKey(liked),
                tween: Tween(begin: liked ? 0.6 : 1, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Icon(
                  liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 16,
                  color: liked ? const Color(0xFFFF3B5C) : theme.inkMuted,
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: theme.caption.copyWith(
                    fontSize: 11,
                    color: theme.inkMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small reaction pill under a comment, for anything other than the heart.
class _MiniReaction extends StatelessWidget {
  const _MiniReaction({
    super.key,
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
    required this.onLongPress,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: emoji,
      selected: mine,
      shape: FocusRingShape.capsule,
      child: RawGestureDetector(
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (i) => i
                  ..onTap = onTap
                  ..onSecondaryTap = onLongPress,
              ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: kReactorsLongPress),
                (i) => i.onLongPress = onLongPress,
              ),
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: mine ? theme.accent.withValues(alpha: 0.18) : quietFill(theme),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12, height: 1.2)),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: theme.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mine ? theme.accent : theme.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextTap extends StatelessWidget {
  const _TextTap({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
          child: Text(
            label,
            style: theme.caption.copyWith(
              color: theme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.size,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color color;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
