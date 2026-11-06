/// The transcript half of a message: the button, and the slab that opens
/// under it. One component for voice notes, videos and round video notes.
///
/// ── One component, three homes ─────────────────────────────────────────────
///
/// [TranscriptButton] and [TranscriptSlab] are the same widgets wherever they
/// are used. A voice bubble puts the button in its player row and the slab
/// inside its own bubble. A video or a round note has no text bubble to open
/// into, so [MediaTranscript] wraps the picture: the button sits on a corner
/// of it (`onMedia`, white on a dark chip, readable over any frame) and the
/// slab opens as a card of its own under the picture, in the bubble's colour.
/// What differs per kind lives in `TranscriptSubject`, not here.
///
/// ── Why it reads along ─────────────────────────────────────────────────────
///
/// A transcript under a voice note is two ways into the same message, and the
/// interesting moment is when someone uses both — reading while listening, or
/// skimming for the part worth replaying. So the slab follows playback the way
/// the waveform does: words already spoken take the full ink, the rest wait at
/// the waveform's unplayed alpha, and tapping a word jumps the audio there.
/// At rest (never played, or finished) the whole transcript is full ink — a
/// half-dimmed paragraph that is not playing would just look faded.
///
/// ── Why the slab grows downward ────────────────────────────────────────────
///
/// The same reasoning as the translation slab (see `translation_slab.dart`):
/// the player stays put and the transcript arrives under a hairline, so the
/// list grows rather than the bubble changing shape under the reader's thumb.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../companions/translation/language.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../media/file_meta.dart' show formatFileSize;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../transcripts/transcript.dart';
import '../transcripts/transcript_subject.dart';
import '../transcripts/voice_transcriber.dart';
import '../services/clipboard_actions.dart';
import 'spring_press.dart';
import 'translation_slab.dart' show FrozenBubble;

/// The 26pt disc at the end of the player row.
///
/// Its glyph is three lines of "text" that fold into a chevron when the slab
/// opens, so the same control reads as "show the words" and then "put them
/// away". While the model downloads a ring fills around it; while the engine
/// works the lines breathe.
class TranscriptButton extends StatelessWidget {
  const TranscriptButton({
    super.key,
    required TranscriptHandle this.handle,
    required this.isMine,
    required this.onTap,
    this.onMedia = false,
  });

  /// The same disc, at rest, where the platform cannot transcribe (the
  /// browser). It stays because it is the app's to show off: [onTap] says
  /// where transcripts live instead of hiding that they exist.
  const TranscriptButton.appOnly({
    super.key,
    required this.isMine,
    required this.onTap,
  })  : handle = null,
        onMedia = false;

  final TranscriptHandle? handle;
  final bool isMine;
  final VoidCallback onTap;

  /// Sitting on a picture rather than a bubble: white ink on a dark chip,
  /// which reads over any frame, instead of the bubble's own ink.
  final bool onMedia;

  static const double size = 26;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ink = onMedia ? Colors.white : (isMine ? theme.accentInk : theme.ink);
    final handle = this.handle;
    if (handle == null) {
      return SpringPress(
        onTap: onTap,
        scale: PressSpec.scaleSmall,
        focusShape: FocusRingShape.circle,
        focusRadius: size / 2 + 2,
        semanticLabel: l10n.voiceTranscriptShow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: _TranscriptDisc(
            ink: ink,
            fill: ink.withValues(alpha: 0.12),
            open: false,
            busy: false,
            ring: null,
            indeterminate: false,
          ),
        ),
      );
    }
    final frozen = FrozenBubble.of(context);
    return ListenableBuilder(
      listenable: frozen
          ? const AlwaysStoppedAnimation<double>(0)
          : Listenable.merge([handle, VoiceTranscriber.instance.download]),
      builder: (context, _) {
        final phase = handle.phase;
        final dl = VoiceTranscriber.instance.download.value;
        final double? ring = switch (phase) {
          TranscriptPhase.downloading => dl?.fraction ?? 0,
          TranscriptPhase.transcribing => handle.progress,
          _ => null,
        };
        final busy = phase == TranscriptPhase.downloading ||
            phase == TranscriptPhase.transcribing;
        return SpringPress(
          onTap: onTap,
          scale: PressSpec.scaleSmall,
          focusShape: FocusRingShape.circle,
          focusRadius: size / 2 + 2,
          semanticLabel:
              handle.open ? l10n.voiceTranscriptHide : l10n.voiceTranscriptShow,
          child: Padding(
            // The disc is 26pt; the target is not. Padding is what takes the
            // tap area to 34 x 44 inside a row the play button already makes
            // 34 tall.
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _TranscriptDisc(
              ink: ink,
              fill: onMedia
                  ? Colors.black.withValues(alpha: handle.open ? 0.62 : 0.5)
                  : ink.withValues(alpha: handle.open ? 0.2 : 0.12),
              open: handle.open,
              busy: busy,
              ring: ring,
              indeterminate: phase == TranscriptPhase.transcribing && ring == null,
            ),
          ),
        );
      },
    );
  }
}

class _TranscriptDisc extends StatefulWidget {
  const _TranscriptDisc({
    required this.ink,
    required this.fill,
    required this.open,
    required this.busy,
    required this.ring,
    required this.indeterminate,
  });

  final Color ink;
  final Color fill;
  final bool open;
  final bool busy;

  /// 0..1 around the rim, or null for no ring.
  final double? ring;

  /// Queued behind another note: a short arc travelling the rim instead of a
  /// fill, because there is no fraction to show yet.
  final bool indeterminate;

  @override
  State<_TranscriptDisc> createState() => _TranscriptDiscState();
}

class _TranscriptDiscState extends State<_TranscriptDisc>
    with TickerProviderStateMixin {
  late final AnimationController _fold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.open ? 1 : 0,
  );

  /// The breathing loop. Only exists while busy, and never under calm motion:
  /// idle loops are for live states, and a ticker behind a static glyph is the
  /// cost the setting removes.
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(_TranscriptDisc old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      final calm = MotionScope.of(context).calm;
      if (calm) {
        _fold.value = widget.open ? 1 : 0;
      } else if (widget.open) {
        _fold.animateTo(1, curve: Curves.easeOutBack);
      } else {
        _fold.animateBack(0, curve: Curves.easeOutCubic);
      }
    }
    _syncLoop();
  }

  void _syncLoop() {
    final want = widget.busy && !MotionScope.of(context).calm;
    if (want && _loop == null) {
      _loop = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    } else if (!want && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  @override
  void dispose() {
    _fold.dispose();
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loop = _loop;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_fold, ?loop]),
        builder: (context, _) => CustomPaint(
          size: const Size.square(TranscriptButton.size),
          painter: _TranscriptGlyphPainter(
            ink: widget.ink,
            fill: widget.fill,
            fold: _fold.value,
            breath: widget.busy ? (loop?.value ?? 0) : null,
            ring: widget.ring,
            indeterminate: widget.indeterminate,
          ),
        ),
      ),
    );
  }
}

/// Three text lines that fold into a chevron.
///
/// Each line is a pair of endpoints, lerped between the two shapes: the top
/// line becomes the chevron's left arm, the middle one its right arm, and the
/// short bottom line shrinks into the apex. `easeOutBack` on the fold gives the
/// chevron a small kick past its final angle as it lands.
class _TranscriptGlyphPainter extends CustomPainter {
  _TranscriptGlyphPainter({
    required this.ink,
    required this.fill,
    required this.fold,
    required this.breath,
    required this.ring,
    required this.indeterminate,
  });

  final Color ink;
  final Color fill;
  final double fold;
  final double? breath;
  final double? ring;
  final bool indeterminate;

  // In a 14pt box, centred in the disc.
  static const _lines = [
    (Offset(1.5, 3.5), Offset(12.5, 3.5)),
    (Offset(1.5, 7), Offset(10, 7)),
    (Offset(1.5, 10.5), Offset(7, 10.5)),
  ];
  static const _chevron = [
    (Offset(2.5, 9), Offset(7, 4.5)),
    (Offset(7, 4.5), Offset(11.5, 9)),
    (Offset(7, 4.5), Offset(7, 4.5)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2, Paint()..color = fill);

    final r = ring;
    if (r != null || indeterminate) {
      final rim = Rect.fromCircle(center: c, radius: size.width / 2 - 1.25);
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink.withValues(alpha: 0.18);
      canvas.drawOval(rim, track);
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = ink;
      if (indeterminate || r == null) {
        final start = (breath ?? 0) * 2 * math.pi - math.pi / 2;
        canvas.drawArc(rim, start, math.pi / 2, false, arc);
      } else if (r > 0) {
        // A sliver at least, so "started" is visible before the first percent.
        canvas.drawArc(rim, -math.pi / 2, math.max(r, 0.03) * 2 * math.pi, false, arc);
      }
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..color = ink;
    final origin = c - const Offset(7, 7);
    final t = fold;
    for (var i = 0; i < 3; i++) {
      var a = Offset.lerp(_lines[i].$1, _chevron[i].$1, t)!;
      var b = Offset.lerp(_lines[i].$2, _chevron[i].$2, t)!;
      final w = breath;
      if (w != null && t < 0.5) {
        // Each line's right end swings in and out, a third of a cycle apart:
        // text being written, not a spinner.
        final phase = math.sin((w + i / 3) * 2 * math.pi);
        final len = (b.dx - a.dx);
        b = Offset(a.dx + len * (0.72 + 0.28 * (phase + 1) / 2), b.dy);
      }
      if ((b - a).distance < 0.05) continue;
      a += origin;
      b += origin;
      canvas.drawLine(a, b, stroke);
    }
  }

  @override
  bool shouldRepaint(_TranscriptGlyphPainter old) =>
      old.fold != fold ||
      old.breath != breath ||
      old.ring != ring ||
      old.indeterminate != indeterminate ||
      old.ink != ink ||
      old.fill != fill;
}

/// Under the player, once the button has been tapped.
///
/// Inside a voice bubble it opens under a hairline. For a video or a round
/// note (`decoration` set) it is a card of its own, [cardWidth] wide, in the
/// bubble's colour: there is no text bubble to grow, and a full-width text
/// slab under a circle would look like a caption that lost its message.
class TranscriptSlab extends StatelessWidget {
  const TranscriptSlab({
    super.key,
    required this.handle,
    required this.isMine,
    this.position = Duration.zero,
    this.following = false,
    this.onSeek,
    this.decoration,
    this.cardWidth,
  });

  final TranscriptHandle handle;
  final bool isMine;

  /// Where playback is, for reading along. Videos play in their own viewer,
  /// so they leave this at rest.
  final Duration position;

  /// Whether the note is mid-play (playing, or paused partway). Only then do
  /// unspoken words dim — see the library doc.
  final bool following;

  /// Tapping a word jumps playback there. Null where the transcript is not
  /// beside a player (a video's), and words are then plain text.
  final ValueChanged<Duration>? onSeek;

  /// Set for the card form: what the card is painted with.
  final Decoration? decoration;
  final double? cardWidth;

  bool get _card => decoration != null;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final frozen = FrozenBubble.of(context);
    return ListenableBuilder(
      listenable: frozen
          ? const AlwaysStoppedAnimation<double>(0)
          : Listenable.merge([handle, VoiceTranscriber.instance.download]),
      builder: (context, _) {
        final Widget? content = !handle.open
            ? null
            : KeyedSubtree(
                key: ValueKey((handle.phase, handle.fetching)),
                child: _body(context, theme, motion),
              );
        final Widget switched = (frozen || content == null)
            ? (content ?? const SizedBox.shrink())
            : AnimatedSwitcher(
                duration: motion.d(const Duration(milliseconds: 200)),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                child: content,
              );
        final ink = isMine ? theme.accentInk : theme.ink;
        final Widget body;
        if (!handle.open) {
          body = _card ? const SizedBox.shrink() : const SizedBox(width: double.infinity);
        } else if (_card) {
          body = Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: cardWidth,
              decoration: decoration,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: switched,
            ),
          );
        } else {
          body = Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 1, color: ink.withValues(alpha: 0.14)),
                const SizedBox(height: 8),
                switched,
              ],
            ),
          );
        }
        if (frozen) return body;
        return AnimatedSize(
          duration: motion.d(theme.motionMed),
          curve: motion.c(Curves.easeOutCubic),
          alignment: Alignment.topLeft,
          child: body,
        );
      },
    );
  }

  Widget _body(BuildContext context, AppTheme theme, MotionScope motion) {
    final status = _status(context, theme, motion);
    final previous = handle.transcript;
    // An upgrade in flight: the built-in transcript stays readable above the
    // download, rather than the slab emptying out to a progress bar.
    if (previous == null ||
        previous.isEmpty ||
        handle.phase == TranscriptPhase.done ||
        handle.phase == TranscriptPhase.idle) {
      return status;
    }
    final ink = isMine ? theme.accentInk : theme.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ReadAlongText(
          transcript: previous,
          style: theme.body.copyWith(color: ink.withValues(alpha: 0.6)),
          dimmed: ink.withValues(alpha: 0.42),
          position: position,
          following: following,
          onSeek: onSeek,
        ),
        const SizedBox(height: 8),
        status,
      ],
    );
  }

  Widget _status(BuildContext context, AppTheme theme, MotionScope motion) {
    final l10n = AppLocalizations.of(context);
    final model = VoiceTranscriber.instance.model;
    final ink = isMine ? theme.accentInk : theme.ink;
    final quiet = theme.caption.copyWith(color: ink.withValues(alpha: 0.72));
    final voice = handle.media == TranscriptMedia.voice;
    switch (handle.phase) {
      case TranscriptPhase.idle:
        return const SizedBox.shrink();

      case TranscriptPhase.awaitingConsent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.voiceTranscriptCellularPrompt(model.sizeLabel), style: quiet),
            _LinkRow(
              theme: theme,
              isMine: isMine,
              links: [
                (
                  l10n.voiceTranscriptDownloadAction(model.sizeLabel),
                  () => VoiceTranscriber.instance.allowCellular(handle.storageId),
                ),
              ],
            ),
          ],
        );

      case TranscriptPhase.downloading:
        final dl = VoiceTranscriber.instance.download.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.voiceTranscriptDownloading(
                _mb(dl?.received ?? 0),
                model.sizeLabel,
              ),
              style: quiet.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            _Bar(fraction: dl?.fraction ?? 0, ink: ink, width: _card ? cardWidth : null),
            const SizedBox(height: 8),
            Text(l10n.voiceTranscriptOneTimeNote, style: quiet),
            _LinkRow(
              theme: theme,
              isMine: isMine,
              links: [
                (l10n.voiceTranscriptCancel, VoiceTranscriber.instance.cancelDownload),
              ],
            ),
          ],
        );

      case TranscriptPhase.transcribing:
        final fetching = handle.fetching;
        final p = handle.progress;
        final label = fetching
            ? l10n.voiceTranscriptFetching
            : (p == null || p <= 0
                ? l10n.voiceTranscriptWorking
                : '${l10n.voiceTranscriptWorking} ${(p * 100).round()}%');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Where the words will be: three lines of shimmer, so the slab is
            // already the shape of the answer when it arrives.
            _Skeleton(ink: ink, motion: motion),
            const SizedBox(height: 8),
            Text(
              label,
              style: quiet.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            _LinkRow(
              theme: theme,
              isMine: isMine,
              links: [
                (
                  l10n.voiceTranscriptCancel,
                  () => VoiceTranscriber.instance.cancel(handle.storageId),
                ),
              ],
            ),
          ],
        );

      case TranscriptPhase.failed:
        final tooLarge = handle.failure == TranscriptFailure.tooLarge;
        final message = switch (handle.failure) {
          TranscriptFailure.network => l10n.voiceTranscriptFailedNetwork,
          TranscriptFailure.storage =>
            l10n.voiceTranscriptFailedStorage(model.sizeLabel),
          TranscriptFailure.audio =>
            voice ? l10n.voiceTranscriptFailedAudio : l10n.voiceTranscriptFailedAudioVideo,
          TranscriptFailure.tooLarge => l10n.voiceTranscriptTooLarge,
          TranscriptFailure.engine || null =>
            voice ? l10n.voiceTranscriptFailed : l10n.voiceTranscriptFailedVideo,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: quiet),
            _LinkRow(
              theme: theme,
              isMine: isMine,
              links: [
                if (!tooLarge)
                  (
                    l10n.voiceTranscriptRetry,
                    () => VoiceTranscriber.instance.retry(handle.storageId),
                  ),
                if (_card) (l10n.voiceTranscriptHide, _fold),
              ],
            ),
          ],
        );

      case TranscriptPhase.done:
        final t = handle.transcript;
        if (t == null || (t.isEmpty && t.source == TranscriptSource.model)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(voice ? l10n.voiceTranscriptNoSpeech : l10n.voiceTranscriptNoSpeechVideo, style: quiet),
              _LinkRow(
                theme: theme,
                isMine: isMine,
                links: [if (_card) (l10n.voiceTranscriptHide, _fold)],
              ),
            ],
          );
        }
        final lang = t.language;
        final builtIn = t.source == TranscriptSource.builtIn;
        final languageName = lang == null ? null : autonymFor(lang);
        void copy() {
          unawaited(copyText(
            context,
            t.text,
            toast: l10n.voiceTranscriptCopied,
            haptic: CopyHaptic.selection,
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Empty from the built-in recognizer means "not this language"
            // far more often than silence; the offer below says so.
            //
            // Held down, the words copy: the same as the Copy link, where a
            // thumb already is. Taps still seek, on the bubbles that can.
            if (!t.isEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: copy,
                child: ReadAlongText(
                  transcript: t,
                  style: theme.body.copyWith(color: ink),
                  dimmed: ink.withValues(alpha: 0.42),
                  position: position,
                  following: following,
                  onSeek: onSeek,
                ),
              ),
            // Who heard it, said plainly: the built-in recognizer was TOLD a
            // language, so naming it is how a reader spots the wrong one.
            _LinkRow(
              theme: theme,
              isMine: isMine,
              lead: builtIn
                  ? (languageName == null
                      ? l10n.voiceTranscriptBuiltInCredit
                      : l10n.voiceTranscriptBuiltInLanguageCredit(languageName))
                  : (languageName == null
                      ? l10n.voiceTranscriptOnDevice
                      : l10n.voiceTranscriptLanguageOnDevice(languageName)),
              links: [(l10n.voiceTranscriptCopy, copy)],
            ),
            // The card has no disc in its own row to fold it again. Its own
            // line, for the credit's reason below.
            if (_card)
              _LinkRow(
                theme: theme,
                isMine: isMine,
                tight: true,
                links: [(l10n.voiceTranscriptHide, _fold)],
              ),
            // Its own line rather than a third item on the credit: wrapped
            // into that line it either strands a dot or leads with one.
            if (builtIn && !handle.offering)
              _LinkRow(
                theme: theme,
                isMine: isMine,
                tight: true,
                links: [
                  (
                    l10n.voiceTranscriptUpgradeLink,
                    () => VoiceTranscriber.instance.setOffering(handle.storageId, true),
                  ),
                ],
              ),
            if (builtIn && handle.offering) ...[
              const SizedBox(height: 2),
              Text(l10n.voiceTranscriptUpgradeOffer(model.sizeLabel), style: quiet),
              _LinkRow(
                theme: theme,
                isMine: isMine,
                links: [
                  (
                    l10n.voiceTranscriptDownloadAction(model.sizeLabel),
                    () => VoiceTranscriber.instance.upgrade(handle.storageId),
                  ),
                  (
                    l10n.voiceTranscriptNotNow,
                    () => VoiceTranscriber.instance.setOffering(handle.storageId, false),
                  ),
                ],
              ),
            ],
          ],
        );
    }
  }

  /// Folds the slab, for the card's own "Hide" link.
  void _fold() => VoiceTranscriber.instance.setOpen(handle.storageId, false);

  static String _mb(int bytes) => formatFileSize(bytes, wholeUnits: true);
}

/// The wrapper a video or a round note puts around its picture: the button on
/// one corner, the card under it.
///
/// Renders [child] unchanged where the platform cannot transcribe. The card
/// is [cardWidth] wide and sits on the bubble's side ([isMine]) so it lines up
/// with the picture rather than floating mid-row.
class MediaTranscript extends StatelessWidget {
  const MediaTranscript({
    super.key,
    required this.subject,
    required this.isMine,
    required this.decoration,
    required this.cardWidth,
    required this.child,
    this.buttonAlignment = Alignment.topLeft,
    this.buttonInset = const EdgeInsets.all(4),
  });

  final TranscriptSubject subject;
  final bool isMine;

  /// The bubble's own decoration, so the card reads as part of the message.
  final Decoration decoration;
  final double cardWidth;
  final Widget child;
  final Alignment buttonAlignment;

  /// Distance of the button's 34pt target from the picture's edges.
  final EdgeInsets buttonInset;

  @override
  Widget build(BuildContext context) {
    final handle = subject.handle;
    if (handle == null) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            child,
            Positioned.fill(
              child: Padding(
                padding: buttonInset,
                child: Align(
                  alignment: buttonAlignment,
                  child: TranscriptButton(
                    handle: handle,
                    isMine: isMine,
                    onMedia: true,
                    onTap: () => subject.toggle(context),
                  ),
                ),
              ),
            ),
          ],
        ),
        TranscriptSlab(
          handle: handle,
          isMine: isMine,
          decoration: decoration,
          cardWidth: cardWidth,
        ),
      ],
    );
  }
}

/// The transcript, lit as far as playback has got.
///
/// One [Text.rich] with a span per word — not a [Wrap] of word widgets, which
/// would break the line only at the gaps it was given and so lay Japanese or
/// Chinese out as a column of single characters.
class ReadAlongText extends StatefulWidget {
  const ReadAlongText({
    super.key,
    required this.transcript,
    required this.style,
    required this.dimmed,
    required this.position,
    required this.following,
    this.onSeek,
  });

  final Transcript transcript;
  final TextStyle style;
  final Color dimmed;
  final Duration position;
  final bool following;
  final ValueChanged<Duration>? onSeek;

  @override
  State<ReadAlongText> createState() => _ReadAlongTextState();
}

class _ReadAlongTextState extends State<ReadAlongText> {
  /// One per word, made once per transcript. Recognisers own gesture arena
  /// state and must be disposed, so they cannot be minted in [build] — which
  /// runs on every position tick.
  List<TapGestureRecognizer> _taps = const [];

  @override
  void initState() {
    super.initState();
    _makeTaps();
  }

  @override
  void didUpdateWidget(ReadAlongText old) {
    super.didUpdateWidget(old);
    if (!identical(old.transcript, widget.transcript)) {
      _disposeTaps();
      _makeTaps();
    }
  }

  void _makeTaps() {
    _taps = [
      for (final w in widget.transcript.words)
        TapGestureRecognizer()
          ..onTap = () {
            final seek = widget.onSeek;
            if (seek == null) return;
            HapticFeedback.selectionClick();
            seek(w.start);
          },
    ];
  }

  void _disposeTaps() {
    for (final t in _taps) {
      t.dispose();
    }
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.transcript.words;
    if (words.isEmpty) {
      return Text(widget.transcript.text, style: widget.style);
    }
    final spoken = widget.following
        ? spokenWordIndex(words, widget.position)
        : words.length - 1;
    final dim = widget.style.copyWith(color: widget.dimmed);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < words.length; i++)
            TextSpan(
              text: words[i].text,
              style: i <= spoken ? widget.style : dim,
              recognizer: _taps[i],
            ),
        ],
      ),
      style: widget.style,
    );
  }
}

/// One quiet caption line: an optional fact, then links, dot separated —
/// the same rhythm as the translation slab's attribution.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.theme,
    required this.isMine,
    required this.links,
    this.lead,
    this.tight = false,
  });

  final AppTheme theme;
  final bool isMine;
  final String? lead;

  /// Directly under another link row: no top padding, so the two lines sit
  /// at text spacing instead of stacking two tap margins. The row above
  /// already covers the shared space.
  final bool tight;
  final List<(String, VoidCallback)> links;

  @override
  Widget build(BuildContext context) {
    final ink = (isMine ? theme.accentInk : theme.inkMuted).withValues(alpha: 0.7);
    final linkStyle = theme.caption.copyWith(
      color: theme.linkInk(isMine: isMine),
      fontWeight: FontWeight.w600,
    );
    final lead = this.lead;
    // A Wrap, not a Row: the built-in credit plus two links is wider than a
    // narrow bubble, and the line should break between parts rather than
    // ellipsize the language away.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (lead != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(lead, style: theme.caption.copyWith(color: ink)),
          ),
        for (final (i, (label, onTap)) in links.indexed)
          // Each separator rides with the link AFTER it, so a wrapped line
          // never ends on a stranded dot.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lead != null || i > 0) _Dot(color: ink),
              GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  // The tap target has to clear 44pt inside a caption line;
                  // the padding is where that comes from, not a bigger font.
                  // Vertical only, so a link that starts the line sits flush
                  // with the text above and the dots space evenly.
                  padding: EdgeInsets.only(top: tight ? 0 : 10, bottom: 10),
                  child: Text(label, style: linkStyle),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Container(
          width: 2,
          height: 2,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}

/// The download's own bar. Thin, in the bubble's ink, animated between
/// progress ticks so 1 MB jumps do not stutter.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.ink, this.width});

  final double fraction;
  final Color ink;

  /// Null is the bubble's 180; a card passes its own, minus its padding.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        width: width == null ? 180 : width! - 24,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: ink.withValues(alpha: 0.16))),
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: motion.d(const Duration(milliseconds: 240)),
              builder: (context, f, _) => FractionallySizedBox(
                // Both factors and the alignment are load-bearing: a childless
                // ColoredBox sizes to the smallest it is allowed, so without
                // heightFactor the fill is zero tall, and without the
                // alignment it grows from the middle.
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                widthFactor: f.clamp(0.0, 1.0),
                child: ColoredBox(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three bars where the words will be, with a light sweeping across them.
///
/// Telegram's treatment of a transcript in progress: the slab already has the
/// shape of the answer, so when text arrives it replaces the bars instead of
/// pushing the list around. Under calm motion the bars hold still.
class _Skeleton extends StatefulWidget {
  const _Skeleton({required this.ink, required this.motion});

  final Color ink;
  final MotionScope motion;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (!widget.motion.calm) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  static const _widths = [1.0, 0.86, 0.5];

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final base = widget.ink.withValues(alpha: 0.12);
    final glint = widget.ink.withValues(alpha: 0.26);
    Widget bars(double t) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: [base, glint, base],
            stops: const [0.0, 0.5, 1.0],
            // Wider than the box and slid across it, so the glint enters from
            // the left edge and leaves at the right.
            begin: Alignment(-2.0 + t * 4.0 - 1.0, 0),
            end: Alignment(-2.0 + t * 4.0 + 1.0, 0),
          ).createShader(rect),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, w) in _widths.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 2 : 6),
                  child: FractionallySizedBox(
                    widthFactor: w,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
    if (ctrl == null) return bars(0.5);
    return RepaintBoundary(
      child: AnimatedBuilder(animation: ctrl, builder: (_, _) => bars(ctrl.value)),
    );
  }
}
