import 'package:flutter/material.dart';

import '../data/mention_session.dart';
import '../keyboard/focusable_tap.dart';
import '../keyboard/mention_keyboard_nav.dart';
import '../keyboard/submit_on_enter.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'composer_capture.dart';
import 'composer_format_toolbar.dart';
import 'liquid_glass.dart';

class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.onSend,
    required this.semanticLabel,
    this.classic = true,
  });

  final VoidCallback onSend;
  final String semanticLabel;
  final bool classic;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    if (classic) {
      return FocusableTap(
        onTap: onSend,
        semanticLabel: semanticLabel,
        shape: FocusRingShape.circle,
        child: GestureDetector(
          onTap: onSend,
          child: Container(
            width: 38,
            height: 38,
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
          ),
        ),
      );
    } else {
      return LiquidGlass(
        shape: LiquidGlassShape.circle,
        size: const Size(44, 44),
        tinted: true,
        onTap: onSend,
        child: Icon(Icons.arrow_upward, size: 18, color: theme.accentInk),
      );
    }
  }
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
