import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/file_meta.dart';
import '../../media/storage/storage_kinds.dart';
import '../../media/storage/storage_service.dart';
import '../../models/chat_room.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../theme/layout.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/chat_list_row.dart' show ChatRoomAvatar;
import '../../widgets/donut_chart.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/teardown_safe.dart';
import 'storage_labels.dart';

/// The top of Storage Usage, Data Usage and a chat's storage sheet: the ring,
/// a big title, one line of context, and optionally a hairline meter of how
/// much of the device the app is using.
class UsageHero extends StatelessWidget {
  const UsageHero({
    super.key,
    required this.segments,
    required this.centerLabel,
    this.centerBytes,
    this.title,
    this.subtitle,
    this.meter,
    this.calculating = false,
    this.highlighted,
    this.onSegmentTap,
    this.centerCaption,
    this.leading,
  });

  final List<DonutSegment> segments;
  final String centerLabel;

  /// When set, the centre counts to this many bytes in step with the ring's
  /// morph instead of jumping, and [centerLabel] is ignored. A number that
  /// snaps while the ring is still sweeping reads as a glitch.
  final int? centerBytes;

  /// A small line under [centerLabel] inside the ring: what a tapped slice
  /// is.
  final String? centerCaption;
  /// Under the ring. Null on a page whose large title already says it.
  final String? title;
  final String? subtitle;

  /// 0..1 for the free space meter under the subtitle, null for none.
  final double? meter;
  final bool calculating;
  final Object? highlighted;
  final ValueChanged<Object?>? onSegmentTap;

  /// Drawn inside the ring instead of the label: a chat's avatar.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final center = leading ??
        // Not cross-faded: two numbers fading through each other while the
        // ring morphs read as flicker. The ring carries the motion.
        Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: centerBytes == null
                    ? Text(centerLabel, style: _centerStyle(theme))
                    : TweenAnimationBuilder<double>(
                        // The ring's own duration and curve.
                        tween: Tween(end: centerBytes!.toDouble()),
                        duration: const Duration(milliseconds: 560),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Text(
                          bytesLabel(v.round()),
                          style: _centerStyle(theme),
                        ),
                      ),
              ),
              if (centerCaption != null)
                Text(
                  centerCaption!,
                  style: groupedMetaStyle(theme),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      child: Column(
        children: [
          DonutChart(
            segments: segments,
            calculating: calculating,
            highlighted: highlighted,
            onTap: onSegmentTap,
            center: center,
          ),
          if (title != null) ...[
            const SizedBox(height: 18),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.displaySmall.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
          ],
          if (subtitle != null) ...[
            SizedBox(height: title == null ? 16 : 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: groupedSubtitleStyle(theme),
            ),
          ],
          if (meter != null) ...[
            const SizedBox(height: 10),
            _Meter(value: meter!),
          ],
        ],
      ),
    );
  }
}

TextStyle _centerStyle(AppTheme theme) => theme.displaySmall.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: theme.ink,
      letterSpacing: -0.5,
      // Digits of equal width, so a counting number doesn't jitter sideways.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class _Meter extends StatelessWidget {
  const _Meter({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      width: 160,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: theme.ink.withValues(alpha: 0.10)),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v == 0 ? 0 : v.clamp(0.02, 1.0),
                child: ColoredBox(color: theme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One category in a breakdown: "Videos 52.2%  ·  30.6 MB".
///
/// Leads with a check circle in the category's colour when the list is a
/// selection (Storage Usage: untick what to keep), or its coloured tile when
/// it is a readout (Data Usage). [details] makes the row expand in place, the
/// way Telegram splits a category into incoming and outgoing.
class UsageCategoryRow extends StatefulWidget implements GroupedInsetRow {
  const UsageCategoryRow({
    super.key,
    required this.title,
    required this.bytes,
    required this.color,
    this.percent,
    this.checked,
    this.onToggle,
    this.icon,
    this.tone,
    this.details = const [],
    this.navigates = false,
    this.onOpen,
  });

  final String title;
  final int bytes;
  final Color color;
  final String? percent;

  /// Non-null draws a check circle; [onToggle] flips it.
  final bool? checked;
  final VoidCallback? onToggle;
  final IconData? icon;
  final TileTone? tone;
  final List<({String label, int bytes, IconData icon})> details;

  /// Draws a forward chevron: the row opens somewhere rather than toggling.
  final bool navigates;

  /// Opens the category. With it set, the check circle alone toggles and
  /// the rest of the row opens: select with the circle, look with the row.
  final VoidCallback? onOpen;

  @override
  double get groupedInset => checked != null ? 52 : (icon != null ? 60 : 16);

  @override
  State<UsageCategoryRow> createState() => _UsageCategoryRowState();
}

class _UsageCategoryRowState extends State<UsageCategoryRow>
    with TeardownSafe<UsageCategoryRow> {
  bool _open = false;
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final w = widget;
    final expandable = w.details.isNotEmpty;
    final onTap = w.onOpen ??
        w.onToggle ??
        (expandable ? () => setState(() => _open = !_open) : null);

    final check = w.checked == null
        ? null
        : SelectionCheck(picked: w.checked!, color: w.color);
    final Widget? lead = check != null
        ? (w.onOpen == null
            ? check
            // Its own target, so the circle toggles while the row around it
            // opens. 36 wide is the circle plus the usual 14pt gap, so the
            // title lands where it always does; 30 tall is the row's tile
            // height, so the row keeps its 52pt.
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: w.onToggle,
                child: SizedBox(
                  width: 36,
                  height: 30,
                  child: Align(alignment: Alignment.centerLeft, child: check),
                ),
              ))
        : w.icon != null
            ? Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileColor(theme, w.tone ?? TileTone.gray),
                  borderRadius: BorderRadius.circular(7.5),
                ),
                child: Icon(w.icon, size: 18, color: Colors.white),
              )
            : null;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kGroupedRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            if (lead != null) ...[
              lead,
              if (w.onOpen == null || check == null) const SizedBox(width: 14),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: w.title),
                  if (w.percent != null && w.percent!.isNotEmpty)
                    TextSpan(
                      text: '  ${w.percent}',
                      style: groupedValueStyle(theme).copyWith(fontSize: 15),
                    ),
                ]),
                style: groupedTitleStyle(theme),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(bytesLabel(w.bytes), style: groupedValueStyle(theme)),
            if (w.navigates || w.onOpen != null) ...[
              const SizedBox(width: 10),
              Icon(CupertinoIcons.chevron_forward,
                  size: 14, color: theme.inkMuted.withValues(alpha: 0.55)),
            ],
            if (expandable) ...[
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: theme.motionFast,
                child: Icon(CupertinoIcons.chevron_down,
                    size: 13, color: theme.inkMuted.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        AnimatedSize(
          duration: theme.motionMed,
          curve: theme.motionCurve,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Column(
                  children: [
                    for (final d in w.details)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(60, 0, 16, 12),
                        child: Row(
                          children: [
                            Icon(d.icon, size: 15, color: theme.inkMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(d.label,
                                  style: groupedSubtitleStyle(theme)
                                      .copyWith(color: theme.ink)),
                            ),
                            Text(bytesLabel(d.bytes),
                                style: groupedSubtitleStyle(theme)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );

    if (onTap == null) return body;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: w.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: onTap,
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 260),
          color: _pressed ? theme.ink.withValues(alpha: 0.08) : Colors.transparent,
          child: body,
        ),
      ),
    );
  }
}

/// A room's name as the chat list prints it.
String roomTitle(AppLocalizations l10n, ChatRepository repo, ChatRoom room) {
  if (room.isSavedMessages) return l10n.savedMessagesTitle;
  if (room.isDm) {
    final me = repo.userId;
    final other = me == null ? null : room.otherParticipantId(me);
    final user = other == null ? null : repo.userById(other);
    if (user != null) return user.displayName;
  }
  return room.name;
}

/// One chat's row in the Chats tab: its face, its name, its size.
class StorageChatRow extends StatelessWidget implements GroupedInsetRow {
  const StorageChatRow({
    super.key,
    required this.usage,
    required this.repo,
    required this.api,
    required this.onTap,
    this.selected,
  });

  final RoomUsage usage;
  final ChatRepository repo;
  final ChatApi api;
  final VoidCallback onTap;

  /// Non-null draws a check circle after the size: the row is being picked
  /// rather than opened.
  final bool? selected;

  @override
  double get groupedInset => kPersonRowTextInset;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final room = repo.roomById(usage.roomId);
    final me = repo.userId;
    final otherId = room == null || me == null ? null : room.otherParticipantId(me);
    final title = room == null
        ? l10n.storageChatUnknown
        : roomTitle(l10n, repo, room);
    return PersonRow(
      avatar: room == null
          ? Container(
              decoration: BoxDecoration(
                color: theme.ink.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.chat_bubble_2_fill,
                  size: 18, color: theme.inkMuted),
            )
          : ChatRoomAvatar(
              room: room,
              size: kPersonRowAvatar,
              dmUser: otherId == null ? null : repo.userById(otherId),
              api: api,
            ),
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bytesLabel(usage.total), style: groupedValueStyle(theme)),
          if (selected != null) ...[
            const SizedBox(width: 12),
            SelectionCheck(picked: selected!),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

/// One message's worth of cached media: a photo, or a video with its poster.
/// The grid shows one tile per message and clears every part of it.
class MediaTileData {
  MediaTileData(this.key, this.parts);
  final String key;
  final List<StoredItem> parts;

  int get bytes => parts.fold(0, (a, i) => a + i.bytes);
  bool get isVideo => parts.any((p) =>
      p.kind == StorageKind.videos || p.kind == StorageKind.videoMessages);

  /// A picture already on disk for this tile, drawn with no network at all:
  /// the photo, the poster, the GIF.
  String? get thumbPath {
    for (final p in parts) {
      if (p.isImageFile) return p.path;
    }
    return null;
  }

  /// An image to draw: the photo itself, or a video's poster.
  String? get thumbId {
    for (final p in parts) {
      if (p.url != null) return p.id;
    }
    return null;
  }

  /// The playable file of a video tile, when it is on disk.
  StoredItem? get video {
    for (final p in parts) {
      if (p.url == null &&
          p.hasStorageId &&
          (p.kind == StorageKind.videos ||
              p.kind == StorageKind.videoMessages)) {
        return p;
      }
    }
    return null;
  }

  /// A photo a viewer can open by its storage id.
  String? get photoId {
    for (final p in parts) {
      if (p.url != null && p.hasStorageId) return p.id;
    }
    return null;
  }

  static List<MediaTileData> group(List<StoredItem> items) {
    final byKey = <String, List<StoredItem>>{};
    for (final i in items) {
      byKey.putIfAbsent(i.messageId ?? i.id, () => []).add(i);
    }
    return [for (final e in byKey.entries) MediaTileData(e.key, e.value)]
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
  }
}

/// A tile in the Media tab: the picture, its size, and a selection circle.
class StorageMediaTile extends StatelessWidget {
  const StorageMediaTile({
    super.key,
    required this.tile,
    required this.api,
    this.selected = false,
    this.onTap,
    this.onToggle,
  });

  final MediaTileData tile;
  final ChatApi api;
  final bool selected;
  final VoidCallback? onTap;

  /// Null draws no selection circle: a tile that is only looked at.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final local = tile.thumbPath;
    final thumb = tile.thumbId;
    final placeholder = ColoredBox(
      color: theme.surfaceSunken,
      child: Icon(
        tile.isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
        color: theme.inkMuted,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The cached file itself: this page is about what is ON the
          // device, so it never reaches the network to draw it.
          if (local != null)
            Image.file(
              File(local),
              fit: BoxFit.cover,
              cacheWidth:
                  (140 * MediaQuery.devicePixelRatioOf(context)).round(),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder,
            )
          else if (thumb != null)
            RemoteImage(
              storageId: thumb,
              api: api,
              borderRadius: BorderRadius.zero,
            )
          else
            placeholder,
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: theme.motionFast,
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tile.isVideo) ...[
                    const Icon(CupertinoIcons.play_fill,
                        size: 9, color: Colors.white),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    bytesLabel(tile.bytes),
                    style: theme.caption.copyWith(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onToggle != null)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SelectionCheck(picked: selected, media: true, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row in the Files tab: type badge, name, when it was sent, size.
class StorageFileRow extends StatelessWidget implements GroupedInsetRow {
  const StorageFileRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  final StoredItem item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  double get groupedInset => 96;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final name = item.fileName ?? storageLabel(l10n, item.kind);
    final sent = item.sentAt;
    final when = sent == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(
            DateTime.fromMillisecondsSinceEpoch(sent));
    final isVoice = item.kind == StorageKind.voice;
    return FocusableTap(
      onTap: onToggle,
      semanticLabel: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              SelectionCheck(picked: selected),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: storageColor(theme, item.kind).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: isVoice
                    ? Icon(CupertinoIcons.mic_fill,
                        size: 18, color: storageColor(theme, item.kind))
                    : Text(
                        fileTypeBadge(name),
                        style: theme.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: storageColor(theme, item.kind),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: groupedTitleStyle(theme),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (when != null)
                      Text(when, style: groupedMetaStyle(theme)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(bytesLabel(item.bytes), style: groupedValueStyle(theme)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar that floats over a page while items are picked: "Clear selected
/// 12 MB". Slides up with the first pick and away with the last.
///
/// In its own [Material] because it sits beside the page's Scaffold, not in
/// it: without one its label paints in Flutter's debug fallback, the yellow
/// double underline.
class ClearSelectionBar extends StatelessWidget {
  const ClearSelectionBar({
    super.key,
    required this.visible,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final bool visible;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: edgeToEdgeBottom(context, 12),
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 2.5),
          duration: theme.motionMed,
          curve: theme.motionCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: theme.motionFast,
            child: Material(
              type: MaterialType.transparency,
              child: AdaptivePageBody(
                child: SheetActionButton(
                  label: label,
                  busy: busy,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
