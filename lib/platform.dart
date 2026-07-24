import 'package:flutter/foundation.dart';

/// Platform predicates shared across the app.
///
/// These two look similar and mean different things — read the doc comments
/// before picking one. The distinction is the `kIsWeb` short-circuit.

/// Platforms that need the web/desktop delivery paths: alert sounds, the web
/// Notification API, web push. Mobile is served by OneSignal and needs none of
/// it.
///
/// `kIsWeb` is checked first so `defaultTargetPlatform` reads stay off the
/// mobile path — the convention used everywhere else in this codebase.
///
/// Mobile web IS included, deliberately: a phone browser still has no native
/// push and still needs the in-page banner.
bool get isWebOrDesktop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Platforms where a physical keyboard is the primary input, and Enter can
/// therefore be reinterpreted as "submit".
///
/// Deliberately does NOT short-circuit on `kIsWeb` — that omission is the whole
/// point of having a second predicate. On Flutter web `defaultTargetPlatform`
/// is derived from the browser's user agent, so Chrome on Android reports
/// `android` and correctly stays out (it has a soft keyboard, where Enter is
/// the only way to type a newline), while Chrome on macOS reports `macOS` and
/// correctly opts in. Reading it on web touches no `dart:io`.
///
/// Known imperfection: iPadOS Safari sends a desktop user agent and lands here,
/// so an iPad with no hardware keyboard gets Enter-to-send. Accepted — iPads
/// are keyboard-adjacent and the failure mode is mild.
///
/// Use this ONLY to gate behaviour that reinterprets a key the soft keyboard
/// also produces. Focus rings, Tab traversal and Esc handling ship ungated:
/// they are inert without a keyboard, and gating them would deny a
/// Bluetooth-keyboard tablet user the feature entirely.
bool get isPhysicalKeyboardPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;
