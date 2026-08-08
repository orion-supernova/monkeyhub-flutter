import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/screens/navigation/tab_reselect.dart';

/// Tapping the tab you are already on sends that tab's list back to the top.
///
/// Every nav chrome already reported the re-tap and the shell already dropped
/// it, so the whole feature is the two pieces exercised here: the signal, and a
/// section that listens for its own name. The four real sections need backend
/// services to pump, so this stands one minimal screen in their place — the
/// mixin is the entire contract they share.
void main() {
  Widget wrap(HomeSection section) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(375, 812)),
      child: _Screen(section),
    ),
  );

  double offsetOf(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView)).controller!.offset;

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(offsetOf(tester), greaterThan(0), reason: 'nothing to rewind');
  }

  testWidgets('a re-tap rewinds the section it names', (tester) async {
    await tester.pumpWidget(wrap(HomeSection.chat));
    await scrollDown(tester);

    TabReselect.instance.fire(HomeSection.chat);
    await tester.pumpAndSettle();

    expect(offsetOf(tester), 0);
  });

  testWidgets('a re-tap of another section is left alone', (tester) async {
    await tester.pumpWidget(wrap(HomeSection.chat));
    await scrollDown(tester);
    final before = offsetOf(tester);

    TabReselect.instance.fire(HomeSection.feed);
    await tester.pumpAndSettle();

    expect(offsetOf(tester), before);
  });

  testWidgets('an unmounted section stops listening', (tester) async {
    await tester.pumpWidget(wrap(HomeSection.chat));
    await scrollDown(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    // Would reach a disposed State — and its disposed controller — if the
    // mixin had not unsubscribed.
    TabReselect.instance.fire(HomeSection.chat);
    await tester.pumpAndSettle();
  });
}

/// The least a section screen can be: one scroll view, one section name.
class _Screen extends StatefulWidget {
  const _Screen(this.section);
  final HomeSection section;
  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with TabReselectScroll<_Screen> {
  final _scroll = ScrollController();

  @override
  HomeSection get reselectSection => widget.section;
  @override
  ScrollController get reselectScroll => _scroll;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: _scroll,
    children: [
      for (var i = 0; i < 40; i++)
        SizedBox(height: 80, child: Text('row $i')),
    ],
  );
}
