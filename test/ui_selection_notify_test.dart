import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/ui_selection_store.dart';

/// Backing out of a room while the Settings screen was mounted threw
/// *"setState() or markNeedsBuild() called when widget tree was locked"*.
///
/// `_RoomScreenState.dispose` clears its own room from [UiSelectionStore] (so a
/// stale id can't resurrect a closed room on a later resize), and Flutter runs
/// dispose from `BuildOwner.finalizeTree` — inside `lockState`. The
/// notification fanned straight out to `SettingsScreen`, which rebuilds on
/// selection changes to highlight the active pane row, and the frame blew up.
///
/// These pin the deferral: notifying from inside a frame waits for that frame
/// to end, without the caller having to know it is being disposed.

/// Stands in for `SettingsScreen` — rebuilds on every selection change.
class _Watcher extends StatefulWidget {
  const _Watcher();
  @override
  State<_Watcher> createState() => _WatcherState();
}

int _watcherBuilds = 0;

class _WatcherState extends State<_Watcher> {
  void _onSelection() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    UiSelectionStore.instance.addListener(_onSelection);
  }

  @override
  void dispose() {
    UiSelectionStore.instance.removeListener(_onSelection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _watcherBuilds++;
    return const SizedBox.shrink();
  }
}

/// Stands in for `_RoomScreenState` — clears its own room on the way out.
class _Clearer extends StatefulWidget {
  const _Clearer({required this.roomId});
  final String roomId;
  @override
  State<_Clearer> createState() => _ClearerState();
}

class _ClearerState extends State<_Clearer> {
  @override
  void dispose() {
    if (UiSelectionStore.instance.roomId == widget.roomId) {
      UiSelectionStore.instance.selectRoom(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _tree({required bool withClearer}) => Column(
  children: [
    const _Watcher(),
    if (withClearer) const _Clearer(roomId: 'a'),
  ],
);

void main() {
  setUp(() {
    _watcherBuilds = 0;
    UiSelectionStore.instance.selectRoom(null);
  });

  tearDown(() => UiSelectionStore.instance.selectRoom(null));

  testWidgets('a selection cleared from dispose does not blow up the frame', (
    tester,
  ) async {
    UiSelectionStore.instance.selectRoom('a');
    await tester.pumpWidget(_tree(withClearer: true));

    // Unmounting the clearer runs its dispose from `finalizeTree`, with the
    // tree locked — the exact moment the crash used to land.
    await tester.pumpWidget(_tree(withClearer: false));
    expect(tester.takeException(), isNull);

    // The write itself is NOT deferred: a non-listening reader in the same tick
    // still sees the room gone.
    expect(UiSelectionStore.instance.roomId, isNull);
  });

  testWidgets('the deferred notification still reaches listeners', (
    tester,
  ) async {
    UiSelectionStore.instance.selectRoom('a');
    await tester.pumpWidget(_tree(withClearer: true));
    final before = _watcherBuilds;

    await tester.pumpWidget(_tree(withClearer: false));
    // Swallowing the notification would be its own bug — a settings row left
    // highlighted for a room that is no longer open.
    await tester.pump();
    expect(_watcherBuilds, greaterThan(before));
  });

  testWidgets('a selection made outside a frame notifies synchronously', (
    tester,
  ) async {
    await tester.pumpWidget(_tree(withClearer: false));
    var notified = false;
    void listener() => notified = true;
    UiSelectionStore.instance.addListener(listener);
    addTearDown(() => UiSelectionStore.instance.removeListener(listener));

    // A tap handler's call site: no frame in flight, so nothing waits.
    UiSelectionStore.instance.selectRoom('b');
    expect(notified, isTrue);
  });
}
