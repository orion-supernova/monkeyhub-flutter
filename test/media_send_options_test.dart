import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/media_send_options.dart';
import 'package:monkeyhub/widgets/inline_photo_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// HD is one send's decision: off at the start of every send, on every
/// platform, never remembered. It used to stick once turned on and quietly
/// kept every later photo at full size.
void main() {
  test('every send starts with HD off, even right after an HD one', () {
    final first = MediaSendOptions()..hd = true;
    expect(first.hd, isTrue);
    expect(MediaSendOptions().hd, isFalse);
  });

  test('sending resets HD with the other switches', () {
    final options = MediaSendOptions()
      ..hd = true
      ..spoiler = true
      ..viewOnce = true;
    options.reset();
    expect(options.hd, isFalse);
    expect(options.spoiler, isFalse);
    expect(options.viewOnce, isFalse);
  });

  test('unpicking the last photo abandons the send and its HD', () {
    final picker = InlinePickerController();
    addTearDown(picker.dispose);
    AssetEntity asset(String id) =>
        AssetEntity(id: id, typeInt: 1, width: 10, height: 10);
    final a = asset('a'), b = asset('b');
    picker.toggle(a);
    picker.toggle(b);
    picker.options.hd = true;
    picker.toggle(a);
    expect(picker.options.hd, isTrue, reason: 'one pick still in the send');
    picker.toggle(b);
    expect(picker.options.hd, isFalse);
  });
}
