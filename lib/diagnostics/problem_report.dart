import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../media/upload_service.dart';
import 'device_report.dart';
import 'diag_buffer.dart';
import 'diag_export.dart';

/// Builds and sends a user-written problem report.
///
/// Separate from [DiagExport], which is the developer-facing tool: that one
/// hands a whole session to whoever is holding the phone, through a share sheet.
/// This one is the feature every user can reach, and it *delivers* — it uploads
/// and posts, so the report exists whether or not the user knows what to do next
/// with a share sheet.
///
/// The two now carry the same evidence. [DiagExport] used to be the only route
/// the captured event log could leave by, and a report saying "it flickers" with
/// no log attached is a report nobody can act on. Since capture is on for
/// everyone and `Redactor` withholds message content, credentials and capability
/// URLs at capture time, the log holds the app's own timings and nothing the user
/// wrote — so attaching it costs the reporter nothing they would object to, and
/// the screen says plainly that it is attached.
class ProblemReport {
  const ProblemReport._();

  /// The identifying facts, in the order somebody triaging wants them.
  ///
  /// Device id is first: it is the one thing that cannot be guessed or looked up
  /// any other way, and it is what ties this report to a specific handset.
  ///
  /// [appLocale] is the language the app is actually rendering in, which the
  /// caller has to supply because it only exists below `MaterialApp` — see
  /// [DeviceReport.appLocaleTag]. Passed rather than read off that static so a
  /// screen with a `BuildContext` in hand always wins over a value some earlier
  /// build recorded.
  static Future<List<({String label, String value})>> facts(
    AuthService auth, {
    String? appLocale,
  }) async {
    final d = await DeviceReport.gather();
    String s(String k) => d[k]?.toString() ?? '—';
    final session = auth.session;
    final override = d['localeOverride']?.toString();
    return [
      (label: 'Device ID', value: s('deviceId')),
      (label: 'User ID', value: session?.userId ?? '—'),
      // The handle, which is what the row is called — the display name used
      // to sit here, which is neither unique nor what support asks for.
      (label: 'Username', value: session?.username ?? '—'),
      (label: 'App', value: '${s('appVersion')} (${s('appBuild')})'),
      (label: 'Device', value: DeviceReport.describeDevice(d)),
      (label: 'System', value: DeviceReport.describeSystem(d)),
      (
        label: 'Display',
        value: '${_num(d['physW'])} × ${_num(d['physH'])} @${_num(d['dpr'])}x',
      ),
      // Three separate lines because they answer three different questions and
      // used to be collapsed into one labelled "Locale" — which read as the app
      // language and was not: it was the handset's. On a Norwegian phone with no
      // override the app renders in English while that row said `nb-NO`, so the
      // one fact a language bug turns on was the one fact missing.
      (
        label: 'App language',
        value:
            '${appLocale ?? DeviceReport.appLocaleTag ?? '—'}'
            ' (${override == null ? languageFromSystem : languageChosen})',
      ),
      (label: 'System locale', value: s('locale')),
      (label: 'Log', value: '${DiagBuffer.instance.length} events attached'),
    ];
  }

  /// The 'App language' fact's suffix, in English because the report is read
  /// by whoever triages it. Named so the screen can swap in the reader's own
  /// words for display without guessing at the string.
  static const languageFromSystem = 'from system';
  static const languageChosen = 'chosen';

  /// A reading without the `.0` a double prints: "2400 × 1800 @3x", not
  /// "2400.0x1800.0 @3.0".
  static String _num(Object? v) {
    if (v is! num) return v?.toString() ?? '—';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// One copyable block. What the user pastes if they'd rather hand the details
  /// over some other way than by sending the report.
  static String formatFacts(List<({String label, String value})> facts) {
    final width = facts
        .map((f) => f.label.length)
        .reduce((a, b) => a > b ? a : b);
    return facts
        .map((f) => '${f.label.padRight(width)}  ${f.value}')
        .join('\n');
  }

  static String buildBody({
    required List<({String label, String value})> facts,
    required String description,
    required int screenshotCount,
  }) {
    final b = StringBuffer()
      ..writeln('--- what happened ---')
      ..writeln(
        description.trim().isEmpty ? '(not described)' : description.trim(),
      )
      ..writeln()
      ..writeln('--- device ---')
      ..writeln(formatFacts(facts));
    if (screenshotCount > 0) {
      b
        ..writeln()
        ..writeln('$screenshotCount screenshot(s) attached.');
    }
    return b.toString();
  }

  /// Uploads the evidence and files the report. Throws on failure, so the caller
  /// can only ever tell the user "sent" when it was.
  ///
  /// Order matters: the blobs go up first and the mutation goes last. Convex
  /// storage is written by a direct PUT that the deployment cannot roll back, so
  /// an upload that succeeds while the mutation fails leaves orphaned bytes —
  /// which `files.gcOrphanedFiles` already reclaims, since nothing references
  /// them. The other order would be a message pointing at a blob that never
  /// arrived: a permanent broken tile, and one no sweep can repair.
  ///
  /// A screenshot that fails to upload is dropped rather than allowed to fail the
  /// report. The text and the identifiers are the part that has to arrive.
  static Future<void> send({
    required ChatApi api,
    required UploadService uploads,
    required AuthService auth,
    required String body,
    required List<XFile> screenshots,
    required String deviceId,
  }) async {
    // The run before this one, off disk. A report about a CRASH is always
    // filed from the session after it — the buffer this snapshot reads was
    // built by a fresh boot and holds nothing but that boot — so without this
    // the one report that matters most is the one guaranteed to arrive empty.
    // Failure here is swallowed by `readFile`, which answers with an empty
    // list, so a missing or unreadable file cannot cost us the rest of the
    // report.
    final previous = await DiagBuffer.instance.readFile(previous: true);
    final log = await DiagExport.build(
      events: DiagBuffer.instance.snapshot(),
      dropped: DiagBuffer.instance.dropped,
      previous: previous,
    );
    final logBytes = utf8.encode(log);

    String? logStorageId;
    try {
      logStorageId = await uploads.uploadFile(
        bytes: logBytes,
        contentType: 'text/plain',
      );
    } catch (e) {
      // Same reasoning as a dropped screenshot, one level more important: a
      // report with no log still names the device, and a device id is enough to
      // ask for a fresh one.
      debugPrint('[report] log upload failed, sending without it: $e');
    }

    final shotIds = <String>[];
    for (final shot in screenshots) {
      try {
        shotIds.add(
          await uploads.uploadFile(
            bytes: await shot.readAsBytes(),
            contentType: shot.mimeType ?? 'image/jpeg',
          ),
        );
      } catch (e) {
        debugPrint('[report] screenshot upload failed, dropping it: $e');
      }
    }

    await api.submitProblemReport(
      deviceId: deviceId,
      reporterId: auth.session?.userId,
      body: body,
      logStorageId: logStorageId,
      logFileName: logStorageId == null ? null : _logFileName(),
      logFileSize: logStorageId == null ? null : logBytes.length,
      screenshots: shotIds,
    );
  }

  /// `.txt`, not `.ndjson`, for the same reason [DiagExport.share] uses it: the
  /// content is one JSON object per line either way, and an extension the
  /// receiving platform recognises is the difference between a file that opens
  /// with a tap and one that does not open at all.
  static String _logFileName() {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    return 'monkeyhub-report-$stamp.txt';
  }
}
