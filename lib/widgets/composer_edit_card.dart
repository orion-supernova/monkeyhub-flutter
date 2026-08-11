import 'package:flutter/cupertino.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/message_preview.dart';
import '../theme/theme_scope.dart';

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

class _ComposerEditCardState extends State<ComposerEditCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = widget.message;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        // Same construction as the reply card, for the same reason: the strip
        // as a sibling inside a ClipRRect avoids Flutter's "non-uniform border
        // colors can't have borderRadius" assertion.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              border: Border.all(color: theme.divider, width: 0.5),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 3, color: theme.accent),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      CupertinoIcons.pencil,
                      size: 14,
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).composerEditCardTitle,
                            style: theme.monoTiny.copyWith(color: theme.accent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The ORIGINAL text, held by this card while the
                            // composer holds the replacement — so mid-edit the
                            // user can still see what they are replacing.
                            messagePreviewLine(m, hasThumbnail: false),
                            style:
                                theme.bodySoft.copyWith(color: theme.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onCancel,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: theme.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
