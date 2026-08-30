import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// The floors `FormattingSurface` promises, asserted on every bubble surface
/// the app can paint — 13 themes × incoming/outgoing.
///
/// This is the test that would have caught the defect it was written for: the
/// old `ink @ 8%` / `accentInk @ 14%` code wash measured 1.27:1 and 1.21:1 on
/// Midnight, and nothing in the suite noticed for as long as it shipped. A
/// fourteenth theme now has to clear the same bar to land.
///
/// Colour getters only — never `codeStyle`, which pulls GoogleFonts and would
/// turn a millisecond of arithmetic into a font resolution per theme.
void main() {
  double contrast(Color a, Color b) => debugFormattingContrast(a, b);

  /// Formats a colour the way the failure message needs to read.
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  for (final theme in ThemeController.all) {
    for (final isMine in const [false, true]) {
      final side = isMine ? 'outgoing' : 'incoming';
      final label = '${theme.name} ($side)';

      test('$label — inline code chip is legible', () {
        final bubble = theme.bubbleFill(isMine: isMine);
        final fill = theme.codeBackground(isMine: isMine);
        final border = theme.codeBorder(isMine: isMine);
        final codeInk = isMine ? theme.accentInk : theme.ink;

        expect(
          contrast(fill, bubble),
          greaterThanOrEqualTo(1.5),
          reason: 'chip fill ${hex(fill)} on bubble ${hex(bubble)} — a wash '
              'this close to the bubble is the original defect',
        );
        expect(
          contrast(border, bubble),
          greaterThanOrEqualTo(2.5),
          reason: 'chip border ${hex(border)} on bubble ${hex(bubble)} — the '
              'edge is what carries the chip on dark themes',
        );
        expect(
          contrast(border, fill),
          greaterThanOrEqualTo(1.3),
          reason: 'border ${hex(border)} vs fill ${hex(fill)} — if these '
              'collapse the chip is one flat patch with no edge',
        );
        expect(
          contrast(codeInk, fill),
          greaterThanOrEqualTo(4.5),
          reason: 'code text ${hex(codeInk)} on chip ${hex(fill)} — the chip '
              'must not eat the legibility of the code it holds',
        );

        // Fill and border must sit on the SAME side of the bubble. When they
        // split — Vault Noir once took a darker fill under a lighter border —
        // the chip paints a pale outline around a dark well and stops reading
        // as one material.
        final lb = bubble.computeLuminance();
        expect(
          (fill.computeLuminance() - lb).sign,
          border.computeLuminance().compareTo(lb).sign,
          reason: 'fill ${hex(fill)} and border ${hex(border)} straddle bubble '
              '${hex(bubble)} — they must both darken or both lighten',
        );
      });

      test('$label — spoiler dust registers on the bubble', () {
        final bubble = theme.bubbleFill(isMine: isMine);
        final dust = theme.spoilerDust(isMine: isMine);

        // There is no plate: the dust sits directly on the bubble's own
        // ground, so this is the only contrast the veil has.
        expect(
          contrast(dust, bubble),
          greaterThan(3.0),
          reason: 'dust ${hex(dust)} on bubble ${hex(bubble)} — sub-pixel '
              'motes vanish below this',
        );
      });
    }
  }

  test('media captions get a fixed neutral, not the bubble', () {
    // Over a photograph no palette colour is the ground, so the dust must
    // ignore the theme entirely.
    final dusts = <Color>{};
    for (final theme in ThemeController.all) {
      for (final isMine in const [false, true]) {
        dusts.add(theme.spoilerDust(isMine: isMine, onMedia: true));
      }
    }
    expect(dusts, hasLength(1));
    expect(dusts.single, const Color(0xFFFFFFFF));
  });

  test('bubbleFill resolves an opaque colour for every theme', () {
    for (final theme in ThemeController.all) {
      for (final isMine in const [false, true]) {
        for (final ephemeral in const [false, true]) {
          final fill =
              theme.bubbleFill(isMine: isMine, ephemeral: ephemeral);
          expect(
            fill.a,
            1.0,
            reason: '${theme.name} bubbleFill must be composited over the '
                'page background, not left translucent',
          );
        }
      }
    }
  });
}
