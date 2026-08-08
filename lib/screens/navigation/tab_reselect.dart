import 'package:flutter/widgets.dart';

import '../../data/settings_store.dart';
import '../../theme/motion.dart';

/// How long the trip back to the top takes.
///
/// Long enough to read as travel rather than a cut — the point of animating at
/// all is that the user sees where the list went, so a re-tap that meant to
/// reveal the top doesn't leave them wondering whether the list reloaded. Short
/// enough that a list a hundred rooms deep doesn't hold them there.
const Duration _kRewind = Duration(milliseconds: 320);

/// Broadcasts a tap on the nav destination the user is already looking at.
///
/// All three nav chromes — the pill, the radial menu and the desktop side rail
/// — report every tap to the shell, including one on the active destination
/// (see `PillBottomNav._commit`), and [SettingsStore.setSection] drops a
/// same-section change on the floor. That left the re-tap meaning nothing at
/// all; this is where the shell says it happened, and whoever is filling that
/// section decides what it means.
///
/// A [ChangeNotifier] rather than a stream so it matches every other app-wide
/// signal here ([SettingsStore], `FeedStore`, `UiSelectionStore`) and needs no
/// subscription to cancel. It notifies on every [fire], even twice in a row for
/// the same section, because two taps are two events.
class TabReselect extends ChangeNotifier {
  TabReselect._();

  static final TabReselect instance = TabReselect._();

  HomeSection? _section;

  /// The section whose destination was tapped while it was already active.
  HomeSection? get section => _section;

  void fire(HomeSection s) {
    _section = s;
    notifyListeners();
  }
}

/// Gives a section screen the standard "tap the tab you're on to go back to the
/// top" behaviour.
///
/// The screen keeps owning its [ScrollController] — Feed's is also driving its
/// depth field, so a mixin that created one would be taking that job off it —
/// and only says which section it fills and which controller to rewind.
///
/// Nothing happens when the list is already at the top, so a stray second tap
/// on a screen nobody has scrolled costs nothing.
mixin TabReselectScroll<T extends StatefulWidget> on State<T> {
  /// The shell section this screen is the whole of.
  HomeSection get reselectSection;

  /// The scroll view a re-tap sends back to the top.
  ScrollController get reselectScroll;

  @override
  void initState() {
    super.initState();
    TabReselect.instance.addListener(_onReselect);
  }

  @override
  void dispose() {
    TabReselect.instance.removeListener(_onReselect);
    super.dispose();
  }

  void _onReselect() {
    if (!mounted || TabReselect.instance.section != reselectSection) return;
    // No clients during the frame a section is being built or torn down. A
    // section retired mid-transition still hears this; it is on its way out,
    // and rewinding it would be rewinding something already covered.
    if (!reselectScroll.hasClients) return;
    if (reselectScroll.offset <= 0) return;
    if (MotionScope.of(context).calm) {
      reselectScroll.jumpTo(0);
      return;
    }
    reselectScroll.animateTo(0, duration: _kRewind, curve: Curves.easeOutCubic);
  }
}
