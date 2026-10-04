import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';

class _Sub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _Backend extends Fake implements ConvexBackend {
  final sinks = <String, void Function(dynamic)>{};
  Completer<dynamic>? writing;
  Completer<dynamic>? refreshing;
  int writes = 0;
  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connectionState => const Stream.empty();
  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object)? onError,
  }) async {
    sinks[name] = onData;
    return _Sub();
  }

  @override
  Future<dynamic> mutation(String name, Map<String, dynamic> args) async {
    if (name == 'interactions:respond') {
      writes++;
      return writing!.future;
    }
    return null;
  }

  @override
  Future<dynamic> query(String name, Map<String, dynamic> args) async {
    if (name == 'interactions:stateForMessages' && refreshing != null) {
      return refreshing!.future;
    }
    return [];
  }
}

Map<String, dynamic> _row({String held = '0'}) => {
  'messageId': 'm1',
  'kind': 'poll',
  'createdBy': 'me',
  'createdAt': 0,
  'choices': [
    {'id': '0', 'label': 'A', 'count': held == '0' ? 1 : 0},
    {'id': '1', 'label': 'B', 'count': held == '1' ? 1 : 0},
  ],
  'respondentCount': 1,
  'myChoiceIds': [held],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'pending replacement survives subscriptions, acknowledgement and duplicate taps',
    () async {
      final backend = _Backend();
      final repo = ChatRepository(api: ChatApi(backend), cv: backend);
      await repo.attach('me');
      await repo.openRoom('r');
      backend.sinks['messages:list']!([]);
      await Future<void>.delayed(Duration.zero);
      backend.sinks['interactions:listForRoom']!([_row()]);
      backend.writing = Completer();
      backend.refreshing = Completer();
      final first = repo.respondToInteraction(
        roomId: 'r',
        messageId: 'm1',
        choiceId: '1',
      );
      final duplicate = repo.respondToInteraction(
        roomId: 'r',
        messageId: 'm1',
        choiceId: '1',
      );
      await Future<void>.delayed(Duration.zero);
      expect(backend.writes, 1);
      var current = repo.interactionFor('r', 'm1')!;
      expect(current.choiceSelected(current.choices[0]), isFalse);
      expect(current.choiceSelected(current.choices[1]), isTrue);
      backend.sinks['interactions:listForRoom']!([_row()]);
      current = repo.interactionFor('r', 'm1')!;
      expect(current.pendingChoiceIds, {'1'});
      expect(current.choiceSelected(current.choices[1]), isTrue);
      // The subscription can acknowledge before the mutation's future completes.
      backend.sinks['interactions:listForRoom']!([_row(held: '1')]);
      current = repo.interactionFor('r', 'm1')!;
      expect(current.choiceSelected(current.choices[1]), isTrue);
      backend.writing!.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.interactionFor('r', 'm1')!.pendingChoiceIds, {'1'});
      backend.refreshing!.complete([_row(held: '1')]);
      expect(await first, isTrue);
      expect(await duplicate, isTrue);
      current = repo.interactionFor('r', 'm1')!;
      expect(current.pendingChoiceIds, isEmpty);
      expect(current.myChoiceIds, ['1']);
      expect(current.choiceSelected(current.choices[1]), isTrue);
      repo.dispose();
    },
  );

  test(
    'failed response restores confirmed selection and permits retry',
    () async {
      final backend = _Backend();
      final repo = ChatRepository(api: ChatApi(backend), cv: backend);
      await repo.attach('me');
      await repo.openRoom('r');
      backend.sinks['messages:list']!([]);
      await Future<void>.delayed(Duration.zero);
      backend.sinks['interactions:listForRoom']!([_row()]);
      backend.writing = Completer();
      final first = repo.respondToInteraction(
        roomId: 'r',
        messageId: 'm1',
        choiceId: '1',
      );
      await Future<void>.delayed(Duration.zero);
      backend.writing!.completeError(StateError('offline'));
      expect(await first, isFalse);
      var current = repo.interactionFor('r', 'm1')!;
      expect(current.pendingChoiceIds, isEmpty);
      expect(current.choiceSelected(current.choices[0]), isTrue);
      backend.writing = Completer()..complete(null);
      backend.refreshing = Completer()..complete([_row(held: '1')]);
      expect(
        await repo.respondToInteraction(
          roomId: 'r',
          messageId: 'm1',
          choiceId: '1',
        ),
        isTrue,
      );
      expect(backend.writes, 2);
      current = repo.interactionFor('r', 'm1')!;
      expect(current.myChoiceIds, ['1']);
      repo.dispose();
    },
  );
}
