
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mention_session.dart';
import '../keyboard/focusable_tap.dart';
import '../keyboard/mention_keyboard_nav.dart';
import '../keyboard/submit_on_enter.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'composer_capture.dart';
import 'composer_format_toolbar.dart';
import 'send_button.dart';
import 'glass_buttons.dart';
import 'liquid_glass.dart';

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
class _SendButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 40 in the liquid composer, like every chrome button; its slot stays
    // 44 so the disc centres on the 44pt field beside it. Everything else —
    // the disc, the hold, the ring — is the shared [SendButton], the same one
    // the photo composer sends with.
    return SendButton(
      size: classic ? 38 : 40,
      onSend: onSend,
      onSchedule: onSchedule,
      semanticLabel: scheduledCount > 0
          ? '$semanticLabel, '
              '${l10n.composerScheduledBadgeSemantics(scheduledCount)}'
          : semanticLabel,
      badge: scheduledCount > 0
          // Announced by the button's own semantic label instead — a screen
          // reader meeting both reads the count twice.
          ? _ScheduledBadge(count: scheduledCount)
          : null,
    );
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
          // The badge token — 13/w600 tabular on the body face, never the
          // theme's tracked mono at an off-scale 9.
          style: theme.bodySoft.copyWith(
            color: theme.accent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
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
            open ? CupertinoIcons.keyboard : CupertinoIcons.smiley,
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

/// The composer's trailing button slot (send, record, camera) and the gap
/// before it. [collapsed] folds both away, animated, so a host with nothing
/// to put there at rest gets a full-width field.
class _TrailingSlot extends StatelessWidget {
  const _TrailingSlot({required this.collapsed, required this.child});

  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: MotionScope.of(context).d(const Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: collapsed
          ? const SizedBox(height: 38)
          : Padding(padding: const EdgeInsets.only(left: 10), child: child),
    );
  }
}

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
    this.hint,
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

  /// The field's placeholder, for a host that is not a room — a highlight's
  /// comments say "Add a comment…" rather than "Message". Null keeps the
  /// room's own hint.
  final String? hint;

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
                      hintText: hint ?? (ephemeral
                          ? AppLocalizations.of(context).deepOceanThemeEphemeralHint
                          : AppLocalizations.of(context).deepOceanThemeDefaultHint),
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
          _ComposerEmptiness(
            controller: controller,
            builder: (context, hasText) => _TrailingSlot(
              // Nothing to offer at rest (no recorder, no camera): the slot
              // takes no room until there is something to send, so the field
              // runs the full width instead of stopping short of a hole.
              collapsed: !hasText && capture == null && onCamera == null,
              child: AnimatedSwitcher(
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
    this.hint,
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

  /// The field's placeholder, for a host that is not a room — a highlight's
  /// comments say "Add a comment…" rather than "Message". Null keeps the
  /// room's own hint.
  final String? hint;

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
            // The Messages "+": a glyph in the label colour on glass. The
            // accent is kept for the one control that sends. THE 40pt chrome
            // button, centred in a 44pt slot so it sits level with the field.
            SizedBox.square(
              dimension: 44,
              child: Center(
                child: GlassIconButton(
                  icon: CupertinoIcons.plus,
                  iconSize: 20,
                  onTap: onAttach,
                  semanticLabel: AppLocalizations.of(context)
                      .deepOceanThemeAttachButtonLabel,
                ),
              ),
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
                      hintText: hint ?? (ephemeral
                          ? AppLocalizations.of(context).deepOceanThemeEphemeralHint
                          : AppLocalizations.of(context).deepOceanThemeMessageHint),
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
          _ComposerEmptiness(
            controller: controller,
            builder: (context, hasText) => _TrailingSlot(
              // Nothing to offer at rest (no recorder, no camera): the slot
              // takes no room until there is something to send, so the field
              // runs the full width instead of stopping short of a hole.
              collapsed: !hasText && capture == null && onCamera == null,
              child: AnimatedSwitcher(
              // Springs in with a little overshoot the moment there is
              // something to send — the Telegram pop — and slips out quickly.
              duration: MotionScope.of(context)
                  .d(const Duration(milliseconds: 420)),
              reverseDuration: MotionScope.of(context)
                  .d(const Duration(milliseconds: 140)),
              // Only the send disc springs: it is a solid fill. The camera
              // beside it is glass, and a BackdropFilter that fades or scales
              // re-rasterises its blur every frame — it simply swaps.
              transitionBuilder: (child, animation) =>
                  child.key != const ValueKey('send')
                      ? child
                      : FadeTransition(
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
                  ? SizedBox.square(
                      key: const ValueKey('send'),
                      dimension: 44,
                      child: Center(
                        child: _SendButton(
                          onSend: onSend,
                          semanticLabel: AppLocalizations.of(context)
                              .deepOceanThemeSendButtonLabel,
                          classic: false,
                          onSchedule: onSchedule,
                          scheduledCount: scheduledCount,
                        ),
                      ),
                    )
                  : modeButton != null
                      ? SizedBox(
                          key: const ValueKey('mode'),
                          width: 44,
                          height: 44,
                          child: modeButton,
                        )
                      : onCamera != null
                          ? SizedBox.square(
                              key: const ValueKey('camera'),
                              dimension: 44,
                              child: Center(
                                child: GlassIconButton(
                                  icon: CupertinoIcons.camera,
                                  iconSize: 20,
                                  onTap: onCamera,
                                  semanticLabel: AppLocalizations.of(context)
                                      .deepOceanThemeCameraButtonLabel,
                                ),
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('empty'),
                              width: 44,
                              height: 44,
                            ),
            ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
