import 'package:flutter/widgets.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import '../theme/vanish_palette.dart';
import 'message_stamp.dart';
import 'vanish_ring.dart';
import 'vanish_scope.dart';

/// The vanish mark for [message]'s stamp, or null when it is not a vanishing
/// message. One helper for the in-bubble stamp and the external meta row, so
/// the two can never disagree.
Widget? vanishMarkFor(
  BuildContext context, {
  required ChatMessage message,
  required bool isMine,
  required StampTone tone,
  required AppTheme theme,
}) {
  if (message.vanishUntil == null) return null;
  // The ink the stamp's own loud text uses, so the mark reads on whatever it
  // sits on: violet on an incoming bubble or the bare surface, the outgoing
  // ink on the violet bubble, white over a photo.
  final color = switch (tone) {
    StampTone.onBubble => VanishPalette(theme).vanish,
    StampTone.onSurface => VanishPalette(theme).vanish,
    StampTone.onAccent => theme.accentInk,
    StampTone.onMedia => const Color(0xFFFFFFFF),
  };
  final style = theme.caption.copyWith(
    fontSize: 11.5,
    height: 1.0,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return VanishStampMark(
    message: message,
    isMine: isMine,
    color: color,
    style: style,
    controller: VanishScope.maybeOf(context)?.controller,
  );
}
