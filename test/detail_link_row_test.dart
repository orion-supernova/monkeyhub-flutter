import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/detail_link_row.dart';

/// The chevron on a disclosure row has one job beyond pointing: it marks where
/// the row ends. A stack of them whose arrows stop at different distances from
/// the padding reads as broken alignment even to someone who never works out
/// which row is the odd one, and that is exactly what shipped — the label and
/// the value were two flex children splitting the width 1:1, so whatever the
/// label did not use became dead space parked behind the chevron. FAMILY / add
/// a child left the arrow 54pt short on a 360pt row.
///
/// These tests pin the arrow to the padding regardless of what the row carries.
void main() {
  const rowWidth = 360.0;
  const hPad = 16.0;

  /// The 1pt hairline around the card, which insets the padding box on top of
  /// [hPad].
  const border = 1.0;

  /// The row's inner right edge — where the chevron's right side belongs.
  double contentRight(WidgetTester tester) =>
      tester.getRect(find.byType(DetailLinkRow)).right - hPad - border;

  Widget host(Widget child, {double width = rowWidth}) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      );

  Finder chevron() => find.byIcon(Icons.chevron_right);

  testWidgets('a plain row ends with its chevron on the padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DetailLinkRow(
          label: 'SET UP RECOVERY PHRASE',
          icon: Icons.key_outlined,
          onTap: () {},
        ),
      ),
    );
    expect(tester.getRect(chevron()).right, contentRight(tester));
  });

  testWidgets('a row carrying a value ends in the same place', (tester) async {
    // The regression: this is the shape that drifted, and it drifted by an
    // amount that changed with the label, so no two rows agreed.
    await tester.pumpWidget(
      host(
        DetailLinkRow(
          label: 'FAMILY',
          value: 'add a child',
          icon: Icons.family_restroom,
          onTap: () {},
        ),
      ),
    );
    expect(tester.getRect(chevron()).right, contentRight(tester));
  });

  testWidgets('the value keeps exactly the row\'s gap from the chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DetailLinkRow(
          label: 'FAMILY',
          value: 'add a child',
          icon: Icons.family_restroom,
          onTap: () {},
        ),
      ),
    );
    // 8pt is the gap the row puts between trailing content and the chevron.
    expect(
      tester.getRect(find.text('add a child')).right,
      tester.getRect(chevron()).left - 8,
    );
  });

  testWidgets('a badge does not push the chevron off the padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DetailLinkRow(
          label: 'FAMILY',
          value: '2 children',
          badge: 3,
          icon: Icons.family_restroom,
          onTap: () {},
        ),
      ),
    );
    expect(tester.getRect(chevron()).right, contentRight(tester));
  });

  testWidgets('rows of differing length agree on where the arrow lands', (
    tester,
  ) async {
    // The thing the eye actually catches is disagreement between neighbours,
    // so assert on a stack rather than on one row at a time.
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailLinkRow(
              label: 'FAMILY',
              value: 'add a child',
              icon: Icons.family_restroom,
              onTap: () {},
            ),
            DetailLinkRow(
              label: 'LINKED ACCOUNTS',
              value: 'apple · google',
              icon: Icons.link_rounded,
              onTap: () {},
            ),
            DetailLinkRow(
              label: 'BLOCKED USERS',
              icon: Icons.block,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    final rights = tester
        .widgetList(chevron())
        .mapIndexed((i, _) => tester.getRect(chevron().at(i)).right)
        .toSet();
    expect(rights, hasLength(1));
  });

  testWidgets('a label too long for the row still leaves the arrow put', (
    tester,
  ) async {
    // A locale with a much longer word for the same thing must not be able to
    // shove the chevron anywhere, or overflow the row trying.
    await tester.pumpWidget(
      host(
        DetailLinkRow(
          label: 'SICHTBARKEITSEINSTELLUNGEN VERWALTEN',
          value: 'nur freunde und familie',
          icon: Icons.visibility_outlined,
          onTap: () {},
        ),
        width: 300,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getRect(chevron()).right, contentRight(tester));
  });

  testWidgets('the row is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        DetailLinkRow(
          label: 'PRIVACY POLICY',
          icon: Icons.privacy_tip_outlined,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text('PRIVACY POLICY'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

extension _Indexed<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int, E) f) {
    var i = 0;
    return map((e) => f(i++, e));
  }
}
