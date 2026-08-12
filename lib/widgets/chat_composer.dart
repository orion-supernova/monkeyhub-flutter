import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../data/mention_session.dart';
import '../keyboard/focusable_tap.dart';
import '../keyboard/mention_keyboard_nav.dart';
import '../keyboard/submit_on_enter.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/interaction.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'composer_capture.dart';
import 'composer_format_toolbar.dart';
import 'liquid_glass.dart';

/// How long a press has to last before the hold ring is allowed to appear.
///
/// A tap is over in well under this; a hold is only a third of the way through
/// it. So the ring never shows on a send, and a user who genuinely means to
/// hold sees it come up almost at once. Below roughly 100ms it starts catching
/// deliberate taps again, and much above 150ms the hold feels unresponsive
/// before anything happens — this is the window between those.
const Duration _kHoldRingLead = Duration(milliseconds: 130);

/// The composer's send button.
///
/// Tap sends. Hold opens the schedule sheet, if the host offered one — the
/// affordance is absent rather than inert where scheduling does not apply
/// (a self-destructing room, the thread overlay), because a hold that visibly
/// charges and then does nothing is worse than one that never starts.
///
/// A small clock badge appears while the room is holding queued messages. It is
/// deliberately the SECONDARY indicator: this button only exists while the
/// composer has text (see the `AnimatedSwitcher`s below), so with an empty
/// composer there is nothing here to badge. `ScheduledPill` above the composer
/// is what carries that state persistently.
class _SendButton extends StatefulWidget {
  const _SendButton({
    super.key,
    required this.onSend,
    required this.semanticLabel,
    this.classic = true,
    this.onSchedule,
    this.scheduledCount = 0,
  });

  final VoidCallback onSend;
  final String semanticLabel;
  final bool classic;

  /// Null hides the hold gesture entirely — no recognizer, no ring, no rotor
  /// action.
  final VoidCallback? onSchedule;

  /// How many messages this room already has waiting. Zero hides the badge.
  final int scheduledCount;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  /// Drives the ring that sweeps around the button while it is held.
  ///
  /// The whole point is that a hold has to LOOK like it is going somewhere.
  /// Without it the button sits there for 400ms and the user either lets go
  /// (thinking it is broken) or is surprised by a sheet. The ring is the
  /// mechanism iOS uses for the same gesture, rather than a fade or a wobble
  /// tuned until it feels long enough.
  late final AnimationController _hold;

  /// Waits out [_kHoldRingLead] before the ring is allowed to start.
  ///
  /// This is the whole fix for the ring flashing on an ordinary tap.
  /// `onLongPressDown` fires on POINTER-DOWN — the recognizer has no idea yet
  /// whether this will become a tap or a hold — so starting the sweep there
  /// meant every send flashed a stub of arc and then spent up to 400ms
  /// reversing it. No opacity threshold fixes that: the animation is running,
  /// and the only question is how much of it you can see.
  Timer? _leadIn;

  /// Kept across the `AnimatedSwitcher` rebuild that fires on every keystroke.
  ///
  /// Load-bearing: this button is rebuilt whenever `controller.text` changes,
  /// and a recognizer holding a live pointer whose element is re-created loses
  /// the gesture mid-hold. The same reparenting problem `ComposerCaptureHost`
  /// documents on its own mode button.
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(
      vsync: this,
      // What is LEFT of the gesture once the lead-in has passed, so the ring
      // still closes at the exact instant the recognizer fires. Using the full
      // threshold here would leave it a lead-in short of complete at the moment
      // the sheet opens — a progress indicator that never reaches its end.
      duration: kActionMenuLongPress - _kHoldRingLead,
    );
  }

  @override
  void dispose() {
    _leadIn?.cancel();
    _hold.dispose();
    super.dispose();
  }

  void _startHold() {
    if (widget.onSchedule == null) return;
    if (MotionScope.of(context).calm) return;
    _leadIn?.cancel();
    _leadIn = Timer(_kHoldRingLead, () {
      if (mounted) _hold.forward(from: 0);
    });
  }

  /// Withdraws the ring, instantly.
  ///
  /// Snapped rather than reversed. A reverse reads as the button finishing
  /// something; the user has just let go, and the honest rendering of an
  /// abandoned gesture is that it is gone. It also means a press that ends a
  /// millisecond after the lead-in leaves nothing lingering on screen.
  void _endHold() {
    _leadIn?.cancel();
    _leadIn = null;
    if (_hold.value != 0) _hold.value = 0;
  }

  void _fire() {
    final schedule = widget.onSchedule;
    if (schedule == null) return;
    HapticFeedback.mediumImpact();
    _endHold();
    schedule();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final size = widget.classic ? 38.0 : 44.0;

    Widget core = widget.classic
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.north_east, color: theme.accentInk, size: 16),
          )
        : LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: Size(size, size),
            tinted: true,
            child: Icon(Icons.arrow_upward, size: 18, color: theme.accentInk),
          );

    if (widget.scheduledCount > 0) {
      core = Stack(
        clipBehavior: Clip.none,
        children: [
          core,
          Positioned(
            right: -1,
            bottom: -1,
            child: _ScheduledBadge(
              // Announced by the button's own semantic label below instead —
              // a screen reader meeting both reads the count twice.
              count: widget.scheduledCount,
            ),
          ),
        ],
      );
    }

    // The ring, painted outside the button's own bounds so it adds nothing to
    // layout — the FocusableTap focus-ring trick, for the same reason.
    if (widget.onSchedule != null) {
      core = Stack(
        clipBehavior: Clip.none,
        children: [
          core,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _hold,
                // A plain `== 0` check is enough now that the lead-in timer
                // keeps the controller at rest through every tap: while it is
                // moving at all, the user is deliberately holding.
                builder: (context, _) => _hold.value == 0
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _HoldRingPainter(
                          progress: _hold.value,
                          color: theme.accentInk,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
    }

    // The button shrinks slightly as the ring fills, so the hold reads as one
    // gesture gathering rather than a decoration spinning on a static button.
    //
    // Driven by the same controller on purpose, now that the controller only
    // ever leaves zero during a real hold. Its earlier form scaled on
    // pointer-down and was the other half of the tap glitch: every send
    // twitched. There is deliberately no press-down scale any more — the
    // classic button never had one, and the ring is the feedback.
    if (widget.onSchedule != null) {
      core = AnimatedBuilder(
        animation: _hold,
        builder: (context, child) => Transform.scale(
          scale: 1 - (_hold.value * 0.06),
          child: child,
        ),
        child: core,
      );
    }

    // RawGestureDetector, not GestureDetector: a plain one's long press is
    // fixed at Flutter's half-second with no way to shorten it, and this app
    // has already settled on `kActionMenuLongPress` for "hold reveals options"
    // everywhere else. Two recognizers in one arena so a tap still sends.
    Widget body = widget.onSchedule == null
        ? GestureDetector(onTap: widget.onSend, child: core)
        : RawGestureDetector(
            key: _key,
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (instance) {
                  instance.onTap = widget.onSend;
                  instance.onTapCancel = _endHold;
                },
              ),
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: kActionMenuLongPress,
                ),
                (instance) {
                  instance.onLongPressDown = (_) => _startHold();
                  instance.onLongPress = _fire;
                  instance.onLongPressCancel = _endHold;
                  instance.onLongPressUp = _endHold;
                },
              ),
            },
            child: core,
          );

    body = FocusableTap(
      onTap: widget.onSend,
      semanticLabel: widget.scheduledCount > 0
          ? '${widget.semanticLabel}, '
              '${l10n.composerScheduledBadgeSemantics(widget.scheduledCount)}'
          : widget.semanticLabel,
      shape: FocusRingShape.circle,
      child: body,
    );

    if (widget.onSchedule != null) {
      // The keyboard route to the sheet, bound outside FocusableTap so it fires
      // while the button's own node holds focus. Cmd/Ctrl+Enter is what every
      // mail client already uses for "send with options".
      body = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _fire,
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _fire,
        },
        child: body,
      );
      // The screen-reader route. A hold is a gesture a VoiceOver user cannot
      // perform on a target they cannot see, so it gets a rotor action —
      // `ComposerCaptureHost` ships both routes for its hold and so does this.
      body = Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.composerScheduleAction): _fire,
        },
        child: body,
      );
    }

    return body;
  }
}

/// The small clock on the corner of the send button.
class _ScheduledBadge extends StatelessWidget {
  const _ScheduledBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        constraints: const BoxConstraints(minWidth: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.accent, width: 1.2),
        ),
        child: Text(
          // Past nine the number stops being the point and the badge is just
          // saying "several" — which is what the pill above spells out.
          count > 9 ? '9+' : '$count',
          style: theme.monoTiny.copyWith(
            color: theme.accent,
            fontSize: 9,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// The arc that sweeps around the send button while it is held.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      // Fades in over the first fifth of the sweep, so a tap that happens to
      // register a few milliseconds of hold does not flash a stub of arc.
      ..color = color.withValues(alpha: (progress * 5).clamp(0.0, 1.0) * 0.9);
    canvas.drawArc(
      rect.deflate(2),
      -1.5707963267948966, // 12 o'clock
      progress * 6.283185307179586,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HoldRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// The two message composers, lifted verbatim out of `room_screen.dart` so
/// the thread overlay can use the same input the room does.
///
/// They are deliberately NOT unified behind one widget. Their layout
/// contracts differ: [ChatComposerClassic] does no safe-area work and expects
/// an ancestor `SafeArea`, while [ChatComposerLiquid] adds the bottom safe
/// area itself. Neither handles `viewInsets`, because inside a `Scaffold`
/// that's `resizeToAvoidBottomInset`'s job — a host outside one (e.g. a root
/// `OverlayEntry`) must pass its own [padding].
///
/// Which one to build stays a call-site decision, keyed off
/// `SettingsStore.instance.chatStyle`. Don't move that switch in here: hosts
/// listen to `SettingsStore` to rebuild on style change, and a widget reading
/// the singleton in `build` would silently stop updating.
///
/// Both stay `StatelessWidget` even now that the right-hand button records.
/// Everything stateful about that — the mode, the recorder, the camera session,
/// the lifecycle observer — lives in [ComposerCaptureHost], which each of them
/// wraps its row in. Making either composer stateful would have been the
/// obvious move and the wrong one: their state would be rebuilt from scratch
/// whenever the host re-ran `build` off a `SettingsStore` notification, which
/// is exactly the contract the paragraph above exists to protect.

/// Bordered, flat composer. Assumes an ancestor `SafeArea`.
class ChatComposerClassic extends StatelessWidget {
  const ChatComposerClassic({
    super.key,
    required this.controller,
    required this.ephemeral,
    required this.onSend,
    this.focusNode,
    this.onChanged,
    this.onAttach,
    this.onCamera,
    this.padding,
    this.mention,
    this.capture,
    this.onSchedule,
    this.scheduledCount = 0,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool ephemeral;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;

  /// Pass null to hide the attach button entirely.
  final VoidCallback? onAttach;

  /// Opens the camera in one tap, without going through the attachment sheet.
  ///
  /// Nullable for the same reason [onAttach] is, and it matters as much: the
  /// thread overlay builds this composer inside a root `OverlayEntry`, and the
  /// camera is a full-screen route that would fight it for layering. Pass null
  /// and the button is absent rather than present and broken.
  final VoidCallback? onCamera;

  /// Overrides the default outer padding. Only needed by hosts that own
  /// their own keyboard insets; leave null inside a `Scaffold`.
  final EdgeInsets? padding;

  /// Drives the `@`-picker's keyboard navigation. Null where no picker is
  /// wired up, and then [MentionKeyboardNav] adds no node at all — so key
  /// routing is byte-identical to what it was before this existed.
  ///
  /// The picker itself is NOT built here. It goes above the composer as a
  /// sibling, the same way the reply card does, because only the host knows
  /// what else is stacked there.
  final MentionSession? mention;

  /// Turns the camera button into a mode switcher that can also record a voice
  /// note or a circular video note. Null leaves the plain camera button, and
  /// every host that passes null is byte-identical to what it was.
  ///
  /// Independent of [onCamera] on purpose: the camera is a full-screen route
  /// and the two recorders are not, so a host with nowhere to push a route can
  /// still offer both of them.
  final ComposerCapture? capture;

  /// Opens the schedule sheet on a HOLD of the send button.
  ///
  /// Nullable, and null means the gesture does not exist rather than that it
  /// does nothing: the hold visibly charges a ring, so a host that cannot
  /// schedule (the thread overlay, a self-destructing room) must not offer the
  /// animation and then swallow it.
  final VoidCallback? onSchedule;

  /// How many messages this room is already holding for later, for the badge on
  /// the send button. Zero hides it.
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
      child: ComposerCaptureHost(
        capture: capture,
        style: ComposerCaptureStyle.classic,
        builder: (context, modeButton) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onAttach != null) ...[
            FocusableTap(
              onTap: onAttach,
              semanticLabel: AppLocalizations.of(context).deepOceanThemeAttachButtonLabel,
              shape: FocusRingShape.circle,
              child: GestureDetector(
                onTap: onAttach,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.divider),
                  ),
                  child: Icon(Icons.add, color: theme.inkSoft, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // No `onSubmitted` here: a multi-line TextField never fires it —
              // Flutter turns Enter into a newline. SubmitOnEnter intercepts
              // the key instead, and leaves Shift+Enter as the newline.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: MentionKeyboardNav(
                  session: mention,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: theme.body.copyWith(color: theme.ink),
                    cursorColor: theme.accent,
                    minLines: 1,
                    maxLines: 4,
                    // The native toolbar plus the FORMAT entry — mirrored in
                    // the liquid variant below; the two are intentionally
                    // duplicated widgets and must be kept in step by hand.
                    // Keep this function identity stable. EditableText
                    // recreates its selection overlay when this callback
                    // changes; an inline closure here made the handles and
                    // toolbar flicker whenever the room rebuilt.
                    contextMenuBuilder: buildComposerContextMenu,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: ephemeral
                          ? AppLocalizations.of(context).deepOceanThemeEphemeralHint
                          : AppLocalizations.of(context).deepOceanThemeDefaultHint,
                      hintStyle: theme.body.copyWith(color: theme.inkMuted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
                ),
                child: child,
              ),
            ),
            child: controller.text.isNotEmpty
                ? _SendButton(
                    key: const ValueKey('send'),
                    onSend: onSend,
                    semanticLabel: AppLocalizations.of(context).deepOceanThemeSendButtonLabel,
                    classic: true,
                    onSchedule: onSchedule,
                    scheduledCount: scheduledCount,
                  )
                : modeButton != null
                    ? SizedBox(
                        key: const ValueKey('mode'),
                        width: 38,
                        height: 38,
                        child: modeButton,
                      )
                    : onCamera != null
                        ? FocusableTap(
                            key: const ValueKey('camera'),
                            onTap: onCamera,
                            semanticLabel: AppLocalizations.of(context).deepOceanThemeCameraButtonLabel,
                            shape: FocusRingShape.circle,
                            child: GestureDetector(
                              onTap: onCamera,
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.surfaceRaised,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.divider),
                                ),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  color: theme.inkSoft,
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('empty'),
                            width: 38,
                            height: 38,
                          ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Liquid-glass composer. Adds the bottom safe area itself.
class ChatComposerLiquid extends StatelessWidget {
  const ChatComposerLiquid({
    super.key,
    required this.controller,
    required this.ephemeral,
    required this.onSend,
    this.focusNode,
    this.onChanged,
    this.onAttach,
    this.onCamera,
    this.padding,
    this.mention,
    this.capture,
    this.onSchedule,
    this.scheduledCount = 0,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool ephemeral;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;

  /// Pass null to hide the attach button entirely.
  final VoidCallback? onAttach;

  /// Opens the camera in one tap, without going through the attachment sheet.
  ///
  /// Nullable for the same reason [onAttach] is, and it matters as much: the
  /// thread overlay builds this composer inside a root `OverlayEntry`, and the
  /// camera is a full-screen route that would fight it for layering. Pass null
  /// and the button is absent rather than present and broken.
  final VoidCallback? onCamera;

  /// Overrides the default outer padding, including the bottom safe area
  /// this widget would otherwise add. Only needed by hosts that own their
  /// own keyboard insets; leave null inside a `Scaffold`.
  final EdgeInsets? padding;

  /// See [ChatComposerClassic.mention].
  final MentionSession? mention;

  /// See [ChatComposerClassic.capture].
  final ComposerCapture? capture;

  /// See [ChatComposerClassic.onSchedule].
  final VoidCallback? onSchedule;

  /// See [ChatComposerClassic.scheduledCount].
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Scaffold handles the keyboard via resizeToAvoidBottomInset — the body
    // shrinks and `bottomSafe` is already reduced to 0 when the keyboard
    // covers the home indicator. Adding viewInsets here would double-count.
    final pad = padding ?? EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomSafe);
    return Padding(
      padding: pad,
      child: ComposerCaptureHost(
        capture: capture,
        style: ComposerCaptureStyle.liquid,
        builder: (context, modeButton) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onAttach != null) ...[
            LiquidGlass(
              shape: LiquidGlassShape.circle,
              size: const Size(44, 44),
              onTap: onAttach,
              child: Icon(Icons.add, size: 18, color: theme.accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: LiquidGlass(
              shape: LiquidGlassShape.rounded,
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              // See ChatComposerClassic — multi-line fields never fire
              // onSubmitted.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: MentionKeyboardNav(
                  session: mention,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: theme.body.copyWith(color: theme.ink, fontSize: 16),
                    cursorColor: theme.accent,
                    minLines: 1,
                    maxLines: 5,
                    // Kept in step with the classic variant above by hand —
                    // see the note there.
                    // See the classic composer: the stable callback prevents
                    // selection-overlay churn during ordinary room rebuilds.
                    contextMenuBuilder: buildComposerContextMenu,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: ephemeral
                          ? AppLocalizations.of(context).deepOceanThemeEphemeralHint
                          : AppLocalizations.of(context).deepOceanThemeMessageHint,
                      hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
                ),
                child: child,
              ),
            ),
            child: controller.text.isNotEmpty
                ? _SendButton(
                    key: const ValueKey('send'),
                    onSend: onSend,
                    semanticLabel: AppLocalizations.of(context).deepOceanThemeSendButtonLabel,
                    classic: false,
                    onSchedule: onSchedule,
                    scheduledCount: scheduledCount,
                  )
                : modeButton != null
                    ? SizedBox(
                        key: const ValueKey('mode'),
                        width: 44,
                        height: 44,
                        child: modeButton,
                      )
                    : onCamera != null
                        ? LiquidGlass(
                            key: const ValueKey('camera'),
                            shape: LiquidGlassShape.circle,
                            size: const Size(44, 44),
                            onTap: onCamera,
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                              color: theme.accent,
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('empty'),
                            width: 44,
                            height: 44,
                          ),
          ),
        ],
        ),
      ),
    );
  }
}
