import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every icon handed to a component with a native skin needs an SF Symbol in
/// `_symbols` (lib/ui/native/native_control.dart). Without one that control
/// silently drops to its Flutter twin, and beside native neighbours it reads
/// as a different button ("Sessize al" on a profile, 2026-11-08). Source
/// scan, so it covers screens no widget test pumps.
void main() {
  test('every icon given to a native-capable component has an SF Symbol', () {
    final table = File('lib/ui/native/native_control.dart').readAsStringSync();
    final mapped = RegExp(r"CupertinoIcons\.(\w+):\s*'")
        .allMatches(table)
        .map((m) => m[1]!)
        .toSet();
    // Same IconData under another name (a const map cannot hold both).
    const aliases = {'videocam_fill': 'video_camera_solid'};
    const components = [
      'QuickAction', 'QuickActionTile', 'ProfileActionTile',
      'GlassIconButton', 'GlassCloseButton', 'GlassBackButton',
      'GlassPillButton', 'RowPillButton', 'CallGlyphButton',
    ];
    final call = RegExp(r'\b(' + components.join('|') + r')(?:\.\w+)?\(');
    final icon = RegExp(
      r'icon:\s*(?:[^,]*?\?\s*)?CupertinoIcons\.(\w+)'
      r'(?:\s*:\s*CupertinoIcons\.(\w+))?',
    );
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        final end = (m.end + 600).clamp(0, src.length);
        final hit = icon.firstMatch(src.substring(m.end, end));
        if (hit == null) continue;
        for (final name in [hit[1], hit[2]].whereType<String>()) {
          final n = aliases[name] ?? name;
          if (!mapped.contains(n)) missing.add('${f.path}: ${m[1]} $name');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'Add these to _symbols in native_control.dart');
  });
}
