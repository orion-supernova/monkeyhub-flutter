import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/services/link_preview_service.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/link_preview_card.dart';
import 'package:monkeyhub/widgets/timeline_list_view.dart';

void main() {
  testWidgets('failed link keeps its resolved height when scrolled back in', (
    tester,
  ) async {
    const url = 'unsupported://failed-preview-scroll';
    // Invalid schemes exercise the same cached-null path as an unreachable
    // server, without making a network request in the test.
    await LinkPreviewService.instance.fetch(url);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TimelineListView(
            controller: controller,
            rowKeys: [for (var i = 0; i < 50; i++) ValueKey(i)],
            itemBuilder: (context, i) => i == 3
                ? LinkPreviewCard(
                    url: url,
                    isMine: true,
                    insideBubble: false,
                    onTap: (_) {},
                  )
                : SizedBox(height: 100, child: Text('row$i')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 250));
    final card = find.byType(LinkPreviewCard);
    final height = tester.getSize(card).height;
    expect(height, lessThan(100));
    controller.jumpTo(3000);
    await tester.pump();
    expect(card, findsNothing);
    controller.jumpTo(200);
    await tester.pump();
    expect(tester.getSize(card).height, height);
    final offset = controller.offset;
    final rowPosition = tester.getTopLeft(find.text('row5'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getSize(card).height, height);
    expect(tester.getTopLeft(find.text('row5')), rowPosition);
    expect(controller.offset, offset);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(card).height, height);
    expect(tester.getTopLeft(find.text('row5')), rowPosition);
    expect(controller.offset, offset);
  });
}
