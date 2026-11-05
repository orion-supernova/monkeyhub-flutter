// The weak-link video tier notice over a call's video, both shapes.
//
//   flutter test test/design_preview/quality_notice_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

import 'preview_kit.dart';

Widget _stage(Locale locale) => Builder(builder: (context) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Stand-in for a lamp-lit face on video.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.9,
                colors: [Color(0xFF9A7B5C), Color(0xFF2B2119)],
              ),
            ),
          ),
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Positioned(
              left: 16,
              right: 16,
              bottom: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: CallNoticeChip(
                      label: l10n.callQualityLoweredBanner('1080p'),
                      closeSemanticLabel: l10n.interactionClose,
                      onClose: () {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CallNoticeChip(
                      label: l10n.callQualityOfferBanner('4K'),
                      closeSemanticLabel: l10n.interactionClose,
                      onClose: () {},
                      actionLabel: l10n.callQualityOfferAction('1080p'),
                      onAction: () {},
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });

void main() {
  setUpAll(loadPreviewFonts);
  for (final locale in const [Locale('en'), Locale('tr')]) {
    testWidgets('quality notice ${locale.languageCode}', (tester) async {
      await snap(
        tester,
        previewApp(BasicTheme.midnight(), _stage(locale), locale: locale),
        'quality_notice_${locale.languageCode}.png',
      );
    });
  }
}
