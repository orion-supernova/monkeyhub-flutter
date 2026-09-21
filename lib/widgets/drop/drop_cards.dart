
import 'package:flutter/cupertino.dart';

import '../../drop/drop_classifier.dart';
import '../../drop/drop_copy.dart';
import '../../drop/drop_item.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/file_meta.dart';
import '../../theme/app_theme.dart';
import 'drop_glow.dart' show dropToneColor;

/// The most cards the fan ever draws.
///
/// Four, because the fifth adds no information — the count is already on the
/// verdict chip, and past four the stack stops reading as "some things" and
/// starts reading as a smear. Everything beyond it becomes the `+N` badge.
const int kDropMaxCards = 4;

/// One dragged item, as a card under the cursor.
///
/// Sized by how much is KNOWN rather than by kind. A macOS drag carries names
/// and byte counts, so the card is a wide row that can hold `Q3-deck.key` and
/// `4.2 MB`; a browser drag carries neither, so the card shrinks to a glyph
/// and a word. Drawing the wide card with "file" repeated in it four times
/// would look like a bug.
class DropCard extends StatelessWidget {
  const DropCard({
    super.key,
    required this.assessment,
    required this.theme,
    required this.l10n,
    required this.tone,
    this.overflowCount = 0,
  });

  final DropAssessment assessment;
  final AppTheme theme;
  final AppLocalizations l10n;
  final DropTone tone;

  /// Non-zero turns this card into the bottom of the stack and puts `+N` on it.
  final int overflowCount;

  static const double wide = 226;
  static const double narrow = 132;
  static const double height = 58;

  static double widthFor(DropAssessment a) =>
      a.candidate.displayName == null ? narrow : wide;

  @override
  Widget build(BuildContext context) {
    final name = assessment.candidate.displayName;
    final refused = !assessment.accepted;
    final accent = dropToneColor(theme, tone);
    final ink = refused ? theme.inkMuted : theme.ink;

    return Container(
      width: widthFor(assessment),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: refused
              ? theme.danger.withValues(alpha: 0.55)
              : accent.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          // A real drag has a shadow under it, and this one is doing the job a
          // native drag image would: separating the thing being carried from
          // everything it is being carried over. Long and soft rather than
          // tight, because it sits over arbitrary content.
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _KindGlyph(
            assessment: assessment,
            theme: theme,
            tone: tone,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? dropKindWord(l10n, assessment.kind),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.bodyEmph.copyWith(
                    color: ink,
                    // BOTH conditional, and that pairing is the point. A
                    // `TextStyle` inherits every field it does not set, so a
                    // null `decoration` beside a non-null `decorationColor`
                    // does not mean "no decoration" — it means "whatever is
                    // inherited, painted in THIS colour". Mounted outside a
                    // Scaffold, what got inherited was Flutter's debug
                    // underline, and this line is what painted it red.
                    decoration:
                        refused ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: refused ? theme.danger : null,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.monoTiny.copyWith(
                    color: refused ? theme.danger : theme.inkSoft,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          if (overflowCount > 0) ...[
            const SizedBox(width: 8),
            _OverflowPip(
              theme: theme,
              accent: accent,
              label: l10n.dropMoreCount(overflowCount),
            ),
          ],
        ],
      ),
    );
  }

  /// The second line: a size where one is known, otherwise the word for what
  /// this will become. Never both — the card is 58pt tall and the filename is
  /// the thing worth the space.
  String _subtitle() {
    switch (assessment.refusal) {
      case DropRefusal.folder:
        return dropKindWord(l10n, DropKind.folder);
      case DropRefusal.tooLarge:
        final size = assessment.candidate.size;
        return size == null
            ? formatFileSize(kMaxFileUploadBytes)
            : formatFileSize(size);
      case DropRefusal.empty:
        return formatFileSize(0);
      case DropRefusal.notPermitted:
      case DropRefusal.batchFull:
      case null:
        break;
    }
    final size = assessment.candidate.size;
    if (size != null && size > 0) {
      // Name and size together is the Finder row, which is what a Mac user is
      // already looking at when they start the drag. A downgrade earns the
      // extra half of the line here rather than a second card: this is the
      // "it's going as a regular file" warning, at the item that causes it.
      return assessment.downgraded
          ? '${formatFileSize(size)} · ${dropKindWord(l10n, DropKind.document)}'
          : formatFileSize(size);
    }
    final name = assessment.candidate.name;
    if (name != null && fileExtensionOf(name).isNotEmpty) {
      return fileTypeBadge(name);
    }
    return dropKindWord(l10n, assessment.kind);
  }
}

/// The disc on the left of a card: an icon for media, a type badge for a
/// document — the same split [FileMessage] makes in the transcript, so a `PDF`
/// looks like a `PDF` on both sides of the send.
class _KindGlyph extends StatelessWidget {
  const _KindGlyph({
    required this.assessment,
    required this.theme,
    required this.tone,
  });

  final DropAssessment assessment;
  final AppTheme theme;
  final DropTone tone;

  @override
  Widget build(BuildContext context) {
    final refused = !assessment.accepted;
    final accent = refused ? theme.danger : dropToneColor(theme, tone);
    final name = assessment.candidate.name;
    final badge = (assessment.kind == DropKind.document && name != null)
        ? fileTypeBadge(name)
        : null;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: refused ? 0.12 : 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: badge != null
          ? Text(
              badge,
              maxLines: 1,
              style: theme.monoTiny.copyWith(
                color: accent,
                fontSize: badge.length > 3 ? 8 : 9.5,
                letterSpacing: 0.2,
                height: 1,
              ),
            )
          : Icon(_icon, size: 17, color: accent),
    );
  }

  IconData get _icon {
    if (assessment.refusal == DropRefusal.folder) {
      return CupertinoIcons.folder;
    }
    switch (assessment.kind) {
      case DropKind.photo:
        return CupertinoIcons.photo;
      case DropKind.video:
        return CupertinoIcons.film;
      case DropKind.audio:
        return CupertinoIcons.waveform;
      case DropKind.folder:
        return CupertinoIcons.folder;
      case DropKind.text:
        return CupertinoIcons.text_alignleft;
      case DropKind.link:
        return CupertinoIcons.link;
      case DropKind.document:
      case DropKind.unknown:
        return CupertinoIcons.doc;
    }
  }
}

class _OverflowPip extends StatelessWidget {
  const _OverflowPip({
    required this.theme,
    required this.accent,
    required this.label,
  });

  final AppTheme theme;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.monoTiny.copyWith(
          color: accent,
          letterSpacing: 0.2,
          height: 1.15,
        ),
      ),
    );
  }
}

/// Where card [index] of [total] sits relative to the top card, and how far it
/// is turned.
///
/// A fan, not a pile. Perfectly stacked cards are indistinguishable from one
/// card with a thick border, and the single most useful thing the stack can
/// say at a glance is HOW MANY — so each card below the top one peeks out by a
/// few points and leans a little further over.
({Offset offset, double angle}) dropCardFan(int index, int total) {
  if (index == 0) return (offset: Offset.zero, angle: 0);
  final depth = index.toDouble();
  return (
    offset: Offset(depth * 7, depth * 8),
    angle: -depth * 0.032 * (index.isEven ? -1 : 1),
  );
}

/// Total height the fan occupies, used to place the verdict chip under it.
double dropFanHeight(int cards) =>
    cards == 0 ? 0 : DropCard.height + ((cards - 1) * 8);
