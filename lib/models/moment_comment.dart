import 'package:flutter/widgets.dart' show BuildContext;

import '../data/profile_scope.dart';
import 'expression_item.dart';
import 'moment.dart' show MomentReactor;

/// One comment on a highlight, or one reply in a thread under one.
///
/// Mirrors `momentComments:list` in `backend/convex/momentComments.ts`, which
/// hand-builds every field here and is the access boundary — nothing on this
/// object is something the viewer could not already see.
///
/// One level of threading, Instagram's: [parentId] is always a top-level
/// comment, never another reply. Replying to a reply files under the same root
/// and records who it answered in [replyToName].
class MomentComment {
  const MomentComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.createdAt,
    required this.isAuthor,
    required this.mine,
    required this.canDelete,
    this.userAvatarStorageId,
    this.parentId,
    this.replyToName,
    this.text,
    this.expression,
    this.reactionCounts = const {},
    this.myReactions = const {},
    this.reactors = const [],
  });

  final String id;
  final String userId;
  final String userName;

  /// Null when the commenter's avatar setting hides it from this viewer.
  final String? userAvatarStorageId;

  /// The thread root this replies to; null on a top-level comment.
  final String? parentId;

  /// Who a reply answers, when it answers a reply rather than the root.
  final String? replyToName;

  final String? text;

  /// The sticker or GIF, when there is one. Words and a picture may come
  /// together.
  final ExpressionItem? expression;

  final DateTime createdAt;

  /// Written by the person who posted the highlight — the "Author" badge.
  final bool isAuthor;
  final bool mine;

  /// The commenter, or the highlight's own author.
  final bool canDelete;

  final Map<String, int> reactionCounts;
  final Set<String> myReactions;
  final List<MomentReactor> reactors;

  bool get isReply => parentId != null;

  /// The commenter's live name from the profile cache, [userName] (the copy)
  /// as fallback. A deleted account reads "Deleted account".
  String nameIn(BuildContext context) =>
      context.profileName(userId, fallback: userName);

  /// The commenter's live face; the copy only when no profile is known.
  String? avatarIn(BuildContext context) =>
      context.profileAvatar(userId, fallback: userAvatarStorageId);

  static MomentComment fromJson(Map<String, dynamic> j) {
    // A list of {emoji, count}, never an emoji-keyed map — see
    // `Moment.fromJson` for why the wire is shaped this way.
    final counts = <String, int>{};
    final raw = j['reactionCounts'];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final emoji = e['emoji']?.toString();
        final n = (e['count'] as num?)?.toInt() ?? 0;
        if (emoji != null && emoji.isNotEmpty && n > 0) counts[emoji] = n;
      }
    }
    return MomentComment(
      id: j['_id'].toString(),
      userId: j['userId'].toString(),
      userName: j['userName']?.toString() ?? '',
      // `?.toString()`, never `.toString()`: a null id must stay null rather
      // than become the string "null" (see `Moment.fromJson`).
      userAvatarStorageId: j['userAvatarStorageId']?.toString(),
      parentId: j['parentId']?.toString(),
      replyToName: j['replyToName']?.toString(),
      text: j['text']?.toString(),
      expression: _expressionOf(j),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      isAuthor: j['isAuthor'] == true,
      mine: j['mine'] == true,
      canDelete: j['canDelete'] == true,
      reactionCounts: counts,
      myReactions: {
        for (final e in (j['myReactions'] as List?) ?? const []) e.toString(),
      },
      reactors: [
        for (final r in (j['reactors'] as List?) ?? const [])
          if (r is Map)
            MomentReactor(
              emoji: r['emoji']?.toString() ?? '',
              userId: r['userId']?.toString() ?? '',
              name: r['name']?.toString() ?? '',
            ),
      ],
    );
  }

  /// The comment's sticker or GIF as the shared expression widgets draw it,
  /// or null when there is none this build understands.
  static ExpressionItem? _expressionOf(Map<String, dynamic> j) {
    final kind = switch (j['expressionKind']) {
      'gif' => ExpressionKind.gif,
      'sticker' => ExpressionKind.sticker,
      _ => null,
    };
    final source = ExpressionItem.parseSource(j['mediaSource']);
    if (kind == null || source == null) return null;
    return ExpressionItem(
      kind: kind,
      source: source,
      stickerId: j['stickerId']?.toString(),
      storageId: j['stickerStorageId']?.toString(),
      format: ExpressionItem.parseFormat(j['stickerFormat']),
      url: j['mediaUrl']?.toString(),
      previewUrl: j['mediaPreviewUrl']?.toString(),
      ref: j['mediaRef']?.toString(),
      width: (j['mediaWidth'] as num?)?.toDouble(),
      height: (j['mediaHeight'] as num?)?.toDouble(),
      title: j['alt']?.toString(),
    );
  }
}
