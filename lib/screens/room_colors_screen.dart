import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/speaker_colors.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';
import '../widgets/user_avatar.dart';

/// Who speaks in which colour, for one room, for one reader.
///
/// The colours are normally settled without anybody being asked — a hash of the
/// user id, de-collided in join order — and this screen exists for the two
/// cases that answer cannot reach. One is taste ("jun is the teal one"). The
/// other is eyesight: twelve hues spread as widely as the palette can spread
/// them are still twelve hues, and which two of them a given reader cannot tell
/// apart is not something an algorithm gets to decide.
///
/// It doubles as the LEGEND. Even a reader who never changes anything gets one
/// place where every face in the room is shown next to the colour it will speak
/// in, which is the piece the transcript on its own cannot give them.
///
/// Every choice here is this reader's alone — see `speakerColors.ts`. Nobody
/// else's client reads these rows, nobody else's app does any work when one is
/// written, and there is no question of who in the room gets to decide.
class RoomColorsScreen extends StatefulWidget {
  const RoomColorsScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
    required this.members,
  });

  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  /// The roster, handed in rather than subscribed to here: Room Info opened
  /// this screen and already holds a live `rooms:getMembers`, and a second one
  /// would pay for the same rows twice.
  final List<ChatUser> members;

  @override
  State<RoomColorsScreen> createState() => _RoomColorsScreenState();
}

class _RoomColorsScreenState extends State<RoomColorsScreen> {
  /// Which member's rail is open. One at a time — twelve swatches under every
  /// row at once is a wall of colour with no subject, and the whole point of
  /// the row is that you are choosing FOR somebody.
  String? _expanded;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // The pins live on the repository (one app-wide subscription) and the
    // on/off level lives on the settings store. Both can move under this
    // screen — the second from the card at the top of it.
    widget.repo.addListener(_onChanged);
    SettingsStore.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChanged);
    SettingsStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  Map<String, int> get _pinned => widget.repo.speakerColorsFor(widget.roomId);

  List<ChatUser> get _roster {
    final me = widget.repo.userId;
    // You are not in your own palette — your messages are painted in the accent
    // and sit on the other margin — so a row for yourself would offer a choice
    // that changes nothing.
    final others = [
      for (final m in widget.members)
        if (m.id != me && !m.isSystem) m,
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));
    return others;
  }

  SpeakerSlots get _slots => SpeakerSlots.forMembers(
        [
          for (final m in widget.members)
            (id: m.id, joinedAt: m.joinedAt?.millisecondsSinceEpoch ?? 0)
        ],
        exclude: widget.repo.userId,
        pinned: _pinned,
      );

  Future<void> _pick(ChatUser member, int? slot) async {
    final l10n = AppLocalizations.of(context);
    final error = await widget.repo.setSpeakerSlot(widget.roomId, member.id, slot);
    if (!mounted || error == null) return;
    final limit = error == 'OVERRIDE_LIMIT';
    showAppToast(
      context,
      limit ? l10n.roomColorsScreenLimitToast : l10n.roomColorsScreenFailedToast,
      // A cap is a rule, not a fault. Only the genuine failure wears danger, so
      // the colour keeps meaning something.
      tone: limit ? ToastTone.neutral : ToastTone.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roster = _roster;
    final slots = _slots;
    final pinned = _pinned;
    final off = SettingsStore.instance.speakerTint == SpeakerTint.off;

    return SettingsPage(
      title: l10n.roomColorsPageTitle,
      children: [
        // The switch itself, not a signpost to it: sending somebody standing
        // in the colour screen off to Settings to find it is making them do
        // navigation work for a control that can simply be here.
        if (off)
          GroupedSection(
            footer: l10n.roomColorsOffFooter,
            children: [
              GroupedRow.toggle(
                icon: CupertinoIcons.paintbrush,
                tone: TileTone.orange,
                title: l10n.settingsHubSpeakerColors,
                value: false,
                onChanged: (_) {
                  pickFeedback();
                  SettingsStore.instance.setSpeakerTint(SpeakerTint.bubble);
                },
              ),
            ],
          ),
        GroupedSection(
          header: l10n.roomColorsPageHeader,
          children: [
            for (final m in roster)
              _MemberColorRow(
                member: m,
                api: widget.api,
                slot: slots.slotOf(m.id),
                isPinned: pinned.containsKey(m.id),
                expanded: _expanded == m.id,
                sharedWith: [
                  for (final id in slots.holdersOf(slots.slotOf(m.id) ?? -1))
                    if (id != m.id)
                      (widget.members
                              .where((u) => u.id == id)
                              .firstOrNull
                              ?.displayName ??
                          '')
                ]..removeWhere((n) => n.isEmpty),
                onToggle: () => setState(
                    () => _expanded = _expanded == m.id ? null : m.id),
                onPick: (slot) => _pick(m, slot),
              ),
          ],
        ),
        if (pinned.isNotEmpty)
          GroupedSection(
            children: [
              GroupedRow(
                title: l10n.roomColorsReset,
                icon: CupertinoIcons.arrow_counterclockwise,
                tone: TileTone.gray,
                chevron: false,
                onTap: () {
                  pickFeedback();
                  setState(() => _expanded = null);
                  widget.repo.clearSpeakerSlots(widget.roomId);
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// One person, their current colour, and — when opened — the palette.
class _MemberColorRow extends StatelessWidget {
  const _MemberColorRow({
    required this.member,
    required this.api,
    required this.slot,
    required this.isPinned,
    required this.expanded,
    required this.sharedWith,
    required this.onToggle,
    required this.onPick,
  });

  final ChatUser member;
  final ChatApi api;
  final int? slot;
  final bool isPinned;
  final bool expanded;

  /// Display names of anyone ELSE currently speaking in this member's colour.
  /// Empty in every room under thirteen people that nobody has hand-pinned.
  final List<String> sharedWith;

  final VoidCallback onToggle;
  final void Function(int? slot) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ground = theme.surfaceSunken;
    final mark = slot == null ? theme.inkMuted : theme.speakerMark(slot!, on: ground);

    return AnimatedContainer(
      duration: theme.motionFast,
      curve: theme.motionCurve,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      color: expanded ? theme.ink.withValues(alpha: 0.04) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusableTap(
            onTap: onToggle,
            semanticLabel: member.displayName,
            radius: theme.radiusSm,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Row(
                children: [
                  UserAvatar(
                    user: member,
                    size: 36,
                    api: api,
                    showStatus: false,
                    ring: slot != null,
                    ringColor: mark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: theme.body.copyWith(
                            // The name in the room's own transcript colour, so
                            // the row shows the answer rather than describing
                            // it. This IS what that person will look like.
                            color: slot == null
                                ? theme.ink
                                : theme.speakerInk(slot!, on: ground),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (sharedWith.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          // Stated, never refused. Two people in one colour is
                          // a choice a reader is allowed to make — they may
                          // simply not care about telling those two apart —
                          // and a picker that blocked it would be overruling
                          // the person it is supposed to be serving.
                          Text(
                            l10n.roomColorsSharedWith(sharedWith.join(', ')),
                            style: theme.caption.copyWith(
                              fontSize: 13,
                              color: theme.inkMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // A filled dot for a hand-pinned colour, a ring for one the
                  // room settled on its own — so "did I choose this" is legible
                  // without opening the rail.
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPinned ? mark : Colors.transparent,
                      border: Border.all(color: mark, width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: theme.motionFast,
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: theme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            _PaletteRail(
              current: slot,
              isPinned: isPinned,
              onPick: onPick,
            ),
          ],
        ],
      ),
    );
  }
}

/// AUTO, then the twelve.
///
/// WRAPPED, not scrolled. Twelve 40px cells plus the chip do not fit the width
/// of a phone, and the first cut put them in a horizontal `ListView` — which
/// looked tidy and quietly hid four colours off the right edge. A picker whose
/// whole job is "compare these and choose one" cannot have options you have to
/// discover by dragging: you would pick from the eight you could see.
class _PaletteRail extends StatelessWidget {
  const _PaletteRail({
    required this.current,
    required this.isPinned,
    required this.onPick,
  });

  final int? current;
  final bool isPinned;
  final void Function(int? slot) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ground = theme.surfaceSunken;

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
          // Clearing is a value of this control, not a separate action hidden
          // behind a long-press — which is why it sits at the head of the rail
          // rather than under it.
          FocusableTap(
            onTap: () => onPick(null),
            semanticLabel: l10n.roomColorsAuto,
            radius: theme.radiusSm,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(null),
              // No `alignment:` here. A Container with one set makes itself
              // as big as its constraints allow, and inside a Wrap those are
              // the full line — which is how the chip first shipped as a
              // full-width slab with the word AUTO adrift in the middle of it.
              // The padding centres the text on its own.
              child: Container(
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isPinned
                      ? theme.ink.withValues(alpha: 0.07)
                      : theme.accent.withValues(alpha: 0.18),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    l10n.roomColorsAuto,
                    style: theme.body.copyWith(
                      fontSize: 15,
                      fontWeight: isPinned ? FontWeight.w500 : FontWeight.w600,
                      color: isPinned ? theme.inkSoft : theme.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (var slot = 0; slot < kSpeakerSlotCount; slot++)
            _Swatch(
              color: theme.speakerMark(slot, on: ground),
              selected: isPinned && current == slot,
              label: l10n.roomColorsScreenSwatchSemantic('${slot + 1}'),
              onTap: () => onPick(slot),
            ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: 20,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          label: label,
          selected: selected,
          button: true,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              // The chosen one grows and gains a halo of the page behind it, so
              // selection survives being one saturated circle among twelve.
              width: selected ? 30 : 24,
              height: selected ? 30 : 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: theme.background, width: 3)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
