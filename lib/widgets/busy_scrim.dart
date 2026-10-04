import 'package:flutter/material.dart'
    show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../theme/theme_scope.dart';
import 'ios_kit.dart' show groupedFooterStyle;
import 'photo_chrome.dart';

/// A dim over the whole surface with one spinner in it, for the stretch of a
/// flow where the app is working and there is nothing else on screen to say so.
///
/// Exists because of one specific hole. `ImagePicker.pickImage` is passed an
/// `imageQuality`, which forces the plugin to decode and re-encode the chosen
/// asset — seconds for a 12 megapixel HEIC — and it does that work *after* the
/// native picker sheet has already dismissed. So the user tapped a photo,
/// watched the sheet slide away, and was returned to an unchanged chat screen
/// for several seconds with no way to tell whether their tap had registered.
/// Half of them tapped again.
///
/// Deliberately **not** in `photo_chrome.dart`. That file's own docstring is
/// explicit that its palette is fixed neutral dark *because the backdrop is an
/// arbitrary photograph*. This scrim goes over the app's own surfaces, where the
/// theme is the backdrop, so it reads from the theme. Putting it there would
/// have made that file's central claim false.
///
/// No text by default — a bare spinner is what the avatar flow in
/// `ProfileScreen` uses, and it needs no translating. An optional [label] goes
/// under the spinner for a longer sequence that is worth naming (switching
/// servers). The label carries its own [DefaultTextStyle] and a transparent
/// [Material], so it never paints Flutter's debug fallback — yellow underlines
/// — even when the scrim is hoisted into an overlay.
class BusyScrim extends StatelessWidget {
  const BusyScrim({super.key, this.label, this.opacity = 0.72});

  /// One quiet line under the spinner. Null for the bare spinner.
  final String? label;

  /// How much of the page shows through. 0.72 by default; a destructive
  /// sequence that wants the page out of the way entirely goes higher.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Swallows taps rather than ignoring them: an IgnorePointer would let a
    // second tap through to the composer's attach button underneath, which is
    // the very thing the flow is busy with. The re-entrancy flag on the caller
    // is the real guard; this is the belt behind it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: theme.background.withValues(alpha: opacity),
        child: Center(
          child: label == null
              ? PhotoSpinner(color: theme.accent)
              : Material(
                  type: MaterialType.transparency,
                  child: DefaultTextStyle(
                    style: groupedFooterStyle(theme),
                    textAlign: TextAlign.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhotoSpinner(color: theme.accent),
                          const SizedBox(height: 16),
                          Text(label!),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
