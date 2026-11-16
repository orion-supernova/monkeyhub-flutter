import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../backend/chat_api.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'liquid_glass.dart';
import 'location_map_preview.dart' show locationMapAccent;
import 'message_stamp.dart';
import 'sheet_kit.dart';
import 'strip_pill.dart';
import 'user_avatar.dart';

/// Height the strip takes when shown, for chrome that reserves its space
/// (the floating header style), like the games strip.
const kLiveLocationBannerHeight = kLiveLocationStripHeight + 6.0;
const kLiveLocationStripHeight = 44.0;

/// "Someone is sharing live location here", under the room's header, for as
/// long as any live share in the room is running.
///
/// The bubble that started a share scrolls away as the chat carries on; this
/// keeps the share one tap from anywhere in the room, the way the ongoing
/// call strip keeps a call. One share names the person and opens their live
/// map; several say how many and open a list. Zero height when nothing runs.
///
/// Drawn as the games strip's sibling: same height, same glass in the
/// floating style, same pill.
class LiveLocationBanner extends StatelessWidget {
  const LiveLocationBanner({
    super.key,
    required this.shares,
    required this.currentUserId,
    required this.authorOf,
    required this.onOpen,
    this.api,
    this.glass = false,
  });

  /// The room's running live shares, newest first.
  final List<ChatMessage> shares;
  final String currentUserId;
  final ChatUser? Function(String userId) authorOf;
  final ValueChanged<ChatMessage> onOpen;
  final ChatApi? api;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedSize(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      alignment: Alignment.topCenter,
      child: shares.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : _strip(context),
    );
  }

  String _nameOf(BuildContext context, ChatMessage m) {
    final user = authorOf(m.senderId);
    if (user != null && user.displayName.isNotEmpty) return user.displayName;
    return m.senderName.isEmpty ? '?' : m.resolvedSenderName(context);
  }

  Widget _strip(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final one = shares.length == 1 ? shares.first : null;
    final String title;
    String? meta;
    if (one != null) {
      title = one.senderId == currentUserId
          ? l10n.liveLocationBannerYou
          : l10n.liveLocationBannerOne(_nameOf(context, one));
      final until = one.locationShare?.liveExpiresAt;
      if (until != null) {
        meta = l10n.liveLocationBannerUntil(formatClockTime(until));
      }
    } else {
      title = l10n.liveLocationBannerMany(shares.length);
    }

    void open() => one != null ? onOpen(one) : _showList(context);

    final faces = <Widget>[
      for (final m in shares.take(3))
        if (authorOf(m.senderId) case final user?)
          UserAvatar(user: user, api: api, size: 26, showStatus: false),
    ];

    final row = SizedBox(
      height: kLiveLocationStripHeight,
      child: Row(
        children: [
          const SizedBox(width: 9),
          if (faces.isEmpty)
            _Lead(color: locationMapAccent(theme))
          else
            SizedBox(
              width: 26 + (faces.length - 1) * 16.0,
              height: 26,
              child: Stack(
                children: [
                  for (var i = 0; i < faces.length; i++)
                    Positioned(left: i * 16.0, child: faces[i]),
                ],
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (meta != null)
                    TextSpan(
                      text: '  $meta',
                      style: TextStyle(color: theme.inkMuted),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(color: theme.ink, fontSize: 15),
            ),
          ),
          const SizedBox(width: 6),
          StripPill(label: l10n.liveLocationBannerView),
          const SizedBox(width: 8),
        ],
      ),
    );

    final tappable = FocusableTap(
      onTap: open,
      semanticLabel: meta == null ? title : '$title, $meta',
      radius: glass ? kStripGlassRadius : 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: row,
      ),
    );

    if (glass) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          kStripGlassGutter,
          0,
          kStripGlassGutter,
          6,
        ),
        child: LiquidGlass(
          shape: LiquidGlassShape.rounded,
          radius: kStripGlassRadius,
          child: tappable,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: tappable,
    );
  }

  void _showList(BuildContext context) {
    showAdaptiveSheet<void>(
      context,
      useSafeArea: true,
      builder: (sheet) {
        final l10n = AppLocalizations.of(sheet);
        return SheetFrame(
          title: sentenceCaseOf(sheet, l10n.liveLocationBannerSheetTitle),
          showClose: true,
          padding: EdgeInsets.zero,
          scrollsUnderInset: true,
          child: ListView(
            shrinkWrap: true,
            padding: sheetListPadding(sheet),
            children: [
              SheetGroup(
                children: [
                  for (final m in shares)
                    GroupedRow(
                      title: m.senderId == currentUserId
                          ? l10n.locationMapYou
                          : _nameOf(context, m),
                      subtitle: m.locationShare?.liveExpiresAt == null
                          ? null
                          : l10n.locationBubbleLiveUntil(
                              formatClockTime(m.locationShare!.liveExpiresAt!),
                            ),
                      trailing: authorOf(m.senderId) == null
                          ? null
                          : UserAvatar(
                              user: authorOf(m.senderId)!,
                              api: api,
                              size: 34,
                              showStatus: false,
                            ),
                      onTap: () {
                        Navigator.of(sheet).pop();
                        onOpen(m);
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      CupertinoIcons.dot_radiowaves_left_right,
      size: 16,
      color: color,
    ),
  );
}
