import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/mention_session.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'user_avatar.dart';

/// The list of people you can tag, shown directly above the composer while an
/// `@` is being typed.
///
/// Built as a sibling of the composer inside the host's existing
/// `AnimatedSize`, exactly like [ComposerReplyCard] — not as an `OverlayEntry`.
/// The thread overlay already builds its composer inside a root overlay entry,
/// and a second one would fight it for layering (the same collision that makes
/// its camera button null). Sitting in the Column also means the keyboard
/// insets stay the host's business, which is how every other piece of composer
/// chrome here works.
class MentionPicker extends StatefulWidget {
  const MentionPicker({
    super.key,
    required this.session,
    this.api,
  });

  final MentionSession session;

  /// Resolves member avatars. Null falls back to [UserAvatar]'s gradient +
  /// initials, which is what a test or a preview with no backend gets.
  final ChatApi? api;

  static const double rowHeight = 44;

  /// Showing four and a half rows is what tells the user there is more without
  /// letting the list eat the transcript on a small phone above the keyboard.
  static const double maxHeight = rowHeight * 4.5;

  @override
  State<MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends State<MentionPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final ScrollController _scroll = ScrollController();
  int _lastActive = 0;

  /// Whether to paint the armed row at all.
  ///
  /// The session always has a row armed so that Enter has somewhere to go, but
  /// showing that on a touch device makes the list open looking like a choice
  /// has already been made — the top entry reads as picked before the user has
  /// done anything, which is worse than no affordance.
  ///
  /// So the highlight follows [FocusManager.highlightMode], the same signal
  /// `FocusableTap` uses to decide whether to paint its focus ring. It lands
  /// where it should on both ends without either being special-cased: typing
  /// `@` on a hardware keyboard has already flipped the mode to `traditional`,
  /// so a desktop user sees the armed row and Enter takes it; a soft keyboard
  /// goes through the text-input channel and never flips it, so a phone shows a
  /// flat list you tap. An iPad that grows a Bluetooth keyboard mid-sentence
  /// gets the highlight from the first key it sends.
  bool _keyboardMode = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
    widget.session.addListener(_followActiveRow);
    _keyboardMode =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    widget.session.removeListener(_followActiveRow);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final next = mode == FocusHighlightMode.traditional;
    if (next == _keyboardMode || !mounted) return;
    setState(() => _keyboardMode = next);
  }

  /// Keeps the armed row on screen while the arrow keys walk past the bottom of
  /// a scrolled list — without this, holding Down moves a selection nobody can
  /// see.
  void _followActiveRow() {
    final i = widget.session.activeIndex;
    if (i == _lastActive) return;
    _lastActive = i;
    if (!_scroll.hasClients) return;
    final top = i * MentionPicker.rowHeight;
    final bottom = top + MentionPicker.rowHeight;
    final view = _scroll.position;
    final target = bottom > view.pixels + view.viewportDimension
        ? bottom - view.viewportDimension
        : top < view.pixels
            ? top
            : null;
    if (target == null) return;
    _scroll.jumpTo(target.clamp(
      view.minScrollExtent,
      view.maxScrollExtent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final s = widget.session;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
        );
      },
      // Wrapped so nothing inside has to find a Material ancestor of its own —
      // in the thread overlay there isn't one, and the fallback Flutter draws
      // instead is yellow-underlined debug text.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            // A raised plate with no outline — iOS popovers separate by
            // elevation, not by a drawn border.
            child: Container(
              decoration: BoxDecoration(color: theme.surfaceRaised),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: MentionPicker.maxHeight),
                child: AnimatedBuilder(
                  animation: s,
                  builder: (context, _) => _list(theme, s),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(AppTheme theme, MentionSession s) {
    final count = s.itemCount;
    return ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemExtent: MentionPicker.rowHeight,
      itemCount: count,
      itemBuilder: (context, i) {
        final active = _keyboardMode && i == s.activeIndex;
        if (s.showEveryone && i == 0) {
          return _Row(
            active: active,
            onTap: () => s.accept(0),
            leading: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.ink.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.speaker_2_fill,
                size: 14,
                color: theme.accent,
              ),
            ),
            title: AppLocalizations.of(context).cyberpunkThemeMentionPickerEveryoneTitle,
            handle: '@everyone',
            trailing: AppLocalizations.of(context).cyberpunkThemeMentionPickerNotifiesAllBadge,
          );
        }
        final u = s.matches[i - (s.showEveryone ? 1 : 0)];
        return _Row(
          active: active,
          onTap: () => s.accept(i),
          leading: UserAvatar(user: u, size: 28, api: widget.api),
          title: u.displayName,
          handle: '@${u.username}',
          trailing: u.role == 'owner'
              ? AppLocalizations.of(context).cyberpunkThemeMentionPickerOwnerBadge
              : null,
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.active,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.handle,
    this.trailing,
  });

  final bool active;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String handle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // A bare GestureDetector, and deliberately NOT wrapped in FocusableTap: a
    // real focus stop here would pull focus out of the field the user is still
    // typing into. The armed row is chosen by the index the session holds, and
    // the keyboard drives that — so the list is keyboard-operable without any
    // of its rows ever taking focus.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // A neutral highlight: an accent wash on a dark plate reads as navy.
        color: active ? theme.ink.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            // Mirrors the reply card's 3px accent strip, so "this is the one"
            // reads the same in both pieces of composer chrome.
            Container(
              width: 3,
              height: 22,
              decoration: BoxDecoration(
                color: active ? theme.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: theme.body.copyWith(color: theme.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                handle,
                style: theme.bodySoft.copyWith(
                  fontSize: 13,
                  color: theme.inkMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: theme.bodySoft.copyWith(
                  fontSize: 13,
                  color: theme.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
