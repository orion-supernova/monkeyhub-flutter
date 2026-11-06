import 'dart:async';

import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/live_calls_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_room.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/live_call_row.dart' show LiveCallHalo;
import '../../widgets/spring_press.dart';
import 'call_actions.dart';
import 'call_row_tile.dart' show resolveSubject;
import 'call_log_models.dart';
import 'calls_directory.dart';
import 'calls_favourites.dart' show CallsSectionLabel;

/// Huddles and group calls going on right now in the user's rooms, from the
/// app-wide [LiveCallsStore] (no subscription of its own). A pulsing ring
/// around the room's picture is the only idle loop on the whole tab, and it
/// exists only for a call that is live. Hidden when there is nothing live.
class CallsLiveStrip extends StatelessWidget {
  const CallsLiveStrip({super.key, required this.directory, this.api});

  final CallsDirectory directory;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LiveCallsStore.instance,
      builder: (context, _) {
        final calls = <(LiveRoomCall, ChatRoom)>[
          for (final c in LiveCallsStore.instance.groupCalls)
            if (!c.mine && c.groupCallId != null)
              if (directory.room(c.roomId) case final room?) (c, room),
        ];
        return AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: calls.isEmpty
              ? const SizedBox(width: double.infinity)
              : _Strip(calls: calls, directory: directory, api: api),
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.calls, required this.directory, this.api});
  final List<(LiveRoomCall, ChatRoom)> calls;
  final CallsDirectory directory;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: CallsSectionLabel(l10n.callsTabLiveNow),
        ),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: calls.length,
            itemBuilder: (context, i) {
              final (call, room) = calls[i];
              return _LiveTile(call: call, room: room, directory: directory, api: api);
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({
    required this.call,
    required this.room,
    required this.directory,
    this.api,
  });
  final LiveRoomCall call;
  final ChatRoom room;
  final CallsDirectory directory;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    // A DM never has a group call; the room's own picture and name are right.
    final subject = resolveSubject(
      l10n,
      directory,
      api,
      CallLogEntry(
        id: call.roomId,
        roomId: call.roomId,
        kind: CallLogKind.group,
        video: call.video,
        incoming: true,
        outcome: CallOutcome.answered,
        startedAt: 0,
        endedAt: 0,
      ),
    );
    final caption =
        call.isHuddle ? l10n.callsTabLiveHuddle : l10n.callsTabLiveGroupCall;
    return SpringPress(
      onTap: () => unawaited(joinLiveCall(context, call)),
      scale: 0.94,
      haptic: false,
      semanticLabel: l10n.callsTabLiveJoinSemantic(subject.name),
      focusRadius: 16,
      hoverRadius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
        width: 84,
        child: Column(
          children: [
            const SizedBox(height: 4),
            RepaintBoundary(
              child: LiveCallHalo(
                call: call,
                size: 60,
                ringForHuddle: true,
                child: subject.avatar(60),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyEmph.copyWith(fontSize: 12.5, color: theme.ink),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySoft.copyWith(fontSize: 11.5, color: theme.inkMuted),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
