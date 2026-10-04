import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        defaultTargetPlatform,
        kIsWeb,
        listEquals,
        visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_preference.dart';
import '../../theme/theme_scope.dart';
import 'destinations.dart';

/// The bridge to `ios/Runner/NativeChrome.swift`.
abstract final class NativeChrome {
  static const channel = MethodChannel('monkeyhub/native_chrome');

  static bool _supported = false;

  /// True on an iPhone or iPad running iOS 26 or later — where the OS has
  /// Liquid Glass to give. Resolved once by [init]; false until then and
  /// everywhere else.
  static bool get supported => _supported;

  /// Lets a test or a design preview stand in for an iOS 26 phone.
  @visibleForTesting
  static set debugSupported(bool v) => _supported = v;

  /// Whether the shell should hand its bottom bar to iOS right now.
  static bool get active =>
      _supported && SettingsStore.instance.glassEngine == GlassEngine.native;

  /// How many overlays currently need the native bar out of the way.
  ///
  /// A pushed route or a sheet hides the bar on its own (the shell stops being
  /// the current route), but an [OverlayEntry] — the long-press row menu, for
  /// one — sits above the shell without changing that, and a native view is
  /// always drawn over every Flutter pixel. Anything that floats over the
  /// shell calls [hold] while it is up.
  static final ValueNotifier<int> holds = ValueNotifier(0);

  /// Hides the native bar until the returned callback is called. The callback
  /// is safe to call more than once; only the first call counts.
  static VoidCallback hold() {
    holds.value++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      holds.value--;
    };
  }

  /// Asks the native side once, at startup. Cheap, and never throws: a
  /// missing handler (a build without the Swift file) is simply "no".
  /// The bridge belongs to the UI scene, while the engine can start headless
  /// or outlive that scene. An unanswered probe must not block `runApp`.
  static Future<void> init() async {
    _supported = false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      _supported =
          await channel
              .invokeMethod<bool>('isSupported')
              .timeout(const Duration(seconds: 2)) ??
          false;
    } catch (_) {
      _supported = false;
    }
  }
}

/// SF Symbols per destination, outline at rest and filled when selected — the
/// convention every system tab bar follows.
({String symbol, String selected}) _symbolFor(HomeSection s) => switch (s) {
      HomeSection.chat => (
        symbol: 'bubble.left.and.bubble.right',
        selected: 'bubble.left.and.bubble.right.fill',
      ),
      HomeSection.feed => (symbol: 'sparkles', selected: 'sparkles'),
      HomeSection.discover => (symbol: 'safari', selected: 'safari.fill'),
      HomeSection.settings => (symbol: 'gearshape', selected: 'gearshape.fill'),
    };

/// Stands in for [PillBottomNav] when iOS draws the bar.
///
/// Paints nothing: the bar is a real `UITabBar` above the Flutter view. This
/// widget only keeps it in step — selection, badges, the theme's tint and
/// light/dark — and hides it whenever the shell is not the top route, because
/// a native view cannot sit under a Flutter-drawn sheet or pushed screen; it
/// would float over them.
class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.active,
    required this.onSelect,
    required this.badges,
  });

  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;
  final Map<HomeSection, int> badges;

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  /// Which instance this is, sent with every call. The shell is rebuilt on a
  /// theme change, and the new instance configures the bar before the old one
  /// is disposed; the native side only listens to the latest owner, so the
  /// old instance's dispose can no longer remove the new bar.
  static int _nextOwner = 0;
  final int _owner = _nextOwner++;

  Future<void> _call(String method, [Map<String, Object> args = const {}]) =>
      NativeChrome.channel.invokeMethod(method, {...args, 'owner': _owner});

  /// What was last sent, so a rebuild that changes nothing sends nothing —
  /// the shell rebuilds on every repository notification.
  Map<String, Object>? _lastUpdate;
  bool? _lastVisible;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    NativeChrome.holds.addListener(_sync);
    _current = this;
    NativeChrome.channel.setMethodCallHandler(_onNativeCall);
  }

  /// The instance taps are routed to. The channel has one handler slot, and
  /// a theme change builds the new shell before the old one is disposed —
  /// the old dispose used to clear the slot the new instance had just
  /// filled, so every tap after a theme switch went nowhere until a restart.
  static _NativeTabBarState? _current;

  static Future<Object?> _onNativeCall(MethodCall call) async {
    final state = _current;
    if (call.method == 'select' && state != null && state.mounted) {
      final i = call.arguments as int;
      if (i >= 0 && i < navOrder.length) state.widget.onSelect(navOrder[i]);
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    NativeChrome.holds.removeListener(_sync);
    // Only the current instance may tear down: a disposed predecessor would
    // otherwise unhook (and the native side ignores its stale owner) the bar
    // its successor already owns.
    if (identical(_current, this)) {
      _current = null;
      NativeChrome.channel.setMethodCallHandler(null);
    }
    _call('dispose');
    super.dispose();
  }

  void _sync() {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (locale != _lastLocale) {
      // Labels are the only thing configure carries, so only a language
      // change rebuilds the bar. Selection and badges follow in the update.
      _lastLocale = locale;
      _lastUpdate = null;
      _call('configure', {
        'items': [
          for (final d in navDestinations(l10n))
            {
              'label': d.label,
              'symbol': _symbolFor(d.section).symbol,
              'selectedSymbol': _symbolFor(d.section).selected,
            },
        ],
      });
    }

    final theme = ThemeScope.of(context);
    final update = <String, Object>{
      'selected': navIndexOf(widget.active),
      'badges': [for (final s in navOrder) widget.badges[s] ?? 0],
      'tint': theme.accent.toARGB32(),
      'dark': !theme.isLight,
    };
    if (!_sameUpdate(update, _lastUpdate)) {
      _lastUpdate = update;
      _call('update', update);
    }

    final visible = (ModalRoute.of(context)?.isCurrent ?? true) &&
        NativeChrome.holds.value == 0;
    if (visible != _lastVisible) {
      _lastVisible = visible;
      _call('setVisible', {'visible': visible});
    }
  }

  static bool _sameUpdate(Map<String, Object> a, Map<String, Object>? b) {
    if (b == null) return false;
    return a['selected'] == b['selected'] &&
        a['tint'] == b['tint'] &&
        a['dark'] == b['dark'] &&
        listEquals(a['badges'] as List, b['badges'] as List);
  }

  /// Fills its slot rather than shrinking: whatever holds this was sized
  /// around the full-size pill it replaces, and a 0×0 stand-in collapsed the
  /// shell's Stack to nothing — a black screen under a working tab bar. A
  /// childless box paints nothing and is never hit, so touches pass through.
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

