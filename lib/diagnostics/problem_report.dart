import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import '../auth/auth_service.dart';
import 'device_report.dart';

/// Where problem reports are meant to land.
///
/// Shown on screen and put at the top of the report body, because a share sheet
/// carries no recipient — whichever app the user picks, they need the address
/// in front of them.
const String kSupportEmail = 'info@walhallaa.com';

/// Builds and sends a user-written problem report.
///
/// Separate from `DiagExport` on purpose. That one is a developer tool behind an
/// allowlist and emits a machine-readable event log; this is a normal feature
/// every user can reach, and it emits a short human-readable note. They share a
/// device header and nothing else — and critically, **this never includes the
/// captured event log**, because an ordinary user tapping "send report" has not
/// agreed to hand over a trace of everything their app did.
class ProblemReport {
  const ProblemReport._();

  /// The facts that identify this install, in the order somebody triaging wants
  /// them. Device id is first: it is the one thing that cannot be guessed or
  /// looked up any other way, and it is what unlocks diagnostics for this
  /// handset.
  static Future<List<({String label, String value})>> facts(
    AuthService auth,
  ) async {
    final d = await DeviceReport.gather();
    String s(String k) => d[k]?.toString() ?? '—';
    final session = auth.session;
    return [
      (label: 'Device ID', value: s('deviceId')),
      (label: 'User ID', value: session?.userId ?? '—'),
      (label: 'Username', value: session?.name ?? '—'),
      (label: 'App', value: '${s('appVersion')} (${s('appBuild')})'),
      (label: 'Device', value: '${s('model')} · ${s('manufacturer')}'),
      (
        label: 'System',
        value:
            '${s('os')} ${s('release')}'
            '${d['sdkInt'] != null ? ' (SDK ${s('sdkInt')})' : ''}'
            '${d['oneUi'] != null ? ' · One UI ${s('oneUi')}' : ''}',
      ),
      (label: 'Display', value: '${s('physW')}x${s('physH')} @${s('dpr')}'),
      (label: 'Locale', value: s('locale')),
    ];
  }

  /// One copyable block. What the user pastes if they'd rather type it into a
  /// chat than use the share sheet.
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
      ..writeln('To: $kSupportEmail')
      ..writeln()
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

  /// Opens the share sheet with the note as the message body and any
  /// screenshots attached.
  ///
  /// [origin] is the tapped button's global rect, required for iPad and macOS
  /// popover anchoring and harmless elsewhere.
  static Future<void> send({
    required String body,
    required List<XFile> screenshots,
    required String deviceLabel,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        // Gmail and most mail clients pick this up as the subject line, which
        // is the closest a share sheet gets to prefilling an email.
        subject: 'MonkeyHub problem report — $deviceLabel',
        text: body,
        files: screenshots.isEmpty ? null : screenshots,
        sharePositionOrigin: origin,
      ),
    );
  }

  /// A `mailto:` for the case where the user would rather just write an email.
  ///
  /// Fully prefills recipient, subject and body — the one thing a share sheet
  /// cannot do — at the cost of carrying no attachments, which is why it is the
  /// secondary route and not the primary one.
  static Uri mailto({required String body, required String deviceLabel}) => Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: Uri(
      queryParameters: {
        'subject': 'MonkeyHub problem report — $deviceLabel',
        'body': body,
      },
    ).query,
  );

  /// Encodes the note as a file when a share target refuses long text.
  static XFile asTextFile(String body) => XFile.fromData(
    utf8.encode(body),
    name: 'monkeyhub-report.txt',
    mimeType: 'text/plain',
  );
}
