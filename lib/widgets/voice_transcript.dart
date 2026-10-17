/// The transcript half of a voice bubble: the button beside the waveform, and
/// the slab that opens under it.
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
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../transcripts/transcript.dart';
import '../transcripts/voice_transcriber.dart';
import 'app_toast.dart';
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
    required this.handle,
    required this.isMine,
    required this.onTap,
  });

  final TranscriptHandle handle;
  final bool isMine;
  final VoidCallback onTap;

  static const double size = 26;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ink = isMine ? theme.accentInk : theme.ink;
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
              fill: ink.withValues(alpha: handle.open ? 0.2 : 0.12),
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
class TranscriptSlab extends StatelessWidget {
  const TranscriptSlab({
    super.key,
    required this.handle,
    required this.isMine,
    required this.position,
    required this.following,
    required this.onSeek,
  });

  final TranscriptHandle handle;
  final bool isMine;

  /// Where playback is, for reading along.
  final Duration position;

  /// Whether the note is mid-play (playing, or paused partway). Only then do
  /// unspoken words dim — see the library doc.
  final bool following;

  final ValueChanged<Duration> onSeek;

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
        final Widget body = !handle.open
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 1,
                      color: (isMine ? theme.accentInk : theme.ink)
                          .withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 8),
                    _body(context, theme, motion),
                  ],
                ),
              );
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
            _Bar(fraction: dl?.fraction ?? 0, ink: ink),
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
        return _Breathing(
          motion: motion,
          child: Text(l10n.voiceTranscriptWorking, style: quiet),
        );

      case TranscriptPhase.failed:
        final message = switch (handle.failure) {
          TranscriptFailure.network => l10n.voiceTranscriptFailedNetwork,
          TranscriptFailure.storage =>
            l10n.voiceTranscriptFailedStorage(model.sizeLabel),
          TranscriptFailure.audio => l10n.voiceTranscriptFailedAudio,
          TranscriptFailure.engine || null => l10n.voiceTranscriptFailed,
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
                (
                  l10n.voiceTranscriptRetry,
                  () => VoiceTranscriber.instance.retry(handle.storageId),
                ),
              ],
            ),
          ],
        );

      case TranscriptPhase.done:
        final t = handle.transcript;
        if (t == null || (t.isEmpty && t.source == TranscriptSource.model)) {
          return Text(l10n.voiceTranscriptNoSpeech, style: quiet);
        }
        final lang = t.language;
        final builtIn = t.source == TranscriptSource.builtIn;
        final languageName = lang == null ? null : autonymFor(lang);
        void copy() {
          HapticFeedback.selectionClick();
          unawaited(Clipboard.setData(ClipboardData(text: t.text)));
          AppToast.of(context).success(l10n.voiceTranscriptCopied);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Empty from the built-in recognizer means "not this language"
            // far more often than silence; the offer below says so.
            if (!t.isEmpty) ReadAlongText(
              transcript: t,
              style: theme.body.copyWith(color: ink),
              dimmed: ink.withValues(alpha: 0.42),
              position: position,
              following: following,
              onSeek: onSeek,
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

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';
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
    required this.onSeek,
  });

  final Transcript transcript;
  final TextStyle style;
  final Color dimmed;
  final Duration position;
  final bool following;
  final ValueChanged<Duration> onSeek;

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
            HapticFeedback.selectionClick();
            widget.onSeek(w.start);
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
  const _Bar({required this.fraction, required this.ink});

  final double fraction;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        width: 180,
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

/// Fades its child between two visible alphas while work is happening.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.motion, required this.child});

  final MotionScope motion;
  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (!widget.motion.calm) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) return widget.child;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(ctrl),
      child: widget.child,
    );
  }
}
