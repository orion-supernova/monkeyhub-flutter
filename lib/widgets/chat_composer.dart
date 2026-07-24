import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../keyboard/submit_on_enter.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';

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
    this.padding,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool ephemeral;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;

  /// Pass null to hide the attach button entirely.
  final VoidCallback? onAttach;

  /// Overrides the default outer padding. Only needed by hosts that own
  /// their own keyboard insets; leave null inside a `Scaffold`.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onAttach != null) ...[
            FocusableTap(
              onTap: onAttach,
              semanticLabel: 'Attach',
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
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: theme.body.copyWith(color: theme.ink),
                  cursorColor: theme.accent,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: ephemeral
                        ? 'whisper something the server will forget…'
                        : 'say something…',
                    hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FocusableTap(
            onTap: onSend,
            semanticLabel: 'Send',
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
          ),
        ],
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
    this.padding,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool ephemeral;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;

  /// Pass null to hide the attach button entirely.
  final VoidCallback? onAttach;

  /// Overrides the default outer padding, including the bottom safe area
  /// this widget would otherwise add. Only needed by hosts that own their
  /// own keyboard insets; leave null inside a `Scaffold`.
  final EdgeInsets? padding;

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
      child: Row(
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
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: theme.body.copyWith(color: theme.ink, fontSize: 16),
                  cursorColor: theme.accent,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: ephemeral
                        ? 'whisper something the server will forget…'
                        : 'Message',
                    hintStyle: theme.body.copyWith(color: theme.inkMuted),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: const Size(44, 44),
            tinted: true,
            onTap: onSend,
            child: Icon(Icons.arrow_upward, size: 18, color: theme.accentInk),
          ),
        ],
      ),
    );
  }
}
