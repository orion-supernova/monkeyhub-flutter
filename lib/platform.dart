import 'ui/foundation/caps.dart';

export 'ui/foundation/caps.dart' show Caps;

/// Legacy names for two [Caps] questions. New code asks [Caps] directly; these
/// stay only until the last call site has moved (see
/// `docs/architecture/ui-architecture.html` §3).

/// The app plays its own alert sounds and uses the in-page Notification API.
/// Means [Caps.inAppAlerts]. It was also misused as "has hover": for hover,
/// ask [Caps.hover], which keeps phone browsers out.
bool get isWebOrDesktop => Caps.inAppAlerts;

/// A physical keyboard is the primary input. Means [Caps.physicalKeyboard].
bool get isPhysicalKeyboardPlatform => Caps.physicalKeyboard;
