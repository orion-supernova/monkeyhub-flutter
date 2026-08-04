import 'package:flutter/cupertino.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/message_preview.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';

/// Sits above the composer when the user is replying to a message. Shows
/// who's being replied to + a one-line snippet (or media thumbnail), with an
/// X to cancel. Slides up + fades in on first mount.
class ComposerReplyCard extends StatefulWidget {
  const ComposerReplyCard({
    super.key,
    required this.parent,
    required this.api,
    required this.onCancel,
  });

  final ChatMessage parent;
  final ChatApi api;
  final VoidCallback onCancel;

  @override
  State<ComposerReplyCard> createState() => _ComposerReplyCardState();
}

class _ComposerReplyCardState extends State<ComposerReplyCard>
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

  // This card draws the picture beside the text, so it asks for the caption
  // alone. Shared with the pin banner and pin list via `messagePreviewLine` so
  // the three surfaces cannot drift on what a voice note or an uncaptioned
  // photo is called.
  String _previewText() =>
      messagePreviewLine(widget.parent, hasThumbnail: true);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = widget.parent;
    final isMedia = m.type == MessageType.image || m.type == MessageType.video;

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
        // ClipRRect handles the rounded corners; the inner content uses an
        // intrinsic-height Row so the 3-px accent strip stretches the full
        // card height. Putting the strip as a sibling (rather than as a
        // BorderSide on the outer container) avoids Flutter's "non-uniform
        // border colors can't have borderRadius" assertion.
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
                  // Accent strip — visual anchor mirroring the inline tether.
                  Container(width: 3, color: theme.accent),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      CupertinoIcons.arrowshape_turn_up_left_fill,
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
                            AppLocalizations.of(context)
                                .composerReplyCardReplyingToLabel(
                              m.senderName.toUpperCase(),
                            ),
                            style: theme.monoTiny.copyWith(color: theme.accent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _previewText(),
                            style: theme.bodySoft.copyWith(color: theme.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isMedia && m.mediaStorageId != null) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: RemoteImage(
                          storageId: m.mediaStorageId!,
                          api: widget.api,
                          width: 32,
                          height: 32,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
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
