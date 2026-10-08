import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/media/native_gallery.dart';
import 'package:monkeyhub/media/native_video_player.dart';
import 'package:monkeyhub/media/video_file_cache.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';

class _UrlApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async =>
      'https://example.test/$storageId';
}

ChatMessage _m(String id, MessageType type, {bool viewOnce = false}) =>
    ChatMessage(
      id: id,
      roomId: 'r',
      senderId: 'them',
      senderName: 'Them',
      content: '',
      createdAt: DateTime(2026, 10, 8),
      type: type,
      mediaStorageId: type == MessageType.text ? null : 's_$id',
      viewOnce: viewOnce,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('monkeyhub/video');
  late Directory cacheDir;

  setUp(() {
    FileUrlCache.instance
      ..debugReset()
      ..debugPersist = false;
    cacheDir = Directory.systemTemp.createTempSync('mh_native_gallery_test');
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = cacheDir;
    NativeVideoPlayer.debugSupportedOverride = true;
    nativeGalleryImageStat = (_) async => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cacheDir.path,
    );
  });

  tearDown(() {
    NativeVideoPlayer.debugSupportedOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = null;
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  test('pages keep order, skip what cannot be shown, and find the video',
      () async {
    final items = [
      _m('a', MessageType.image),
      _m('b', MessageType.image, viewOnce: true),
      _m('c', MessageType.video),
      _m('d', MessageType.text),
      _m('e', MessageType.videoNote),
    ];
    final built = await buildNativeGallery(
      gallery: VideoGallery(items: items),
      currentStorageId: 's_c',
      currentUrl: 'file:///local/c.mp4',
      api: _UrlApi(),
    );

    expect(built.messages.map((m) => m.id), ['a', 'c', 'e']);
    expect(built.index, 1);
    // The tapped video plays the copy the viewer just resolved.
    expect(built.pages[1].toMap()['url'], 'file:///local/c.mp4');
    expect(built.pages[1].toMap()['kind'], 'video');
    expect(built.pages[0].toMap()['kind'], 'photo');
    expect(built.pages[0].toMap()['url'], 'https://example.test/s_a');
  });

  test('a cached neighbour video plays from disk, not the network', () async {
    File('${cacheDir.path}/s_e.mp4').writeAsBytesSync([0, 0, 0, 0]);
    final built = await buildNativeGallery(
      gallery: VideoGallery(
          items: [_m('c', MessageType.video), _m('e', MessageType.video)]),
      currentStorageId: 's_c',
      currentUrl: 'file:///local/c.mp4',
      api: _UrlApi(),
    );
    expect(built.pages[1].toMap()['url'], startsWith('file://'));
  });

  test('closing reports the page back through the channel', () async {
    MethodCall? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      sent = call;
      return true;
    });
    int? closedOn;
    final ok = await NativeVideoPlayer.presentGallery(
      items: const [
        NativeMediaItem.photo(url: 'https://x/1'),
        NativeMediaItem.video(url: 'file:///v.mp4'),
      ],
      index: 1,
      onClosed: (i) => closedOn = i,
    );
    expect(ok, isTrue);
    expect(sent!.method, 'presentGallery');
    expect((sent!.arguments as Map)['index'], 1);

    // The platform calling back when the user closes on the first page.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'monkeyhub/video',
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('galleryClosed', 0)),
      (_) {},
    );
    expect(closedOn, 0);
  });

  test('an older native build without the gallery declines cleanly',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'notImplemented');
    });
    final ok = await NativeVideoPlayer.presentGallery(
      items: const [NativeMediaItem.video(url: 'file:///v.mp4')],
      index: 0,
    );
    expect(ok, isFalse);
  });
}
