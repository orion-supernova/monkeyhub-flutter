@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: the iOS Share Extension sends WITHOUT the app, which means
/// it is a second implementation of this app's send path — in Swift, in a
/// separate binary, against Convex's HTTP API instead of the socket.
///
/// A second implementation drifts. These read both files and fail when it does,
/// because every failure here is silent at runtime: a renamed mutation argument
/// is a server-side validator error the user sees as "could not send", and a
/// changed function path is a 404 nobody notices until somebody shares a photo.
///
/// Source scans rather than behaviour tests for the obvious reason — the other
/// side is Swift and cannot be imported. Same shape as `upload_cap_test.dart`.
void main() {
  String read(String path) => File(path).readAsStringSync();

  late String convexHttp;
  late String controller;
  late String chatApi;
  late String uploadService;

  setUpAll(() {
    convexHttp = read('ios/ShareExtension/ConvexHTTP.swift');
    controller = read('ios/ShareExtension/ShareViewController.swift');
    chatApi = read('lib/backend/chat_api.dart');
    uploadService = read('lib/media/upload_service.dart');
  });

  group('the extension calls the same Convex functions the app does', () {
    test('messages:send', () {
      expect(controller, contains('"messages:send"'));
      expect(chatApi, contains("'messages:send'"));
    });

    test('files:generateUploadUrl', () {
      expect(convexHttp, contains('"files:generateUploadUrl"'));
      expect(chatApi, contains("'files:generateUploadUrl'"));
    });

    test('and reads the upload response the same way', () {
      // Both sides pull `storageId` out of the POST's JSON body. A rename
      // server-side breaks both, which is fine; a rename in ONE of them is a
      // send that uploads successfully and then attaches nothing.
      expect(convexHttp, contains('json["storageId"]'));
      // Dart pulls it out with a regex rather than a JSON decode, so the key
      // is spelled inside a pattern — match the key itself, not the syntax
      // around it.
      expect(uploadService, contains(r'"storageId"'));
    });
  });

  group('the mutation arguments agree', () {
    // Every argument the Swift side sends must exist in `ChatApi.sendMessage`'s
    // call. Convex validators are strict — an argument the mutation does not
    // declare is rejected outright, so a typo here is a send that always fails.
    const sent = [
      'roomId',
      'userId',
      'content',
      'type',
      'clientId',
      'senderName',
      'mediaStorageId',
      'mediaWidth',
      'mediaHeight',
      'fileName',
      'fileSize',
      'mimeType',
    ];

    // The literal block of the `messages:send` mutation call in Dart.
    late String dartArgs;
    setUpAll(() {
      final start = chatApi.indexOf("_cv.mutation('messages:send'");
      expect(start, greaterThan(-1),
          reason: 'the messages:send call moved or changed shape');
      dartArgs = chatApi.substring(start, chatApi.indexOf('});', start));
    });

    for (final arg in sent) {
      test('"$arg" is one the app sends too', () {
        expect(controller, contains('"$arg"'),
            reason: 'the extension stopped sending $arg');
        expect(dartArgs, contains("'$arg'"),
            reason: '$arg is not an argument ChatApi.sendMessage passes — '
                'Convex rejects an undeclared argument outright');
      });
    }

    test('the message types are the enum wire names', () {
      // `MessageTypeWire.wire` is `name`, so these strings ARE the Dart enum
      // members. A mismatch renders somebody's photo as a document.
      final enums = read('lib/models/enums.dart');
      for (final type in ['image', 'video', 'file', 'text']) {
        expect(enums, contains('  $type,'),
            reason: '"$type" is not a MessageType member any more');
      }
      final staging = read('ios/ShareExtension/Staging.swift');
      expect(staging, contains('return "image"'));
      expect(staging, contains('return "video"'));
      expect(staging, contains('return "file"'));
    });

    test('fileName / fileSize / mimeType ride on documents only', () {
      // The Dart side sets mimeType as `fileName == null ? null : contentType`
      // — i.e. documents only. A photo that carries a fileName renders as a
      // downloadable blob instead of a picture on every client.
      expect(controller, contains('item.messageType == "file"'),
          reason: 'the document-only guard around fileName/fileSize/mimeType '
              'moved or changed shape');
    });
  });

  group('the extension presents a session, like every other caller does', () {
    // The gap this closes. The group above checks that every argument the
    // SWIFT side sends is one the app sends too — which says nothing about an
    // argument the backend REQUIRES and Swift omits. `functions.ts` grew
    // exactly that: a `sessionToken` wrapped around every authenticated
    // function. The Dart client answered it in one place and nothing failed;
    // the extension kept sending the old argument set and every share died on
    //
    //     ArgumentValidationError: Object is missing the required field
    //     `sessionToken`.
    //
    // — after composing a perfect sheet. Nothing in the suite noticed.
    test('spells the identity argument the way Dart does', () {
      final guard = read('lib/auth/session_guard.dart');
      final match = RegExp(r"identityArg = '([^']+)'").firstMatch(guard);
      expect(match, isNotNull,
          reason: 'SessionGuard.identityArg moved or changed shape');
      final arg = match!.group(1)!;
      expect(convexHttp, contains('identityArg = "$arg"'),
          reason: 'the extension signs its calls with a different argument '
              'name than the app does — every send fails validation');
    });

    test('and attaches it to every mutation, not per call site', () {
      // Injected once, exactly like `ConvexBackend._withToken`. A second caller
      // that has to remember is a caller that will not.
      expect(convexHttp, contains('args[identityArg] = sessionToken'));
      // `files:generateUploadUrl` is authenticated too — an attachment share
      // fails at the upload step, before the message is ever built.
      expect(convexHttp, contains('sessionToken: sessionToken'),
          reason: 'the upload leg must present the session as well');
    });

    test('and the app caches a token for it to present', () {
      expect(read('lib/share/share_targets.dart'),
          contains("'sessionToken': sessionToken"),
          reason: 'publishTargets is the only channel the extension has');
      expect(read('ios/Runner/ShareCache.swift'),
          contains('args["sessionToken"] as? String'));
      // A session cached without one offers a Send that can only fail, so it
      // is not cached at all.
      expect(read('ios/Runner/ShareCache.swift'),
          contains('!sessionToken.isEmpty'));
      expect(read('ios/Shared/ShareSession.swift'),
          contains('!session.sessionToken.isEmpty'));
    });

    test('and reads it live, never captured', () {
      // A frozen credential outliving its session is the bug written up in
      // `SessionGuard.noteError` — the extension must cache the token this
      // device holds now, and re-cache it when it rotates.
      expect(read('lib/share/share_targets.dart'),
          contains('SessionStore.instance.token'));
    });
  });

  group('the extension cannot outlive the session', () {
    test('signing out clears the cache the extension sends with', () {
      // The cache holds the user id, which IS this backend\'s credential
      // (there is no ctx.auth anywhere — see backend/convex/feed.ts). Left
      // behind, the next person to pick up the phone could send as the account
      // that signed out, from the share sheet, without unlocking the app.
      final appDelegate = read('ios/Runner/AppDelegate.swift');
      final clearBlock = appDelegate.substring(
        appDelegate.indexOf('case "clearTargets"'),
        appDelegate.indexOf('default:', appDelegate.indexOf('case "clearTargets"')),
      );
      expect(clearBlock, contains('ShareCache.clear()'));
      expect(read('ios/Runner/ShareCache.swift'), contains('ShareSession.clear()'));
    });

    test('the cache is written at the keychain\'s protection class', () {
      // The app holds its session under `first_unlock_this_device`. The file
      // copy must not be readable under weaker terms than the original.
      final session = read('ios/Shared/ShareSession.swift');
      expect(session, contains('completeFileProtectionUntilFirstUserAuthentication'));
      expect(session, contains('isExcludedFromBackup = true'),
          reason: 'a restored backup would carry a signed-in user id onto '
              'another handset');
      expect(read('lib/auth/session_store.dart'),
          contains('first_unlock_this_device'),
          reason: 'the keychain class moved; the file class should follow it');
    });

    test('an empty credential clears rather than writing half a session', () {
      // An extension that found a session missing any one of these would offer
      // a picker whose Send button could only ever fail.
      expect(
        read('ios/Runner/ShareCache.swift'),
        contains('guard !userId.isEmpty, !deploymentUrl.isEmpty, '
            '!sessionToken.isEmpty else {'),
      );
    });
  });

  group('the sheet can always act on the tap it was given', () {
    /// One function's body, from its signature to the first closing brace at
    /// the type's indentation. Nested closures close deeper than that, so this
    /// is the whole function and nothing after it.
    String bodyOf(String source, String signature) {
      final start = source.indexOf(signature);
      expect(start, greaterThan(-1), reason: '$signature moved or was renamed');
      return source.substring(start, source.indexOf('\n    }', start));
    }

    test('Send reports instead of swallowing the tap', () {
      // A share arriving on a signed-out device still carries the donated room
      // id, so Send is live with no session behind it. A bare `return` on that
      // path is a button that does nothing at all — no spinner, no error, no
      // message — which is indistinguishable from a broken extension.
      final send = bodyOf(controller, 'private func send()');
      expect(send, isNot(contains('else { return }')),
          reason: 'every refusal in send() has to reach the user');
      expect(send, contains('model.state = .failed'));
    });

    group('the hand-off to the app', () {
      late String openApp;
      late String openHost;
      setUpAll(() {
        openApp = bodyOf(controller, 'private func openApp()');
        openHost = bodyOf(controller, 'private func openHost(');
      });

      test('completes the request from an answer, not beside the call', () {
        // The bug this replaces: `open` is asynchronous, and calling
        // `completeRequest` on the next line tears the extension down before
        // iOS acts on the request. The symptom is exactly "the sheet appeared
        // and nothing happened" — no error, no log, no app.
        expect(openApp, contains('openHost {'));
        expect(openApp, contains('done()'));
        expect(openHost, isNot(contains('finish()')),
            reason: 'the request is settled by openApp, from the answer '
                'openHost reports — never from inside the asking');
      });

      test('has a route left when the extension context refuses', () {
        // `NSExtensionContext.open` is documented for Today and iMessage
        // extensions ONLY. From a share extension it answers false, which is
        // the whole of "Open in MonkeyHub does not open MonkeyHub".
        expect(openHost, contains('context.open('));
        expect(openHost, contains('scene.open('),
            reason: 'the scene is the only route left, and the only one that '
                'is public API an app extension may call');
      });

      test('and hands the scene no options dictionary', () {
        // `UIScene.open` takes a `UISceneOpenExternalURLOptions`, NOT
        // UIApplication's options dictionary — the two spell the selector
        // identically. Handing it the dictionary crashes the extension
        // outright with `-[__NSDictionary0 universalLinksOnly]: unrecognized
        // selector`, which is worse than the button doing nothing.
        expect(openHost, contains('options: nil'));
      });

      test('and settles even when nothing answers at all', () {
        expect(openApp, contains('asyncAfter'),
            reason: 'on some releases open() never answers; a sheet that never '
                'completes is one the user has to force-quit out of');
      });
    });
  });

  group('the copy outlives the call that started it', () {
    late String staging;
    setUpAll(() => staging = read('ios/ShareExtension/Staging.swift'));

    test('the controller owns the copy in flight', () {
      expect(controller, contains('private var staging: Staging?'),
          reason: 'an operation nobody holds is one ARC is free to deallocate '
              'in the middle of');
    });

    test('and the callbacks hold it too', () {
      // Nothing else points at a Staging once `run` returns — the loads it
      // kicked off are all there is. Captured weakly, the object died before
      // the first provider answered: every staged file discarded, the
      // completion never called, and a share sheet that spins for the whole
      // deadline and then has nothing to send.
      expect(staging, isNot(contains('[weak self]')),
          reason: 'a weak capture here deallocates the copy mid-flight');
    });

    test('and answers on a deadline rather than waiting forever', () {
      // A provider that never calls its completion handler is ordinary rather
      // than exotic — a declined transcode, an iCloud original that will not
      // download — and one of them must not hold the whole sheet.
      expect(staging, contains('deadline: TimeInterval'));
      expect(staging, contains('guard !delivered else { return }'),
          reason: 'the group and the deadline can both fire, and the '
              'completion must run exactly once');
    });
  });
}
