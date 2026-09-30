import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'expressions/expression_media.dart';
import 'remote_image.dart';
import 'speaker_scope.dart';
import 'user_avatar.dart';

/// The two colours a quote card paints the person it is quoting in.
///
/// A reply is the one place in a transcript that talks about a message OTHER
/// than the one it is attached to, so it is also the one place where the
/// reader has to be told *whose* message that is. Every one of these designs
/// already had a colour for exactly that job — [AppTheme.accent] — and every
/// one of them used the same one for everybody, which meant four elaborate
/// quote designs that all answered "replying to a message" and none that
/// answered "replying to WHOSE".
///
/// Both fall back to the accent, so a DM, a room with speaker colours off,
/// and a quote of your OWN message all render exactly as they did before.
///
/// [ring] is the same colour as [mark] but NULL where there is no speaker
/// colour to be had, which is what lets the quoted avatar stay unringed in a
/// DM instead of gaining an accent circle it never had.
typedef QuoteTone = ({Color mark, Color ink, Color? ring});

QuoteTone _quoteTone(
  BuildContext context,
  AppTheme theme,
  ReplyPreview preview,
) {
  // Quote cards all sit on a raised surface — the phantom's frosted plate, the
  // comic's mini bubble, sticky's polaroid, classic's inset — so both colours
  // are conditioned against that one ground rather than each design measuring
  // its own.
  final mark =
      SpeakerScope.markOf(context, preview.senderId, on: theme.surfaceRaised);
  return (
    mark: mark ?? theme.accent,
    ink: SpeakerScope.inkOf(context, preview.senderId,
            on: theme.surfaceRaised) ??
        theme.accent,
    ring: mark,
  );
}

/// Inline reply context, rendered as a sibling ABOVE the reply bubble.
///
/// Dispatches to one of three sub-widgets based on the user's choice in
/// [SettingsStore.replyStyle]:
///
///   * [ReplyStyle.phantomEcho] — a ghost-bubble of the parent floats above
///     the reply with a curved accent connector and a branch icon button at
///     the join point.
///   * [ReplyStyle.stickyNote] — a slightly rotated polaroid-style card
///     stuck to the top-leading edge of the bubble.
///   * [ReplyStyle.comicTail] — a small parent mini-bubble with a literal
///     comic-book triangle tail pointing down at the main bubble.
///
/// All four handle deleted parents (renders "message removed" muted,
/// disables tap, hides the branch button), media replies (thumbnail in
/// place of the text snippet), and mine/theirs symmetry.
///
/// Every design mirrors on [isMine]: the connector, the tether rail and the
/// branch button all sit on the side facing the bubble they belong to.
class ReplyIndicator extends StatelessWidget {
  const ReplyIndicator({
    super.key,
    required this.preview,
    required this.isMine,
    required this.api,
    required this.onTap,
    this.parentIsMine = false,
    this.parentAuthor,
    this.onViewThread,
    this.styleOverride,
  });

  final ReplyPreview preview;

  /// Whether the *replying* message is the current user's — drives which
  /// side everything mirrors to.
  final bool isMine;

  /// Whether the *quoted parent* was written by the current user. Designs
  /// that give the quote a bubble of its own (phantom, comic) use it to pick
  /// mine-vs-theirs coloring, so replying to yourself doesn't render a ghost
  /// in someone else's colors.
  final bool parentIsMine;

  final ChatApi api;
  final VoidCallback onTap;
  final ChatUser? parentAuthor;
  final VoidCallback? onViewThread;

  /// When non-null, render this specific style regardless of the user's
  /// setting. Used by the reply-style picker so each preview shows its own
  /// design even though the global setting is still pointing elsewhere.
  final ReplyStyle? styleOverride;

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ?? SettingsStore.instance.replyStyle;
    final tone = _quoteTone(context, ThemeScope.of(context), preview);
    switch (style) {
      case ReplyStyle.phantomEcho:
        return _PhantomEcho(
          preview: preview,
          isMine: isMine,
          parentIsMine: parentIsMine,
          api: api,
          parentAuthor: parentAuthor,
          tone: tone,
          onTap: onTap,
          onViewThread: onViewThread,
        );
      case ReplyStyle.stickyNote:
        return _StickyNote(
          preview: preview,
          isMine: isMine,
          api: api,
          parentAuthor: parentAuthor,
          tone: tone,
          onTap: onTap,
          onViewThread: onViewThread,
        );
      case ReplyStyle.comicTail:
        return _ComicTail(
          preview: preview,
          isMine: isMine,
          parentIsMine: parentIsMine,
          api: api,
          parentAuthor: parentAuthor,
          tone: tone,
          onTap: onTap,
          onViewThread: onViewThread,
        );
      case ReplyStyle.classic:
        return _ClassicQuote(
          preview: preview,
          isMine: isMine,
          api: api,
          parentAuthor: parentAuthor,
          tone: tone,
          onTap: onTap,
          onViewThread: onViewThread,
        );
    }
  }
}

/// Height the marker block always occupies, branch button or not.
///
/// It is [_BranchButton]'s own hit box, and holding it even when the button is
/// absent is deliberate: the action menu force-sizes its lifted preview into
/// the rect it measured off the live row, so a marker whose height depended on
/// whether `onViewThread` happened to be null would overflow that rect in the
/// thread overlay. Geometry here answers to layout, not to a callback.
const double _kMarkerBlock = 44.0;

/// How far the tether stops short of the bubble edge it points at, so the
/// stroke lands beside a rounded corner rather than into it.
const double _kTetherEdgeInset = 14.0;

/// Where a [ReplyTether]'s connector runs, in the tether block's own
/// coordinates. Pure geometry — no widgets, no context, no theme — so the
/// routing can be tested exactly rather than eyeballed, the same way
/// `buildRoomItems` keeps the transcript's row logic testable.
typedef TetherPath = ({
  /// Under the parent bubble's near edge, on the block's top line.
  Offset start,

  /// At this bubble's near edge, on the block's bottom line.
  Offset end,

  /// Middle of the horizontal run — where the branch button rides.
  Offset elbow,

  /// Corner rounding for the two turns. Zero when the run has no length, in
  /// which case the connector is a straight drop and there are no corners.
  double radius,
});

/// Routes the connector from the parent's bubble edge to this one's.
///
/// [parentGutter] is the width of the avatar column an incoming row reserves —
/// 0 in a DM, where no row reserves one. It only shifts the anchor when the
/// parent's row has that column and ours does not, i.e. when they are incoming
/// and we are outgoing: our slot starts at the row's edge, theirs starts past
/// the avatar. Every other combination shares an origin and needs no shift.
/// Skip it and the anchor dot floats a whole avatar column left of the bubble
/// it is supposed to be hanging off.
TetherPath replyTetherPath({
  required double width,
  required double height,
  required bool isMine,
  required bool parentIsMine,
  required double parentGutter,
}) {
  final parentInset = (isMine && !parentIsMine) ? parentGutter : 0.0;
  final startX = parentIsMine
      ? width - _kTetherEdgeInset
      : parentInset + _kTetherEdgeInset;
  final endX = isMine ? width - _kTetherEdgeInset : _kTetherEdgeInset;
  final mid = height / 2;
  final span = (endX - startX).abs();
  // Below a couple of pixels the two turns would be drawing over each other.
  // Same side means no run to make, so the connector is just a drop.
  final radius = span < 2 ? 0.0 : math.min(14.0, span / 2);
  return (
    start: Offset(startX, 0),
    end: Offset(endX, height),
    elbow: Offset((startX + endX) / 2, mid),
    radius: radius,
  );
}

/// The compact form of [ReplyIndicator]: a routed connector from the quoted
/// parent's bubble to this one, with the same branch button the full styles
/// draw riding on it. No card, no name, no text.
///
/// Used when the parent is the content row directly above
/// ([ReplyMarker.compact]). The four [ReplyStyle] designs exist to give an
/// off-screen parent a body you can read — which, when the body is already on
/// screen one row up, only puts a second copy of the same message in the
/// transcript. A name doesn't help either: it labels a bubble that is right
/// there, beside its own avatar and its own sender label.
///
/// What is actually missing in that situation is not information, it is a
/// *line*. A reply sits at one margin and its parent often at the other, with
/// nothing between them saying they belong together. So this draws the
/// relationship instead of writing it.
///
/// Routed, not freehand: down off the parent's edge, a level run at mid-height,
/// down again into this bubble. A sweep across the full transcript flattened
/// into 44px would read as a stray hairline; two elbows and a level run read as
/// deliberate. Same side is the same drawing with a zero-length run.
class ReplyTether extends StatelessWidget {
  const ReplyTether({
    super.key,
    required this.preview,
    required this.isMine,
    required this.parentIsMine,
    required this.parentGutter,
    required this.onTap,
    this.onViewThread,
  });

  /// Carried for [ReplyPreview.isDeleted] and the semantic label only —
  /// nothing in it is ever rendered.
  final ReplyPreview preview;

  /// Whether the *replying* message is the current user's: which margin the
  /// connector lands on.
  final bool isMine;

  /// Whether the *quoted parent* is: which margin it leaves from.
  final bool parentIsMine;

  /// Width of the avatar column an incoming row reserves, or 0 where rows
  /// reserve none (a DM). Supplied by the caller because the slot's size lives
  /// with the bubble, not here; only used when the parent's row has that column
  /// and ours does not.
  final double parentGutter;

  /// Jump to the quoted parent.
  final VoidCallback onTap;

  /// Open the thread overlay. Null inside the overlay itself — no
  /// thread-within-a-thread — which is the only case that drops the button.
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deleted = preview.isDeleted;
    // The compact marker prints no name at all — the line IS the whole
    // statement — so colouring it in the quoted author's own hue is the only
    // way it can say which of the bubbles above it is being answered.
    final tone = deleted
        ? theme.inkMuted.withValues(alpha: 0.55)
        : (SpeakerScope.markOf(context, preview.senderId,
                on: theme.background) ??
            theme.accent);
    final branch = onViewThread;
    final showBranch = branch != null && !deleted;

    return SizedBox(
      width: double.infinity,
      height: _kMarkerBlock,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final path = replyTetherPath(
            width: width,
            height: _kMarkerBlock,
            isMine: isMine,
            parentIsMine: parentIsMine,
            parentGutter: parentGutter,
          );
          // The tap target is the connector's own bounding box, not the block.
          // A full-width invisible target for a 30px drop would be a lie about
          // where the control is.
          final bandLeft = math.min(path.start.dx, path.end.dx) - 12;
          final bandRight = math.max(path.start.dx, path.end.dx) + 12;

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ReplyTetherPainter(
                      path: path,
                      color: tone,
                      anchored: !deleted,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: bandLeft.clamp(0.0, width),
                width: (bandRight - bandLeft).clamp(0.0, width),
                child: Semantics(
                  // The name leaves the screen; it must not leave the
                  // accessibility tree with it.
                  label: AppLocalizations.of(
                    context,
                  ).replyIndicatorInReplyToSemanticLabel(preview.senderName),
                  button: !deleted,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: deleted ? null : onTap,
                  ),
                ),
              ),
              if (showBranch)
                Positioned(
                  // Clamped: on a same-side reply the elbow sits 14px from the
                  // margin, and the button's 44px hit box would hang off it.
                  left: (path.elbow.dx - _kMarkerBlock / 2).clamp(
                    0.0,
                    math.max(0.0, width - _kMarkerBlock),
                  ),
                  top: 0,
                  child: _BranchButton(onTap: branch, theme: theme, size: 24),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Strokes a [TetherPath]: down, across, down, with rounded turns and a dot at
/// the origin so the top end reads as an anchor rather than a cut line. Alpha
/// climbs along the run, so the line arrives at this bubble rather than merely
/// passing it.
class _ReplyTetherPainter extends CustomPainter {
  const _ReplyTetherPainter({
    required this.path,
    required this.color,
    required this.anchored,
  });

  final TetherPath path;
  final Color color;

  /// False for a deleted parent: no dot, since there is nothing left to anchor
  /// to. The line still draws — the reply is still a reply.
  final bool anchored;

  @override
  void paint(Canvas canvas, Size size) {
    final start = path.start;
    final end = path.end;
    final mid = size.height / 2;
    final r = path.radius;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // Vertical, over the whole box — deliberately not a gradient laid along
      // start→end. A same-side reply has start.dx == end.dx, which makes that
      // rect zero-width and the shader degenerate on the single commonest case
      // there is. Top-to-bottom is also what the line means: it fades in under
      // the parent and arrives at full strength on this bubble.
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.95)],
      ).createShader(Offset.zero & size);

    final wire = Path()..moveTo(start.dx, start.dy);
    if (r == 0) {
      // Same margin: a straight drop, bowed a little so it reads as drawn
      // rather than as a border someone forgot to remove.
      wire.quadraticBezierTo(
        start.dx + (path.elbow.dx > size.width / 2 ? -6 : 6),
        mid,
        end.dx,
        end.dy,
      );
    } else {
      final dir = end.dx > start.dx ? 1.0 : -1.0;
      wire
        ..lineTo(start.dx, mid - r)
        ..quadraticBezierTo(start.dx, mid, start.dx + dir * r, mid)
        ..lineTo(end.dx - dir * r, mid)
        ..quadraticBezierTo(end.dx, mid, end.dx, mid + r)
        ..lineTo(end.dx, end.dy);
    }
    canvas.drawPath(wire, stroke);

    if (anchored) {
      canvas.drawCircle(
        Offset(start.dx, start.dy + 2),
        2.5,
        Paint()..color = color.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReplyTetherPainter old) =>
      old.path != path || old.color != color || old.anchored != anchored;
}

// ─────────────────── shared bits ───────────────────

String _previewLabel(BuildContext context, ReplyPreview preview) {
  // Ahead of the passthrough below, or the sentinel itself would be rendered
  // as the quoted text. There is no thumbnail to sit beside it either —
  // `_mediaThumb` drops the slot when the preview carries no storage id, which
  // for a view-once parent it never does.
  if (preview.isViewOnce) {
    return AppLocalizations.of(context).replyIndicatorViewOnceLabel;
  }
  // Ahead of the passthrough too: a GIF's `content` is its alt text, and a
  // quote reading "Hello" would say the parent typed it.
  if (preview.type == MessageType.gif) return 'GIF';
  if (preview.type == MessageType.sticker) {
    return AppLocalizations.of(context)
        .replyIndicatorStickerLabel(preview.contentPreview);
  }
  if (preview.contentPreview.isNotEmpty) return preview.contentPreview;
  switch (preview.type) {
    case MessageType.image:
    case MessageType.video:
      // The thumbnail already says "this is media" — a "photo" / "video"
      // text fallback was redundant and obvious.
      return '';
    case MessageType.audio:
      // Voice notes have no thumbnail, so the label IS the only signal.
      return AppLocalizations.of(context).replyIndicatorVoiceMessageLabel;
    case MessageType.file:
      // Nor do documents — and unlike a voice note, one document is not
      // interchangeable with another, so the word "document" would make a
      // quote of a spreadsheet indistinguishable from a quote of a contract.
      // `replyToPreview` carries no filename (it snapshots the parent's text,
      // which for a document send is its caption), so this is the best that
      // is available without widening that snapshot.
      return AppLocalizations.of(context).replyIndicatorDocumentLabel;
    default:
      return '…';
  }
}

Widget _smallAvatar({
  required ReplyPreview preview,
  required ChatApi api,
  required ChatUser? parentAuthor,
  required AppTheme theme,
  required Color accentTone,
  /// The quoted author's speaker colour, or null where there is none. Rings
  /// the puck so the face in the quote matches the face beside the message
  /// being quoted — the two are usually both on screen, and an unringed copy
  /// of a ringed avatar reads as a different person.
  Color? ring,
  double size = 18,
}) {
  if (parentAuthor != null) {
    return UserAvatar(
      user: parentAuthor,
      api: api,
      size: size,
      showStatus: false,
      ring: ring != null,
      ringColor: ring,
    );
  }
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: accentTone.withValues(alpha: 0.18),
      border: Border.all(color: accentTone.withValues(alpha: 0.45), width: 1),
    ),
    child: Text(
      preview.senderName.isEmpty
          ? '?'
          : preview.senderName.characters.first.toUpperCase(),
      style: theme.monoTiny.copyWith(color: accentTone, height: 1.0),
    ),
  );
}

Widget _mediaThumb({
  required ReplyPreview preview,
  required ChatApi api,
  required AppTheme theme,
  double size = 18,
}) {
  final hasMedia =
      preview.mediaStorageId != null && preview.mediaStorageId!.isNotEmpty;
  if (hasMedia) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: RemoteImage(
        storageId: preview.mediaStorageId!,
        api: api,
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
  // A quoted GIF or sticker carries its own small picture instead.
  final thumb = expressionThumbnail(
    type: preview.type,
    url: preview.mediaUrl,
    stickerStorageId: preview.stickerStorageId,
    stickerFormat: preview.stickerFormat,
    alt: preview.contentPreview,
    api: api,
    size: size,
  );
  if (thumb != null) return thumb;
  // No thumbnail available — drop the slot entirely rather than falling
  // back to a "photo / video" glyph here. Those glyphs belong on the
  // chat-list "last message" row, not on the in-room reply indicator.
  return const SizedBox.shrink();
}

/// Branch-icon button reused by all four designs. Frosted accent circle
/// over `BackdropFilter` blur — sits in front of bubble backgrounds without
/// fighting them. The visual stays compact ([size] px) but the hit area is
/// 44×44 so the user doesn't have to land a precise tap to open the thread.
class _BranchButton extends StatelessWidget {
  const _BranchButton({
    required this.onTap,
    required this.theme,
    this.size = 26,
  });
  final VoidCallback onTap;
  final AppTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hitSize = math.max(size, 44.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accent.withValues(alpha: 0.18),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.55),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.arrow_branch,
                  size: size * 0.5,
                  color: theme.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── A) Phantom Echo ─────────────────────────

class _PhantomEcho extends StatelessWidget {
  const _PhantomEcho({
    required this.preview,
    required this.isMine,
    required this.parentIsMine,
    required this.api,
    required this.parentAuthor,
    required this.tone,
    required this.onTap,
    required this.onViewThread,
  });
  final ReplyPreview preview;
  final bool isMine;
  final bool parentIsMine;
  final ChatApi api;
  final ChatUser? parentAuthor;
  final QuoteTone tone;
  final VoidCallback onTap;
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deleted = preview.isDeleted;
    // Never wider than the bubble it is quoting for. This used to be a
    // fraction of the WINDOW, which on a desktop pane made the quote card
    // several times the width of the message under it.
    final maxW = messageMaxWidth(context);
    // Tinted toward the accent when the quoted message is the current user's,
    // matching how their own bubbles read. Blended to an opaque colour first
    // so the 0.88 alpha below doesn't fade an already-translucent token twice.
    final phantomBg = parentIsMine
        ? Color.alphaBlend(theme.accentSoft, theme.surfaceRaised)
        : theme.surfaceRaised;
    final phantomInk = theme.ink;
    final phantomMuted = theme.inkMuted;

    return Padding(
      // 2px bottom padding leaves a hairline gap before the connector area.
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // ── phantom card ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: deleted ? null : onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  // A whisper of blur to give the "phantom" feel without
                  // making it illegible.
                  filter: ImageFilter.blur(sigmaX: 0.4, sigmaY: 0.4),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: phantomBg.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tone.mark.withValues(alpha: 0.28),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _PhantomBody(
                      preview: preview,
                      api: api,
                      parentAuthor: parentAuthor,
                      theme: theme,
                      tone: tone,
                      phantomInk: phantomInk,
                      phantomMuted: phantomMuted,
                      deleted: deleted,
                    ),
                  ),
                ),
              ),
            ),
            // ── connector with branch icon ──
            //
            // Sized to the connector itself rather than wrapped in a
            // full-width Align: an unbounded SizedBox here stretched the whole
            // Column to `maxW`, which made the parent bubble's long-press
            // target extend far past the visible bubble on short messages.
            // The Column's crossAxisAlignment already mirrors it.
            //
            // The connector stays when the parent is deleted — only the branch
            // button goes. Dropping the whole 44px block collapsed the gap to
            // 2px and made deleted-parent replies look like a different design
            // (comic and classic both keep theirs).
            SizedBox(
              width: 64,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PhantomConnectorPainter(
                        isMine: isMine,
                        color: deleted
                            ? theme.inkMuted.withValues(alpha: 0.55)
                            : tone.mark,
                      ),
                    ),
                  ),
                  if (onViewThread != null && !deleted)
                    Positioned(
                      // 44×44 hit area; offset places the visual
                      // icon centered on the curve's midpoint.
                      left: isMine ? null : 0,
                      right: isMine ? 0 : null,
                      top: 0,
                      child: _BranchButton(onTap: onViewThread!, theme: theme),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a soft quadratic-Bezier curve from the phantom's bottom toward
/// the bubble's top, on the leading edge for theirs / trailing edge for mine.
class _PhantomConnectorPainter extends CustomPainter {
  _PhantomConnectorPainter({required this.isMine, required this.color});
  final bool isMine;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.95)],
      ).createShader(Offset.zero & size);

    final path = Path();
    if (isMine) {
      // Curve emerges from the trailing side of the phantom (right) and
      // dives down to the main bubble's leading (still on the right since
      // mine bubbles are right-aligned). Soft S-curve.
      path.moveTo(size.width - 8, 2);
      path.quadraticBezierTo(
        size.width - 36,
        size.height / 2,
        size.width - 12,
        size.height - 2,
      );
    } else {
      path.moveTo(8, 2);
      path.quadraticBezierTo(36, size.height / 2, 12, size.height - 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PhantomConnectorPainter old) =>
      old.isMine != isMine || old.color != color;
}

class _PhantomBody extends StatelessWidget {
  const _PhantomBody({
    required this.preview,
    required this.api,
    required this.parentAuthor,
    required this.theme,
    required this.tone,
    required this.phantomInk,
    required this.phantomMuted,
    required this.deleted,
  });
  final ReplyPreview preview;
  final ChatApi api;
  final ChatUser? parentAuthor;
  final AppTheme theme;
  final QuoteTone tone;
  final Color phantomInk;
  final Color phantomMuted;
  final bool deleted;

  @override
  Widget build(BuildContext context) {
    final isMedia =
        preview.type == MessageType.image || preview.type == MessageType.video;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _smallAvatar(
          preview: preview,
          api: api,
          parentAuthor: parentAuthor,
          theme: theme,
          accentTone: tone.mark,
          ring: tone.ring,
          size: 18,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.senderName.toUpperCase(),
                style: theme.monoTiny.copyWith(
                  color: deleted ? phantomMuted : tone.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              if (deleted)
                Text(
                  AppLocalizations.of(context).replyIndicatorMessageRemoved,
                  style: theme.bodySoft.copyWith(
                    color: phantomMuted,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else if (isMedia)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _mediaThumb(preview: preview, api: api, theme: theme),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _previewLabel(context, preview),
                        style: theme.bodySoft.copyWith(color: phantomInk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  _previewLabel(context, preview),
                  style: theme.bodySoft.copyWith(color: phantomInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── B) Sticky Note ─────────────────────────

class _StickyNote extends StatelessWidget {
  const _StickyNote({
    required this.preview,
    required this.isMine,
    required this.api,
    required this.parentAuthor,
    required this.tone,
    required this.onTap,
    required this.onViewThread,
  });
  final ReplyPreview preview;
  final bool isMine;
  final ChatApi api;
  final ChatUser? parentAuthor;
  final QuoteTone tone;
  final VoidCallback onTap;
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deleted = preview.isDeleted;
    // Sits slightly inside the bubble's own cap — the proportion this style
    // always had (0.66 vs the 0.72 the others used), now measured against the
    // bubble instead of the window.
    final maxW = messageMaxWidth(context) * 0.92;
    final rotation = isMine ? 0.035 : -0.035; // ~±2°
    final isMedia =
        preview.type == MessageType.image || preview.type == MessageType.video;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Padding(
        // Padding indents the polaroid slightly from the bubble's leading
        // edge so the rotation is visible without clipping; the pin stub
        // below supplies the gap to the bubble underneath.
        padding: EdgeInsets.fromLTRB(isMine ? 0 : 8, 0, isMine ? 8 : 0, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Transform.rotate(
              angle: rotation,
              alignment: isMine
                  ? AlignmentDirectional.bottomEnd
                  : AlignmentDirectional.bottomStart,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: deleted ? null : onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.divider, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Leading reserve, used when the branch button is
                          // mirrored to this side.
                          if (onViewThread != null && !deleted && isMine)
                            const SizedBox(width: 28),
                          _smallAvatar(
                            preview: preview,
                            api: api,
                            parentAuthor: parentAuthor,
                            theme: theme,
                            accentTone: tone.mark,
                            ring: tone.ring,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preview.senderName.toUpperCase(),
                                  style: theme.monoTiny.copyWith(
                                    color: deleted ? theme.inkMuted : tone.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                if (deleted)
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).replyIndicatorMessageRemoved,
                                    style: theme.bodySoft.copyWith(
                                      color: theme.inkMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (isMedia)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _mediaThumb(
                                        preview: preview,
                                        api: api,
                                        theme: theme,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _previewLabel(context, preview),
                                          style: theme.bodySoft.copyWith(
                                            color: theme.ink,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    _previewLabel(context, preview),
                                    style: theme.bodySoft.copyWith(
                                      color: theme.ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Trailing reserve — mirrors with the button above.
                          if (onViewThread != null && !deleted && !isMine)
                            const SizedBox(width: 28),
                        ],
                      ),
                      if (onViewThread != null && !deleted)
                        Positioned(
                          // Hangs off the polaroid's bottom corner on the side
                          // facing the bubble; the 44×44 hit area extends well
                          // past it. Mirrored like the rest of the note — left
                          // unmirrored it overhung the column edge on my own
                          // messages, since the note is flush right there.
                          left: isMine ? -22 : null,
                          right: isMine ? null : -22,
                          bottom: -22,
                          child: _BranchButton(
                            onTap: onViewThread!,
                            theme: theme,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Pin stub. The other three designs all bind the quote to its
            // bubble with something — a bezier, a comic tail, a tether rail —
            // and sticky was the only one where the note floated unattached.
            // Inset to sit under the avatar puck, mirrored with the note.
            Padding(
              padding: EdgeInsets.only(
                left: isMine ? 0 : 22,
                right: isMine ? 22 : 0,
              ),
              child: Container(
                width: 2,
                height: 10,
                decoration: BoxDecoration(
                  color: tone.mark.withValues(alpha: deleted ? 0.35 : 0.75),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── C) Comic Tail ─────────────────────────

class _ComicTail extends StatelessWidget {
  const _ComicTail({
    required this.preview,
    required this.isMine,
    required this.parentIsMine,
    required this.api,
    required this.parentAuthor,
    required this.tone,
    required this.onTap,
    required this.onViewThread,
  });
  final ReplyPreview preview;
  final bool isMine;
  final bool parentIsMine;
  final ChatApi api;
  final ChatUser? parentAuthor;
  final QuoteTone tone;
  final VoidCallback onTap;
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deleted = preview.isDeleted;
    // As above — the comic tail's 0.62-of-window proportion, re-based on the
    // bubble's cap.
    final maxW = messageMaxWidth(context) * 0.86;
    final isMedia =
        preview.type == MessageType.image || preview.type == MessageType.video;
    // Tinted toward the accent when the quoted message is the current user's
    // — replying to yourself used to render the mini bubble in someone
    // else's colors. Tail color matches so it reads as one continuous shape.
    final bubbleColor = parentIsMine
        ? Color.alphaBlend(theme.accentSoft, theme.surfaceRaised)
        : theme.surfaceRaised;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: deleted ? null : onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.ink, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: theme.ink.withValues(alpha: 0.18),
                    blurRadius: 0,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Leading reserve, used when the branch button is
                      // mirrored to this side.
                      if (onViewThread != null && !deleted && isMine)
                        const SizedBox(width: 30),
                      _smallAvatar(
                        preview: preview,
                        api: api,
                        parentAuthor: parentAuthor,
                        theme: theme,
                        accentTone: tone.mark,
                        ring: tone.ring,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preview.senderName.toUpperCase(),
                              style: theme.monoTiny.copyWith(
                                color: deleted ? theme.inkMuted : tone.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            if (deleted)
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).replyIndicatorMessageRemoved,
                                style: theme.bodySoft.copyWith(
                                  color: theme.inkMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else if (isMedia)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _mediaThumb(
                                    preview: preview,
                                    api: api,
                                    theme: theme,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _previewLabel(context, preview),
                                      style: theme.bodySoft.copyWith(
                                        color: theme.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                _previewLabel(context, preview),
                                style: theme.bodySoft.copyWith(
                                  color: theme.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Trailing reserve — mirrors with the button below.
                      if (onViewThread != null && !deleted && !isMine)
                        const SizedBox(width: 30),
                    ],
                  ),
                  if (onViewThread != null && !deleted)
                    Positioned(
                      // 44×44 hit area centered roughly on the mini bubble's
                      // top corner, on the side facing the reply. The tail
                      // below already mirrors; this didn't, which read as a
                      // misplaced icon on my own messages.
                      left: isMine ? -14 : null,
                      right: isMine ? null : -14,
                      top: -14,
                      child: _BranchButton(
                        onTap: onViewThread!,
                        theme: theme,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // The comic-book triangle tail. Aligned to the leading edge of the
          // mini bubble for theirs and trailing for mine, so it visually
          // points toward where the main reply bubble's leading edge sits.
          // No Align wrapper: it expanded to the full `maxW`, dragging the
          // whole Column — and therefore the bubble's long-press target —
          // out to 62% of the screen beside short messages. The Column's
          // crossAxisAlignment already mirrors this.
          Padding(
            padding: EdgeInsets.only(
              left: isMine ? 0 : 18,
              right: isMine ? 18 : 0,
            ),
            child: CustomPaint(
              size: const Size(16, 12),
              painter: _ComicTailPainter(fill: bubbleColor, stroke: theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicTailPainter extends CustomPainter {
  _ComicTailPainter({required this.fill, required this.stroke});
  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ComicTailPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

// ───────────────────────── D) Classic Quote ─────────────────────────

/// The original "Tether & Echo" — accent-tinted inset surface with a tether
/// bar on the leading edge, parent avatar puck, mono-caps header, and a
/// 1-line content snippet. Trailing branch icon. Familiar WhatsApp-style
/// quote pill, kept around for users who prefer a more conventional look.
class _ClassicQuote extends StatelessWidget {
  const _ClassicQuote({
    required this.preview,
    required this.isMine,
    required this.api,
    required this.parentAuthor,
    required this.tone,
    required this.onTap,
    required this.onViewThread,
  });
  final ReplyPreview preview;
  final bool isMine;
  final ChatApi api;
  final ChatUser? parentAuthor;
  final QuoteTone tone;
  final VoidCallback onTap;
  final VoidCallback? onViewThread;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final deleted = preview.isDeleted;
    // See _PhantomEcho: the bubble's cap, not a slice of the window.
    final maxW = messageMaxWidth(context);
    final isMedia =
        preview.type == MessageType.image || preview.type == MessageType.video;
    final mutedInk = theme.inkMuted;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: deleted ? null : onTap,
          child: Container(
            decoration: BoxDecoration(
              color: tone.mark.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IntrinsicHeight(
              child: Row(
                // Hugs its content. With the default MainAxisSize.max (and
                // the Expanded that used to sit below) the quote card always
                // filled maxW, so a one-word quote painted a full-width slab.
                // The stretch here is the CROSS axis — it equalises the
                // accent rail's height, and is unrelated.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // Mirrored on isMine. This was the one design that ignored
                // the flag entirely: the rail was pinned hard-left and the
                // branch button hard-right for both sides, so on the user's
                // own right-aligned bubbles the accent tether pointed away
                // from the bubble it belonged to.
                textDirection: isMine ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: tone.mark.withValues(alpha: 0.95),
                      borderRadius: BorderRadiusDirectional.horizontal(
                        start: const Radius.circular(8),
                      ).resolve(isMine ? TextDirection.rtl : TextDirection.ltr),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _smallAvatar(
                      preview: preview,
                      api: api,
                      parentAuthor: parentAuthor,
                      theme: theme,
                      accentTone: tone.mark,
                      ring: tone.ring,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flexible, not Expanded: the text takes only what it needs
                  // and still ellipsizes when the quote is long enough to hit
                  // maxW.
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.senderName.toUpperCase(),
                            style: theme.monoTiny.copyWith(
                              color: deleted ? mutedInk : tone.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (deleted)
                            Text(
                              AppLocalizations.of(
                                context,
                              ).replyIndicatorMessageRemoved,
                              style: theme.bodySoft.copyWith(
                                color: mutedInk,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (isMedia)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _mediaThumb(
                                  preview: preview,
                                  api: api,
                                  theme: theme,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _previewLabel(context, preview),
                                    style: theme.bodySoft.copyWith(
                                      color: theme.ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              _previewLabel(context, preview),
                              // Roman, not italic, and full-strength ink —
                              // classic was the only design that italicised
                              // live message text, which made it read as
                              // deleted/placeholder next to the other three.
                              style: theme.bodySoft.copyWith(color: theme.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (onViewThread != null && !deleted) ...[
                    _BranchButton(onTap: onViewThread!, theme: theme, size: 24),
                    const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
