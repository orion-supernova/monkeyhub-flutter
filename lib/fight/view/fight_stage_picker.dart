import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/spring_press.dart';
import 'art/art_common.dart' show FightLook;
import 'art/camera.dart';
import 'art/stage_art.dart';
import 'art/stages/stages.dart';
import 'fight_renderer.dart';
import '../../data/settings_store.dart';
import 'fight_screen.dart' show fightLookOf;

/// One still picture per stage and look, drawn once per process and shared
/// by every picker (never six live stages at once).
///
/// Cartoon and painted are drawn at [w] x [h]. Pixel goes the fight's way: the
/// pixel-look stage drawn at [pixelW] x [pixelH], palette-snapped and dithered
/// by [FightRenderer.pixelPass], and shown with nearest-neighbour. Its palette
/// is built async from that first render (the raw low-res still shows until
/// then); [updates] ticks when a processed still replaces it.
class FightStageThumbs {
  FightStageThumbs._();
  static const double w = 320, h = 200;
  static const int pixelW = 120, pixelH = 75;
  static final Map<int, ui.Image> _cache = {};
  static final Set<int> _snapping = {};
  static final ValueNotifier<int> updates = ValueNotifier(0);

  static int _key(int id, FightLook look) => id * FightLook.values.length + look.index;

  static ui.Image? cached(int id, {FightLook look = FightLook.painted}) => _cache[_key(id, look)];

  static ui.Image? of(int id, {FightLook look = FightLook.painted}) {
    final key = _key(id, look);
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final pixel = look == FightLook.pixel;
      final size = pixel ? ui.Size(pixelW.toDouble(), pixelH.toDouble()) : const ui.Size(w, h);
      final pic = _record(id, look, size);
      final img = pic.toImageSync(size.width.toInt(), size.height.toInt());
      if (pixel) {
        FightRenderer.warmUp();
        _snap(key, pic, img);
      } else {
        pic.dispose();
      }
      return _cache[key] = img;
    } catch (_) {
      return null;
    }
  }

  static ui.Picture _record(int id, FightLook look, ui.Size size) {
    final art = StageArt();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // Most of the stage in view, the floor at 85% height, the middle centred.
    final scale = size.width / 820;
    art.paint(c, size, FightCamera(scale, size.width / 2 - 600 * scale, size.height * .85), look, 96, id);
    art.dispose();
    return rec.endRecording();
  }

  /// Builds the still's palette and swaps in the processed version.
  static void _snap(int key, ui.Picture pic, ui.Image raw) {
    if (!_snapping.add(key)) return;
    () async {
      try {
        await FightRenderer.warmUp();
        final bytes = await raw.toByteData();
        if (bytes == null) return;
        final pal = await PixelPalette.build(medianCut(FightRenderer.opaqueColors(bytes), 40));
        final done = FightRenderer.pixelPass(pic, pixelW, pixelH, pal, dither: 0.09, outline: false);
        pal.image.dispose();
        // The raw still may be on screen this frame: leave it to the GC.
        _cache[key] = done;
        updates.value++;
      } catch (e) {
        debugPrint('FightStageThumbs: pixel still failed: $e');
      } finally {
        pic.dispose();
      }
    }();
  }
}

/// A sideways row of stage thumbnails: tap one to pick it. [selected] is a
/// stage id, or [kFightStageRandom]. [readOnly] shows just the selected stage
/// (the online guest, who cannot change the host's choice).
class FightStagePicker extends StatelessWidget {
  const FightStagePicker({super.key, required this.selected, required this.onPick, this.readOnly = false, this.allowRandom = true, this.look});

  /// The look the thumbnails are drawn in; null = the player's setting.
  final FightLook? look;

  final int selected;
  final ValueChanged<int> onPick;
  final bool readOnly;
  final bool allowRandom;

  static const double _cardW = 112, _cardH = 70, _labelH = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = [for (final d in kFightStages) d.id, if (allowRandom && !readOnly) kFightStageRandom];
    final look = this.look ?? fightLookOf(SettingsStore.instance.fightLook);
    if (readOnly) {
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: _cardW * 1.5,
          height: _cardH * 1.5 + _labelH,
          child: _StageCard(id: fightStageOf(selected), look: look, selected: true, w: _cardW * 1.5, h: _cardH * 1.5, label: fightStageName(l10n, selected), onTap: null),
        ),
      );
    }
    return SizedBox(
      height: _cardH + _labelH + 6,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        itemCount: ids.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = ids[i];
          return SizedBox(
            width: _cardW,
            child: _StageCard(
              key: ValueKey('fight_stage_$id'),
              id: id,
              look: look,
              selected: id == selected,
              w: _cardW,
              h: _cardH,
              label: id == kFightStageRandom ? l10n.fightStageRandom : fightStageName(l10n, id),
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(id);
              },
            ),
          );
        },
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({super.key, required this.id, required this.look, required this.selected, required this.w, required this.h, required this.label, required this.onTap});

  final int id;
  final FightLook look;
  final bool selected;
  final double w, h;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final random = id == kFightStageRandom;
    final def = random ? null : kFightStages[fightStageOf(id)];
    final card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: random ? const [Color(0xff3a2a5c), Color(0xff15102a)] : [def!.top, def.bottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xffffd23a) : const Color(0x22ffffff), width: selected ? 2.5 : 1),
          ),
          child: random
              ? const Center(child: Icon(CupertinoIcons.shuffle, color: Colors.white, size: 26))
              : _Thumb(key: ValueKey(look), id: id, look: look),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? const Color(0xffffd23a) : const Color(0xd9ffffff)),
        ),
      ],
    );
    if (onTap == null) return card;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SpringPress(onTap: onTap, haptic: false, scale: 0.94, semanticLabel: label, child: card),
    );
  }
}

/// The still, drawn once (staggered over a few frames so opening the picker
/// does not hitch) and cached; until then the card's gradient shows through.
/// Keyed by look, so a look change draws (or reuses) that look's still.
class _Thumb extends StatefulWidget {
  const _Thumb({super.key, required this.id, required this.look});
  final int id;
  final FightLook look;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    FightStageThumbs.updates.addListener(_onUpdate);
    _img = FightStageThumbs.cached(widget.id, look: widget.look);
    if (_img == null) {
      Future<void>.delayed(Duration(milliseconds: 20 + 30 * (widget.id % 6)), () {
        if (!mounted) return;
        setState(() => _img = FightStageThumbs.of(widget.id, look: widget.look));
      });
    }
  }

  void _onUpdate() {
    final next = FightStageThumbs.cached(widget.id, look: widget.look);
    if (mounted && next != null && next != _img) setState(() => _img = next);
  }

  @override
  void dispose() {
    FightStageThumbs.updates.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null) return const SizedBox.shrink();
    final pixel = widget.look == FightLook.pixel;
    return RawImage(image: img, fit: BoxFit.cover, filterQuality: pixel ? FilterQuality.none : FilterQuality.medium);
  }
}
