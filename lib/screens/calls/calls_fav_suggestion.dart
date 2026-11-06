import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../keyboard/focusable_tap.dart' show FocusRingShape;
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart' show groupedFill, groupedRadius;
import '../../widgets/spring_press.dart';
import '../../widgets/user_avatar.dart';
import 'call_log_models.dart';
import 'calls_format.dart';

/// A frequent contact worth offering a pin to: at least this many direct
/// calls, or this much time connected, in the last 30 days.
const int kFavSuggestMinCalls = 3;
const int kFavSuggestMinMs = 20 * 60 * 1000;

/// How long "Not now" keeps a person from being suggested again.
const Duration kFavSuggestSnooze = Duration(days: 30);

/// The person to suggest, and the numbers that earned it.
class FavSuggestion {
  const FavSuggestion(this.user, this.peer);
  final ChatUser user;
  final CallTopPeer peer;

  /// Whether the calls count (rather than the time) is what the card says.
  bool get byCalls => peer.calls >= kFavSuggestMinCalls;
}

/// The first person in [month]'s ranking (direct calls only, most time first)
/// with at least [kFavSuggestMinCalls] calls or [kFavSuggestMinMs] connected,
/// who is not pinned, not snoozed, and is a real person we can show. Null when
/// nobody qualifies. Pure, for tests.
FavSuggestion? pickFavSuggestion({
  required CallLogSummary? month,
  required Iterable<String> favouriteIds,
  required ChatUser? Function(String peerId) userOf,
  required int Function(String peerId) snoozedUntil,
  required int nowMs,
}) {
  if (month == null) return null;
  final pinned = favouriteIds.toSet();
  for (final t in month.top) {
    if (t.calls < kFavSuggestMinCalls && t.ms < kFavSuggestMinMs) continue;
    if (pinned.contains(t.peerId)) continue;
    if (snoozedUntil(t.peerId) > nowMs) continue;
    final u = userOf(t.peerId);
    if (u == null || u.isSystem) continue;
    return FavSuggestion(u, t);
  }
  return null;
}

/// Holds the suggestion card under the favourites row. When the suggestion
/// goes away (added or "Not now") the card fades while the slot collapses with
/// a spring, instead of vanishing.
class CallsFavSuggestionSlot extends StatefulWidget {
  const CallsFavSuggestionSlot({
    super.key,
    required this.suggestion,
    required this.onAdd,
    required this.onNotNow,
    this.api,
  });

  final FavSuggestion? suggestion;
  final ChatApi? api;
  final void Function(ChatUser user) onAdd;
  final void Function(ChatUser user) onNotNow;

  @override
  State<CallsFavSuggestionSlot> createState() => _CallsFavSuggestionSlotState();
}

class _CallsFavSuggestionSlotState extends State<CallsFavSuggestionSlot> {
  /// What the card shows; kept while it collapses.
  FavSuggestion? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.suggestion;
  }

  @override
  void didUpdateWidget(CallsFavSuggestionSlot old) {
    super.didUpdateWidget(old);
    if (widget.suggestion != null) _shown = widget.suggestion;
  }

  @override
  Widget build(BuildContext context) {
    final calm = MotionScope.of(context).calm;
    final visible = widget.suggestion != null;
    final shown = _shown;
    return AnimatedSize(
      duration: Duration(milliseconds: calm ? 140 : 480),
      curve: calm ? Curves.easeOut : const ElasticOutCurve(0.9),
      alignment: Alignment.topCenter,
      onEnd: () {
        if (!visible && _shown != null && mounted) {
          setState(() => _shown = null);
        }
      },
      child: shown == null
          ? const SizedBox(width: double.infinity)
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: visible ? 1 : 0,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: Duration(milliseconds: calm ? 100 : 180),
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: _SuggestionCard(
                      suggestion: shown,
                      api: widget.api,
                      onAdd: () => widget.onAdd(shown.user),
                      onNotNow: () => widget.onNotNow(shown.user),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onAdd,
    required this.onNotNow,
    this.api,
  });
  final FavSuggestion suggestion;
  final ChatApi? api;
  final VoidCallback onAdd;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final user = suggestion.user;
    final first = user.displayName.trim().split(RegExp(r'\s+')).first;
    final text = suggestion.byCalls
        ? l10n.callsTabFavSuggestCalls(suggestion.peer.calls, first)
        : l10n.callsTabFavSuggestTime(first, talkDuration(l10n, suggestion.peer.ms));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(user: user, size: 44, api: api, showStatus: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyEmph.copyWith(fontSize: 15, color: theme.ink),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SpringPress(
                          onTap: onAdd,
                          scale: 0.94,
                          haptic: true,
                          semanticLabel: l10n.callsTabFavAdd,
                          focusShape: FocusRingShape.capsule,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.accent,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              l10n.callsTabFavAdd,
                              style: theme.bodyEmph.copyWith(
                                fontSize: 14,
                                color: theme.accentInk,
                              ),
                            ),
                          ),
                        ),
                        SpringPress(
                          onTap: onNotNow,
                          scale: 0.94,
                          haptic: false,
                          semanticLabel: l10n.callsTabFavNotNow,
                          focusShape: FocusRingShape.capsule,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              l10n.callsTabFavNotNow,
                              style: theme.bodyEmph.copyWith(
                                fontSize: 14,
                                color: theme.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
