import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_classifier.dart';
import 'package:monkeyhub/drop/drop_copy.dart';
import 'package:monkeyhub/drop/drop_item.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/file_meta.dart';

/// What this pins: the sentence in the verdict chip, and the one condition
/// under which the post-drop notice stays silent.
///
/// There are a dozen plausible wrong answers for "three photos and a folder
/// over a room a guardian has restricted", and only one of them is the one a
/// user can act on. The ordering inside [dropLandingNotice] is the ordering of
/// regret — a file that will not arrive at all outranks one that arrives
/// looking different — and it is the kind of thing that gets quietly reordered
/// by a later edit.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  DropCandidate file(String name, {int? size = 1024}) =>
      DropCandidate(name: name, size: size);

  DropPlan planOf(List<DropCandidate> items, {DropPolicy? policy}) => planFor(
        DropSnapshot(items: items, namesKnown: true, sizesKnown: true),
        policy: policy ?? DropPolicy.permissive,
      );

  group('the headline', () {
    test('counts a single kind by its own word', () {
      expect(
        dropMessage(l10n, plan: planOf([file('a.png')])).headline,
        l10n.dropSendPhotos(1),
      );
      expect(
        dropMessage(l10n, plan: planOf([file('a.png'), file('b.jpg')])).headline,
        l10n.dropSendPhotos(2),
      );
      expect(
        dropMessage(l10n, plan: planOf([file('a.pdf')])).headline,
        l10n.dropSendFiles(1),
      );
    });

    test('falls back to items for a mix', () {
      expect(
        dropMessage(l10n, plan: planOf([file('a.png'), file('b.pdf')])).headline,
        l10n.dropSendItems(2),
      );
    });

    test('counts only what will actually be sent', () {
      // Two pictures and a folder is "send 2 photos", not "send 3 items". The
      // folder is the caveat, not part of the promise.
      final plan = planOf([
        file('a.png'),
        file('b.png'),
        const DropCandidate(name: 'Exports', isDirectory: true),
      ]);
      expect(dropMessage(l10n, plan: plan).headline, l10n.dropSendPhotos(2));
    });

    test('text is offered as a draft, not as a send', () {
      final plan = planFor(const DropSnapshot(carriesText: true));
      expect(dropMessage(l10n, plan: plan).headline, l10n.dropSendText);
      final link = planFor(const DropSnapshot(carriesLink: true));
      expect(dropMessage(l10n, plan: link).headline, l10n.dropSendLink);
    });
  });

  group('with no zone under the pointer', () {
    test('says where to aim, and refuses', () {
      final message = dropMessage(
        l10n,
        plan: planOf([file('a.png')]),
        hasTarget: false,
      );
      expect(message.headline, l10n.dropHintNoTarget);
      expect(message.tone, DropTone.refuse);
      // No target means no name to carry, whatever the caller passed.
      expect(message.detail, isNull);
    });
  });

  group('the second line', () {
    test('names the target when there is nothing to warn about', () {
      final message = dropMessage(
        l10n,
        plan: planOf([file('a.png')]),
        targetLabel: 'Alice',
      );
      expect(message.detail, l10n.dropTargetTo('Alice'));
      expect(message.tone, DropTone.accept);
    });

    test('a caveat outranks the target name', () {
      // Only one line is available and only one of the two is actionable.
      final message = dropMessage(
        l10n,
        plan: planOf([file('a.png'), file('clip.mkv')]),
        targetLabel: 'Alice',
      );
      expect(message.detail, l10n.dropNoticeAsFile(1));
      expect(message.tone, DropTone.caution);
    });

    test('a file that will not arrive outranks one that will look different', () {
      final message = dropMessage(
        l10n,
        plan: planOf([
          file('clip.mkv'),
          file('huge.mov', size: kMaxFileUploadBytes + 1),
        ]),
      );
      expect(
        message.detail,
        l10n.dropNoticeTooLarge(1, formatFileSize(kMaxFileUploadBytes)),
      );
    });

    test('a refusal that is the whole story becomes the headline', () {
      final message = dropMessage(
        l10n,
        plan: planOf([const DropCandidate(name: 'Exports', isDirectory: true)]),
      );
      expect(message.headline, l10n.dropNoticeFolder);
      expect(message.tone, DropTone.refuse);
    });

    test('a restricted room says so rather than counting files', () {
      final message = dropMessage(
        l10n,
        plan: planOf([file('a.png')], policy: const DropPolicy(allowFiles: false)),
        targetLabel: 'Alice',
      );
      expect(message.headline, l10n.dropNoticeNotAllowed);
      expect(message.tone, DropTone.refuse);
    });
  });

  group('the notice after the drop', () {
    test('is silent for a drop with nothing to report', () {
      // The whole point: the transcript is already the confirmation, and a
      // toast on every successful send is noise.
      expect(dropLandingNotice(l10n, planOf([file('a.png')])), isNull);
      expect(dropLandingNotice(l10n, planOf([file('a.pdf')])), isNull);
    });

    test('reports a downgrade, which on web is the first chance to', () {
      expect(
        dropLandingNotice(l10n, planOf([file('clip.mkv')])),
        l10n.dropNoticeAsFile(1),
      );
    });

    test('reports a fragile format', () {
      expect(
        dropLandingNotice(l10n, planOf([file('IMG.HEIC')])),
        l10n.dropNoticeFragile(1),
      );
    });

    test('reports the cap with the cap in it', () {
      expect(
        dropLandingNotice(
          l10n,
          planOf([file('huge.mov', size: kMaxFileUploadBytes + 1)]),
        ),
        l10n.dropNoticeTooLarge(1, formatFileSize(kMaxFileUploadBytes)),
      );
    });

    test('reports empty files as skipped', () {
      expect(
        dropLandingNotice(l10n, planOf([file('nothing.txt', size: 0)])),
        l10n.dropNoticeEmpty(1),
      );
    });
  });

  group('the batch that did not fit', () {
    test('outranks a folder, because it is the surprising one', () {
      // A folder is something the user already knows cannot be sent; a file
      // left out of the tail of their own selection is not.
      final plan = planOf([
        for (var i = 0; i < kMaxDropItems; i++) file('f$i.png'),
        const DropCandidate(name: 'Exports', isDirectory: true),
        file('left-out.png'),
      ]);
      expect(dropLandingNotice(l10n, plan), l10n.dropNoticeBatchFull(1));
    });

    test('still ranks below a file that is simply too large', () {
      final plan = planOf([
        for (var i = 0; i < kMaxDropItems; i++) file('f$i.png'),
        file('huge.mov', size: kMaxFileUploadBytes + 1),
        file('left-out.png'),
      ]);
      expect(
        dropLandingNotice(l10n, plan),
        l10n.dropNoticeTooLarge(1, formatFileSize(kMaxFileUploadBytes)),
      );
    });
  });

  group('the word on a card', () {
    test('every kind has one, including the one we do not know', () {
      for (final kind in DropKind.values) {
        expect(dropKindWord(l10n, kind), isNotEmpty, reason: '$kind');
      }
      // An unknown file is still called a file to the reader: "unknown" is an
      // honest internal state and a useless label.
      expect(dropKindWord(l10n, DropKind.unknown), l10n.dropKindFile);
    });
  });
}
