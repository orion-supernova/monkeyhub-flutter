import 'package:flutter/cupertino.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/message_preview.dart';
import '../theme/theme_scope.dart';
import 'chrome_motion.dart';
import 'composer_context_card.dart';
import 'expressions/expression_media.dart';
import 'media_spoiler.dart';
import 'remote_image.dart';
import 'reply_indicator.dart' show albumStackThumb;
import 'speaker_scope.dart';

/// Sits above the composer when the user is replying to a message. Shows
/// who's being replied to + a one-line snippet (or media thumbnail), with an
/// X to cancel. Slides up + fades in on first mount.
class ComposerReplyCard extends StatefulWidget {
  const ComposerReplyCard({
    super.key,
    required this.parent,
    required this.api,
    required this.onCancel,
    this.albumCount,
  });

  final ChatMessage parent;

  /// Set when the reply is to the whole album [parent] heads: its size. The
  /// card then says "4 items" beside a stacked thumbnail.
  final int? albumCount;
  final ChatApi api;
  final VoidCallback onCancel;

  @override
  State<ComposerReplyCard> createState() => _ComposerReplyCardState();
}

class _ComposerReplyCardState extends State<ComposerReplyCard> {
  // This card draws the picture beside the text, so it asks for the caption
  // alone. Shared with the pin banner and pin list via `messagePreviewLine` so
  // the three surfaces cannot drift on what a voice note or an uncaptioned
  // photo is called.
  String _previewText() {
    final album = widget.albumCount;
    if (album != null) {
      return AppLocalizations.of(context).replyAlbumItems(album);
    }
    return messagePreviewLine(widget.parent, hasThumbnail: true);
  }

  Widget? _thumb(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = widget.parent;
    const size = 34.0;
    final expression = expressionThumbnail(
      type: m.type,
      url: m.mediaPreviewUrl ?? m.mediaUrl,
      stickerStorageId: m.stickerStorageId,
      stickerFormat: m.stickerFormat,
      alt: m.content,
      api: widget.api,
      size: size,
    );
    if (expression != null) return expression;
    final isMedia = m.type == MessageType.image || m.type == MessageType.video;
    // A video's thumbnail is its poster; the video blob is not a picture.
    final storageId =
        m.type == MessageType.video ? m.posterStorageId : m.mediaStorageId;
    if (!isMedia || storageId == null) return null;
    final radius = BorderRadius.circular(8);
    Widget image = ClipRRect(
      borderRadius: radius,
      child: RemoteImage(
        storageId: storageId,
        api: widget.api,
        width: size,
        height: size,
        borderRadius: radius,
      ),
    );
    // Replying to a spoiler does not show it either.
    if (m.mediaSpoiler) {
      image = MediaSpoilerCover(
        interactive: false,
        dust: false,
        sigma: 4,
        borderRadius: radius,
        child: image,
      );
    }
    return widget.albumCount == null
        ? image
        : albumStackThumb(theme: theme, size: size, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = widget.parent;
    // The card names the person you are about to answer, so it is exactly the
    // kind of place their own colour belongs — and it is the one surface where
    // the reader can no longer see the bubble they tapped. Falls back to the
    // accent in a DM and wherever colours are off.
    final tone =
        SpeakerScope.markOf(context, m.senderId, on: theme.surfaceRaised) ??
            theme.accent;
    final nameInk =
        SpeakerScope.inkOf(context, m.senderId, on: theme.surfaceRaised) ??
            theme.accent;
    return ComposerContextCard(
      tone: tone,
      titleInk: nameInk,
      icon: CupertinoIcons.arrowshape_turn_up_left,
      // The reply arrow swings back toward the message it points at.
      kick: GlyphKick.back,
      kickAmplitude: -1,
      title: AppLocalizations.of(context)
          .composerReplyCardReplyingToLabel(m.resolvedSenderName(context)),
      line: _previewText(),
      contentKey: '${m.id}:${widget.albumCount ?? 0}',
      onCancel: widget.onCancel,
      thumb: _thumb(context),
    );
  }
}
