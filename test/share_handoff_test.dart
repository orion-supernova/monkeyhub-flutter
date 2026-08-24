@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/invites/invite_link.dart';
import 'package:monkeyhub/media/file_meta.dart';

/// What this pins: the two constants the share feature duplicates across three
/// languages, and the one URL that must never be mistaken for an invite.
///
/// Source scans rather than behaviour tests, for the same reason
/// `upload_cap_test.dart` is one: the other two copies live in Kotlin and Swift
/// and cannot be imported. A drift between them fails silently — a share sheet
/// that dismisses to nothing, or a join screen for a room that never existed.
void main() {
  group('the share handoff URL is not an invite', () {
    // `parseInviteLink`'s last resort is "treat whatever is left as a typed
    // code", so an unrecognised URL does not return null — it returns a
    // plausible-looking InviteLink. Every spelling the platform might report
    // `monkeyhub://share/open` as has to be refused explicitly.
    //
    // If these ever start passing an InviteLink through, the symptom is that
    // sharing a photo on iOS opens a join screen instead of a chat picker.
    for (final raw in [
      'monkeyhub://share/open',
      'monkeyhub://share',
      'MONKEYHUB://SHARE/OPEN',
      '/share/open',
      '/share',
      'share/open',
    ]) {
      test('refuses "$raw"', () {
        expect(parseInviteLink(raw), isNull);
      });
    }

    test('still accepts a real invite in both spellings', () {
      // The guard is narrow on purpose: it must not have cost the fallback door
      // that exists for devices where App Link verification failed.
      expect(parseInviteLink('monkeyhub://join/$kExampleInviteCode')?.code,
          kExampleInviteCode);
      expect(parseInviteLink('$kInviteSiteUrl/j/$kExampleInviteCode')?.code,
          kExampleInviteCode);
      expect(parseInviteLink(kExampleInviteCode)?.code, kExampleInviteCode);
    });

    test('the segment the guard matches is the one Swift opens', () {
      final swift = File('ios/Shared/ShareGroup.swift').readAsStringSync();
      final match =
          RegExp(r'hostURL\s*=\s*URL\(string:\s*"([^"]+)"').firstMatch(swift);
      expect(match, isNotNull,
          reason: 'ShareGroup.hostURL moved or changed shape');

      final url = Uri.parse(match!.group(1)!);
      expect(url.scheme, kInviteScheme,
          reason: 'the extension reuses the invite scheme; if that changes, '
              'the URL needs its own CFBundleURLTypes entry');
      expect(url.host, kSharePathSegment,
          reason: 'Dart refuses this exact first segment. A URL the app sends '
              'itself that Dart does not recognise opens a join screen.');
    });
  });

  group('the upload cap agrees in all three languages', () {
    // Enforced three times because the decision has to be made three times:
    // Dart refuses at the composer, and both native halves refuse BEFORE the
    // copy so a two-gigabyte video is never written to the user's disk to be
    // rejected a second later.
    //
    // A drift is invisible until somebody shares a large file: a native cap
    // that is higher stages bytes Dart then refuses, and one that is lower
    // silently drops files Dart would have sent.
    test('Kotlin', () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/walhallaa/chattest20241220/ShareIntake.kt',
      ).readAsStringSync();
      final match = RegExp(
        r'MAX_UPLOAD_BYTES\s*=\s*(\d+)L?\s*\*\s*1024\s*\*\s*1024',
      ).firstMatch(kotlin);
      expect(match, isNotNull,
          reason: 'ShareIntake.MAX_UPLOAD_BYTES moved or changed shape');
      expect(int.parse(match!.group(1)!) * 1024 * 1024, kMaxFileUploadBytes);
    });

    test('Swift', () {
      final swift = File('ios/Shared/ShareGroup.swift').readAsStringSync();
      final match = RegExp(
        r'maxUploadBytes:\s*Int64\s*=\s*(\d+)\s*\*\s*1024\s*\*\s*1024',
      ).firstMatch(swift);
      expect(match, isNotNull,
          reason: 'ShareGroup.maxUploadBytes moved or changed shape');
      expect(int.parse(match!.group(1)!) * 1024 * 1024, kMaxFileUploadBytes);
    });
  });

  group('the App Group id agrees across all three files', () {
    // The single quietest failure in this feature. A mismatch builds, signs and
    // installs; `containerURL` then returns nil at runtime with no error
    // anywhere, and the share sheet dismisses to nothing.
    String? groupIn(String path, RegExp pattern) {
      final source = File(path).readAsStringSync();
      return pattern.firstMatch(source)?.group(1);
    }

    test('Swift, the app entitlements and the extension entitlements match', () {
      final swift = groupIn(
        'ios/Shared/ShareGroup.swift',
        RegExp(r'identifier\s*=\s*"(group\.[^"]+)"'),
      );
      expect(swift, isNotNull, reason: 'ShareGroup.identifier moved');

      for (final path in [
        'ios/Runner/Runner.entitlements',
        'ios/Runner/RunnerRelease.entitlements',
        'ios/ShareExtension/ShareExtension.entitlements',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('com.apple.security.application-groups'),
          isTrue,
          reason: '$path lost the App Groups entitlement',
        );
        expect(
          source.contains('<string>$swift</string>'),
          isTrue,
          reason: '$path does not list $swift',
        );
      }
    });
  });

  group('the Android share entry survives an alternate launcher icon', () {
    // `applyAlternateIcon` DISABLES .MainActivity whenever one of the seventeen
    // <activity-alias> icons is active, and a disabled component resolves to
    // nothing. Two consequences, both of which look like "the share sheet
    // forgot about us" and neither of which any build step catches.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('ACTION_SEND is on the activity nothing ever disables', () {
      final shareActivity = RegExp(
        r'<activity[^>]*android:name="\.ShareTargetActivity"[\s\S]*?</activity>',
      ).firstMatch(manifest);
      expect(shareActivity, isNotNull,
          reason: 'ShareTargetActivity is the stable door into the share '
              'sheet — see its class doc');
      expect(shareActivity!.group(0), contains('android.intent.action.SEND'));
      expect(
        shareActivity.group(0),
        contains('android.intent.action.SEND_MULTIPLE'),
      );
    });

    test('the shortcuts meta-data is on MainActivity AND every alias', () {
      // The system reads `android.app.shortcuts` from whichever component is
      // the CURRENT launcher entry. Miss one alias and direct share silently
      // stops working for whoever picked that icon.
      final launchers = RegExp(
        r'<(activity|activity-alias)\b[\s\S]*?</\1>',
      )
          .allMatches(manifest)
          .map((m) => m.group(0)!)
          .where((block) => block.contains('android.intent.category.LAUNCHER'))
          .toList();

      expect(launchers, isNotEmpty);
      for (final block in launchers) {
        final name = RegExp(r'android:name="([^"]+)"').firstMatch(block)?.group(1);
        expect(
          block,
          contains('android:name="android.app.shortcuts"'),
          reason: '$name is a launcher entry with no share-target declaration',
        );
      }
    });

    test('the share-target names ShareTargetActivity', () {
      final xml =
          File('android/app/src/main/res/xml/share_targets.xml').readAsStringSync();
      expect(
        xml,
        contains(
          'android:targetClass="com.walhallaa.chattest20241220.ShareTargetActivity"',
        ),
      );
    });

    test('the share-target category matches the one the shortcuts carry', () {
      // Two halves of the same string. A shortcut whose category does not match
      // is a launcher shortcut and nothing else — it never appears in a share
      // sheet, with no error anywhere.
      final xml =
          File('android/app/src/main/res/xml/share_targets.xml').readAsStringSync();
      final kotlin = File(
        'android/app/src/main/kotlin/com/walhallaa/chattest20241220/ShareShortcuts.kt',
      ).readAsStringSync();
      final category = RegExp(r'CATEGORY\s*=\s*"([^"]+)"').firstMatch(kotlin)?.group(1);
      expect(category, isNotNull,
          reason: 'ShareShortcuts.CATEGORY moved or changed shape');
      expect(xml, contains('<category android:name="$category" />'));
    });
  });
}
