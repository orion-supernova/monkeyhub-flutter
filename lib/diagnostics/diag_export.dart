import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'device_report.dart';
import 'diag_buffer.dart';
import 'diag_event.dart';
import 'redactor.dart';

/// Gets a captured session off the device and into a chat message.
class DiagExport {
  const DiagExport._();

  /// Chat clients start refusing attachments well before this, and the tail is
  /// where the crash is, so an oversized log ships its end rather than failing.
  static const int _maxShareBytes = 2 * 1024 * 1024;

  /// Builds the full text: header block, then one JSON object per line.
  ///
  /// [previous] is the run before this one, read back from `previous.ndjson`.
  /// It is the whole reason a crash is reportable at all: a process that dies
  /// takes its in-memory buffer with it, and whoever files the report is by
  /// definition doing it from the session that came AFTER — which contains a
  /// clean boot and nothing else. Passing it empty is the old behaviour and
  /// costs nothing.
  ///
  /// Appended LAST, and that ordering is load-bearing. The size cap below keeps
  /// the tail, so the bytes that survive truncation are the end of the crashed
  /// run — which is exactly where the crash is. Putting it first would let a
  /// long post-restart session push the evidence out of the file.
  static Future<String> build({
    required List<DiagEvent> events,
    required int dropped,
    String? connectionPhase,
    List<DiagEvent> previous = const [],
  }) async {
    final device = await DeviceReport.gather();
    final header = DeviceReport.format(
      device,
      events: events.length,
      dropped: dropped,
      uptimeMs: DiagBuffer.instance.uptimeMs,
      redactionVersion: Redactor.version,
      connectionPhase: connectionPhase,
      previousEvents: previous.length,
    );

    final body = StringBuffer();
    for (final e in events) {
      body.write(e.toNdjsonLine());
    }
    if (previous.isNotEmpty) {
      // A plain-text marker rather than another JSON object: every line in this
      // file parses as one event, and a reader splitting on newlines must not
      // have to know about a sentinel that isn't one.
      body.writeln();
      body.writeln(
        '--- previous session: ${previous.length} events, the run that ended '
        'before this one started ---',
      );
      for (final e in previous) {
        body.write(e.toNdjsonLine());
      }
    }

    var text = '$header\n$body';
    final bytes = utf8.encode(text);
    if (bytes.length > _maxShareBytes) {
      // Keep the header and the END. A truncated log that starts at the
      // beginning throws away the part that explains why it stopped.
      final tail = utf8.decode(
        bytes.sublist(bytes.length - _maxShareBytes),
        allowMalformed: true,
      );
      // Drop the first (probably torn) line of the tail.
      final firstNewline = tail.indexOf('\n');
      final clean = firstNewline == -1
          ? tail
          : tail.substring(firstNewline + 1);
      text =
          '$header\n[… truncated: showing the last '
          '${_maxShareBytes ~/ 1024} KiB of a '
          '${bytes.length ~/ 1024} KiB log]\n$clean';
    }
    return text;
  }

  /// Shares [text] as a file.
  ///
  /// `.txt` rather than `.ndjson`: Android share targets routinely refuse
  /// extensions they don't recognise, and the person on the affected device
  /// being unable to SEND the file is total failure. The content is still one
  /// JSON object per line, so it stays machine-readable.
  ///
  /// [origin] is the tapped button's global rect — required for iPad and macOS
  /// popover anchoring, harmless elsewhere. Same reason `DocumentSaver` passes
  /// it.
  static Future<void> share({
    required String text,
    required String label,
    Rect? origin,
  }) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final name = 'monkeyhub-diag-$label-$stamp.txt';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(utf8.encode(text), name: name, mimeType: 'text/plain'),
        ],
        // XFile.fromData carries no filesystem name, so without this the share
        // sheet invents one.
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
  }

  /// A short summary small enough to paste straight into a chat message.
  ///
  /// This is how the first reply actually arrives — asking someone to find a
  /// share sheet and attach a file is a round trip; asking them to long-press
  /// and paste is not.
  static Future<String> summary({
    required List<DiagEvent> events,
    required int dropped,
    String? connectionPhase,
    int rows = 20,
  }) async {
    final device = await DeviceReport.gather();
    final b = StringBuffer()
      ..write(
        DeviceReport.format(
          device,
          events: events.length,
          dropped: dropped,
          uptimeMs: DiagBuffer.instance.uptimeMs,
          redactionVersion: Redactor.version,
          connectionPhase: connectionPhase,
        ),
      )
      ..writeln();

    // Worst-first rather than newest-first: a summary this short should lead
    // with what went wrong, not with whatever happened to be last.
    final ranked = [...events]
      ..sort((a, b) => b.sev.index.compareTo(a.sev.index));
    for (final e in ranked.take(rows)) {
      b.writeln(
        '${e.upMs}ms ${e.sev.name} ${e.cat.name}/${e.event} '
                '${e.name ?? ''} ${e.detail ?? ''}'
            .trim(),
      );
    }
    return b.toString();
  }
}
