import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/message_bookmark.dart';
import '../models/message_preview.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'labeled_field.dart' show FieldLabel;
import 'message_stamp.dart' show formatClockTime;
import 'remote_image.dart';

/// Room info's "Saved messages" block: what THIS viewer kept from THIS room.
///
/// ── Why it says so out loud ────────────────────────────────────────────────
///
/// The app already has a Saved Messages, and it is a different thing: the
/// `dm:self:` room you forward copies into, which spans every conversation and
/// holds duplicates. This holds neither — it is a set of marks on messages that
/// never moved, scoped to one room and visible to nobody else. Two features
/// cannot share a name and be told apart by their contents, so the caption under
/// the heading is load-bearing rather than decorative: it is the only place the
/// scope and the privacy are stated, and both are exactly what a reader would
/// otherwise have to guess.
///
/// ── Why a plain Column and not a scrollable ────────────────────────────────
///
/// Every row is built eagerly, inside the settings page's own scroll view. That
/// is only safe because `bookmarks.ts` caps saves at 50 per reader per room — an
/// unbounded-looking widget made bounded by a server constant, which is the same
/// bargain `_membersList` on this screen already makes. The alternative, an
/// inner `ListView` with its own height, puts a second vertical scrollable
/// inside a page that scrolls, and a drag that lands on the wrong one is worse
/// than a long page.
class SavedMessagesSection extends StatelessWidget {
  const SavedMessagesSection({
    super.key,
    required this.repo,
    required this.api,
    required this.roomId,
    required this.onJump,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;

  /// Take the reader to this message in the transcript.
  ///
  /// Handed up rather than performed here for the reason `_openContent` on this
  /// screen states: `RoomScreen` owns the jump machinery — the back-trail, the
  /// folded-thread fallback, the window fetch — and none of it is reachable
  /// from a route stacked on top of it.
  final void Function(ChatMessage message) onJump;

  @override
  Widget build(BuildContext context) {
    // Read through to the repository on every build rather than snapshotting,
    // so unsaving from inside this section updates it — and so does saving
    // something from the transcript underneath, or from another device.
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) => _body(context, ThemeScope.of(context)),
    );
  }

  Widget _body(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final saved = repo.savedFor(roomId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(l10n.roomInfoScreenSavedMessagesLabel),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.roomInfoScreenSavedMessagesCaption,
            style: theme.bodySoft.copyWith(fontSize: 12),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: theme.divider, width: 1.4),
          ),
          // Clipped so the first and last rows' press highlight cannot paint
          // over the rounded corners.
          clipBehavior: Clip.antiAlias,
          child: saved.isEmpty
              ? _Empty(theme: theme)
              : Column(
                  children: [
                    for (var i = 0; i < saved.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.divider,
                        ),
                      _SavedRow(
                        bookmark: saved[i],
                        api: api,
                        onTap: () => onJump(saved[i].message),
                        onUnsave: () => _unsave(saved[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _unsave(MessageBookmark bookmark) async {
    HapticFeedback.selectionClick();
    await repo.unsaveMessage(roomId, bookmark.message.id);
  }
}

/// Nothing saved yet — which is the state this section spends most of its life
/// in, so it says how to leave it rather than only that it is empty. "No saved
/// messages" is true and useless; the gesture is the missing half.
class _Empty extends StatelessWidget {
  const _Empty({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Icon(
              CupertinoIcons.bookmark,
              size: 18,
              color: theme.inkMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).roomInfoScreenSavedMessagesEmpty,
              style: theme.bodySoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// One saved message: who said it, when, what it was, and a way to let it go.
///
/// Two tap targets in one row, like the pinned list's rows — the body travels
/// to the message, the trailing glyph drops the bookmark. Pressed state is
/// drawn here rather than by an overlay because the row sits inside a clipped,
/// bordered container, and this app draws no ink anywhere regardless.
class _SavedRow extends StatefulWidget {
  const _SavedRow({
    required this.bookmark,
    required this.api,
    required this.onTap,
    required this.onUnsave,
  });

  final MessageBookmark bookmark;
  final ChatApi api;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  @override
  State<_SavedRow> createState() => _SavedRowState();
}

class _SavedRowState extends State<_SavedRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = widget.bookmark.message;
    // View-once media has no storage id — the server withholds it — so there is
    // deliberately nothing to show for those beyond the words.
    final hasThumb = !m.viewOnce &&
        m.mediaStorageId != null &&
        (m.type == MessageType.image || m.type == MessageType.video);

    return Row(
      children: [
        Expanded(
          // `FocusableTap` registers no gesture recognizer of its own, so the
          // bare `GestureDetector` inside is what actually receives the
          // pointer. Both carry the handler; wrapping alone would render a row
          // that does nothing. Never an InkWell.
          child: FocusableTap(
            onTap: widget.onTap,
            radius: theme.radiusSm,
            inset: 1,
            semanticLabel: l10n.roomInfoScreenSavedMessageJumpSemantic(
              m.senderName,
            ),
            child: GestureDetector(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                color: _pressed ? theme.accent.withValues(alpha: 0.10) : null,
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    if (hasThumb) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: RemoteImage(
                            storageId: m.mediaStorageId!,
                            api: widget.api,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.senderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.bodyEmph,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // The message's own time, not `savedAt`. The list
                              // is already ordered by when it was saved; what a
                              // reader needs here is where in the conversation
                              // they are being sent.
                              Text(
                                formatClockTime(m.createdAt),
                                style: theme.monoTiny.copyWith(
                                  color: theme.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            messagePreviewLine(m, hasThumbnail: hasThumb),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                theme.bodySoft.copyWith(color: theme.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        FocusableTap(
          onTap: widget.onUnsave,
          radius: theme.radiusSm,
          semanticLabel: l10n.roomInfoScreenSavedMessageUnsaveSemantic(
            m.senderName,
          ),
          child: GestureDetector(
            onTap: widget.onUnsave,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
              child: Icon(
                CupertinoIcons.bookmark_fill,
                size: 18,
                color: theme.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
