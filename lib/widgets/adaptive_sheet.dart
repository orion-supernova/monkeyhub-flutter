import 'package:flutter/material.dart';

import '../theme/layout.dart';

/// Presents modal content adaptively: a bottom sheet on compact (phone)
/// windows, a centered modal dialog on wider (desktop/web) windows — where a
/// panel sliding up from the bottom of a large window feels out of place.
///
/// Signature mirrors [showModalBottomSheet] so migration is mechanical: most
/// call sites just swap the function name and drop the now-default
/// `backgroundColor`/`isScrollControlled` arguments. The existing sheet content
/// widgets already build their own themed, rounded container, which reads fine
/// as a centered card too.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color backgroundColor = Colors.transparent,
  bool useRootNavigator = false,
  double maxWidth = 460,
}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Content widgets are authored for a full-width bottom sheet; give them
        // bounded height and let them scroll internally if the viewport is
        // short, so nothing overflows in the centered form.
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: builder(ctx),
          ),
        ),
      ),
    ),
  );
}
