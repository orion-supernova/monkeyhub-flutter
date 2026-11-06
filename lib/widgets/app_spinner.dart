import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../ui/foundation/ui_kit.dart';
import '../ui/kits/material/material_kit_theme.dart';

/// THE indeterminate spinner: iOS's spoked [CupertinoActivityIndicator] in
/// every kit but Material, which draws a [CircularProgressIndicator].
///
/// [radius] is the Cupertino radius (10 by default); the Material ring is the
/// same overall size, so swapping kits never moves the layout around it.
///
/// Call sites that still build a bare [CupertinoActivityIndicator] keep the
/// iOS spinner on Android; migrate them to this one as they are touched.
class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.color, this.radius = 10});

  /// The spinner's colour; null takes the ambient one.
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) => KitSwitch(
    glass: (context) => CupertinoActivityIndicator(color: color, radius: radius),
    material: (context) => MaterialKitScope(
      child: SizedBox.square(
        dimension: radius * 2,
        child: CircularProgressIndicator(
          strokeWidth: (radius / 4).clamp(2.0, 3.0),
          color: color,
        ),
      ),
    ),
  );
}
