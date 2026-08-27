import 'package:flutter/widgets.dart';

import '../models/chat_message.dart';

/// Lets a photo in the transcript open the room's whole gallery without knowing
/// what is in it.
///
/// A bubble knows about one message. "Every picture in this conversation, in
/// order" is the room screen's knowledge — it holds the timeline, it owns the
/// jump-to-message machinery the gallery's SHOW IN CHAT needs, and it is the
/// only thing that can answer what comes next. The alternative was another
/// `onOpenImage` threaded through [MessageBubble] and its ephemeral twin and
/// both of their call sites and the thread overlay's two more — six edits to
/// hand one callback to a widget five levels down that every other bubble in
/// the transcript would then carry and never use.
///
/// Absence is meaningful, not a bug. A bubble with no scope over it — a lifted
/// preview on the root overlay, a message in the thread sheet — falls back to
/// the single-picture viewer, which is the honest answer there: those trees
/// have no conversation behind them to swipe through.
class RoomGalleryScope extends InheritedWidget {
  const RoomGalleryScope({
    super.key,
    required this.openGallery,
    required super.child,
  });

  /// Opens the fullscreen gallery on [message] and completes when it closes.
  /// The room decides what the set is and where the flight goes.
  ///
  /// A future rather than a plain callback so the bubble can keep its stamp out
  /// of the way for exactly as long as its picture is away — see `_ImageTile`.
  ///
  /// [sourceDecodeWidth] is what the thumbnail under the finger has its picture
  /// decoded at, in device pixels. The gallery flies that decode and lands on
  /// it, so it has to be the caller's real one and not an estimate — the tiles
  /// of an album are three different sizes, and a lone photo's tile is a fourth.
  final Future<void> Function(
    ChatMessage message, {
    required int sourceDecodeWidth,
  }) openGallery;

  /// Read WITHOUT registering a dependency, because every caller reads this in
  /// a tap handler rather than in a build. A `dependOnInheritedWidgetOfExactType`
  /// here would enlist every photo bubble in the transcript to rebuild whenever
  /// the room rebuilt this scope — which is every frame the keyboard animates.
  static RoomGalleryScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RoomGalleryScope>();

  @override
  bool updateShouldNotify(RoomGalleryScope old) =>
      old.openGallery != openGallery;
}
