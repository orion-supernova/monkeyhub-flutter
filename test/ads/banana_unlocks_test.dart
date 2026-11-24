import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/ads/banana_wallet.dart';
import 'package:monkeyhub/fight/view/art/art_common.dart' show FightLook;
import 'package:monkeyhub/games/catalog.dart';

void main() {
  final w = BananaWallet.instance;

  setUp(() {
    BananaWallet.debugOffline = true;
    w.owned = {};
    w.prices = {};
    w.child = null;
    w.firstPickReady = false;
    w.firstPackBonus = false;
  });

  test('parses the unlock fields of lifelines:mine', () {
    w.debugApply({
      'balance': 12,
      'owned': ['fighter.mojo', 'game.chess'],
      'firstPickReady': true,
      'firstPackBonus': true,
      'prices': {'fighter.mojo': 55, 'bundle.animals': 400},
      'child': {'ask': true, 'spend': 'all'},
    });
    expect(w.balance, 12);
    expect(w.owns('fighter.mojo'), isTrue);
    expect(w.canSendGame('chess'), isTrue);
    expect(w.canSendGame('checkers'), isFalse);
    expect(w.canSendGame('tictactoe'), isTrue);
    expect(w.firstPickReady && w.firstPackBonus, isTrue);
    expect(w.priceOf('fighter.mojo'), 55);
    expect(w.priceOf('fighter.tank'), 60);
    expect(w.child, (ask: true, spend: 'all'));
    expect(w.childMaySpendOnUnlocks, isTrue);
    w.debugApply({'child': null});
    expect(w.child, isNull);
  });

  test('free things are always owned', () {
    expect(w.ownsFighter(0), isTrue);
    expect(w.ownsFighter(1), isFalse);
    expect(w.ownsStage(0), isTrue);
    expect(w.ownsStage(2), isFalse);
    expect(w.ownsLook(FightLook.cartoon), isTrue);
    expect(w.ownsLook(FightLook.pixel), isFalse);
  });

  test('bundle price is complete-the-set', () {
    expect(w.priceOf('bundle.animals'), 450);
    // One 60 animal owned: 450 * 540 / 600 = 405.
    w.owned = {'fighter.mojo'};
    expect(w.priceOf('bundle.animals'), 405);
    w.owned = {'fighter.mojo', 'fighter.tank', 'fighter.bruno'};
    expect(w.priceOf('bundle.animals'), (450 * 420 / 600).ceil());
    expect(w.ownsItem('bundle.animals'), isFalse);
    // Everything owned: nothing to pay, bundle is owned.
    w.owned = {for (final id in catalogItem('bundle.animals')!.members) id};
    expect(w.priceOf('bundle.animals'), 0);
    expect(w.ownsItem('bundle.animals'), isTrue);
  });

  test('catalog ids, members and prices match the contract', () {
    expect(catalogItem('fighter.golem')!.price, 90);
    expect(catalogItem('fighter.pip')!.price, 60);
    expect(catalogItem('stage.deck')!.price, 40);
    expect(catalogItem('game.chess')!.price, 150);
    expect(catalogItem('look.pixel')!.price, 120);
    expect(catalogItem('bundle.animals')!.members.length, 10);
    expect(catalogItem('bundle.legends')!.members.length, 5);
    expect(catalogItem('bundle.stages')!.members.length, 5);
    expect(catalogItem('bundle.fist')!.members.length, 22);
    expect(catalogItem('bundle.gamenight')!.members.length, 6);
    expect(isFreeGame('fight'), isTrue);
    expect(isFreeGame('chess'), isFalse);
    expect(bundleFor('fighter.golem')!.id, 'bundle.legends');
    expect(fighterItemId(19), 'fighter.golem');
    expect(stageItemId(1), 'stage.temple');
    expect(gameItemId('race'), 'game.race');
  });
}
