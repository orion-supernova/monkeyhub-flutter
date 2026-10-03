import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'composer_capture.dart';
import 'composer_format_toolbar.dart';
import 'haptic_ramp.dart';
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

  /// The vibration that builds with the ring, and stops the instant it does.
  late final HapticRamp _holdHaptics;

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
    _holdHaptics = HapticRamp(_hold);
  }

  @override
  void dispose() {
    _leadIn?.cancel();
    _holdHaptics.dispose();
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
  /// True from [deactivate]: the hold recognizer can fire its cancel from
  /// inside the unmount, and notifying [_hold]'s listeners then would mark a
  /// builder dirty while the tree is locked (see TeardownSafe).
  bool _leaving = false;

  @override
  void deactivate() {
    _leaving = true;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _leaving = false;
  }

  void _endHold() {
    _leadIn?.cancel();
    _leadIn = null;
    if (_leaving) return;
    if (_hold.value != 0) _hold.value = 0;
  }

  /// A send is one light tick. The hold's heavy impact stays the loud one.
  void _send() {
    HapticFeedback.lightImpact();
    widget.onSend();
  }

  void _fire() {
    final schedule = widget.onSchedule;
    if (schedule == null) return;
    // Heavier than anything the ramp played, so the sheet opening lands as
    // its own beat rather than one more tap in the buzz.
    HapticFeedback.heavyImpact();
    _endHold();
    schedule();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final size = widget.classic ? 38.0 : 44.0;

    // A solid disc in the outgoing-bubble colour on both composers, not
    // tinted glass and not a glowing accent button: send is the one control on
    // screen that commits something, and it wears the colour of what it is
    // about to create. Only the size differs.
    Widget core = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.bubbleFill(isMine: true),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.arrow_up,
              size: widget.classic ? 19 : 21,
              color: theme.accentInk,
            ),
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
        ? GestureDetector(onTap: _send, child: core)
        : RawGestureDetector(
            key: _key,
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (instance) {
                  instance.onTap = _send;
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
      onTap: _send,
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

/// Rebuilds its subtree when the composer crosses between empty and non-empty.
///
/// The trailing button is chosen off `controller.text`, but both composers are
/// `StatelessWidget`s (deliberately — see the note below) and neither host
/// rebuilds on a keystroke: the room screen's `setState` runs on a 1Hz ticker
/// and the thread overlay's on repo traffic. So the send button used to arrive
/// whenever the host next happened to build — up to a second after the
/// character that earned it, and only then starting its 200ms fade. Listening
/// to the controller here puts it on the keystroke instead.
///
/// Only the flip rebuilds. A `TextEditingController` notifies on every
/// selection and composing-region change as well, and none of those change
/// which button belongs in the row.
class _ComposerEmptiness extends StatefulWidget {
  const _ComposerEmptiness({required this.controller, required this.builder});

  final TextEditingController controller;
  final Widget Function(BuildContext context, bool hasText) builder;

  @override
  State<_ComposerEmptiness> createState() => _ComposerEmptinessState();
}

class _ComposerEmptinessState extends State<_ComposerEmptiness> {
  late bool _hasText = widget.controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_ComposerEmptiness old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _hasText = widget.controller.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final has = widget.controller.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _hasText);
}

/// The smiley at the end of the text field that swaps the keyboard for the
/// expression panel, and back — a keyboard glyph while the panel is up.
///
/// Inside the field rather than beside it, the way every messenger places it:
/// the row's two outer slots are already the attach button and the send/record
/// button, and a third circle would squeeze the field on a small phone.
class _ExpressionsToggle extends StatelessWidget {
  const _ExpressionsToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel:
          open ? l10n.expressionShowKeyboard : l10n.expressionOpenPanel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Icon(
            open ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
            size: 22,
            color: open ? theme.accent : theme.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// What the composers accept from the keyboard besides text: the GIFs and
/// stickers Gboard, Samsung's keyboard and the iOS sticker drawer insert.
///
/// Without this the keyboard's GIF button does nothing at all in this app —
/// Android shows "this app doesn't support image insertion here". The list
/// is what the send path can carry untouched; see `prepareUneditedForSend`.
const List<String> kComposerInsertableMimeTypes = [
  'image/gif',
  'image/webp',
  'image/png',
  'image/jpeg',
];

ContentInsertionConfiguration? _insertion(
        ValueChanged<KeyboardInsertedContent>? onContent) =>
    onContent == null
        ? null
        : ContentInsertionConfiguration(
            onContentInserted: onContent,
            allowedMimeTypes: kComposerInsertableMimeTypes,
          );

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
    this.captureOpenHintRoomId,
    this.onExpressions,
    this.expressionsOpen = false,
    this.onFieldTap,
    this.onContentInserted,
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

  /// Toggles the emoji/GIF/sticker panel. Null hides the smiley — a host with
  /// no panel to show must not offer one.
  final VoidCallback? onExpressions;

  /// Whether that panel is up, which turns the smiley into a keyboard glyph.
  final bool expressionsOpen;

  /// Called when the text field itself is tapped — the host closes the panel
  /// so the keyboard can come back in its place.
  final VoidCallback? onFieldTap;

  /// A GIF or sticker the keyboard inserted (Gboard's GIF tab, the iOS sticker
  /// drawer). Null leaves the keyboard's insert button inert, as before.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

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

  /// The room this composer belongs to, or null to never play the mode
  /// button's open hint (bump + tooltip) — see
  /// [ComposerCaptureHost.openHintRoomId].
  ///
  /// Null by default like every other opt-in here: the room screen passes
  /// its room's id, the thread overlay does not.
  final String? captureOpenHintRoomId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.divider,
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
      child: ComposerCaptureHost(
        capture: capture,
        openHintRoomId: captureOpenHintRoomId,
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
                  // The same iOS glyph the floating composer uses, on a plain
                  // raised disc — no outline.
                  decoration: BoxDecoration(
                    color: theme.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.plus, color: theme.ink, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              // A capsule, like Messages' field, rather than the theme's
              // bordered form input.
              decoration: BoxDecoration(
                color: theme.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // No `onSubmitted` here: a multi-line TextField never fires it —
              // Flutter turns Enter into a newline. SubmitOnEnter intercepts
              // the key instead, and leaves Shift+Enter as the newline.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: MentionKeyboardNav(
                  session: mention,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  Expanded(child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onTap: onFieldTap,
                    contentInsertionConfiguration:
                        _insertion(onContentInserted),
                    style: theme.body.copyWith(color: theme.ink, fontSize: 17),
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
                      hintStyle: theme.body
                          .copyWith(color: theme.inkMuted, fontSize: 17),
                      // One line, always. The field is `minLines: 1`, but a
                      // hint is laid out like any other text and wraps: the
                      // ephemeral hint is the longest string here and it grew
                      // the empty composer to two rows before anyone had typed
                      // anything. Ellipsize instead of pushing the send button
                      // down — no translation can undo this.
                      hintMaxLines: 1,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: onChanged,
                  )),
                  if (onExpressions != null)
                    _ExpressionsToggle(
                      open: expressionsOpen,
                      onTap: onExpressions!,
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ComposerEmptiness(
            controller: controller,
            builder: (context, hasText) => AnimatedSwitcher(
              // The floating composer's spring: pops in with overshoot the
              // moment there is something to send, slips out quickly.
              duration: MotionScope.of(context)
                  .d(const Duration(milliseconds: 420)),
              reverseDuration: MotionScope.of(context)
                  .d(const Duration(milliseconds: 140)),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0, 0.4),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.4, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                      reverseCurve: Curves.easeIn,
                    ),
                  ),
                  child: child,
                ),
              ),
              child: hasText
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
                                  ),
                                  child: Icon(
                                    CupertinoIcons.camera,
                                    color: theme.ink,
                                    size: 20,
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
    this.captureOpenHintRoomId,
    this.onExpressions,
    this.expressionsOpen = false,
    this.onFieldTap,
    this.onContentInserted,
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

  /// See [ChatComposerClassic.onExpressions].
  final VoidCallback? onExpressions;

  /// See [ChatComposerClassic.expressionsOpen].
  final bool expressionsOpen;

  /// See [ChatComposerClassic.onFieldTap].
  final VoidCallback? onFieldTap;

  /// See [ChatComposerClassic.onContentInserted].
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

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

  /// See [ChatComposerClassic.captureOpenHintRoomId].
  final String? captureOpenHintRoomId;

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
        openHintRoomId: captureOpenHintRoomId,
        style: ComposerCaptureStyle.liquid,
        builder: (context, modeButton) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onAttach != null) ...[
            LiquidGlass(
              shape: LiquidGlassShape.circle,
              size: const Size(44, 44),
              onTap: onAttach,
              // The Messages "+": a glyph in the label colour on glass. The
              // accent is kept for the one control that sends.
              child: Icon(CupertinoIcons.plus, size: 21, color: theme.ink),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: LiquidGlass(
              shape: LiquidGlassShape.rounded,
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
              // See ChatComposerClassic — multi-line fields never fire
              // onSubmitted.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: MentionKeyboardNav(
                  session: mention,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  Expanded(child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onTap: onFieldTap,
                    contentInsertionConfiguration:
                        _insertion(onContentInserted),
                    style: theme.body.copyWith(color: theme.ink, fontSize: 17),
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
                      hintStyle: theme.body
                          .copyWith(color: theme.inkMuted, fontSize: 17),
                      // See the classic composer — a wrapping hint grew the
                      // glass pill to two rows before anything was typed.
                      hintMaxLines: 1,
                    ),
                    onChanged: onChanged,
                  )),
                  if (onExpressions != null)
                    _ExpressionsToggle(
                      open: expressionsOpen,
                      onTap: onExpressions!,
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ComposerEmptiness(
            controller: controller,
            builder: (context, hasText) => AnimatedSwitcher(
              // Springs in with a little overshoot the moment there is
              // something to send — the Telegram pop — and slips out quickly.
              duration: MotionScope.of(context)
                  .d(const Duration(milliseconds: 420)),
              reverseDuration: MotionScope.of(context)
                  .d(const Duration(milliseconds: 140)),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0, 0.4),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.4, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut,
                      reverseCurve: Curves.easeIn,
                    ),
                  ),
                  child: child,
                ),
              ),
              child: hasText
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
                                CupertinoIcons.camera,
                                size: 21,
                                color: theme.ink,
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('empty'),
                              width: 44,
                              height: 44,
                            ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
