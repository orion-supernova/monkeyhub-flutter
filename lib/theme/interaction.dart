/// How long a finger has to stay down before a hold becomes a gesture.
///
/// Flutter's default is 500ms, which is a beat longer than anything in this app
/// wants — but "shorter" is not one number, so the two holds the app actually
/// uses are named here instead of being re-guessed at each call site. Both are
/// gesture-invariant (identical across all 9 themes), so they live beside
/// `layout.dart`'s breakpoints rather than on the per-theme `AppTheme`.
///
/// Plain `GestureDetector` has no hook for either of these — a duration means
/// going straight to `LongPressGestureRecognizer` through a
/// `RawGestureDetector`. See `chat_row_action_menu.dart`'s `ChatRowLongPress`
/// for the house pattern.
library;

/// The hold that opens an action menu: a message bubble's
/// (`message_bubble.dart`) and a chat-list row's (`chat_row_action_menu.dart`)
/// alike.
///
/// A shade under the platform default, because a menu that takes over the
/// screen is a deliberate gesture and wants a near-full hold. One constant for
/// both surfaces on purpose — it is the same gesture on two kinds of row, and
/// while the row sat on the 500ms default it read as the slower, stickier of
/// the two for no reason a user could name.
const Duration kActionMenuLongPress = Duration(milliseconds: 400);

/// The hold that peeks at who reacted — the chat reaction chip
/// (`reaction_bubble.dart`) and the moment reaction chip
/// (`feed/moment_viewer.dart`).
///
/// Deliberately quicker than [kActionMenuLongPress]: a chip is a smaller,
/// lighter target than the action menu behind the whole message, and its
/// recognizer is a *descendant* of the bubble's — the quicker one has to win
/// the arena, or a chip could never be held at all.
const Duration kReactorsLongPress = Duration(milliseconds: 200);
