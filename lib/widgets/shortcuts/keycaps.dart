import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../keyboard/app_shortcuts.dart';
import '../../theme/theme_scope.dart';

/// A chord drawn as keycaps: ⌘ K as two small rounded keys, the way macOS
/// menus and Apple's own shortcut sheets print them. The ONE way a shortcut is
/// shown anywhere in the app (peek, panel, palette, hover hints), so a chord
/// reads the same wherever someone meets it.
class Keycaps extends StatelessWidget {
  const Keycaps(this.combo, {super.key, this.size = KeycapSize.regular, this.color});

  final KeyCombo combo;
  final KeycapSize size;

  /// Ink for the glyphs and the key outline. Defaults to the theme's muted
  /// ink; a dark hover pill passes white.
  final Color? color;

  /// The chord for [def] as printed: its first combo.
  static Widget forDef(ShortcutDef def, {KeycapSize size = KeycapSize.regular, Color? color}) =>
      Keycaps(def.chords.first, size: size, color: color);

  @override
  Widget build(BuildContext context) {
    final caps = combo.caps();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < caps.length; i++) ...[
          if (i > 0) SizedBox(width: size == KeycapSize.small ? 2 : 3),
          Keycap(caps[i], size: size, color: color),
        ],
      ],
    );
  }
}

enum KeycapSize { small, regular }

class Keycap extends StatelessWidget {
  const Keycap(this.glyph, {super.key, this.size = KeycapSize.regular, this.color});

  final String glyph;
  final KeycapSize size;
  final Color? color;

  /// Glyphs drawn as icons: ↩ and ⇥ are missing from several system UI
  /// fonts (the web's and Windows' among them) and fall back to a tofu box.
  static const _icons = <String, IconData>{
    '↩': Icons.keyboard_return_rounded,
    '⇥': Icons.keyboard_tab_rounded,
    '⌫': Icons.backspace_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = color ?? theme.inkSoft;
    final small = size == KeycapSize.small;
    final h = small ? 18.0 : 22.0;
    // A single symbol (⌘, ↑, K) sits in a square key; a word (Esc, Space,
    // Ctrl) gets a wider one. Symbols are set a touch larger: at caption size
    // ⌘ and ⇧ read as smudges.
    final symbol = glyph.runes.length == 1;
    return Container(
      constraints: BoxConstraints(minWidth: h, minHeight: h),
      height: h,
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(small ? 4 : 5),
        border: Border.all(color: ink.withValues(alpha: 0.16), width: 0.5),
      ),
      child: _icons[glyph] != null
          ? Icon(_icons[glyph], size: small ? 12 : 14, color: ink)
          : Text(
        glyph,
        maxLines: 1,
        style: theme.caption.copyWith(
          color: ink,
          fontSize: small ? (symbol ? 11.5 : 10.5) : (symbol ? 13 : 11.5),
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
