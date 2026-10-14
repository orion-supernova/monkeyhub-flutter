import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/games/ranking.dart';

/// The one tie rule every board uses: an exact tie shares the place
/// ("1, 1, 3"), and a tie is listed A to Z by name.
void main() {
  group('rankedPlaces', () {
    bool same(int a, int b) => a == b;

    test('competition places: a tie shares, the next skips', () {
      expect(rankedPlaces([5, 5, 3, 2, 2, 2, 1], same), [1, 1, 3, 4, 4, 4, 7]);
    });

    test('no ties is 1..n, and empty is empty', () {
      expect(rankedPlaces([9, 8, 7], same), [1, 2, 3]);
      expect(rankedPlaces(<int>[], same), isEmpty);
    });

    test('everyone tied is everyone first', () {
      expect(rankedPlaces([4, 4, 4], same), [1, 1, 1]);
    });
  });

  group('sameTimedScore', () {
    test('the same whole second is a tie; milliseconds never split it', () {
      expect(
        sameTimedScore(aSolved: true, aMs: 61000, bSolved: true, bMs: 61999),
        isTrue,
      );
      expect(
        sameTimedScore(aSolved: true, aMs: 61999, bSolved: true, bMs: 62000),
        isFalse,
      );
    });

    test('two give-ups tie; a solve never ties a give-up', () {
      expect(
        sameTimedScore(aSolved: false, aMs: null, bSolved: false, bMs: null),
        isTrue,
      );
      expect(
        sameTimedScore(aSolved: true, aMs: 1000, bSolved: false, bMs: null),
        isFalse,
      );
    });
  });

  group('compareNames', () {
    test('ignores case', () {
      expect(compareNames('ada', 'ADA'), 0);
      expect(compareNames('bo', 'Ada'), greaterThan(0));
    });

    test('folds accents, Turkish İ and ı included', () {
      expect(compareNames('Émile', 'emile'), 0);
      expect(compareNames('İpek', 'ipek'), 0);
      expect(compareNames('Işık', 'isik'), 0);
      expect(compareNames('Çağla', 'cagla'), 0);
      expect(compareNames('Ömer', 'Zeynep'), lessThan(0));
      // A decomposed accent (e + combining acute) reads like the plain letter.
      expect(compareNames('René', 'Rene'), 0);
    });

    test('sorts a list A to Z', () {
      final names = ['zoe', 'Ümit', 'İlker', 'ada', 'Bora'];
      names.sort(compareNames);
      expect(names, ['ada', 'Bora', 'İlker', 'Ümit', 'zoe']);
    });
  });

  group('rankByPlace', () {
    test('computes places and lists each tie A to Z', () {
      final rows = [
        (name: 'Zed', score: 10),
        (name: 'ada', score: 10),
        (name: 'Mia', score: 8),
        (name: 'Öykü', score: 5),
        (name: 'Can', score: 5),
      ];
      final out = rankByPlace(
        rows,
        sameScore: (a, b) => a.score == b.score,
        nameOf: (r) => r.name,
      );
      expect([for (final e in out) e.row.name], [
        'ada', 'Zed', 'Mia', 'Can', 'Öykü',
      ]);
      expect([for (final e in out) e.place], [1, 1, 3, 4, 4]);
    });

    test("uses the data's places when every row carries one", () {
      final rows = [
        (name: 'b', place: 1),
        (name: 'a', place: 1),
        (name: 'c', place: 3),
      ];
      final out = rankByPlace(
        rows,
        // Would say nobody ties, but the server's places win.
        sameScore: (a, b) => false,
        nameOf: (r) => r.name,
        placeOf: (r) => r.place,
      );
      expect([for (final e in out) e.row.name], ['a', 'b', 'c']);
      expect([for (final e in out) e.place], [1, 1, 3]);
    });

    test('a row without a place falls back to computing all of them', () {
      final rows = [(name: 'b', place: 1), (name: 'a', place: null)];
      final out = rankByPlace(
        rows,
        sameScore: (a, b) => true,
        nameOf: (r) => r.name,
        placeOf: (r) => r.place,
      );
      expect([for (final e in out) e.place], [1, 1]);
      expect([for (final e in out) e.row.name], ['a', 'b']);
    });
  });
}
