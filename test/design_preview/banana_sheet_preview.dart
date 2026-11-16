// The banana sheet: phone with a video to watch, phone with enough bananas,
// desktop (no videos). flutter test test/design_preview/banana_sheet_preview.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/ads/banana_sheet.dart';
import 'package:monkeyhub/ads/banana_glyph.dart';
import 'package:monkeyhub/ads/banana_pill.dart';
import 'package:monkeyhub/ads/banana_wallet.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/tab_root_bar.dart';

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

  testWidgets('wallet, phone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    BananaWallet.instance
      ..balance = 4
      ..adsLeft = 12
      ..nextBonusIn = 2
      ..freeReady = true;
    await snap(
      tester,
      previewApp(BasicTheme.midnight(), _Opener((c) => showBananaWallet(c, userId: 'u'))),
      'banana_wallet.png',
      act: () async {},
    );
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('glyph and pill', (tester) async {
    BananaWallet.instance
      ..balance = 7
      ..freeReady = false;
    await snap(
      tester,
      previewApp(
        BasicTheme.daylight(),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BananaGlyph(size: 22),
                  SizedBox(width: 16),
                  BananaGlyph(size: 48),
                  SizedBox(width: 16),
                  BananaGlyph(size: 120),
                ],
              ),
              SizedBox(height: 30),
              BananaPill(userId: 'u'),
            ],
          ),
        ),
      ),
      'banana_glyph.png',
      act: () async {},
    );
  });

  for (final (name, size) in [('phone', kIphone16Pro), ('desktop', const Size(1280, 800))]) {
    testWidgets('games tab bar, $name', (tester) async {
      BananaWallet.instance
        ..balance = 12
        ..freeReady = true;
      final scroll = ScrollController();
      await snap(
        tester,
        previewApp(
          BasicTheme.midnight(),
          Stack(
            children: [
              ListView(
                controller: scroll,
                padding: const EdgeInsets.only(top: 120, left: 20, right: 20),
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1D22),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                ],
              ),
              TabRootBar(
                title: 'Games',
                scroll: scroll,
                trailing: const BananaPill(userId: 'u'),
              ),
            ],
          ),
        ),
        'banana_tabbar_$name.png',
        size: size,
        dpr: name == 'desktop' ? 2 : 3,
        topInset: name == 'desktop' ? 0 : kIphoneTopInset,
        bottomInset: name == 'desktop' ? 0 : kIphoneBottomInset,
        act: () async {},
      );
    });
  }
}
