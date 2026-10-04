import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/count_badge.dart';

void main() {
  for (final theme in ThemeController.all) {
    testWidgets('${theme.id}: readable ordinary, muted and mention counts', (
      tester,
    ) async {
      for (final badge in const [
        RoomUnreadBadge(count: 1),
        RoomUnreadBadge(count: 12, quiet: true),
        RoomUnreadBadge(count: 108, mention: true),
      ]) {
        await tester.pumpWidget(
          ThemeScope(
            controller: ThemeController(theme),
            child: MaterialApp(home: Center(child: badge)),
          ),
        );
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(RoomUnreadBadge),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = box.decoration! as BoxDecoration;
        final text = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(RoomUnreadBadge),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(
          debugFormattingContrast(text.style!.color!, decoration.color!),
          greaterThanOrEqualTo(4.5),
        );
        final size = tester.getSize(find.byType(RoomUnreadBadge));
        expect(
          size.width,
          greaterThan(size.height),
          reason: 'even 1 is a capsule',
        );
        expect(
          decoration.boxShadow,
          isNull,
          reason: 'no glowing attention dot',
        );
      }
    });
  }

  testWidgets(
    'unread without count is distinct from read, without a fake zero',
    (tester) async {
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(ThemeController.all.first),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Column(
              children: [RoomUnreadBadge(unread: true), RoomUnreadBadge()],
            ),
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(
        tester.getSize(find.byType(RoomUnreadBadge).first),
        const Size(16, 8),
      );
      expect(tester.getSize(find.byType(RoomUnreadBadge).last), Size.zero);
    },
  );
}
