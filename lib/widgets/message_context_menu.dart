import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/message_capabilities.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'glass_reveal.dart';
import 'glass_surface.dart';
import 'ios_kit.dart' show quietFill;
import 'message_action_menu.dart';

/// The mouse's message menu: a compact popover at the point that was
/// right-clicked, the way every Mac and Windows app answers a secondary click.
///
/// ### Why it is not the long-press menu
///
/// [showMessageActionMenu] is the iOS focus overlay: it photographs and blurs
/// the page, lifts the bubble off it and lays out 48pt rows for a thumb. All of
/// that is right under a finger and wrong under a cursor. A pointer is
/// precise, so the rows are 28pt; the menu is AT the pointer, so there is no
/// bubble to lift to say what it is about; and a desktop menu is a quick,
/// throwaway thing that opens on mouse-down and is gone a beat after the
/// choice, so there is no page snapshot to take or blur to pay for either.
///
/// What it shares is everything that decides what the menu SAYS: the same
/// [messageActionSpecs] rows in the same order, the same quick six emoji (with
/// the viewer's own reactions folded in by [quickPillEmojis]) and the same
/// [MessageActionResult], so the caller handles a right-click with exactly the
/// switch it already runs for a long-press.
///
/// [reactionsOnly] draws the emoji row alone: the hover strip's react button.
Future<MessageActionResult?> showMessageContextMenu({
  required BuildContext context,
  required Offset position,
  required MessageCapabilities capabilities,
  bool isPinned = false,
  bool isSaved = false,
  bool isTranslated = false,
  String? fileName,
  Set<String> myReactions = const {},
  bool reactionsOnly = false,

  /// False drops the emoji row: a message nobody can react to (a pending
  /// send, a system notice) still has rows worth offering.
  bool showReactions = true,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<MessageActionResult?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => MessageContextMenu(
      position: position,
      capabilities: capabilities,
      isPinned: isPinned,
      isSaved: isSaved,
      isTranslated: isTranslated,
      fileName: fileName,
      myReactions: myReactions,
      reactionsOnly: reactionsOnly,
      showReactions: showReactions,
      onResolve: (result) {
        if (!completer.isCompleted) completer.complete(result);
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// The popover itself. Public so a test can pump it on its own and look at
/// it; everything else should go through [showMessageContextMenu].
@visibleForTesting
class MessageContextMenu extends StatefulWidget {
  const MessageContextMenu({
    super.key,
    required this.position,
    required this.capabilities,
    required this.onResolve,
    this.isPinned = false,
    this.isSaved = false,
    this.isTranslated = false,
    this.fileName,
    this.myReactions = const {},
    this.reactionsOnly = false,
    this.showReactions = true,
  });

  /// Where the click landed, in the root overlay's (global) coordinates.
  final Offset position;
  final MessageCapabilities capabilities;
  final bool isPinned;
  final bool isSaved;
  final bool isTranslated;
  final String? fileName;
  final Set<String> myReactions;
  final bool reactionsOnly;
  final bool showReactions;
  final ValueChanged<MessageActionResult?> onResolve;

  /// The whole menu is this wide. Fixed rather than shrink-wrapped so the
  /// emoji row and the rows below it share one edge, and wide enough for the
  /// longest English row ("Copy coordinates") with its glyph.
  static const double width = 248;

  static const double rowH = 28;
  static const double emojiRowH = 36;
  static const double separatorH = 9;

  /// Inside the glass, around everything.
  static const double inset = 5;

  @override
  State<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<MessageContextMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;

  /// The row the keyboard or the pointer is on, or -1 for none. One index for
  /// both, the way a native menu has one highlight: moving the mouse over a
  /// row and then pressing ↓ continues from where the mouse left it.
  int _hi = -1;

  final FocusNode _focus = FocusNode(debugLabel: 'MessageContextMenu');

  @override
  void initState() {
    super.initState();
    // A desktop menu is there almost at once. Long enough to read as growing
    // out of the pointer, short enough that a quick right-click-choose is
    // never waiting on it.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 90),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _resolve(MessageActionResult? result) async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve(result);
  }

  List<MessageActionSpec> _specs(AppLocalizations l10n) => widget.reactionsOnly
      ? const []
      : messageActionSpecs(
          l10n: l10n,
          capabilities: widget.capabilities,
          isPinned: widget.isPinned,
          isSaved: widget.isSaved,
          isTranslated: widget.isTranslated,
          hasFileName: widget.fileName != null,
        );

  /// Where a separator goes: ahead of the first destructive row, so the red
  /// pair stands apart from everything that can be taken back.
  static int _firstDestructive(List<MessageActionSpec> specs) {
    final i = specs.indexWhere((s) => s.destructive);
    return i <= 0 ? -1 : i;
  }

  KeyEventResult _onKey(
    FocusNode node,
    KeyEvent event,
    List<MessageActionSpec> specs,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final n = specs.length;
    if (n == 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _hi = _hi < 0 ? 0 : (_hi + 1) % n);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _hi = _hi < 0 ? n - 1 : (_hi - 1 + n) % n);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.pageUp) {
      setState(() => _hi = 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end || key == LogicalKeyboardKey.pageDown) {
      setState(() => _hi = n - 1);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      if (_hi < 0 || _hi >= n) return KeyEventResult.handled;
      _choose(specs[_hi].action);
      return KeyEventResult.handled;
    }
    // Type-to-select, the native menu's: a letter moves to the next row that
    // starts with it, wrapping, so pressing D twice walks "Delete" then back.
    final ch = event.character;
    final keys = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        ch != null &&
        ch.trim().length == 1 &&
        !keys.isMetaPressed &&
        !keys.isControlPressed &&
        !keys.isAltPressed) {
      final want = ch.toLowerCase();
      for (var step = 1; step <= n; step++) {
        final i = (_hi + step + n) % n;
        final label = sentenceCaseOf(context, specs[i].label).toLowerCase();
        if (label.startsWith(want)) {
          setState(() => _hi = i);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _choose(MessageAction a) {
    HapticFeedback.selectionClick();
    _resolve(MessageActionResult.action(a));
  }

  /// Exact by construction: every element of the menu is a fixed height
  /// except the filename header, which is measured against the width it will
  /// get — the same trick the long-press menu uses, for the same reason.
  double _height(
    BuildContext context,
    AppTheme theme,
    List<MessageActionSpec> specs,
  ) {
    var h = MessageContextMenu.inset * 2;
    final reactions = widget.showReactions || widget.reactionsOnly;
    if (reactions) h += MessageContextMenu.emojiRowH;
    if (reactions && specs.isNotEmpty) h += MessageContextMenu.separatorH;
    final name = widget.fileName;
    if (name != null && specs.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: name, style: _headerStyle(theme)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: MessageContextMenu.width - 2 * MessageContextMenu.inset - 16);
      h += painter.height + 10 + MessageContextMenu.separatorH;
    }
    h += specs.length * MessageContextMenu.rowH;
    if (_firstDestructive(specs) > 0) h += MessageContextMenu.separatorH;
    return h;
  }

  static TextStyle _headerStyle(AppTheme theme) => theme.caption.copyWith(
        color: theme.inkMuted,
        fontSize: 12,
        height: 1.25,
      );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final specs = _specs(l10n);
    final media = MediaQuery.of(context);
    final screen = media.size;
    const pad = 8.0;

    final wantedH = _height(context, theme, specs);
    final maxH = math.max(0.0, screen.height - 2 * pad);
    final h = math.min(wantedH, maxH);
    final w = widget.reactionsOnly
        ? _EmojiRow.widthFor(7) + 2 * MessageContextMenu.inset
        : MessageContextMenu.width;

    // Down and to the right of the pointer, as every desktop menu opens;
    // flipped to the other side on whichever axis would run off the window,
    // then held inside it.
    final p = widget.position;
    var left = p.dx + 1;
    final flipX = left + w > screen.width - pad;
    if (flipX) left = p.dx - w - 1;
    left = left.clamp(pad, math.max(pad, screen.width - pad - w)).toDouble();
    var top = p.dy + 1;
    final flipY = top + h > screen.height - pad;
    if (flipY) top = p.dy - h - 1;
    top = top.clamp(pad, math.max(pad, screen.height - pad - h)).toDouble();
    final grow = Alignment(flipX ? 1 : -1, flipY ? 1 : -1);

    final children = <Widget>[];
    if (widget.showReactions || widget.reactionsOnly) {
      children.add(_EmojiRow(
        selected: widget.myReactions,
        onEmoji: (e) => _resolve(MessageActionResult.emoji(e)),
        onMore: () => _resolve(const MessageActionResult.fullPicker()),
      ));
      if (specs.isNotEmpty) children.add(_Separator(theme: theme));
    }
    final name = widget.fileName;
    if (name != null && specs.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Text(
          name,
          style: _headerStyle(theme),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ));
      children.add(_Separator(theme: theme));
    }
    final split = _firstDestructive(specs);
    for (var i = 0; i < specs.length; i++) {
      if (i == split) children.add(_Separator(theme: theme));
      final spec = specs[i];
      children.add(_MenuRow(
        spec: spec,
        highlighted: i == _hi,
        onHover: (inside) {
          if (inside && _hi != i) setState(() => _hi = i);
          if (!inside && _hi == i) setState(() => _hi = -1);
        },
        onTap: () => _choose(spec.action),
      ));
    }

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (wantedH > maxH) {
      body = SingleChildScrollView(child: body);
    }

    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    return Material(
      type: MaterialType.transparency,
      child: OverlayModalScope(
        onDismiss: () => _resolve(null),
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (node, event) => _onKey(node, event, specs),
          child: Stack(
            children: [
              // Mouse-DOWN outside closes, as a native menu does, and the
              // barrier is opaque so the press (and the wheel) never reaches
              // the transcript underneath: scrolling a conversation out from
              // under an open menu is what no desktop app lets happen.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => _resolve(null),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: w,
                height: h,
                child: AnimatedBuilder(
                  animation: curved,
                  builder: (_, child) => GlassReveal(
                    t: curved.value,
                    alignment: grow,
                    from: 0.9,
                    child: child!,
                  ),
                  child: GlassSurface(
                    radius: 12,
                    padding: const EdgeInsets.all(MessageContextMenu.inset),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MessageContextMenu.separatorH,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: 1 / MediaQuery.devicePixelRatioOf(context),
          color: theme.ink.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

/// One action. A pointer row, not a thumb row: 28pt, 14pt type, the glyph
/// LEADING the way macOS and Windows menus place it, and the highlight a
/// filled accent capsule with the label turned to the accent's own ink.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.spec,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final MessageActionSpec spec;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = highlighted
        ? (spec.destructive ? Colors.white : theme.accentInk)
        : (spec.destructive ? theme.danger : theme.ink);
    final fill = highlighted
        ? (spec.destructive ? theme.danger : theme.accent)
        : Colors.transparent;
    final label = sentenceCaseOf(context, spec.label);
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: MessageContextMenu.rowH,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(spec.icon, size: 15, color: ink),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: theme.body.copyWith(
                      fontSize: 14,
                      height: 1.2,
                      color: ink,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The quick six and a `+`, small enough to sit across the top of a pointer
/// menu. Each is its own focus stop, so Tab reaches them from the keyboard
/// while ↑/↓ stay on the rows.
class _EmojiRow extends StatelessWidget {
  const _EmojiRow({
    required this.selected,
    required this.onEmoji,
    required this.onMore,
  });

  final Set<String> selected;
  final ValueChanged<String> onEmoji;
  final VoidCallback onMore;

  static const double cell = 32;
  static double widthFor(int cells) => cells * cell + 4;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      height: MessageContextMenu.emojiRowH,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final e in quickPillEmojis(selected))
            _EmojiCell(
              semanticLabel: e,
              selected: selected.contains(e),
              onTap: () => onEmoji(e),
              child: Text(e, style: const TextStyle(fontSize: 19, height: 1.1)),
            ),
          _EmojiCell(
            semanticLabel: MaterialLocalizations.of(context).moreButtonTooltip,
            selected: false,
            onTap: onMore,
            child: Icon(CupertinoIcons.plus, size: 15, color: theme.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EmojiCell extends StatefulWidget {
  const _EmojiCell({
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_EmojiCell> createState() => _EmojiCellState();
}

class _EmojiCellState extends State<_EmojiCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final Color fill;
    if (widget.selected) {
      fill = theme.accent.withValues(alpha: _hover ? 0.32 : 0.22);
    } else {
      fill = _hover ? quietFill(theme) : Colors.transparent;
    }
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
      selected: widget.selected ? true : null,
      shape: FocusRingShape.circle,
      inset: 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // The hovered glyph grows a touch, the tapback's own answer to a
          // pointer resting on it; a fill alone reads as a button, not a face.
          child: AnimatedScale(
            scale: _hover ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              width: _EmojiRow.cell,
              height: _EmojiRow.cell,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
