import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

Widget _host(Widget child) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// The dot is the only circle-decorated Container the avatar draws without
/// an image; counting them is enough to tell whether it is there.
Finder _dot() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle &&
      (w.decoration as BoxDecoration).border != null,
);

void main() {
  final online = ChatUser(
    id: 'bea',
    username: 'bea',
    name: 'Bea',
    status: 'online',
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await SettingsStore.instance.setShowPresenceDots(true);
  });

  testWidgets('the Settings toggle reaches a const avatar without a rebuild',
      (tester) async {
    await tester.pumpWidget(_host(UserAvatar(user: online)));
    expect(_dot(), findsOneWidget);

    await SettingsStore.instance.setShowPresenceDots(false);
    await tester.pump();
    expect(_dot(), findsNothing);

    await SettingsStore.instance.setShowPresenceDots(true);
    await tester.pump();
    expect(_dot(), findsOneWidget);
  });

  testWidgets('showStatus: false still wins with the setting on',
      (tester) async {
    await tester.pumpWidget(
      _host(UserAvatar(user: online, showStatus: false)),
    );
    expect(_dot(), findsNothing);
  });
}
