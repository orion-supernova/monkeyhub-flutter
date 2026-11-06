import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/app_toast.dart';

/// The buzz that confirms a copy.
enum CopyHaptic { none, selection, light }

/// Copies [text] to the clipboard, then says so.
///
/// A copy is otherwise completely silent: the clipboard changes somewhere the
/// user cannot see. So: the clipboard write (awaited, errors caught: web can
/// refuse without a gesture, and "copied" must never be shown for a copy that
/// did not happen), a [haptic] buzz, and [toast] over everything, modal
/// sheets included, when given.
///
/// The toast handle is taken from [context] before the await, so a screen that
/// closes itself mid-copy still gets to confirm.
Future<void> copyText(
  BuildContext context,
  String text, {
  String? toast,
  ToastTone tone = ToastTone.success,
  CopyHaptic haptic = CopyHaptic.none,
}) async {
  final toaster = AppToast.of(context);
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (e) {
    debugPrint('copy failed: $e');
    return;
  }
  switch (haptic) {
    case CopyHaptic.none:
      break;
    case CopyHaptic.selection:
      HapticFeedback.selectionClick();
    case CopyHaptic.light:
      HapticFeedback.lightImpact();
  }
  if (toast != null) toaster.show(toast, tone: tone);
}
