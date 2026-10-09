import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/navigation/destinations.dart';
import '../widgets/shortcuts/command_palette.dart';
import '../widgets/shortcuts/shortcut_peek.dart';
import '../widgets/shortcuts/shortcuts_panel.dart';
import 'app_shortcuts.dart';

/// Where keyboard shortcuts are heard, and the shortcuts that belong to the
/// whole app rather than to any one screen (⌘K, ⌘/, ⌘,).
///
/// ## Dispatch
///
/// A key event bubbles up the focus tree from the focused widget, and this
/// sits above the navigator, so it hears a key only after everything on
/// screen has passed on it: a text field keeps its own chords, a menu its
/// arrows, a viewer its Esc. What reaches here is matched against
/// [AppShortcutRegistry], whose newest active binding for the chord runs.
///
/// It must sit inside `MaterialApp.builder`, below `WidgetsApp`'s own shortcut
/// table and text-editing shortcuts. That means it hears a chord BEFORE those,
/// so the catalog must never bind one a text field relies on (⌘A, ⌘C, ⌘←…).
/// The composer's ⌘B/⌘I/⌘U/⌘V are only listed ([ShortcutDef.ambient]) for
/// that reason, and handled closer to the field.
///
/// ## The peek
///
/// Holding the primary modifier alone (⌘, or Ctrl off Apple) for a moment
/// shows [ShortcutPeek]; letting go hides it. Watched through
/// [HardwareKeyboard] rather than the focus tree, so it works with nothing
/// focused, and never consumes anything. Any other key, a click, or the app
/// losing focus (⌘⇥ away never delivers the key-up) calls it off.
class ShortcutHost extends StatefulWidget {
  const ShortcutHost({
    super.key,
    required this.navigatorKey,
    required this.repo,
    required this.onOpenRoom,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ChatRepository repo;

  /// Opens a chat by id, from wherever the app happens to be.
  final void Function(String roomId) onOpenRoom;
  final Widget child;

  @override
  State<ShortcutHost> createState() => _ShortcutHostState();
}

class _ShortcutHostState extends State<ShortcutHost> {
  static const _holdDelay = Duration(milliseconds: 650);

  final List<Object> _tokens = [];
  Timer? _hold;
  ShortcutPeek? _peek;
  late final AppLifecycleListener _lifecycle;

  /// Set while the palette or the panel is up, so a second ⌘K does not stack
  /// a second palette on the first.
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    final reg = AppShortcutRegistry.instance;
    bool always() => mounted;
    _tokens
      ..add(reg.bind(AppShortcuts.commandPalette, _openPalette, always))
      ..add(reg.bind(AppShortcuts.showShortcuts, _openPanel, always))
      ..add(reg.bind(AppShortcuts.settings, _openSettings, always));
    // ⌘1–4 follow the nav's own order, so the number matches the position
    // of the tab it names.
    const sections = [
      AppShortcuts.section1,
      AppShortcuts.section2,
      AppShortcuts.section3,
      AppShortcuts.section4,
    ];
    for (var i = 0; i < sections.length && i < navOrder.length; i++) {
      final s = navOrder[i];
      _tokens.add(reg.bind(sections[i], () => _goTo(s), always));
    }
    HardwareKeyboard.instance.addHandler(_watchHold);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _lifecycle = AppLifecycleListener(
      onInactive: _callOffPeek,
      onHide: _callOffPeek,
    );
  }

  @override
  void dispose() {
    for (final t in _tokens) {
      AppShortcutRegistry.instance.unbind(t);
    }
    HardwareKeyboard.instance.removeHandler(_watchHold);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _lifecycle.dispose();
    _callOffPeek();
    super.dispose();
  }

  BuildContext? get _navContext => widget.navigatorKey.currentContext;

  List<String> _sectionLabels(BuildContext context) => [
        for (final d in navDestinations(AppLocalizations.of(context))) d.label,
      ];

  Future<void> _present(Future<void> Function(BuildContext) open) async {
    final ctx = _navContext;
    if (ctx == null || _presenting) return;
    _callOffPeek();
    _presenting = true;
    try {
      await open(ctx);
    } finally {
      _presenting = false;
    }
  }

  void _openPalette() => _present(
        (ctx) => showCommandPalette(
          ctx,
          repo: widget.repo,
          onOpenRoom: widget.onOpenRoom,
          sectionLabels: _sectionLabels(ctx),
        ),
      );

  void _openPanel() => _present(
        (ctx) => showShortcutsPanel(ctx, sectionLabels: _sectionLabels(ctx)),
      );

  void _openSettings() => _goTo(HomeSection.settings);

  /// Back to the shell, then the section: a tab switch underneath a pushed
  /// page would change nothing anyone can see.
  void _goTo(HomeSection s) {
    widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
    SettingsStore.instance.setSection(s);
  }

  // ── Dispatch ──

  KeyEventResult _dispatch(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus?.context;
    final field = focused?.findAncestorStateOfType<EditableTextState>();
    // Mid-composition every key is the input method's.
    if (field != null && field.textEditingValue.composing.isValid) {
      return KeyEventResult.ignored;
    }
    final run = AppShortcutRegistry.instance.match(event, typing: field != null);
    if (run == null) return KeyEventResult.ignored;
    // A held chord repeats. Claim the repeats so the platform does not beep
    // at them, but run once: nothing here should fire eight times a second.
    if (event is KeyDownEvent) {
      _callOffPeek();
      run();
    }
    return KeyEventResult.handled;
  }

  // ── The peek ──

  static bool get _apple => KeyCombo.appleModifiers;

  static bool _isPrimary(LogicalKeyboardKey k) => _apple
      ? k == LogicalKeyboardKey.metaLeft || k == LogicalKeyboardKey.metaRight
      : k == LogicalKeyboardKey.controlLeft || k == LogicalKeyboardKey.controlRight;

  bool _watchHold(KeyEvent e) {
    if (_isPrimary(e.logicalKey)) {
      if (e is KeyDownEvent) {
        final alone = HardwareKeyboard.instance.logicalKeysPressed.every(_isPrimary);
        if (alone && _peek == null && !_presenting && SettingsStore.instance.shortcutPeek) {
          _hold?.cancel();
          _hold = Timer(_holdDelay, _showPeek);
        }
      } else if (e is KeyUpEvent) {
        _callOffPeek();
      }
    } else if (e is KeyDownEvent) {
      // ⌘ was the start of a chord, not a question. The chord itself still
      // goes through: this handler never consumes anything.
      _callOffPeek();
    }
    return false;
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) _callOffPeek();
  }

  void _showPeek() {
    _hold = null;
    final overlay = widget.navigatorKey.currentState?.overlay;
    final ctx = _navContext;
    if (overlay == null || ctx == null || !mounted) return;
    if (!HardwareKeyboard.instance.logicalKeysPressed.any(_isPrimary)) return;
    _peek = ShortcutPeek.show(overlay, sectionLabels: _sectionLabels(ctx));
  }

  void _callOffPeek() {
    _hold?.cancel();
    _hold = null;
    _peek?.hide();
    _peek = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _dispatch,
      child: widget.child,
    );
  }
}
