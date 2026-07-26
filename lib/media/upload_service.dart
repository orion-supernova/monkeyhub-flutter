import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

import '../backend/chat_api.dart';

/// Thrown when an upload is stopped on purpose — the user discarded the message,
/// or left and the repository gave up on it.
///
/// A distinct type rather than a generic failure because the two mean opposite
/// things to the caller: a failure wants a red bubble with a retry on it, a
/// cancel wants the bubble gone.
class UploadCancelled implements Exception {
  const UploadCancelled();
  @override
  String toString() => 'upload cancelled';
}

/// Thrown when an upload stops moving.
class UploadStalled implements Exception {
  const UploadStalled(this.after);
  final Duration after;
  @override
  String toString() => 'upload stalled for ${after.inSeconds}s';
}

/// A handle on one upload in flight.
///
/// Holds the request's own [http.Client] because closing a client is the only
/// thing `package:http` gives you that actually aborts a request mid-body —
/// there is no cancel token. One client per upload, so cancelling one cannot
/// tear down another's socket.
class UploadTask {
  UploadTask();

  http.Client? _client;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _client?.close();
    _client = null;
  }
}

/// Uploads a single binary blob to Convex's file storage.
///
/// Flow (mirrors v02 ConvexChatAPI.uploadFile):
///   1. Ask backend for a short-lived upload URL.
///   2. POST the bytes there. Response body is JSON: `{ "storageId": "..." }`.
///
/// Bytes only, deliberately. There used to be a `uploadXFile(File)` wrapper
/// whose entire body was `readAsBytes()` — which throws `UnsupportedError` on
/// web, where a picked file is a `blob:` URL with no filesystem behind it.
/// Callers that start from an `XFile` read it themselves; everything the media
/// pipeline produces is already bytes.
class UploadService {
  UploadService(this._api);
  final ChatApi _api;

  /// How long an upload may make no progress at all before it is given up on.
  ///
  /// An inactivity watchdog rather than a total deadline, and that distinction
  /// matters: a 20 MB video over a train's wifi is legitimately slow, and a
  /// total deadline would kill exactly the sends that most needed patience. This
  /// only fires when nothing has moved.
  static const stallTimeout = Duration(seconds: 30);

  /// The whole-request ceiling used on the web, where there is no progress to
  /// watch — see [_upload]. Generous, because it is the only limit there is.
  static const webTimeout = Duration(minutes: 5);

  Future<String> uploadFile({
    required Uint8List bytes,
    required String contentType,

    /// Called with cumulative bytes handed to the transport, then the total.
    ///
    /// Not called at all on the web: `package:http`'s browser client drains the
    /// whole body into a `Blob` before a single byte leaves the page, so any
    /// number reported there would jump straight to 100% and then sit. An
    /// indeterminate spinner is the honest rendering of that, and the caller
    /// gets it by being told nothing.
    ///
    /// (The alternative was a conditional-import client built on
    /// `XMLHttpRequest.upload.onprogress`, which `package:http` does not
    /// surface. Hand-rolling a second HTTP stack for one progress arc is not a
    /// trade worth making.)
    void Function(int sent, int total)? onProgress,
    UploadTask? task,
  }) async {
    final url = await _api.generateUploadUrl();
    if (task?.cancelled ?? false) throw const UploadCancelled();
    return _upload(
      url: url,
      bytes: bytes,
      contentType: contentType,
      onProgress: kIsWeb ? null : onProgress,
      task: task,
    );
  }

  Future<String> _upload({
    required String url,
    required Uint8List bytes,
    required String contentType,
    void Function(int sent, int total)? onProgress,
    UploadTask? task,
  }) async {
    final client = http.Client();
    task?._client = client;
    // Reset by every progress tick and again when the response headers land.
    // Fires only if neither has happened for [stallTimeout].
    Timer? watchdog;
    var stalled = false;

    void arm() {
      if (onProgress == null) return;
      watchdog?.cancel();
      watchdog = Timer(stallTimeout, () {
        stalled = true;
        // Closing the client is what aborts the socket; the addStream below then
        // completes with an error, which we translate into [UploadStalled].
        client.close();
      });
    }

    try {
      final request = ProgressRequest(
        Uri.parse(url),
        bytes,
        onProgress == null
            ? null
            : (sent) {
                arm();
                onProgress(sent, bytes.length);
              },
      )..headers['Content-Type'] = contentType;

      arm();
      final streamed = onProgress == null
          ? await client.send(request).timeout(webTimeout)
          : await client.send(request);
      watchdog?.cancel();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Upload failed (${resp.statusCode}): ${resp.body}');
      }
      // Convex returns { storageId: "kg2..." }.
      final match = RegExp(r'"storageId"\s*:\s*"([^"]+)"').firstMatch(resp.body);
      if (match == null) {
        throw Exception('Upload succeeded but storageId missing: ${resp.body}');
      }
      return match.group(1)!;
    } catch (_) {
      // Order matters: a cancel and a stall both surface as a closed-client
      // error from the same place, and both must be named before the generic
      // failure they look like.
      if (task?.cancelled ?? false) throw const UploadCancelled();
      if (stalled) throw const UploadStalled(stallTimeout);
      rethrow;
    } finally {
      watchdog?.cancel();
      task?._client = null;
      client.close();
    }
  }
}

/// A request whose body is handed over in chunks, counting them on the way past.
///
/// A [http.BaseRequest] subclass rather than [http.StreamedRequest], which was
/// the obvious choice and the wrong one: `StreamedRequest` gives you an
/// `EventSink` with no backpressure, so a loop pushing 64 KiB chunks into it
/// reports 100% the instant the loop finishes, however slow the network is. A
/// lazy stream is piped with `addStream`, which pauses the generator whenever
/// the socket's sink is full — so the counter tracks the wire.
///
/// Two caveats worth knowing, both of which the UI is built around:
///
///  * The count still runs ahead of the network by whatever the socket's send
///    buffer holds (64–256 KiB), so the arc reaches its end slightly early. The
///    tile caps what it draws and holds there until the response lands, because
///    showing 100% while bytes sit in a kernel buffer is the same lie as showing
///    nothing.
///  * `contentLength` is set explicitly. Without it `dart:io` switches to
///    chunked transfer-encoding, and there is no reason to hand Convex's upload
///    endpoint a body shape nobody has verified it accepts.
@visibleForTesting
class ProgressRequest extends http.BaseRequest {
  ProgressRequest(Uri url, this.bytes, this.onSent) : super('POST', url) {
    contentLength = bytes.length;
  }

  final Uint8List bytes;
  final void Function(int sent)? onSent;

  /// Small enough that the arc moves visibly on a slow link, large enough that a
  /// 5 MB photo is 80 writes rather than 5000.
  static const chunkSize = 64 * 1024;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_chunks());
  }

  Stream<List<int>> _chunks() async* {
    var sent = 0;
    while (sent < bytes.length) {
      final end = (sent + chunkSize).clamp(0, bytes.length);
      yield Uint8List.sublistView(bytes, sent, end);
      sent = end;
      onSent?.call(sent);
    }
    // A zero-length body still has to report completion, or a caller waiting for
    // the arc to fill waits forever on an empty attachment.
    if (bytes.isEmpty) onSent?.call(0);
  }
}
