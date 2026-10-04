import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/services/link_preview_service.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/link_preview_card.dart';

import 'preview_kit.dart';

const _rich = 'https://preview.example/weekend';
const _bare = 'unsupported://shared-link';

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    await http.runWithClient(
      () => LinkPreviewService.instance.fetch(_rich),
      () => MockClient((_) async => http.Response('''
        <html><head><title>A weekend by the sea</title>
        <meta property="og:site_name" content="Weekend notes">
        </head></html>
      ''', 200)),
    );
    await LinkPreviewService.instance.fetch(_bare);
  });
  for (final theme in [
    BasicTheme.midnight(),
    BasicTheme.rose(),
    BasicTheme.daylight(),
  ]) {
    testWidgets('${theme.id} link bubbles', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shared links', style: theme.bodyEmph),
                    const SizedBox(height: 18),
                    for (final url in [_rich, _bare]) ...[
                      SizedBox(
                        width: 310,
                        child: LinkPreviewCard(
                          url: url,
                          isMine: true,
                          insideBubble: false,
                          onTap: (_) {},
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        'link_bubbles_${theme.id}.png',
        size: const Size(393, 400),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
