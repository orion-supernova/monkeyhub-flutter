import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/diagnostics/problem_report.dart';
import 'package:monkeyhub/media/upload_service.dart';

/// Records what a report actually put on the wire.
class _FakeApi extends Fake implements ChatApi {
  int calls = 0;
  String? deviceId;
  String? reporterId;
  String? body;
  String? logStorageId;
  String? logFileName;
  int? logFileSize;
  List<String> screenshots = const [];

  /// Thrown instead of recording, when set.
  Object? failWith;

  @override
  Future<void> submitProblemReport({
    required String deviceId,
    String? reporterId,
    required String body,
    String? logStorageId,
    String? logFileName,
    int? logFileSize,
    List<String> screenshots = const [],
  }) async {
    calls++;
    if (failWith != null) throw failWith!;
    this.deviceId = deviceId;
    this.reporterId = reporterId;
    this.body = body;
    this.logStorageId = logStorageId;
    this.logFileName = logFileName;
    this.logFileSize = logFileSize;
    this.screenshots = screenshots;
  }
}

/// Hands out predictable storage ids, and can refuse a specific upload.
class _FakeUploads extends Fake implements UploadService {
  _FakeUploads({this.failOnCall});

  /// 1-based index of the upload to fail, or null to accept all.
  final int? failOnCall;

  final List<String> contentTypes = [];
  final List<int> sizes = [];

  @override
  Future<String> uploadFile({
    required Uint8List bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
    UploadTask? task,
  }) async {
    contentTypes.add(contentType);
    sizes.add(bytes.length);
    if (contentTypes.length == failOnCall) {
      throw Exception('upload refused');
    }
    return 'storage-${contentTypes.length}';
  }
}

XFile _shot(String name) => XFile.fromData(
  Uint8List.fromList(utf8.encode('pretend-jpeg-$name')),
  name: name,
  mimeType: 'image/png',
);

void main() {
  // `DiagExport.build` reads the device header, which touches plugins that do
  // not exist in a test host. Every lookup in `DeviceReport.gather` is
  // individually guarded, so it returns a partial map rather than throwing —
  // which is exactly the shape a real report from a locked-down handset has.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi api;
  late AuthService auth;

  setUp(() {
    api = _FakeApi();
    // Signed out, which is a real case: the report screen is reachable from a
    // shake, and nothing about a bug requires being logged in.
    auth = AuthService(api);
  });

  test('uploads the log, then files the report naming it', () async {
    final uploads = _FakeUploads();

    await ProblemReport.send(
      api: api,
      uploads: uploads,
      auth: auth,
      body: 'the screen flickers',
      screenshots: const [],
      deviceId: 'device-abc',
    );

    expect(api.calls, 1);
    expect(api.deviceId, 'device-abc');
    expect(api.reporterId, isNull);
    expect(api.body, 'the screen flickers');
    expect(api.logStorageId, 'storage-1');
    expect(uploads.contentTypes, ['text/plain']);
    // `.txt`, so the attachment opens with a tap on every platform.
    expect(api.logFileName, endsWith('.txt'));
    expect(api.logFileSize, uploads.sizes.single);
    expect(api.screenshots, isEmpty);
  });

  test('forwards a storage id per screenshot, log first', () async {
    final uploads = _FakeUploads();

    await ProblemReport.send(
      api: api,
      uploads: uploads,
      auth: auth,
      body: 'two shots',
      screenshots: [_shot('one.png'), _shot('two.png')],
      deviceId: 'device-abc',
    );

    expect(uploads.contentTypes, ['text/plain', 'image/png', 'image/png']);
    expect(api.logStorageId, 'storage-1');
    expect(api.screenshots, ['storage-2', 'storage-3']);
  });

  test('a refused screenshot is dropped, not allowed to fail the report', () async {
    // The second upload is the first screenshot.
    final uploads = _FakeUploads(failOnCall: 2);

    await ProblemReport.send(
      api: api,
      uploads: uploads,
      auth: auth,
      body: 'one shot will not go up',
      screenshots: [_shot('bad.png'), _shot('good.png')],
      deviceId: 'device-abc',
    );

    expect(api.calls, 1, reason: 'the note still has to arrive');
    expect(api.screenshots, ['storage-3']);
  });

  test('a refused log is dropped too — the device id is the load-bearing part', () async {
    final uploads = _FakeUploads(failOnCall: 1);

    await ProblemReport.send(
      api: api,
      uploads: uploads,
      auth: auth,
      body: 'no log for you',
      screenshots: const [],
      deviceId: 'device-abc',
    );

    expect(api.calls, 1);
    expect(api.logStorageId, isNull);
    // Both must be absent together: a name and a size for a blob that was never
    // stored would render as an attachment that cannot be opened.
    expect(api.logFileName, isNull);
    expect(api.logFileSize, isNull);
  });

  test('a refused mutation throws, so the screen cannot claim success', () async {
    api.failWith = Exception('TOO_MANY_REPORTS');

    await expectLater(
      ProblemReport.send(
        api: api,
        uploads: _FakeUploads(),
        auth: auth,
        body: 'throttled',
        screenshots: const [],
        deviceId: 'device-abc',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
