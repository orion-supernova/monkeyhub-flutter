import 'package:flutter/foundation.dart';

/// THE platform seam. Every "which platform am I on" question in the app is
/// asked here, by INTENT, never re-derived at a call site.
///
/// Read `docs/architecture/ui-architecture.html` §3 before adding a getter.
///
/// Three rules this file exists to enforce:
///
/// 1. **Ask for the capability, not the OS.** A widget wants "is there a
///    hover pointer", not "is this macOS or Windows or Linux or a desktop
///    browser". When a new intent appears, add a getter here and document who
///    is in and who is out — including web.
/// 2. **`kIsWeb` is decided once, here.** No `dart:io` `Platform.isX` reads
///    anywhere else in the UI: `Platform` throws on web, and every copy of the
///    "kIsWeb first" dance was one more place to get it wrong.
/// 3. **On web, [defaultTargetPlatform] follows the browser's user agent.**
///    Chrome on macOS reports macOS; Chrome on Android reports android. The
///    `native*` getters exclude web; the UA-following getters include it on
///    purpose and say so.
///
/// Everything is a getter (not a const) so a test can flip it with
/// `debugDefaultTargetPlatformOverride`.
abstract final class Caps {
  // ---------------------------------------------------------------- exact OS
  //
  // The running BINARY. False on web, whatever the browser claims. Use these
  // only for genuinely OS-bound work: a platform channel, a store, a file path.

  static bool get web => kIsWeb;
  static bool get iOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get macOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  static bool get windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool get linux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// A native phone or tablet app: iOS or Android, never a browser.
  static bool get nativeMobile => iOS || android;

  /// A native desktop app: macOS, Windows or Linux, never a browser.
  static bool get nativeDesktop => macOS || windows || linux;

  /// A native Apple app (iOS or macOS): AVFoundation, Keychain, StoreKit,
  /// Apple sign-in, Darwin WebRTC.
  static bool get nativeApple => iOS || macOS;

  // ------------------------------------------------------- input & presence
  //
  // These FOLLOW THE USER AGENT on web, deliberately: a desktop browser is a
  // desktop as far as the person in front of it is concerned.

  /// The OS family the person is looking at (on web: what the browser says).
  /// For look-and-feel only — modifier glyphs, Apple-style labels.
  static bool get appleLook =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// A desktop OS family, native or in a browser.
  static bool get desktopLook =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// A physical keyboard is the primary input, so Enter can mean "submit".
  ///
  /// Follows the user agent on web: Chrome on Android stays out (soft keyboard,
  /// Enter is the only newline), Chrome on macOS is in. Known imperfection:
  /// iPadOS Safari sends a desktop UA and lands here; accepted, iPads are
  /// keyboard-adjacent and the failure is mild.
  ///
  /// Use ONLY to reinterpret a key the soft keyboard also produces. Focus
  /// rings, Tab traversal and Esc ship ungated: inert without a keyboard.
  static bool get physicalKeyboard => desktopLook;

  /// A mouse or trackpad pointer that can hover: hover hints, hover-revealed
  /// actions, always-visible viewer chrome in place of tap-to-toggle.
  ///
  /// Same population as [physicalKeyboard] (a desktop app or a desktop
  /// browser). A phone browser is NOT in: it has no hover, and treating it as
  /// a desktop (the old `isWebOrDesktop` reading) gave it desktop chrome.
  static bool get hover => desktopLook;

  /// Touch is the primary input: a native phone/tablet or a mobile browser.
  static bool get touchFirst => !desktopLook;

  /// Delivery paths a native mobile app gets from the OS (APNs/FCM banners,
  /// CallKit) are missing here, so the app must play its own alert sounds and
  /// use the in-page Notification API: web (mobile web included — a phone
  /// browser still has no native push) and every native desktop.
  static bool get inAppAlerts => kIsWeb || nativeDesktop;

  // --------------------------------------------------------------- features

  /// Calls run through CallKit / ConnectionService with the OS audio session:
  /// a native phone. Desktop and web calls pick devices themselves.
  static bool get mobileCalls => nativeMobile;

  /// The OS can give us its own Liquid Glass (iOS 26+). Probed once at boot
  /// by `NativeChrome.init`; see there.
  static bool get nativeGlass => _nativeGlass;
  static bool _nativeGlass = false;

  /// Set by `NativeChrome.init` (and tests). Not for general use.
  static set nativeGlassProbe(bool v) => _nativeGlass = v;

  /// A local disk the app may cache to. False on web (memory/IndexedDB only).
  static bool get disk => !kIsWeb;
}
