import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/update/version_compare.dart';

/// [compareVersions] decides whether a user is shown the update prompt at all,
/// and — via `minSupported` — whether they're locked out of the app until they
/// take it. Both failure directions are silent in production: too lenient and
/// nobody is ever told to update, too strict and everyone gets a mandatory
/// prompt they can't dismiss. So the contract is pinned here rather than
/// discovered in the field.
void main() {
  group('numeric, not lexicographic', () {
    test('the double-digit patch that breaks a string compare', () {
      // The whole reason this function exists: "1.3.9".compareTo("1.3.10") > 0.
      expect(compareVersions('1.3.9', '1.3.10'), lessThan(0));
      expect(compareVersions('1.3.10', '1.3.9'), greaterThan(0));
    });

    test('this project has already crossed that boundary twice', () {
      expect(compareVersions('1.3.29', '1.3.30'), lessThan(0));
      expect(compareVersions('1.3.2', '1.3.29'), lessThan(0));
    });

    test('a minor bump beats any patch', () {
      expect(compareVersions('1.3.99', '1.4.0'), lessThan(0));
      expect(compareVersions('1.4.0', '1.3.99'), greaterThan(0));
      expect(compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });
  });

  group('equality is what suppresses the prompt', () {
    test('identical versions', () {
      expect(compareVersions('1.3.29', '1.3.29'), 0);
    });

    test('the pinned +1 build suffix is ignored', () {
      // pubspec carries "1.3.29+1"; PackageInfo.version drops the suffix, but
      // a published row could carry it either way. They must compare equal, or
      // every user gets prompted to install the version they already have.
      expect(compareVersions('1.3.29+1', '1.3.29'), 0);
      expect(compareVersions('1.3.29', '1.3.29+1'), 0);
      expect(compareVersions('1.3.29+1', '1.3.29+7'), 0);
    });

    test('a pre-release suffix is ignored too', () {
      expect(compareVersions('1.3.29-beta', '1.3.29'), 0);
    });

    test('missing segments read as zero', () {
      expect(compareVersions('1.3', '1.3.0'), 0);
      expect(compareVersions('1.3', '1.3.1'), lessThan(0));
      expect(compareVersions('1', '1.0.0'), 0);
    });

    test('whitespace is tolerated', () {
      expect(compareVersions(' 1.3.29 ', '1.3.29'), 0);
    });
  });

  group('malformed input sorts as old rather than throwing', () {
    // An exception here would be caught by UpdateChecker and swallowed, leaving
    // the user silently unprompted. Degrading to 0-valued segments at least
    // keeps a real version on the newer side.
    test('non-numeric segments', () {
      expect(compareVersions('1.x.3', '1.0.3'), 0);
      expect(compareVersions('', '1.0.0'), lessThan(0));
      expect(compareVersions('nonsense', '0.0.1'), lessThan(0));
    });
  });

  group('the mandatory-update comparison', () {
    // How UpdateChecker uses it: current < minSupported → no Later button.
    bool isMandatory(String current, String minSupported) =>
        compareVersions(current, minSupported) < 0;

    test('below the floor is mandatory', () {
      expect(isMandatory('1.3.20', '1.3.25'), isTrue);
    });

    test('exactly at the floor is not', () {
      expect(isMandatory('1.3.25', '1.3.25'), isFalse);
      expect(isMandatory('1.3.25+1', '1.3.25'), isFalse);
    });

    test('above the floor is not', () {
      expect(isMandatory('1.3.26', '1.3.25'), isFalse);
    });
  });
}
