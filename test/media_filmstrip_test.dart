import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/media_filmstrip.dart';

/// The thumbnail rail shared by the fullscreen gallery and the photo tray.
///
/// The contract worth pinning is not what it looks like — it is that the rail
/// stays LAZY and stays in step with the selection. Both are easy to lose:
///
///  * an eager `for` loop building every tile was the first version, and in a
///    conversation with four hundred photographs that is four hundred
///    `RemoteImage`s resolving four hundred serving URLs the moment somebody
///    opens one picture;
///  * the ring has to follow the index it is given, because the index is driven
///    by a swipe on the picture above and not by a tap down here.
void main() {
  final theme = ThemeController(BasicTheme.midnight());

  Widget host(Widget strip, {double width = 360}) => MaterialApp(
    home: ThemeScope(
      controller: theme,
      child: Scaffold(
        body: Center(child: SizedBox(width: width, child: strip)),
      ),
    ),
  );

  /// A cheap, identifiable stand-in for a photograph.
  Widget swatch(int i) => ColoredBox(
    color: Color(0xFF000000 | (0x101010 * (i + 1))),
    child: Center(child: Text('$i', textDirection: TextDirection.ltr)),
  );

  testWidgets('builds only the tiles the viewport can show', (tester) async {
    final built = <int>[];
    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 400,
          index: 0,
          onTap: (_) {},
          thumbnailBuilder: (_, i) {
            built.add(i);
            return swatch(i);
          },
        ),
      ),
    );

    // 360pt of rail at 62pt a tile is a handful, plus whatever cache extent
    // the list keeps. The number that matters is "nothing like 400".
    expect(built.length, lessThan(40));
    expect(built, contains(0));
  });

  testWidgets('reports the tile that was tapped', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 4,
          index: 0,
          onTap: tapped.add,
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );

    await tester.tap(find.text('2'));
    expect(tapped, [2]);
  });

  testWidgets('offers a remove badge only when removal is possible', (
    tester,
  ) async {
    // The gallery's case: these photographs are already in a conversation and
    // there is nothing to take back.
    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 3,
          index: 0,
          onTap: (_) {},
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.trash_fill), findsNothing);

    final removed = <int>[];
    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 3,
          index: 0,
          onTap: (_) {},
          onRemove: removed.add,
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );

    // One badge, on the current tile only: the others are for switching to,
    // and a badge on each sat where the thumb lands when doing that.
    final badges = find.byIcon(CupertinoIcons.trash_fill);
    expect(badges, findsOneWidget);
    await tester.tap(badges);
    expect(removed, [0]);

    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 3,
          index: 2,
          onTap: (_) {},
          onRemove: removed.add,
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.trash_fill));
    expect(removed, [0, 2]);
  });

  testWidgets('a rail that fits does not scroll, and a longer one does', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 3,
          index: 0,
          onTap: (_) {},
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<NeverScrollableScrollPhysics>(),
      reason: 'three tiles under a centred photo should sit centred, not left',
    );

    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 40,
          index: 0,
          onTap: (_) {},
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );
  });

  testWidgets('opens already scrolled to the tile it was given', (tester) async {
    // The gallery opens on the photograph that was tapped, which in a long
    // conversation is nowhere near the start of the rail. Mounting at offset
    // zero would put the ring off the right-hand edge with nothing on screen to
    // say the rail had a selection at all.
    await tester.pumpWidget(
      host(
        MediaFilmstrip(
          count: 60,
          index: 42,
          onTap: (_) {},
          thumbnailBuilder: (_, i) => swatch(i),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('42'), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).controller!.offset,
      greaterThan(0),
    );
  });

  testWidgets('drags the selected tile back into view when the index moves', (
    tester,
  ) async {
    Widget at(int index) => host(
      MediaFilmstrip(
        count: 60,
        index: index,
        onTap: (_) {},
        thumbnailBuilder: (_, i) => swatch(i),
      ),
    );

    await tester.pumpWidget(at(0));
    final scroll = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    expect(scroll.offset, 0);

    // The reader swiped the picture above, not the rail. The rail has to catch
    // up on its own or the ring ends up off screen.
    await tester.pumpWidget(at(30));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(find.text('30'), findsOneWidget);
  });
}
