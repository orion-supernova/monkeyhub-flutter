import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

/// Every keyboard shortcut the app has, in one place.
///
/// One catalog because three things read it and must never disagree: the
/// dispatcher that runs a shortcut, the hold-⌘ peek and the searchable ⌘/
/// panel that list them, and the hover hints that print one next to a button.
/// A shortcut added anywhere else would work and be invisible, which for a
/// keyboard shortcut is the same as not existing.
///
/// A definition says nothing about what the shortcut DOES. Screens attach
/// that with [ShortcutBindings], and a shortcut is offered (in the peek, the
/// panel, the palette) only while something on screen has bound it, so the
/// lists always describe the screen you are looking at.
///
/// Some entries are [ShortcutDef.ambient]: keys handled by a widget of their
/// own (Enter in the composer, Esc everywhere, ← → in a viewer) that are
/// listed here only so they can be found. They are never dispatched from here.

/// The headings the lists are grouped under, in display order.
enum ShortcutGroup { general, navigation, chat, composer, viewer, call }

/// One physical chord. [primary] is ⌘ on Apple platforms and Ctrl elsewhere,
/// so a definition is written once and reads natively on both.
@immutable
class KeyCombo {
  const KeyCombo(
    this.key, {
    this.primary = false,
    this.shift = false,
    this.alt = false,
    this.control = false,
    this.nativeOnly = false,
  });

  final LogicalKeyboardKey key;

  /// The browser keeps this chord for itself (⌃⇥ switches tabs) and never
  /// hands it to a page. Dropped on web; the definition's other chords stay.
  final bool nativeOnly;
  final bool primary;
  final bool shift;
  final bool alt;

  /// The literal Ctrl key on every platform (⌃ on a Mac), for the few chords
  /// that are Ctrl everywhere, like Ctrl+Tab.
  final bool control;

  /// No ⌘/Ctrl/⌥ held: in a text field this chord types or edits, so it
  /// stays the field's.
  bool get typesText => !primary && !alt && !control;

  /// Whether ⌘ (rather than Ctrl) is this platform's primary modifier.
  /// Web follows the browser's OS: Chrome on a Mac reports macOS here.
  static bool get appleModifiers =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  SingleActivator get activator {
    final apple = appleModifiers;
    return SingleActivator(
      key,
      meta: primary && apple,
      control: control || (primary && !apple),
      shift: shift,
      alt: alt,
    );
  }

  /// The chord as printed keycaps, in the platform's own modifier order:
  /// ⌃⌥⇧⌘ on a Mac, Ctrl Alt Shift elsewhere.
  List<String> caps() {
    final apple = appleModifiers;
    final ctrl = control || (primary && !apple);
    return [
      if (ctrl) apple ? '⌃' : 'Ctrl',
      if (alt) apple ? '⌥' : 'Alt',
      if (shift) apple ? '⇧' : 'Shift',
      if (primary && apple) '⌘',
      keyCap(key),
    ];
  }

  static String keyCap(LogicalKeyboardKey key) {
    final apple = appleModifiers;
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.enter) return apple ? '↩' : 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.tab) return apple ? '⇥' : 'Tab';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.backspace) return apple ? '⌫' : 'Backspace';
    if (key == LogicalKeyboardKey.delete) return apple ? '⌦' : 'Del';
    if (key == LogicalKeyboardKey.equal) return '+';
    if (key == LogicalKeyboardKey.minus) return '−';
    return key.keyLabel.toUpperCase();
  }
}

@immutable
class ShortcutDef {
  const ShortcutDef(
    this.id,
    this.group,
    this.combos, {
    this.ambient = false,
    this.nativeOnly = false,
  });

  /// Stable identifier, also the suffix of the label's l10n key.
  final String id;
  final ShortcutGroup group;

  /// Every chord that triggers it. The first is the one printed.
  final List<KeyCombo> combos;

  /// Handled by a widget of its own and only LISTED here. See the file doc.
  final bool ambient;

  /// The browser reserves the chord (⌘N, ⌘W) and never hands it to a page,
  /// so on web it would be a promise that does nothing. Hidden there; the
  /// palette still offers the action by name.
  final bool nativeOnly;

  bool get offeredHere => !(nativeOnly && kIsWeb) && chords.isNotEmpty;

  /// [combos] minus any the browser would swallow. What is matched, printed
  /// and listed, everywhere: use this rather than [combos].
  List<KeyCombo> get chords =>
      kIsWeb ? [for (final c in combos) if (!c.nativeOnly) c] : combos;

  bool accepts(KeyEvent event) {
    for (final c in chords) {
      if (c.activator.accepts(event, HardwareKeyboard.instance)) return true;
    }
    return false;
  }

  @override
  String toString() => 'ShortcutDef($id)';
}

/// The catalog. Order within a group is display order.
abstract final class AppShortcuts {
  static const _k = LogicalKeyboardKey.keyK;

  // ── General ──
  static const commandPalette = ShortcutDef(
    'commandPalette',
    ShortcutGroup.general,
    [KeyCombo(_k, primary: true)],
  );
  static const showShortcuts = ShortcutDef(
    'showShortcuts',
    ShortcutGroup.general,
    [KeyCombo(LogicalKeyboardKey.slash, primary: true)],
  );
  static const search = ShortcutDef(
    'search',
    ShortcutGroup.general,
    [KeyCombo(LogicalKeyboardKey.keyF, primary: true)],
  );
  static const newChat = ShortcutDef(
    'newChat',
    ShortcutGroup.general,
    [KeyCombo(LogicalKeyboardKey.keyN, primary: true)],
    nativeOnly: true,
  );
  static const settings = ShortcutDef(
    'settings',
    ShortcutGroup.general,
    [KeyCombo(LogicalKeyboardKey.comma, primary: true)],
  );
  static const back = ShortcutDef(
    'back',
    ShortcutGroup.general,
    [KeyCombo(LogicalKeyboardKey.escape)],
    ambient: true,
  );

  // ── Navigation ──
  static const section1 = ShortcutDef(
    'section1',
    ShortcutGroup.navigation,
    // Chrome and Safari switch tabs on ⌘1–⌘9 and never let a page have it.
    [KeyCombo(LogicalKeyboardKey.digit1, primary: true, nativeOnly: true)],
  );
  static const section2 = ShortcutDef(
    'section2',
    ShortcutGroup.navigation,
    // Chrome and Safari switch tabs on ⌘1–⌘9 and never let a page have it.
    [KeyCombo(LogicalKeyboardKey.digit2, primary: true, nativeOnly: true)],
  );
  static const section3 = ShortcutDef(
    'section3',
    ShortcutGroup.navigation,
    // Chrome and Safari switch tabs on ⌘1–⌘9 and never let a page have it.
    [KeyCombo(LogicalKeyboardKey.digit3, primary: true, nativeOnly: true)],
  );
  static const section4 = ShortcutDef(
    'section4',
    ShortcutGroup.navigation,
    // Chrome and Safari switch tabs on ⌘1–⌘9 and never let a page have it.
    [KeyCombo(LogicalKeyboardKey.digit4, primary: true, nativeOnly: true)],
  );
  static const nextChat = ShortcutDef(
    'nextChat',
    ShortcutGroup.navigation,
    [
      KeyCombo(LogicalKeyboardKey.arrowDown, primary: true, alt: true),
      KeyCombo(LogicalKeyboardKey.tab, control: true, nativeOnly: true),
    ],
  );
  static const previousChat = ShortcutDef(
    'previousChat',
    ShortcutGroup.navigation,
    [
      KeyCombo(LogicalKeyboardKey.arrowUp, primary: true, alt: true),
      KeyCombo(LogicalKeyboardKey.tab, control: true, shift: true, nativeOnly: true),
    ],
  );
  static const nextUnread = ShortcutDef(
    'nextUnread',
    ShortcutGroup.navigation,
    [KeyCombo(LogicalKeyboardKey.arrowDown, primary: true, alt: true, shift: true)],
  );
  static const closeChat = ShortcutDef(
    'closeChat',
    ShortcutGroup.navigation,
    [KeyCombo(LogicalKeyboardKey.keyW, primary: true)],
    nativeOnly: true,
  );

  // ── In a chat ──
  static const roomInfo = ShortcutDef(
    'roomInfo',
    ShortcutGroup.chat,
    [KeyCombo(LogicalKeyboardKey.keyI, primary: true, shift: true)],
  );
  static const searchInChat = ShortcutDef(
    'searchInChat',
    ShortcutGroup.chat,
    // Same chord as [search]: inside a chat the chat's own binding is the
    // newer one and wins, which is what ⌘F means everywhere else too.
    [KeyCombo(LogicalKeyboardKey.keyF, primary: true)],
  );
  static const jumpToLatest = ShortcutDef(
    'jumpToLatest',
    ShortcutGroup.chat,
    [KeyCombo(LogicalKeyboardKey.keyJ, primary: true)],
  );
  static const attach = ShortcutDef(
    'attach',
    ShortcutGroup.chat,
    [KeyCombo(LogicalKeyboardKey.keyO, primary: true)],
  );
  static const voiceCall = ShortcutDef(
    'voiceCall',
    ShortcutGroup.chat,
    [KeyCombo(LogicalKeyboardKey.keyA, primary: true, alt: true)],
  );
  static const videoCall = ShortcutDef(
    'videoCall',
    ShortcutGroup.chat,
    [KeyCombo(LogicalKeyboardKey.keyV, primary: true, alt: true)],
  );

  // ── Composer (all handled by the composer itself) ──
  static const send = ShortcutDef(
    'send',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.enter)],
    ambient: true,
  );
  static const newline = ShortcutDef(
    'newline',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.enter, shift: true)],
    ambient: true,
  );
  static const editLast = ShortcutDef(
    'editLast',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.arrowUp)],
    ambient: true,
  );
  static const bold = ShortcutDef(
    'bold',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.keyB, primary: true)],
    ambient: true,
  );
  static const italic = ShortcutDef(
    'italic',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.keyI, primary: true)],
    ambient: true,
  );
  static const underline = ShortcutDef(
    'underline',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.keyU, primary: true)],
    ambient: true,
  );
  static const pasteMedia = ShortcutDef(
    'pasteMedia',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.keyV, primary: true)],
    ambient: true,
  );
  static const emoji = ShortcutDef(
    'emoji',
    ShortcutGroup.composer,
    [KeyCombo(LogicalKeyboardKey.keyE, primary: true)],
  );

  // ── Photo and video viewer ──
  static const viewerPrevious = ShortcutDef(
    'viewerPrevious',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.arrowLeft)],
    ambient: true,
  );
  static const viewerNext = ShortcutDef(
    'viewerNext',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.arrowRight)],
    ambient: true,
  );
  static const zoomIn = ShortcutDef(
    'zoomIn',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.equal, primary: true)],
  );
  static const zoomOut = ShortcutDef(
    'zoomOut',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.minus, primary: true)],
  );
  static const zoomFit = ShortcutDef(
    'zoomFit',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.digit0, primary: true)],
  );
  static const playPause = ShortcutDef(
    'playPause',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.space)],
  );
  static const copyMedia = ShortcutDef(
    'copyMedia',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.keyC, primary: true)],
  );
  static const saveMedia = ShortcutDef(
    'saveMedia',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.keyS, primary: true)],
  );
  // The standalone video player's own: there is no set to step through
  // there, so ← → scrub instead. In the gallery they still page.
  static const seekBackward = ShortcutDef(
    'seekBackward',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.arrowLeft)],
  );
  static const seekForward = ShortcutDef(
    'seekForward',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.arrowRight)],
  );
  static const muteVideo = ShortcutDef(
    'muteVideo',
    ShortcutGroup.viewer,
    [KeyCombo(LogicalKeyboardKey.keyM)],
  );

  // ── Calls ──
  static const toggleMute = ShortcutDef(
    'toggleMute',
    ShortcutGroup.call,
    [KeyCombo(LogicalKeyboardKey.keyM, primary: true, shift: true)],
  );
  static const toggleCamera = ShortcutDef(
    'toggleCamera',
    ShortcutGroup.call,
    [KeyCombo(LogicalKeyboardKey.keyE, primary: true, shift: true)],
  );
  static const hangUp = ShortcutDef(
    'hangUp',
    ShortcutGroup.call,
    [KeyCombo(LogicalKeyboardKey.keyH, primary: true, shift: true)],
  );

  static const List<ShortcutDef> all = [
    commandPalette,
    showShortcuts,
    search,
    newChat,
    settings,
    back,
    section1,
    section2,
    section3,
    section4,
    nextChat,
    previousChat,
    nextUnread,
    closeChat,
    roomInfo,
    searchInChat,
    jumpToLatest,
    attach,
    voiceCall,
    videoCall,
    send,
    newline,
    editLast,
    bold,
    italic,
    underline,
    pasteMedia,
    emoji,
    viewerPrevious,
    viewerNext,
    zoomIn,
    zoomOut,
    zoomFit,
    playPause,
    copyMedia,
    saveMedia,
    seekBackward,
    seekForward,
    muteVideo,
    toggleMute,
    toggleCamera,
    hangUp,
  ];

  static String groupLabel(AppLocalizations l10n, ShortcutGroup g) =>
      switch (g) {
        ShortcutGroup.general => l10n.kbdGroupGeneral,
        ShortcutGroup.navigation => l10n.kbdGroupNavigation,
        ShortcutGroup.chat => l10n.kbdGroupChat,
        ShortcutGroup.composer => l10n.kbdGroupComposer,
        ShortcutGroup.viewer => l10n.kbdGroupViewer,
        ShortcutGroup.call => l10n.kbdGroupCall,
      };

  /// [sectionLabels] names the four sections in their on-screen order, so
  /// "⌘2" reads "Feed" rather than "Section 2". Sections a profile hides are
  /// simply missing and their shortcut is never bound.
  static String label(
    AppLocalizations l10n,
    ShortcutDef d, {
    List<String> sectionLabels = const [],
  }) {
    String section(int i) =>
        i < sectionLabels.length ? l10n.kbdGoTo(sectionLabels[i]) : '';
    return switch (d.id) {
      'commandPalette' => l10n.kbdCommandPalette,
      'showShortcuts' => l10n.kbdShowShortcuts,
      'search' => l10n.kbdSearch,
      'newChat' => l10n.kbdNewChat,
      'settings' => l10n.kbdSettings,
      'back' => l10n.kbdBack,
      'section1' => section(0),
      'section2' => section(1),
      'section3' => section(2),
      'section4' => section(3),
      'nextChat' => l10n.kbdNextChat,
      'previousChat' => l10n.kbdPreviousChat,
      'nextUnread' => l10n.kbdNextUnread,
      'closeChat' => l10n.kbdCloseChat,
      'roomInfo' => l10n.kbdRoomInfo,
      'searchInChat' => l10n.kbdSearchInChat,
      'jumpToLatest' => l10n.kbdJumpToLatest,
      'attach' => l10n.kbdAttach,
      'voiceCall' => l10n.kbdVoiceCall,
      'videoCall' => l10n.kbdVideoCall,
      'send' => l10n.kbdSend,
      'newline' => l10n.kbdNewline,
      'editLast' => l10n.kbdEditLast,
      'bold' => l10n.kbdBold,
      'italic' => l10n.kbdItalic,
      'underline' => l10n.kbdUnderline,
      'pasteMedia' => l10n.kbdPasteMedia,
      'emoji' => l10n.kbdEmoji,
      'viewerPrevious' => l10n.kbdViewerPrevious,
      'viewerNext' => l10n.kbdViewerNext,
      'zoomIn' => l10n.kbdZoomIn,
      'zoomOut' => l10n.kbdZoomOut,
      'zoomFit' => l10n.kbdZoomFit,
      'playPause' => l10n.kbdPlayPause,
      'copyMedia' => l10n.kbdCopyMedia,
      'saveMedia' => l10n.kbdSaveMedia,
      'seekBackward' => l10n.kbdSeekBackward,
      'seekForward' => l10n.kbdSeekForward,
      'muteVideo' => l10n.kbdMuteVideo,
      'toggleMute' => l10n.kbdToggleMute,
      'toggleCamera' => l10n.kbdToggleCamera,
      'hangUp' => l10n.kbdHangUp,
      _ => d.id,
    };
  }
}

/// Who currently answers which shortcut.
///
/// Bindings stack: the most recently registered ACTIVE binding for a chord
/// wins, so a chat opened over the shell takes ⌘F for "search in chat" while
/// it is on screen and hands it back when it closes. "Active" is decided by
/// the binding's owner (see [ShortcutBindings]): its route is on top and its
/// subtree is not an offstage tab.
class AppShortcutRegistry extends ChangeNotifier {
  AppShortcutRegistry._();
  static final AppShortcutRegistry instance = AppShortcutRegistry._();

  final List<_Binding> _bindings = [];

  Object bind(ShortcutDef def, VoidCallback run, bool Function() isActive) {
    final b = _Binding(def, run, isActive);
    _bindings.add(b);
    _changed();
    return b;
  }

  void unbind(Object token) {
    if (_bindings.remove(token)) _changed();
  }

  // Bindings come and go as routes mount, often several in one frame; the
  // lists only need to hear about it once, and never mid-build.
  bool _pending = false;
  void _changed() {
    if (_pending) return;
    _pending = true;
    scheduleMicrotask(() {
      _pending = false;
      notifyListeners();
    });
  }

  _Binding? _top(bool Function(_Binding) where) {
    for (var i = _bindings.length - 1; i >= 0; i--) {
      final b = _bindings[i];
      if (where(b) && b.isActive()) return b;
    }
    return null;
  }

  /// The handler [event] would run, or null. Bare-key shortcuts (Space, M)
  /// never fire while a text field has focus: there they are typing.
  VoidCallback? match(KeyEvent event, {required bool typing}) {
    final b = _top(
      (b) =>
          b.def.offeredHere &&
          !(typing && b.def.chords.every((c) => c.typesText)) &&
          b.def.accepts(event),
    );
    return b?.run;
  }

  /// Whether something on screen answers [def] right now.
  bool isBound(ShortcutDef def) => _top((b) => b.def == def) != null;

  /// Runs [def] as if its keys were pressed. False if nothing answers it.
  bool invoke(ShortcutDef def) {
    final b = _top((b) => b.def == def);
    b?.run();
    return b != null;
  }

  /// What the peek and the panel list: everything bound right now, plus the
  /// ambient keys of the groups that are live (a composer's Enter is worth
  /// listing only while a chat is open). Catalog order.
  ///
  /// An ambient key is dropped when something bound right now answers the
  /// same chord: in the video player ← seeks back, and listing "← Previous"
  /// beside it would describe a key that no longer does that.
  List<ShortcutDef> available({required Set<ShortcutGroup> ambientGroups}) {
    final bound = [
      for (final d in AppShortcuts.all)
        if (d.offeredHere && !d.ambient && isBound(d)) d,
    ];
    final taken = {
      for (final d in bound)
        for (final c in d.chords) c.caps().join(' '),
    };
    return [
      for (final d in AppShortcuts.all)
        if (d.offeredHere &&
            (d.ambient
                ? ambientGroups.contains(d.group) &&
                    !d.chords.any((c) => taken.contains(c.caps().join(' ')))
                : bound.contains(d)))
          d,
    ];
  }

  /// Groups with at least one live binding: the ambient keys of a group are
  /// shown only alongside them. General always counts (Esc is always there).
  Set<ShortcutGroup> liveGroups() => {
        ShortcutGroup.general,
        for (final b in _bindings)
          if (b.isActive()) b.def.group,
      };

  @visibleForTesting
  void reset() => _bindings.clear();
}

class _Binding {
  _Binding(this.def, this.run, this.isActive);
  final ShortcutDef def;
  final VoidCallback run;
  final bool Function() isActive;
}

/// Attaches handlers to catalog shortcuts for as long as this widget is
/// mounted, its route is the top one, and it is not inside an offstage tab.
///
/// The map may be rebuilt freely: callbacks are read from the latest widget at
/// the moment a key fires, and only a change in WHICH shortcuts are bound
/// touches the registry. Bind only what this screen can actually do right now;
/// a missing entry is simply not offered.
class ShortcutBindings extends StatefulWidget {
  const ShortcutBindings({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<ShortcutDef, VoidCallback> bindings;
  final Widget child;

  @override
  State<ShortcutBindings> createState() => _ShortcutBindingsState();
}

class _ShortcutBindingsState extends State<ShortcutBindings> {
  final Map<ShortcutDef, Object> _tokens = {};
  ModalRoute<Object?>? _route;
  ValueListenable<TickerModeData>? _ticker;

  bool _active() {
    if (!mounted) return false;
    if (_ticker != null && !_ticker!.value.enabled) return false;
    final r = _route;
    return r == null || r.isCurrent;
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _ticker = TickerMode.getValuesNotifier(context);
  }

  @override
  void didUpdateWidget(ShortcutBindings old) {
    super.didUpdateWidget(old);
    if (!setEquals(old.bindings.keys.toSet(), widget.bindings.keys.toSet())) {
      _sync();
    }
  }

  void _sync() {
    final want = widget.bindings.keys.toSet();
    final reg = AppShortcutRegistry.instance;
    for (final d in _tokens.keys.toList()) {
      if (!want.contains(d)) reg.unbind(_tokens.remove(d)!);
    }
    for (final d in want) {
      _tokens[d] ??= reg.bind(d, () => widget.bindings[d]?.call(), _active);
    }
  }

  @override
  void dispose() {
    for (final t in _tokens.values) {
      AppShortcutRegistry.instance.unbind(t);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
