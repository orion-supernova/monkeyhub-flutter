import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/room_admin.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
import 'remote_image.dart';

/// Height of a visible strip.
///
/// Exported for the reason [kPinnedBannerHeight] is: the liquid chat style
/// floats its chrome OVER the transcript and grows the list's top padding by
/// exactly this much. The strip renders a box of this height rather than
/// sizing to its content, so the two cannot drift apart.
const double kSuggestionsBannerHeight = 44.0;

/// Borrowed from [PinnedMessageBanner] so the two read as one family when they
/// stack under the header.
const double _kGlassGutter = 16.0;
const double _kGlassRadius = 22.0;
const double _kThumb = 26.0;

/// "Murat suggested a new group photo · REVIEW" — the admin's side of a
/// member's suggestion, in the room it is about.
///
/// Zero height with nothing pending, so the room screen mounts it
/// unconditionally — the contract [PinnedMessageBanner] and the translate strip
/// already keep — and it animates its own arrival and departure.
///
/// One suggestion names who and what, with the proposed picture itself as the
/// thumbnail when it is a photo: an admin can often decide from the strip
/// alone whether this is worth stopping for. Two or more collapse to a count,
/// because a line that names one of several reads as if it were the only one.
class RoomSuggestionsBanner extends StatelessWidget {
  const RoomSuggestionsBanner({
    super.key,
    required this.pending,
    required this.api,
    required this.onReview,
    this.glass = false,
  });

  /// Oldest first, as `roomChangeRequests:listPending` returns them.
  final List<RoomChangeRequest> pending;
  final ChatApi api;
  final VoidCallback onReview;

  /// Frosted and gutter-inset, for the compact chat style. Same flag, same
  /// meaning as [PinnedMessageBanner.glass].
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedSize(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      alignment: Alignment.topCenter,
      child: pending.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : _Strip(pending: pending, api: api, onReview: onReview, glass: glass),
    );
  }
}

/// What one suggestion says on the strip, or null for a field this build does
/// not know — which falls back to the count wording rather than inventing one.
String? suggestionHeadline(AppLocalizations l10n, RoomChangeRequest r) {
  final who = r.user?.displayName ?? '';
  if (who.isEmpty) return null;
  switch (r.field) {
    case RoomChangeField.avatar:
      return l10n.roomSuggestionBannerPhoto(who);
    case RoomChangeField.name:
      return l10n.roomSuggestionBannerName(who);
    case RoomChangeField.description:
      return l10n.roomSuggestionBannerDescription(who);
    case RoomChangeField.unknown:
      return null;
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.pending,
    required this.api,
    required this.onReview,
    required this.glass,
  });

  final List<RoomChangeRequest> pending;
  final ChatApi api;
  final VoidCallback onReview;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final single = pending.length == 1 ? pending.first : null;
    final headline = (single == null ? null : suggestionHeadline(l10n, single)) ??
        l10n.roomSuggestionBannerMany(pending.length);
    final photo = single?.field == RoomChangeField.avatar ? single?.storageId : null;

    final row = SizedBox(
      height: kSuggestionsBannerHeight,
      child: Row(
        children: [
          const SizedBox(width: 12),
          _Lead(photoId: photo, api: api, count: pending.length),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(color: theme.ink, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          _ReviewPill(label: l10n.roomSuggestionBannerReview),
          const SizedBox(width: 8),
        ],
      ),
    );

    // The whole strip is the target, not just the word: it is a single
    // action, and a 44pt row whose left three quarters did nothing would be a
    // trap for exactly the thumb this is for.
    final tappable = FocusableTap(
      onTap: onReview,
      semanticLabel: l10n.roomSuggestionBannerSemantic,
      radius: glass ? _kGlassRadius : 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReview,
        child: row,
      ),
    );

    if (glass) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kGlassGutter),
        child: LiquidGlass(
          shape: LiquidGlassShape.rounded,
          radius: _kGlassRadius,
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
}

/// The proposed picture when there is exactly one and it is a photo; the
/// suggestion glyph, with the count on it, otherwise.
class _Lead extends StatelessWidget {
  const _Lead({required this.photoId, required this.api, required this.count});

  final String? photoId;
  final ChatApi api;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final id = photoId;
    if (id != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.accent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: RemoteImage(
            storageId: id,
            api: api,
            width: _kThumb - 6,
            height: _kThumb - 6,
            borderRadius: BorderRadius.circular(_kThumb),
          ),
        ),
      );
    }
    return SizedBox(
      width: _kThumb,
      height: _kThumb,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              Icons.published_with_changes_outlined,
              size: 18,
              color: theme.accent,
            ),
          ),
          if (count > 1)
            Positioned(
              right: -4,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 15),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: theme.monoTiny.copyWith(
                    color: theme.accentInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewPill extends StatelessWidget {
  const _ReviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: theme.caption.copyWith(
            color: theme.accentInk,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
