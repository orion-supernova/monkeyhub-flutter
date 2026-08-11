import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
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

/// How far an OUTGOING message has actually got, once the outbox is done with
/// it — the tick ladder.
///
/// Separate from [MessageStatus] on purpose, and the separation is load-bearing
/// rather than tidy. `MessageStatus` is the local outbox's state machine
/// (uploading → pending → sent, or error), and half the app tests
/// `status == MessageStatus.sent` to mean "this is a real message on the
/// server" — the gate on forwarding, replying, pinning, selecting. Adding
/// `delivered` to that enum would have quietly failed every one of those checks
/// the moment a message reached the other phone. Delivery is not a further
/// state of *our* send; it is news about someone else's device, and it arrives
/// on a different stream.
///
/// Null, rather than a fourth case, is how an incoming message says "no ticks
/// here": receipts are something you read about your own messages.
enum MessageReceipt {
  /// The server has it and nobody else's device is known to. One tick.
  sent,

  /// At least one other member's device holds it. Two ticks, still quiet — the
  /// claim is about a phone, not a person.
  delivered,

  /// At least one other member has read past it. Two ticks, loud. Gated at both
  /// ends: the reader opts in with `visibility.seen`, the viewer opts in with
  /// the local `viewReadReceipts` preference.
  seen,
}

/// Which rung an outgoing message has reached, from the two cursors the
/// repository publishes for the open room.
///
/// A helper rather than a line inlined at each stamp because there are two of
/// them — the in-bubble stamp and the external `_MetaRow` — and they must never
/// disagree about a message. The precedence is the ladder's: read implies
/// delivered, so `seen` wins even on the rare occasion the delivery cursor lags
/// behind the read one (an old row that predates `lastDeliveredAt`, or a
/// recipient who shares reads but has hidden their last-seen).
MessageReceipt? messageReceipt({
  required bool isMine,
  required bool deliveredToOthers,
  required bool seenByOthers,
}) {
  if (!isMine) return null;
  if (seenByOthers) return MessageReceipt.seen;
  if (deliveredToOthers) return MessageReceipt.delivered;
  return MessageReceipt.sent;
}

/// Everything a message says about itself once it has been sent: the time, how
/// far its delivery got, whether the reader kept it, and — for an ephemeral
/// message — how long it has left.
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
///
/// That second rule is also why [saved] is drawn HERE rather than as a corner
/// badge over the bubble. A second overlay would need its own ink for four
/// tones, its own inset clear of the tail gutter and the media tile's corner
/// radius, and its own answer for RTL — all of which this row already has, and
/// all of which a photo bubble's dark lozenge already carries. One glyph inside
/// the row costs the message body about what one tick costs it; a badge outside
/// it costs a corner of every saved message forever.
class MessageStamp extends StatelessWidget {
  const MessageStamp({
    super.key,
    required this.createdAt,
    required this.status,
    required this.tone,
    this.receipt,
    this.countdown,
    this.saved = false,
    this.edited = false,
  });

  final DateTime createdAt;
  final MessageStatus status;
  final StampTone tone;

  /// Whether the author rewrote this message after sending it.
  ///
  /// The one WORD this row allows itself, against its own "status is a glyph"
  /// rule, and deliberately: a pencil glyph reads as "draft" or "editable"
  /// (an affordance) where this is a disclosure — the text you are reading is
  /// not the text that first arrived — and a disclosure that needs decoding
  /// isn't one. Every neighbouring chat app made the same call, so the word
  /// is also the convention readers already know. It costs width only on
  /// messages that were actually edited, and the invisible twin
  /// ([StampSpacer] is this same widget) reserves the wider hole
  /// automatically.
  final bool edited;

  /// How far this message got, for the tick ladder. Null on anything that isn't
  /// mine — see [MessageReceipt].
  final MessageReceipt? receipt;

  /// Remaining life of an ephemeral message; null on every other message.
  final Duration? countdown;

  /// Whether THIS viewer has this message on their personal shelf — the
  /// per-reader bookmark of `bookmarks.ts`, never the room-wide pin.
  ///
  /// Deliberately outside the status chain below rather than another rung on
  /// it. Everything in that chain is one claim about where the message got to,
  /// which is why exactly one of its branches ever draws; this is a claim about
  /// what the reader did, and it is true at the same time as any of them. So it
  /// leads the row instead of joining the ladder — a mark on the cluster rather
  /// than the cluster's last word.
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
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
        // First in the row, which in RTL means first from the right — a `Row`
        // resolves its own direction, so nothing here has to know. `_fill`
        // rather than the outline: it is the same glyph the action menu turns
        // solid when you save, so the bubble ends up wearing the mark the menu
        // just handed it.
        if (saved) ...[
          Icon(CupertinoIcons.bookmark_fill,
              size: 10,
              color: loud,
              semanticLabel: l10n.messageStampSavedLabel),
          const SizedBox(width: 5),
        ],
        if (left != null) ...[
          theme.hourglassIcon(size: 9, color: loud),
          const SizedBox(width: 3),
          Text(_fmtCountdown(left, l10n), style: style.copyWith(color: loud)),
          const SizedBox(width: 6),
        ],
        // Ahead of the clock, so the pair reads as a sentence: "edited 14:32".
        // In the quiet ink — it is a footnote, not a status.
        if (edited) ...[
          Text(l10n.messageStampEditedLabel, style: style),
          const SizedBox(width: 4),
        ],
        Text(formatClockTime(createdAt), style: style),
        // One chain, in this order, and the order is the point. The outbox's
        // own states come FIRST because a [receipt] is computed from another
        // member's cursor measured against this message's timestamp, and a
        // cursor already ahead of "now" makes that comparison true for a
        // message created a moment ago. Left to fall through, an attachment
        // still going up would draw ticks on a photo nobody has received.
        //
        // Below that, the ladder runs downward — seen, then delivered, then
        // sent — so a message that is both delivered and read draws one glyph,
        // the furthest one it has earned.
        if (status == MessageStatus.uploading) ...[
          const SizedBox(width: 5),
          Icon(Icons.arrow_upward,
              size: 11,
              color: quiet,
              semanticLabel: l10n.messageStampUploadingLabel),
        ] else if (status == MessageStatus.pending) ...[
          const SizedBox(width: 5),
          Icon(Icons.schedule,
              size: 11, color: quiet, semanticLabel: l10n.messageStampSendingLabel),
        ] else if (status == MessageStatus.error) ...[
          const SizedBox(width: 5),
          Icon(Icons.error_outline,
              size: 12,
              color: bad,
              semanticLabel: l10n.messageStampFailedToSendLabel),
        ] else if (receipt == MessageReceipt.seen) ...[
          const SizedBox(width: 5),
          Icon(Icons.done_all,
              size: 12, color: loud, semanticLabel: l10n.messageStampSeenLabel),
        ] else if (receipt == MessageReceipt.delivered) ...[
          const SizedBox(width: 5),
          // The same glyph as `seen`, in the same size, differing only in ink.
          // That is deliberate: read is *more* of delivered, not a different
          // event, and the eye should read the promotion as the mark lighting
          // up rather than as one symbol being swapped for another.
          Icon(Icons.done_all,
              size: 12,
              color: quiet,
              semanticLabel: l10n.messageStampDeliveredLabel),
        ] else if (receipt == MessageReceipt.sent) ...[
          const SizedBox(width: 5),
          // `done` rather than `check`: it is the glyph `done_all` is drawn as
          // one half of, so the tick keeps its shape and weight when a second
          // one joins it.
          Icon(Icons.done,
              size: 12, color: quiet, semanticLabel: l10n.messageStampSentLabel),
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
  static String _fmtCountdown(Duration left, AppLocalizations l10n) {
    final s = left.inSeconds.clamp(0, 99999);
    if (s < 60) return l10n.messageStampCountdownSeconds(s);
    return l10n.messageStampCountdownMinutes((s / 60).ceil());
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
