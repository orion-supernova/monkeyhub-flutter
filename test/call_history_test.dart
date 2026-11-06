import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/call_history.dart';

void main() {
  const full =
      'call:{"v":1,"k":"d","id":"c1","t":"video","s":"ended","a":1730000000000,"e":1730000600000,"d":600000,"o":"macos","q":"fair"}';

  test('parses every field', () {
    final e = CallEvent.parse(full)!;
    expect(e.kind, CallEventKind.direct);
    expect(e.id, 'c1');
    expect(e.isVideo, isTrue);
    expect(e.status, CallEventStatus.ended);
    expect(e.answeredAt!.millisecondsSinceEpoch, 1730000000000);
    expect(e.endedAt!.millisecondsSinceEpoch, 1730000600000);
    expect(e.duration, const Duration(minutes: 10));
    expect(e.answeredOn, 'macos');
    expect(e.quality, CallEventQuality.fair);
    expect(e.isLive, isFalse);
  });

  test('group call with people, live', () {
    final e = CallEvent.parse(
        'call:{"v":1,"k":"g","id":"g1","t":"audio","s":"active","a":5,"n":3}')!;
    expect(e.isGroup, isTrue);
    expect(e.people, 3);
    expect(e.isLive, isTrue);
    expect(e.endedAt, isNull);
  });

  test('round-trips', () {
    final e = CallEvent.parse(full)!;
    final again = CallEvent.parse(e.content)!;
    expect(again.content, e.content);
  });

  test('unknown or malformed content is null', () {
    expect(CallEvent.parse('hello'), isNull);
    expect(CallEvent.parse('call:'), isNull);
    expect(CallEvent.parse('call:{nope'), isNull);
    expect(CallEvent.parse('call:[1]'), isNull);
    expect(CallEvent.parse('call:{"v":1,"k":"d","id":"x","t":"video"}'), isNull);
    expect(
        CallEvent.parse('call:{"v":1,"k":"x","id":"x","t":"video","s":"ended"}'),
        isNull);
    expect(
        CallEvent.parse('call:{"k":"d","id":"x","t":"video","s":"ended"}'),
        isNull);
    expect(
        CallEvent.parse('call:{"v":1,"k":"d","id":"","t":"video","s":"ended"}'),
        isNull);
    expect(CallEvent.isCallContent('call:{nope'), isTrue);
  });

  test('unknown quality is ignored, not fatal', () {
    final e = CallEvent.parse(
        'call:{"v":1,"k":"d","id":"x","t":"audio","s":"missed","q":"great"}')!;
    expect(e.quality, isNull);
  });

  CallEvent ev(String s) => CallEvent.parse(
      'call:{"v":1,"k":"d","id":"x","t":"audio","s":"$s"}')!;

  test('perspective table', () {
    CallPhase p(String s, bool mine) => ev(s).phaseFor(isMine: mine);
    expect(p('ringing', true), CallPhase.calling);
    expect(p('ringing', false), CallPhase.incomingRinging);
    expect(p('active', true), CallPhase.live);
    expect(p('active', false), CallPhase.live);
    expect(p('ended', true), CallPhase.outgoingEnded);
    expect(p('ended', false), CallPhase.incomingEnded);
    expect(p('missed', true), CallPhase.noAnswer);
    expect(p('missed', false), CallPhase.missed);
    expect(p('cancelled', true), CallPhase.cancelled);
    expect(p('cancelled', false), CallPhase.missed);
    expect(p('declined', true), CallPhase.declined);
    expect(p('declined', false), CallPhase.declined);
  });

  test('answeredElsewhere compares against the viewer platform', () {
    final e = CallEvent.parse(full)!;
    expect(e.answeredElsewhere('ios'), isTrue);
    expect(e.answeredElsewhere('macos'), isFalse);
    expect(ev('ended').answeredElsewhere('ios'), isFalse);
    final sim = CallEvent.parse(
        'call:{"v":1,"k":"d","id":"x","t":"audio","s":"ended","o":"ios"}')!;
    expect(sim.answeredElsewhere('ios-simulator'), isFalse);
  });

  test('only missed or cancelled direct calls of one type collapse', () {
    expect(ev('missed').collapsesWith(ev('cancelled')), isTrue);
    expect(ev('missed').collapsesWith(ev('ended')), isFalse);
    final video = CallEvent.parse(
        'call:{"v":1,"k":"d","id":"y","t":"video","s":"missed"}')!;
    expect(ev('missed').collapsesWith(video), isFalse);
  });

  test('clock formatting', () {
    expect(CallEvent.formatClock(const Duration(seconds: 761)), '12:41');
    expect(CallEvent.formatClock(const Duration(seconds: 5)), '0:05');
    expect(CallEvent.formatClock(const Duration(seconds: 3723)), '1:02:03');
    expect(CallEvent.formatClock(const Duration(seconds: -4)), '0:00');
  });
}
