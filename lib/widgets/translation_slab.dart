/// The translated half of a bubble.
///
/// ── Why it is a slab under the text and not a replacement for it ───────────
///
/// The obvious design swaps the bubble's text for its translation and offers a
/// "show original" toggle. Three things go wrong with that, and all of them
/// are things you only notice once it is built:
///
///  * The transcript reflows. Every translated message changes height at a
///    different moment as the queue reaches it, so a room translating in the
///    background is a room that will not hold still under your thumb.
///  * You lose the ability to check. Half of why people translate a message is
///    to work out what a specific word was, and swapping the text away is
///    exactly the wrong affordance for that.
///  * A wrong translation becomes invisible. A 0.6B model gets things wrong,
///    and when both texts are present the reader can see that it did.
///
/// So the original stays put, and the translation arrives underneath it behind
/// a hairline. The bubble grows downward, which the list handles, rather than
/// changing shape in place.
library;

import 'package:flutter/material.dart';

import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../companions/translation/language.dart';
import '../models/chat_message.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// What a text bubble actually mounts.
///
/// Two subscriptions, and the split is the whole performance story:
///
///  * [Sebastian.handleRegistry] — fires only when the set of handles changes,
///    which is a few times per room. This is how a bubble learns that its
///    handle now exists, since it cannot listen to a handle it does not have.
///  * the handle itself, once there is one — which is where the fifteen
///    notifications a second of a streaming translation land, reaching this
///    bubble and no other.
///
/// Listening to [Sebastian] directly instead would have been one subscription
/// and would have rebuilt every visible bubble on every room-progress tick.
class MessageTranslation extends StatelessWidget {
  const MessageTranslation({
    super.key,
    required this.message,
    required this.isMine,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sebastian.instance.handleRegistry,
      builder: (context, _) {
        // This build IS the visibility signal — see [Sebastian.noteOnScreen].
        // Records only; the promotion it triggers runs after the frame, so
        // this cannot rebuild the widget that reported it.
        Sebastian.instance.noteOnScreen(message);
        final handle = Sebastian.instance.handleFor(message);
        // The resting case, and by far the most common one: nobody has asked
        // about this message. Costs one map lookup and an empty box, so a room
        // with translation switched off pays essentially nothing for this
        // widget being in every bubble.
        if (handle == null) return const SizedBox.shrink();
        return TranslationSlab(
          handle: handle,
          isMine: isMine,
          onToggleOriginal: () => Sebastian.instance.showOriginal(message),
          onRetry: () => Sebastian.instance.translate(message),
        );
      },
    );
  }
}

class TranslationSlab extends StatelessWidget {
  const TranslationSlab({
    super.key,
    required this.handle,
    required this.isMine,
    required this.onToggleOriginal,
    required this.onRetry,
  });

  /// The one notifier this widget listens to. Deliberately passed in rather
  /// than looked up from [Sebastian] here: the point of the per-text handle is
  /// that a streaming translation rebuilds ONE bubble, and that only holds if
  /// the listening happens at this granularity.
  final TranslationHandle handle;
  final bool isMine;
  final VoidCallback onToggleOriginal;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return AnimatedBuilder(
      animation: handle,
      builder: (context, _) {
        // The reader flipped back to the original. Nothing here at all — not a
        // collapsed slab, not a stub — so a bubble showing its original is
        // pixel-identical to one that was never translated.
        if (handle.showingOriginal) return const SizedBox.shrink();

        // Nothing worth saying. A message already in the reader's language is
        // the overwhelmingly common outcome in a translated room, and drawing
        // a "no change needed" note on hundreds of bubbles would turn the
        // transcript into a form.
        //
        // The single-bubble tap DOES get feedback for this case, but it comes
        // from the room screen as a toast rather than from here — a note that
        // lands in the transcript and stays there is a note the reader has to
        // dismiss on every message they were curious about.
        if (handle.state == TranslationState.sameLanguage) {
          return const SizedBox.shrink();
        }

        return AnimatedSize(
          duration: motion.d(theme.motionMed),
          curve: motion.c(theme.motionCurve),
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Hairline(theme: theme, isMine: isMine),
                const SizedBox(height: 8),
                _body(context, theme, motion),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, AppTheme theme, MotionScope motion) {
    final l10n = AppLocalizations.of(context);
    switch (handle.state) {
      case TranslationState.queued:
        return _WaitingLine(theme: theme, isMine: isMine, motion: motion);

      case TranslationState.failed:
        return _FailedLine(theme: theme, isMine: isMine, onRetry: onRetry);

      case TranslationState.sameLanguage:
        // Unreachable — filtered above. Listed so this switch stays exhaustive
        // and a new state cannot be added without deciding what it draws.
        return const SizedBox.shrink();

      case TranslationState.streaming:
      case TranslationState.done:
        final text = handle.text;
        if (text == null || text.isEmpty) {
          return _WaitingLine(theme: theme, isMine: isMine, motion: motion);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Plain Text, not LinkifiedText. A translation is not the source
            // of truth for anything tappable: its mention handles are the
            // model's copies of real ones and may not resolve, and a URL it
            // reproduced may have been "helpfully" altered. The original above
            // keeps every live affordance; this is a reading aid.
            Text(
              text,
              style: theme.body.copyWith(
                color: isMine ? theme.accentInk : theme.ink,
              ),
            ),
            const SizedBox(height: 6),
            _Attribution(
              theme: theme,
              isMine: isMine,
              handle: handle,
              streaming: handle.state == TranslationState.streaming,
              motion: motion,
              label: l10n.translationSlabShowOriginal,
              onTap: onToggleOriginal,
            ),
          ],
        );
    }
  }
}

/// The rule between what was said and what it means.
///
/// Drawn from the bubble's own ink at low alpha rather than from
/// [AppTheme.divider], because inside an outgoing bubble the divider colour is
/// computed against the page background and lands invisible on the accent
/// fill. Everything in this file that needs a colour derives it from
/// [isMine] for the same reason.
class _Hairline extends StatelessWidget {
  const _Hairline({required this.theme, required this.isMine});

  final AppTheme theme;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: (isMine ? theme.accentInk : theme.ink).withValues(alpha: 0.14),
    );
  }
}

/// The resting state: queued, or generating with nothing to show yet.
///
/// A pulsing bar rather than a spinner. A spinner in a chat transcript reads
/// as "the network is stuck", which is the one thing this feature is not doing
/// — and it would be the only spinner in the room. A bar the width of a short
/// line of text says "text is coming here", which is true.
class _WaitingLine extends StatefulWidget {
  const _WaitingLine({
    required this.theme,
    required this.isMine,
    required this.motion,
  });

  final AppTheme theme;
  final bool isMine;
  final MotionScope motion;

  @override
  State<_WaitingLine> createState() => _WaitingLineState();
}

class _WaitingLineState extends State<_WaitingLine>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    // Under calm motion the controller is never CREATED, not merely never
    // started — a looping ticker running behind a static bar is the exact cost
    // the setting exists to remove. See the note on [MotionScope].
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
    final ink = widget.isMine ? widget.theme.accentInk : widget.theme.ink;
    final ctrl = _ctrl;
    final bar = Container(
      height: 9,
      width: 132,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    if (ctrl == null) return bar;
    return FadeTransition(
      // Never fades all the way out. A bar that disappears reads as finished;
      // one that breathes between two visible alphas reads as working.
      opacity: Tween<double>(begin: 0.45, end: 1).animate(ctrl),
      child: bar,
    );
  }
}

/// Sebastian tried and could not.
///
/// One line, with the retry inline. No icon, no colour change: a translation
/// that failed is not an error in the conversation, and painting it in the
/// danger colour inside someone's message would say it was.
class _FailedLine extends StatelessWidget {
  const _FailedLine({
    required this.theme,
    required this.isMine,
    required this.onRetry,
  });

  final AppTheme theme;
  final bool isMine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ink = (isMine ? theme.accentInk : theme.inkMuted).withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            l10n.translationSlabFailed,
            style: theme.caption.copyWith(color: ink),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRetry,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            // Padding, not a bigger font: the tap target has to clear 44pt of
            // height inside a line of caption text, and this is where it comes
            // from.
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              l10n.translationSlabRetry,
              style: theme.caption.copyWith(
                color: theme.linkInk(isMine: isMine),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Who did this, from what, and the way back.
///
/// Reads as one quiet line — mark, language, action — because it appears under
/// potentially every message in a room and anything louder would become the
/// texture of the transcript.
class _Attribution extends StatelessWidget {
  const _Attribution({
    required this.theme,
    required this.isMine,
    required this.handle,
    required this.streaming,
    required this.motion,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final bool isMine;
  final TranslationHandle handle;
  final bool streaming;
  final MotionScope motion;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ink = (isMine ? theme.accentInk : theme.inkMuted).withValues(alpha: 0.7);
    final source = handle.sourceLanguage;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompanionMark(
            companion: Companion.sebastian,
            size: 13,
            foreground: ink,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              // Says where it came FROM when the detector knew, and only names
              // Sebastian when it didn't. Both fit the same slot, and the
              // language is the more useful of the two facts when it is
              // available — the mark on the left has already said who.
              source == null
                  ? l10n.translationSlabByCompanion(Companion.sebastian.displayName)
                  : l10n.translationSlabFromLanguage(autonymFor(source)),
              style: theme.caption.copyWith(color: ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // The toggle appears only once there is a finished translation to
          // toggle away from. Offering it mid-stream would be offering to
          // cancel something that is nearly done.
          if (!streaming) ...[
            _Dot(color: ink),
            Text(
              label,
              style: theme.caption.copyWith(
                color: theme.linkInk(isMine: isMine),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            _Caret(theme: theme, isMine: isMine, motion: motion),
        ],
      ),
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

/// The blinking tick that says tokens are still arriving.
class _Caret extends StatefulWidget {
  const _Caret({
    required this.theme,
    required this.isMine,
    required this.motion,
  });

  final AppTheme theme;
  final bool isMine;
  final MotionScope motion;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (!widget.motion.calm) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
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
    final bar = Container(
      width: 2,
      height: 11,
      margin: const EdgeInsets.only(left: 6),
      color: widget.theme.linkInk(isMine: widget.isMine),
    );
    final ctrl = _ctrl;
    if (ctrl == null) return bar;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(ctrl),
      child: bar,
    );
  }
}
