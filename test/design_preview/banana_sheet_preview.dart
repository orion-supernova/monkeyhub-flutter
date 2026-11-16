// The banana sheet: phone with a video to watch, phone with enough bananas,
// desktop (no videos). flutter test test/design_preview/banana_sheet_preview.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/ads/banana_sheet.dart';
import 'package:monkeyhub/ads/banana_wallet.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

import 'preview_kit.dart';

class _Opener extends StatefulWidget {
  const _Opener(this.open);
  final void Function(BuildContext) open;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => BananaWallet.debugOffline = true);

  void open(BuildContext c) => offerBananas(
    c,
    userId: 'u',
    use: BananaUse.guess,
    what: 'One more guess',
  );

  for (final (name, theme) in [
    ('midnight', BasicTheme.midnight()),
    ('daylight', BasicTheme.daylight()),
  ]) {
    testWidgets('empty wallet, phone, $name', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final w = BananaWallet.instance
        ..balance = 0
        ..adsLeft = 13
        ..nextBonusIn = 1
        ..freeReady = true;
      expect(w.canWatch, true);
      await snap(tester, previewApp(theme, _Opener(open)), 'banana_empty_$name.png', act: () async {});
      debugDefaultTargetPlatformOverride = null;
    });
    testWidgets('has bananas, phone, $name', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      BananaWallet.instance
        ..balance = 3
        ..adsLeft = 10
        ..nextBonusIn = 2
        ..freeReady = false;
      await snap(tester, previewApp(theme, _Opener(open)), 'banana_has_$name.png', act: () async {});
      debugDefaultTargetPlatformOverride = null;
    });
  }
  testWidgets('desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    BananaWallet.instance
      ..balance = 0
      ..freeReady = false;
    await snap(tester, previewApp(BasicTheme.midnight(), _Opener(open)), 'banana_desktop.png', act: () async {});
    debugDefaultTargetPlatformOverride = null;
  });
}
