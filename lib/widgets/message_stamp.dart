import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/theme_scope.dart';

/// Wall-clock time as the transcript writes it: 24h, zero-padded, no date.
/// The date is carried by the day separators between runs, so a message only
/// ever has to say where in the day it landed.
String formatClockTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// What a stamp is being drawn *on*, which is the only thing that decides its
/// ink and its chrome.
///
/// Deliberately not `isMine`: the same outgoing message is accent-filled in a
/// text bubble and laid over a photograph in a media one, and those need
/// different answers out of the same widget.
enum StampTone {
  /// Inside an incoming bubble — a theme surface behind it.
  onBubble,

  /// Inside an outgoing bubble, which every theme fills with `accent`. Accent
  /// on accent is invisible, so emphasis here means going up to `accentInk`
  /// rather than reaching for a hue.
  onAccent,

  /// Over a photo or a video frame — over a colour no theme knows.
  onMedia,

  /// On the transcript background, for the two message shapes that have no
  /// bubble of their own to sit in. See `messageStampsInline`.
  onSurface,
}

/// Everything a message says about itself once it has been sent: the time, how
/// far its delivery got, and — for an ephemeral message — how long it has left.
///
/// This used to be a row *below* the bubble, which cost every single message a
/// line of vertical space to show four characters. It now lives inside the
/// bubble, trailing the last word, so the eye finds the time where the sentence
/// ends. Two consequences shaped this widget:
///
///  * **The palette depends on what it sits on** — see [StampTone].
///  * **Status is a glyph, not a word.** `· SENDING` / `· FAILED` / `SEEN` were
///    affordable below the bubble and are not affordable inside it: every
///    character of status is a character the message body gives up. The words
///    live on as the icons' semantics labels.
class MessageStamp extends StatelessWidget {
  const MessageStamp({
    super.key,
    required this.createdAt,
    required this.status,
    required this.tone,
    this.showSeen = false,
    this.countdown,
  });

  final DateTime createdAt;
  final MessageStatus status;
  final StampTone tone;

  /// Whether to draw the read receipt. Callers pass `isMine && seenByOthers`.
  final bool showSeen;

  /// Remaining life of an ephemeral message; null on every other message.
  final Duration? countdown;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Held back from full strength on every surface: the stamp is the least
    // important thing in the bubble and should read as a whisper.
    final quiet = switch (tone) {
      StampTone.onBubble || StampTone.onSurface => theme.inkMuted,
      StampTone.onAccent => theme.accentInk.withValues(alpha: 0.72),
      StampTone.onMedia => Colors.white.withValues(alpha: 0.92),
    };
    // What it uses when it has something to actually say — the receipt, the
    // countdown.
    final loud = switch (tone) {
      StampTone.onBubble || StampTone.onSurface => theme.accent,
      StampTone.onAccent => theme.accentInk,
      StampTone.onMedia => Colors.white,
    };
    final bad = switch (tone) {
      StampTone.onBubble || StampTone.onSurface => theme.danger,
      // Danger over an accent fill is a coin toss across nine themes — several
      // accents are themselves red. The bubble's own ink is the one colour
      // guaranteed to read on it, which is the same answer `_LinkAwareBubble`
      // reaches for when it needs a link to show up on an outgoing bubble.
      StampTone.onAccent => theme.accentInk,
      StampTone.onMedia => Colors.white,
    };

    final style = theme.monoTiny.copyWith(
      color: quiet,
      // `monoTiny` has none. Without them a per-second countdown breathes the
      // paragraph's wrap point, because the stamp now shares a line box with
      // the message body.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final left = countdown;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (left != null) ...[
          theme.hourglassIcon(size: 9, color: loud),
          const SizedBox(width: 3),
          Text(_fmtCountdown(left), style: style.copyWith(color: loud)),
          const SizedBox(width: 6),
        ],
        Text(formatClockTime(createdAt), style: style),
        if (status == MessageStatus.pending) ...[
          const SizedBox(width: 5),
          Icon(Icons.schedule, size: 11, color: quiet, semanticLabel: 'sending'),
        ] else if (status == MessageStatus.error) ...[
          const SizedBox(width: 5),
          Icon(Icons.error_outline,
              size: 12, color: bad, semanticLabel: 'failed to send'),
        ] else if (showSeen) ...[
          const SizedBox(width: 5),
          Icon(Icons.done_all, size: 12, color: loud, semanticLabel: 'seen'),
        ],
      ],
    );

    if (tone != StampTone.onMedia) return row;
    // A media tile has no bubble — alignment in the row is what conveys
    // mine/theirs — so there is no surface to put a stamp beside, only the
    // picture. A dark lozenge holds it, the way VideoMessage already holds its
    // play button. Not a theme colour on purpose: it sits over a photograph,
    // whose colour no theme knows.
    return DefaultTextStyle(
      style: style,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(999),
        ),
        child: row,
      ),
    );
  }

  /// Seconds while seconds matter, whole minutes once they don't — and rounded
  /// *up*, so a message never claims less life than it has. The row below the
  /// bubble could afford `4m 07s`; space shared with the message body cannot.
  static String _fmtCountdown(Duration left) {
    final s = left.inSeconds.clamp(0, 99999);
    if (s < 60) return '${s}s';
    return '${(s / 60).ceil()}m';
  }
}

/// Marks the stamp that is actually painted, as opposed to the invisible twin
/// that reserves room for it inside the paragraph.
///
/// Both are the same widget, so a type finder sees two of everything. Anything
/// that needs the real one — a test, a widget-tree dump — looks for this.
const Key kVisibleStampKey = ValueKey('message-stamp');

/// The paragraph-level hole that keeps a bubble's last line from running under
/// its stamp.
///
/// It is the *same widget*, invisible. Nothing is measured and no number is
/// shared between the two: whatever the stamp costs — at this text scale, with
/// this status, in this theme's `monoTiny` — is exactly what the last line gives
/// up, and a line too full to give it up wraps instead.
///
/// `Opacity(0)` rather than `Offstage`/`Visibility`: it still lays out, and
/// `RenderOpacity` paints nothing at alpha 0 without allocating a layer.
InlineSpan stampSpacerSpan(MessageStamp stamp) => WidgetSpan(
      // `middle` rather than `baseline`: the child has no text baseline worth
      // resolving, and every theme's body line box is taller than the stamp,
      // so centring it in the line adds no height.
      alignment: PlaceholderAlignment.middle,
      child: StampSpacer(stamp: stamp),
    );

/// The invisible twin. Named rather than inlined so a widget tree can be read:
/// two identical stamps in one bubble is confusing until one of them says what
/// it is for.
class StampSpacer extends StatelessWidget {
  const StampSpacer({super.key, required this.stamp});

  final MessageStamp stamp;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Opacity(
          opacity: 0,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: stamp,
          ),
        ),
      );
}

/// A bubble text block with its stamp tucked into the bottom-trailing corner.
///
/// [child] must already carry `stampSpacerSpan(stamp)` as its last span — this
/// widget places the visible one, the span reserves the room, and passing the
/// same [stamp] to both is what keeps them the same size.
///
/// The [Positioned] lives *inside* the padded box, so `end: padding.right` is
/// measured from the bubble body's edge. The tail gutter is applied by the
/// enclosing `Container`'s shape before any of this, so nothing here needs to
/// know the tail exists.
class StampedTextBlock extends StatelessWidget {
  const StampedTextBlock({
    super.key,
    required this.stamp,
    required this.padding,
    required this.child,
  });

  final MessageStamp stamp;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(padding: padding, child: child),
        Positioned.directional(
          // Follows the paragraph: in RTL the trailing span lands at the visual
          // left, and so does the stamp.
          textDirection: Directionality.of(context),
          end: padding.right,
          bottom: padding.bottom,
          child: KeyedSubtree(key: kVisibleStampKey, child: stamp),
        ),
      ],
    );
  }
}

/// A media tile with its stamp laid over the bottom-trailing corner.
///
/// The stamp is a SIBLING of whatever [tile] holds — never inside it. The photo
/// is carried through its Hero flight by `SteadyHero` and must not be carrying
/// a timestamp when it lands fullscreen.
class StampedMedia extends StatelessWidget {
  const StampedMedia({super.key, required this.tile, required this.stamp});

  final Widget tile;
  final MessageStamp? stamp;

  @override
  Widget build(BuildContext context) {
    final s = stamp;
    if (s == null) return tile;
    return Stack(
      children: [
        tile,
        Positioned.directional(
          textDirection: Directionality.of(context),
          // 8 clears the tile's own large corner radius: a fully-rounded
          // lozenge inset 8 from both edges keeps its nearest material well
          // inside the curve, so no dark nub pokes outside the picture.
          end: 8,
          bottom: 8,
          // A timestamp is not a tap target; the tile underneath owns the tap.
          child: KeyedSubtree(
            key: kVisibleStampKey,
            child: IgnorePointer(child: s),
          ),
        ),
      ],
    );
  }
}
