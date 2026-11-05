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

/// One still picture per stage, drawn once per process and shared by every
/// picker (never six live stages at once).
class FightStageThumbs {
  FightStageThumbs._();
  static const double w = 320, h = 200;
  static final Map<int, ui.Image> _cache = {};

  static ui.Image? cached(int id) => _cache[id];

  static ui.Image? of(int id) {
    final hit = _cache[id];
    if (hit != null) return hit;
    try {
      final art = StageArt();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const size = ui.Size(w, h);
      // Most of the stage in view, the floor at 85% height, the middle centred.
      final scale = w / 820;
      art.paint(c, size, FightCamera(scale, w / 2 - 600 * scale, h * .85), FightLook.painted, 96, id);
      final pic = rec.endRecording();
      final img = pic.toImageSync(w.toInt(), h.toInt());
      pic.dispose();
      art.dispose();
      return _cache[id] = img;
    } catch (_) {
      return null;
    }
  }
}

/// A sideways row of stage thumbnails: tap one to pick it. [selected] is a
/// stage id, or [kFightStageRandom]. [readOnly] shows just the selected stage
/// (the online guest, who cannot change the host's choice).
class FightStagePicker extends StatelessWidget {
  const FightStagePicker({super.key, required this.selected, required this.onPick, this.readOnly = false, this.allowRandom = true});

  final int selected;
  final ValueChanged<int> onPick;
  final bool readOnly;
  final bool allowRandom;

  static const double _cardW = 112, _cardH = 70, _labelH = 22;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = [for (final d in kFightStages) d.id, if (allowRandom && !readOnly) kFightStageRandom];
    if (readOnly) {
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: _cardW * 1.5,
          height: _cardH * 1.5 + _labelH,
          child: _StageCard(id: fightStageOf(selected), selected: true, w: _cardW * 1.5, h: _cardH * 1.5, label: fightStageName(l10n, selected), onTap: null),
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
  const _StageCard({super.key, required this.id, required this.selected, required this.w, required this.h, required this.label, required this.onTap});

  final int id;
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
              : _Thumb(id: id),
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
class _Thumb extends StatefulWidget {
  const _Thumb({required this.id});
  final int id;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    _img = FightStageThumbs.cached(widget.id);
    if (_img == null) {
      Future<void>.delayed(Duration(milliseconds: 20 + 30 * (widget.id % 6)), () {
        if (!mounted) return;
        setState(() => _img = FightStageThumbs.of(widget.id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null) return const SizedBox.shrink();
    return RawImage(image: img, fit: BoxFit.cover, filterQuality: FilterQuality.medium);
  }
}
