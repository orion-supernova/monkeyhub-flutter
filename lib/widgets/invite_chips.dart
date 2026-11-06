import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'count_bump.dart';
import 'ios_kit.dart';
import 'search_field.dart';
import 'spring_press.dart';
import 'user_avatar.dart';

/// "Who do you want in it?": a search box over a row of friends as avatar
/// chips, tap to pick, tap again to put back. A check draws itself in on the
/// avatar of everyone picked.
///
/// The friends are whatever the host already holds in memory (the repository's
/// list), so filtering is local and costs no round trip. The host owns the
/// selection ([selected], by user id) and is told of every tap through
/// [onToggle]; this widget keeps only the search text.
///
/// The count above the row ("you + 2") rolls through [CountBump]. It says what
/// it counts: the person making the room plus the friends picked.
class InviteChips extends StatefulWidget {
  const InviteChips({
    super.key,
    required this.friends,
    required this.selected,
    required this.onToggle,
    this.api,
  });

  final List<ChatUser> friends;

  /// Ids of the friends picked, in pick order.
  final List<String> selected;
  final ValueChanged<ChatUser> onToggle;
  final ChatApi? api;

  /// How many chips show before the search box is needed to reach the rest.
  static const recentCount = 10;

  @override
  State<InviteChips> createState() => _InviteChipsState();
}

class _InviteChipsState extends State<InviteChips> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<ChatUser> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      // Picked friends stay in view even when they fall past the recent ones.
      final recent = widget.friends.take(InviteChips.recentCount).toList();
      for (final id in widget.selected) {
        if (recent.any((u) => u.id == id)) continue;
        final u = widget.friends.where((f) => f.id == id);
        if (u.isNotEmpty) recent.add(u.first);
      }
      return recent;
    }
    return widget.friends
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    if (widget.friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          l10n.newRoomPeopleNoFriends,
          style: theme.caption.copyWith(color: theme.inkMuted),
        ),
      );
    }
    final shown = _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchField(
          controller: _q,
          hintText: l10n.newRoomPeopleSearchHint,
          showCancel: false,
          compact: true,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Text(
              l10n.newRoomPeopleNoMatch,
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          )
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final u = shown[i];
                return InviteChip(
                  key: ValueKey(u.id),
                  user: u,
                  api: widget.api,
                  on: widget.selected.contains(u.id),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onToggle(u);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The count that sits beside the People label: "only you so far" or
/// "you + 2".
class InviteCount extends StatelessWidget {
  const InviteCount({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return CountBump(
      count: count,
      child: Text(
        count == 0 ? l10n.newRoomPeopleOnlyYou : l10n.newRoomPeopleYouPlus(count),
        style: theme.caption.copyWith(
          color: count == 0 ? theme.inkMuted : theme.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One friend: avatar over first name. Picked, the avatar gets a ring and a
/// check that draws itself in on a spring.
class InviteChip extends StatelessWidget {
  const InviteChip({
    super.key,
    required this.user,
    required this.on,
    required this.onTap,
    this.api,
  });

  final ChatUser user;
  final bool on;
  final VoidCallback onTap;
  final ChatApi? api;

  static const _avatar = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final calm = MotionScope.of(context).calm;
    final first = user.name.trim().split(RegExp(r'\s+')).first;
    return SpringPress(
      onTap: onTap,
      haptic: false,
      semanticLabel: user.name,
      focusRadius: 14,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _avatar + 6,
              height: _avatar + 6,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: calm ? Duration.zero : const Duration(milliseconds: 200),
                    width: _avatar + 6,
                    height: _avatar + 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on ? theme.accent : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: UserAvatar(
                      user: user,
                      size: _avatar - 4,
                      api: api,
                      showStatus: false,
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: _DrawnCheck(on: on, calm: calm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.caption.copyWith(
                fontSize: 12,
                color: on ? theme.ink : theme.inkSoft,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The accent dot with a check whose stroke draws in. Springs in and out of
/// existence; calm motion jumps.
class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck({required this.on, required this.calm});
  final bool on;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: on ? 1 : 0),
      duration: calm ? Duration.zero : Duration(milliseconds: on ? 520 : 140),
      curve: on ? Curves.easeOutBack : Curves.easeIn,
      builder: (context, t, _) => Transform.scale(
        scale: t.clamp(0.0, 1.3),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: theme.accent,
            shape: BoxShape.circle,
            border: Border.all(color: theme.surface, width: 2),
          ),
          child: CustomPaint(
            painter: _CheckPainter(progress: t, color: theme.accentInk),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width * 0.26, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.69)
      ..lineTo(size.width * 0.75, size.height * 0.33);
    final m = p.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
