import 'package:flutter/cupertino.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import '../models/message_preview.dart';
import '../theme/theme_scope.dart';
import 'chrome_motion.dart';
import 'composer_context_card.dart';

/// Sits above the composer while the user is rewriting one of their own
/// messages — [ComposerReplyCard]'s sibling, with the arrow swapped for a
/// pencil and the parent's name swapped for a title, because the question this
/// banner answers is different: not "who am I talking to" but "which words am
/// I about to replace".
///
/// No countdown, although the edit window is finite. A ticking banner turns a
/// typo fix into a timed exam; the rare edit that outlives its window is
/// refused by the server and surfaced as a snack instead.
///
/// Deliberately no media branch: only text messages are editable
/// ([MessageCapabilities.canEdit]), so unlike the reply card there is never a
/// thumbnail to draw.
class ComposerEditCard extends StatefulWidget {
  const ComposerEditCard({
    super.key,
    required this.message,
    required this.onCancel,
  });

  /// The message being rewritten.
  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  State<ComposerEditCard> createState() => _ComposerEditCardState();
}

class _ComposerEditCardState extends State<ComposerEditCard> {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = widget.message;
    return ComposerContextCard(
      // Your own message, so your own colour.
      tone: theme.accent,
      titleInk: theme.accent,
      icon: CupertinoIcons.pencil,
      // A small scribble: the pencil rocks as if writing.
      kick: GlyphKick.rock,
      kickAmplitude: 0.6,
      title: sentenceCaseOf(
        context,
        AppLocalizations.of(context).composerEditCardTitle,
      ),
      // The ORIGINAL text, held by this card while the composer holds the
      // replacement, so mid-edit the user can still see what they replace.
      line: messagePreviewLine(m, hasThumbnail: false),
      contentKey: m.id,
      onCancel: widget.onCancel,
    );
  }
}
