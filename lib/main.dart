import 'package:flutter/foundation.dart'
    show kIsWeb, LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show BrowserContextMenu, SystemChrome, SystemUiMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'backend/server_directory.dart';
import 'backend/server_store.dart';
import 'calls/native_call_handler.dart';
import 'companions/brain_manager.dart';
import 'companions/device_capability.dart';
import 'data/settings_store.dart';
import 'diagnostics/diag_boot.dart';
import 'media/storage/data_usage_store.dart';
import 'media/storage/media_ledger.dart';
import 'media/storage/network_kind.dart';
import 'media/video_duration.dart';
import 'media/file_url_cache.dart';
import 'media/media_aspect_cache.dart';
import 'push/push_manager.dart';
import 'screens/navigation/native_tab_bar.dart' show NativeChrome;

/// Root navigator key — exposed so non-widget code (push handlers, native
/// callbacks) can push routes without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // First real statement, on purpose: this replaces the global `debugPrint`,
  // and anything printed before it would be missed. It also installs the
  // framework error hooks and starts capture, so a bug that fires during
  // startup is recorded rather than missed.
  //
  // Everything it records is redacted at capture time and never leaves the
  // device on its own; see Redactor and DiagExport.
  await DiagBoot.install();

  // The official sticker packs are Google's Noto Animated Emoji, licensed
  // CC BY 4.0 — whose one condition is credit. The packs' info lines carry it
  // in the picker; this carries it on the licences page with everything else
  // the app ships.
  LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(
        ['Noto Emoji Animation (sticker packs)'],
        'Noto Emoji Animation, animated emoji by Google\n'
        'https://googlefonts.github.io/noto-emoji-animation/\n\n'
        'Licensed under the Creative Commons Attribution 4.0 International '
        'License (CC BY 4.0): https://creativecommons.org/licenses/by/4.0/',
      )));
  LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(
        ['Fluent Emoji (sticker packs)'],
        'Fluent Emoji, animated 3D emoji by Microsoft\n'
        'https://github.com/microsoft/fluentui-emoji-animated\n\n'
        'MIT License\n\nCopyright (c) Microsoft Corporation.\n\n'
        'Permission is hereby granted, free of charge, to any person obtaining '
        'a copy of this software and associated documentation files (the '
        '"Software"), to deal in the Software without restriction, including '
        'without limitation the rights to use, copy, modify, merge, publish, '
        'distribute, sublicense, and/or sell copies of the Software, and to '
        'permit persons to whom the Software is furnished to do so, subject to '
        'the following conditions:\n\n'
        'The above copyright notice and this permission notice shall be '
        'included in all copies or substantial portions of the Software.\n\n'
        'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, '
        'EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
        'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
        'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE '
        'LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION '
        'OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION '
        'WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
      )));

  // Declare edge-to-edge ourselves. NOT cosmetic — this is what stops the
  // window's insets from oscillating on Android 15+.
  //
  // targetSdk went 34 → 36 to clear Play's minimum. At 35+ Android enforces
  // edge-to-edge and ignores the opt-out entirely (at 36 the opt-out flag no
  // longer exists), while the app still said nothing about system UI mode and
  // the launch themes still declared the legacy
  // `windowDrawsSystemBarBackgrounds=false`. Platform and framework therefore
  // disagreed about who owned the bar area, and the window re-derived its
  // insets on every layout pass. `MediaQuery.padding` flapped with them, so
  // all 96 SafeArea/viewPadding readers in the app re-laid out each frame:
  // the whole UI strobed, the bottom pill moved out from under a finger
  // between pointer-down and pointer-up (taps on the nav "did nothing"), and
  // the IME closed the frame after it opened. One declared owner settles it.
  //
  // Call screens still swap to immersiveSticky and restore edgeToEdge on the
  // way out (call_screen.dart, group_call_screen.dart) — that restore now
  // returns to this same baseline instead of silently changing the app's mode.
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Never fetch a typeface over the network. Every family the themes use is
  // bundled under assets/google_fonts (see pubspec.yaml), so this costs nothing
  // visually — it just turns "prefer the bundled file" into a guarantee.
  //
  // The point is privacy, not startup time: left enabled, google_fonts contacts
  // Google's font CDN on launch and hands them every user's IP address. That is
  // a third-party data flow this app otherwise does not have — it ships no
  // analytics, no ads and no attribution SDK — and it would be flatly
  // disallowed under the Kids-category rules.
  //
  // If a font ever renders as a plain system face, the cause is a MISSING or
  // MISNAMED asset, not this line. google_fonts wants exactly
  // `<Family>-<Variant>.ttf`; fix the asset rather than re-enabling fetching.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Pre-load persisted settings, env, and disk caches in parallel so the first
  // frame renders immediately under the user's saved theme and avatar URLs,
  // costing a single platform-channel hop time instead of 4 sequential ones.
  await Future.wait([
    dotenv.load(fileName: 'env.local', isOptional: true),
    SettingsStore.instance.load(),
    FileUrlCache.instance.load(),
    MediaAspectCache.instance.load(),
    // The storage ledger and data usage counters: both small JSON reads, and
    // both written to by the first frame's message bubbles and downloads.
    MediaLedger.instance.load(),
    DataUsageStore.instance.load(),
    // Video lengths read from file headers, so a tile shows its time on
    // the first frame.
    VideoDuration.instance.load(),
    // One hop, in parallel with the rest, so the shell's first frame already
    // knows whether iOS is drawing the bottom bar.
    NativeChrome.init(),
  ]);

  // Strictly AFTER dotenv, and strictly before runApp. After, because a store
  // with no saved override falls through to `Env.convexUrl` and would read an
  // unloaded dotenv as "no server configured". Before, because the Convex
  // client is built from this during the first bootstrap — an override that
  // arrived one frame late would open a socket to the wrong deployment and
  // need tearing down again.
  //
  // Its own await rather than a fifth entry above for exactly that ordering;
  // one extra secure-storage read on the boot path is the whole cost.
  await ServerStore.instance.load();
  // The last directive this device was handed, which is what a failed or
  // impossible launch check falls back to. Local read only — the network half
  // runs in `_bootstrap`, where it can be given a timeout that does not sit in
  // front of `runApp`.
  await ServerDirectory.instance.load();

  PaintingBinding.instance.imageCache.maximumSize = 1500;

  // Wi-Fi or cellular, for auto-download, data usage and the calls data saver.
  NetworkKindMonitor.instance.start();

  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  } else {
    // Initialize push and native call handler asynchronously without delaying runApp.
    PushManager.instance
        .initialize()
        .then((_) {
          NativeCallHandler.instance.start();
        })
        .catchError((Object e) {
          debugPrint('PushManager.initialize: $e');
        });

    // How much machine there is, before anything asks which brain Sebastian
    // runs — his shelf is ordered best-first and the device takes the best row
    // it can carry. Not awaited for the same reason the refresh below is not:
    // an unanswered query resolves DOWNWARD to the brain every device can run
    // (see `DeviceCapability`), so the worst a slow probe costs is a first
    // translation on the smaller model.
    DeviceCapability.instance.prime();

    // Asks the disk which companion brains are installed. Not awaited, and
    // deliberately not gated on whether any companion is switched on: the
    // whole subsystem answers "is Sebastian installed" from this table, and
    // until it has been filled in once the answer is a confident no.
    //
    // The visible consequence of skipping it is small and bad: the first
    // TRANSLATE tap of a session would open the install sheet for a brain
    // already on the device, then notice and close itself.
    //
    // It costs one plugin call and touches no model weights — see
    // `BrainManager.refresh`.
    BrainManager.instance.refresh().catchError((Object e) {
      debugPrint('BrainManager.refresh: $e');
    });
  }

  runApp(const MonkeyHubApp());
}
