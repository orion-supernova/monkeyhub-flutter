import 'package:flutter/widgets.dart';

import '../theme/theme_scope.dart';
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
/// No text, and that is not an omission — a bare spinner is what the avatar
/// flow in `ProfileScreen` already uses, and it needs no translating. Anyone
/// adding a label should know this widget is mounted inside a route's own
/// `Stack`, not an `OverlayEntry`: hoist it into an overlay and the [Text] would
/// have no [DefaultTextStyle] above it and Flutter would paint its debug
/// fallback — yellow underlines on double-struck red.
class BusyScrim extends StatelessWidget {
  const BusyScrim({super.key});

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
        color: theme.background.withValues(alpha: 0.72),
        child: Center(child: PhotoSpinner(color: theme.accent)),
      ),
    );
  }
}
