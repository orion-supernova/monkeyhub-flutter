import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// Premium OG-card preview for a single URL.
///
/// Three layout modes, chosen automatically from the fetched metadata:
///
///  * **hero** — full-bleed image at the top, theme-tinted seam, then a
///    typographic info panel (site dot + caps tag, display title, soft
///    description, mono domain with chevron). Used when [LinkPreview.imageUrl]
///    is present and the fetch returned rich content.
///  * **compact** — square accent-gradient sigil on the left and the same
///    info column on the right. Used when no image exists but title /
///    description came back.
///  * **bare** — minimal pill with `link` glyph, domain, and chevron.
///    Used when the fetch failed or yielded nothing.
///
/// The card adapts to whether it lives **inside** a text bubble (under
/// existing message text — [insideBubble] = true) or stands on its own as
/// the entire bubble surface ([insideBubble] = false). When standalone the
/// image bleeds edge-to-edge into the bubble's corners; when inline a
/// rounded surface separates it from the text above.
class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({
    super.key,
    required this.url,
    required this.isMine,
    required this.onTap,
    this.insideBubble = true,
    this.borderRadius,
  });

  final String url;
  final bool isMine;
  final void Function(String url) onTap;

  /// Whether this card sits *inside* an outer bubble decoration (true) or
  /// *is* the bubble surface (false). Affects padding/seam/rounding.
  final bool insideBubble;

  /// When [insideBubble] is false, the card uses this radius to match its
  /// enclosing bubble. Defaults to the theme's [AppTheme.radiusLg].
  final BorderRadius? borderRadius;

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  LinkPreview? _preview;
  bool _loading = false;
  bool _failed = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _preview = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final cached = LinkPreviewService.instance.cached(widget.url);
    if (cached != null) {
      setState(() => _preview = cached);
      return;
    }
    setState(() => _loading = true);
    try {
      final preview = await LinkPreviewService.instance.fetch(widget.url);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
        _failed = preview == null || !preview.hasContent;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String get _domain {
    try {
      final host = Uri.parse(widget.url).host;
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (_) {
      return widget.url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final radius = widget.borderRadius ??
        BorderRadius.circular(widget.insideBubble ? theme.radiusMd : theme.radiusLg);
    final preview = _preview;
    final hasImage =
        preview != null && (preview.imageUrl?.isNotEmpty ?? false);
    final hasContent = preview != null && preview.hasContent;

    final showSkeleton = preview == null && (_loading || !_failed);

    final card = ClipRRect(
      borderRadius: radius,
      child: AnimatedSwitcher(
        // Cross-fade between the skeleton (visible immediately on mount)
        // and the resolved layout, so chatroom entry doesn't leave empty
        // pre-card placeholders. Cached previews skip the skeleton path
        // entirely (set in initState) so there's no flash either.
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: showSkeleton
            ? _Skeleton(
                key: const ValueKey('skeleton'),
                theme: theme,
                isMine: widget.isMine,
                insideBubble: widget.insideBubble,
                hasImage: true,
              )
            : KeyedSubtree(
                key: const ValueKey('content'),
                child: hasContent
                    ? hasImage
                        ? _HeroLayout(
                            theme: theme,
                            preview: preview,
                            domain: _domain,
                            isMine: widget.isMine,
                            insideBubble: widget.insideBubble,
                          )
                        : _CompactLayout(
                            theme: theme,
                            preview: preview,
                            domain: _domain,
                            isMine: widget.isMine,
                          )
                    : _BareLayout(
                        theme: theme,
                        domain: _domain,
                        isMine: widget.isMine,
                        failed: _failed,
                      ),
              ),
      ),
    );

    final outer = widget.insideBubble
        ? Padding(
            // Inline card under text — breathe away from the text bubble's
            // inner padding so the seam doesn't feel cramped.
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: card,
          )
        : card;

    return _PressScale(
      pressed: _pressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => widget.onTap(widget.url),
        child: outer,
      ),
    );
  }
}

class _PressScale extends StatelessWidget {
  const _PressScale({required this.pressed, required this.child});
  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: child,
    );
  }
}

/// Hero layout: full-bleed image, theme seam, info panel with strong type.
class _HeroLayout extends StatelessWidget {
  const _HeroLayout({
    required this.theme,
    required this.preview,
    required this.domain,
    required this.isMine,
    required this.insideBubble,
  });

  final AppTheme theme;
  final LinkPreview preview;
  final String domain;
  final bool isMine;
  final bool insideBubble;

  @override
  Widget build(BuildContext context) {
    final tone = _CardTones.of(theme, isMine, insideBubble);

    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border, width: 1),
        borderRadius: insideBubble
            ? BorderRadius.circular(theme.radiusMd)
            : BorderRadius.circular(theme.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.91,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HeroImage(url: preview.imageUrl!, tone: tone, theme: theme),
                // Subtle gradient at the bottom of the image so the seam
                // melts into the info panel rather than slicing.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          tone.surface.withValues(alpha: 0.55),
                        ],
                        stops: const [0.75, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Theme-accent hairline seam between image and info — a tiny
          // signature flourish that lifts the card out of generic territory.
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.accent.withValues(alpha: 0.0),
                  theme.accent.withValues(alpha: isMine ? 0.55 : 0.35),
                  theme.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: _InfoBlock(
              theme: theme,
              preview: preview,
              domain: domain,
              tone: tone,
              dense: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.url,
    required this.tone,
    required this.theme,
  });

  final String url;
  final _CardTones tone;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    // OG images are arbitrary third-party URLs and routinely far larger than the
    // 1.91:1 strip they're painted into, so the same decode cap that RemoteImage
    // applies matters here too. Cached on disk for the same reason: a preview
    // re-rendered on every scroll back through the room shouldn't re-fetch a
    // stranger's server.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth =
        math.max(1, (MediaQuery.sizeOf(context).width * dpr).round());
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: decodeWidth,
      fadeInDuration: const Duration(milliseconds: 240),
      fadeOutDuration: Duration.zero,
      errorWidget: (_, _, _) => Container(
        color: tone.surface,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_outlined,
            color: tone.inkMuted, size: 22),
      ),
      placeholder: (_, _) => Container(
        color: tone.surface,
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(theme.accent),
          ),
        ),
      ),
    );
  }
}

/// Compact layout: theme-gradient sigil on the left, info column on the
/// right. Used when OG meta exists but no image came back.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.theme,
    required this.preview,
    required this.domain,
    required this.isMine,
  });

  final AppTheme theme;
  final LinkPreview preview;
  final String domain;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final tone = _CardTones.of(theme, isMine, true);
    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border, width: 1),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent gradient sigil — the card's identity when no image
            // exists. Theme.accent shifted through its luminance range
            // creates a "branded chip" feel.
            Container(
              width: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.accent.withValues(alpha: 0.85),
                    theme.accent.withValues(alpha: 0.45),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.link_rounded,
                  size: 22, color: theme.accentInk),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _InfoBlock(
                  theme: theme,
                  preview: preview,
                  domain: domain,
                  tone: tone,
                  dense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bare layout: pill with link glyph, domain, chevron — used when the
/// fetch fails or yields nothing. Stays elegant, doesn't pretend to know
/// more than it does.
class _BareLayout extends StatelessWidget {
  const _BareLayout({
    required this.theme,
    required this.domain,
    required this.isMine,
    required this.failed,
  });

  final AppTheme theme;
  final String domain;
  final bool isMine;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final tone = _CardTones.of(theme, isMine, true);
    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border, width: 1),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.link_rounded, size: 14, color: theme.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failed ? 'LINK' : 'LINK',
                  style: theme.monoTiny.copyWith(
                    color: tone.inkMuted,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  domain,
                  style: theme.body.copyWith(color: tone.ink, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_outward_rounded, size: 14, color: theme.accent),
        ],
      ),
    );
  }
}

/// Shared metadata column: SITE NAME pill, title, description, footer with
/// domain + chevron. Used by hero and compact layouts.
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.theme,
    required this.preview,
    required this.domain,
    required this.tone,
    required this.dense,
  });

  final AppTheme theme;
  final LinkPreview preview;
  final String domain;
  final _CardTones tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final title = preview.title?.trim();
    final desc = preview.description?.trim();
    final siteTag = (preview.siteName ?? domain).toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SITE NAME row: theme.accent dot + mono caps.
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                siteTag,
                style: theme.monoTiny.copyWith(
                  color: tone.inkMuted,
                  letterSpacing: 2.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (title != null && title.isNotEmpty) ...[
          SizedBox(height: dense ? 4 : 6),
          Text(
            title,
            style: theme.bodyEmph.copyWith(
              color: tone.ink,
              height: 1.22,
              fontSize: dense ? 14 : 15.5,
            ),
            maxLines: dense ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (!dense && desc != null && desc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            desc,
            style: theme.bodySoft.copyWith(
              color: tone.inkMuted,
              height: 1.32,
              fontSize: 12.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        SizedBox(height: dense ? 6 : 10),
        Row(
          children: [
            Flexible(
              child: Text(
                domain,
                style: theme.monoTiny.copyWith(
                  color: tone.inkSoft,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_outward_rounded, size: 12, color: theme.accent),
          ],
        ),
      ],
    );
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton({
    super.key,
    required this.theme,
    required this.isMine,
    required this.insideBubble,
    required this.hasImage,
  });

  final AppTheme theme;
  final bool isMine;
  final bool insideBubble;
  final bool hasImage;

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tone = _CardTones.of(theme, widget.isMine, widget.insideBubble);

    // Base = a midtone splitting the difference between the card surface
    // and a slightly sunken color, so the skeleton reads as "card with
    // placeholders" instead of "solid dark rectangle". Highlight rides
    // brighter so the sweep is unmistakable.
    final base = Color.alphaBlend(
      theme.surfaceSunken.withValues(alpha: 0.45),
      tone.surface,
    );
    final highlight = Color.alphaBlend(
      theme.surfaceRaised.withValues(alpha: 0.95),
      base,
    );

    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border, width: 1),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.hasImage)
            AspectRatio(
              aspectRatio: 1.91,
              child: _SweepFill(
                sweep: _sweep,
                base: base,
                highlight: highlight,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SweepBar(sweep: _sweep, base: base, highlight: highlight,
                    width: 64, height: 8),
                const SizedBox(height: 10),
                _SweepBar(sweep: _sweep, base: base, highlight: highlight,
                    width: double.infinity, height: 11),
                const SizedBox(height: 6),
                _SweepBar(sweep: _sweep, base: base, highlight: highlight,
                    width: 180, height: 11),
                const SizedBox(height: 10),
                _SweepBar(sweep: _sweep, base: base, highlight: highlight,
                    width: 100, height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid-color fill with a `base → highlight → base` linear gradient
/// sweeping across it left-to-right on a 1.4s loop. The endpoints sit
/// fully off-screen at the start/end of the cycle so the loop wraps
/// invisibly.
class _SweepFill extends StatelessWidget {
  const _SweepFill({
    required this.sweep,
    required this.base,
    required this.highlight,
  });

  final Animation<double> sweep;
  final Color base;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sweep,
      builder: (context, _) {
        final t = sweep.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-3 + 4 * t, 0),
            end: Alignment(-1 + 4 * t, 0),
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: Container(color: base),
        );
      },
    );
  }
}

class _SweepBar extends StatelessWidget {
  const _SweepBar({
    required this.sweep,
    required this.base,
    required this.highlight,
    required this.width,
    required this.height,
  });

  final Animation<double> sweep;
  final Color base;
  final Color highlight;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: width,
        height: height,
        child: _SweepFill(sweep: sweep, base: base, highlight: highlight),
      ),
    );
  }
}

/// Tone palette derived per-render from the active theme + ownership
/// (mine/theirs) + position (inside-bubble vs standalone). Centralized so
/// each layout doesn't reinvent its own opacity math.
class _CardTones {
  const _CardTones({
    required this.surface,
    required this.border,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
  });

  final Color surface;
  final Color border;
  final Color ink;
  final Color inkSoft;
  final Color inkMuted;

  /// The card stays ownership-neutral; the row alignment (and the surrounding
  /// bubble decoration, when present) communicates mine/theirs. This matches
  /// the existing image-bubble caption treatment which also reuses
  /// [AppTheme.surfaceSunken] regardless of sender.
  factory _CardTones.of(AppTheme theme, bool isMine, bool insideBubble) {
    return _CardTones(
      surface: insideBubble ? theme.surfaceSunken : theme.surface,
      border: theme.divider,
      ink: theme.ink,
      inkSoft: theme.inkSoft,
      inkMuted: theme.inkMuted,
    );
  }
}
