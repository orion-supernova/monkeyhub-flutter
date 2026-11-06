import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../data/vanish_controller.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../privacy/vanish_rules.dart';
import '../theme/theme_scope.dart';
import '../theme/vanish_palette.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart' show GroupedRow;
import 'sheet_kit.dart' show SheetFrame, SheetGroup;

/// "10 seconds" / "1 minute" / "1 hour" for a vanish timer.
String vanishTimerLabel(AppLocalizations l10n, int seconds) => switch (seconds) {
      10 => l10n.vanishAfterSeen10,
      60 => l10n.vanishAfterSeen60,
      3600 => l10n.vanishAfterSeen3600,
      _ => l10n.vanishAfterSeenOther(seconds),
    };

/// The sentence of a `vanish:` system line.
///
/// [name] is null when the reader did it themselves: "You turned on …" is its
/// own sentence in every language rather than "You" dropped into a name slot,
/// because most languages conjugate the verb for "you" (Turkish açtın, not
/// açtı).
String vanishLineText(
  AppLocalizations l10n,
  VanishLine line, {
  required String? name,
}) {
  final timer = vanishTimerLabel(l10n, line.seconds ?? 10);
  return switch (line.kind) {
    VanishLineKind.on => name == null
        ? l10n.vanishSysOnSelf(timer)
        : l10n.vanishSysOn(name, timer),
    VanishLineKind.change => name == null
        ? l10n.vanishSysChangeSelf(timer)
        : l10n.vanishSysChange(name, timer),
    VanishLineKind.off =>
      name == null ? l10n.vanishSysOffSelf : l10n.vanishSysOff(name),
  };
}

/// The small picker behind "Change": 10 seconds, 1 minute or 1 hour after
/// everyone has seen a message. Resolves with the pick, or null.
Future<int?> showVanishTimerPicker(BuildContext context, int current) {
  return showAdaptiveSheet<int>(
    context,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return SheetFrame(
        title: l10n.vanishTimerPickerTitle,
        showClose: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: SheetGroup(
          children: [
            for (final s in kVanishAfterSeenOptions)
              GroupedRow.choice(
                title: vanishTimerLabel(l10n, s),
                selected: s == current,
                onTap: () => Navigator.of(sheetContext).pop(s),
              ),
          ],
        ),
      );
    },
  );
}

/// The short "what vanish mode does" sheet behind a tap on the system line:
/// four one-line facts, no paragraph.
Future<void> showVanishExplainer(BuildContext context, int seconds) {
  return showAdaptiveSheet<void>(
    context,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final theme = ThemeScope.of(sheetContext);
      final violet = VanishPalette(theme).vanish;
      Widget fact(IconData icon, String text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 18, color: violet),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: theme.body.copyWith(color: theme.ink, height: 1.3),
                  ),
                ),
              ],
            ),
          );
      return SheetFrame(
        title: l10n.vanishExplainTitle,
        showClose: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            fact(CupertinoIcons.timer,
                l10n.vanishExplainSeen(vanishTimerLabel(l10n, seconds))),
            fact(CupertinoIcons.clock, l10n.vanishExplain24h),
            fact(CupertinoIcons.camera_viewfinder, l10n.vanishExplainShots),
            fact(CupertinoIcons.device_phone_portrait, l10n.vanishExplainApp),
          ],
        ),
      );
    },
  );
}

/// A `vanish:on|change|off` system line in the transcript: ONE short quiet
/// centered sentence with a small timer glyph inline before it, in the vanish
/// violet. Tapping the line (on / change) opens [showVanishExplainer]; "Change"
/// follows it when the viewer may change the timer.
class VanishSystemLine extends StatelessWidget {
  const VanishSystemLine({
    super.key,
    required this.line,
    required this.name,
    this.onChange,
  });

  final VanishLine line;

  /// Who did it: their display name, or null when it was the reader.
  final String? name;

  /// Null hides "Change".
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final violet = VanishPalette(theme).vanish;
    final base = theme.bodySoft.copyWith(
      fontSize: 13,
      height: 1.3,
      letterSpacing: 0,
      color: theme.inkMuted,
    );
    // "Off" has no timer to explain; the other two open the explainer.
    final explain = line.kind != VanishLineKind.off;
    final text = Text.rich(
      TextSpan(
        style: base,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(CupertinoIcons.timer, size: 13, color: violet),
            ),
          ),
          // With "Change" after it, the last word and "Change" are glued
          // with no-break spaces so "Change" never wraps onto a line alone.
          TextSpan(
            text: onChange == null
                ? vanishLineText(l10n, line, name: name)
                : _glueLastWord(vanishLineText(l10n, line, name: name)),
          ),
          if (onChange != null) ...[
            const TextSpan(text: '\u00A0'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FocusableTap(
                onTap: onChange!,
                semanticLabel: l10n.vanishSysChangeAction,
                radius: 6,
                inset: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChange,
                  child: Text(
                    l10n.vanishSysChangeAction,
                    style: base.copyWith(
                      color: violet,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      textAlign: TextAlign.center,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: explain
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  showVanishExplainer(context, line.seconds ?? 10),
              child: text,
            )
          : text,
    );
  }
}

/// The inline transcript card for someone who hides their Seen in a vanishing
/// chat. Not a modal and it never blocks anything; dismissing it is the same
/// as "Don't share here".
class HiddenSeenCard extends StatelessWidget {
  const HiddenSeenCard({
    super.key,
    required this.isDm,
    required this.name,
    required this.afterSeen,
    required this.onAnswer,
  });

  final bool isDm;

  /// The other person's first name, for the DM copy.
  final String name;

  /// The room's timer in seconds.
  final int afterSeen;

  /// true = "Share my reads here", false = "Don't share here" or dismissed.
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final violet = VanishPalette(theme).vanish;
    final timer = vanishTimerLabel(l10n, afterSeen);
    final body = isDm
        ? l10n.vanishCardDm(name, timer)
        : l10n.vanishCardGroup(timer);
    return _CardShell(
      violet: violet,
      leading: FocusableTap(
        onTap: () => onAnswer(false),
        semanticLabel: l10n.vanishCardDismissSemantics,
        radius: 12,
        inset: 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onAnswer(false),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(CupertinoIcons.xmark, size: 13, color: theme.inkMuted),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(body, style: theme.body.copyWith(color: theme.ink, fontSize: 14.5)),
          const SizedBox(height: 6),
          Text(
            l10n.vanishSettingsNote,
            style: theme.bodySoft.copyWith(color: theme.inkMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: l10n.vanishCardShare,
                  filled: true,
                  violet: violet,
                  onTap: () => onAnswer(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardButton(
                  label: l10n.vanishCardKeep,
                  filled: false,
                  violet: violet,
                  onTap: () => onAnswer(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What replaces the card once it is answered: a short note that always ends
/// with the Settings pointer.
class HiddenSeenNote extends StatelessWidget {
  const HiddenSeenNote({super.key, required this.shared, required this.afterSeen});

  final bool shared;
  final int afterSeen;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final text = shared
        ? l10n.vanishNoteShared(vanishTimerLabel(l10n, afterSeen))
        : l10n.vanishNoteKept;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Text(
        '$text ${l10n.vanishSettingsNote}',
        textAlign: TextAlign.center,
        style: theme.bodySoft.copyWith(
          fontSize: 12.5,
          height: 1.3,
          letterSpacing: 0,
          color: theme.inkMuted,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.violet, required this.child, this.leading});

  final Color violet;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: violet.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top-start, the way every close button sits.
          if (leading != null) ...[
            Align(alignment: AlignmentDirectional.centerStart, child: leading),
            const SizedBox(height: 2),
          ],
          child,
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.filled,
    required this.violet,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final Color violet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final fg = filled ? VanishPalette.onColor(violet) : theme.ink;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: 12,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? violet : violet.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.body.copyWith(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the hidden-seen card (or its note) lives in the transcript: just
/// under the newest message. Collapses to nothing when there is nothing to
/// ask, and grows in rather than fading.
class VanishHiddenSeenSlot extends StatelessWidget {
  const VanishHiddenSeenSlot({
    super.key,
    required this.controller,
    required this.vanishOn,
    required this.isDm,
    required this.name,
    required this.afterSeen,
  });

  final VanishController controller;
  final bool vanishOn;
  final bool isDm;
  final String name;
  final int afterSeen;

  @override
  Widget build(BuildContext context) {
    if (!vanishOn) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final answered = controller.answeredShare;
        final Widget child;
        if (answered != null) {
          child = HiddenSeenNote(shared: answered, afterSeen: afterSeen);
        } else if (showHiddenSeenCard(
          vanishOn: vanishOn,
          prefs: controller.prefs,
          answeredHere: false,
        )) {
          child = HiddenSeenCard(
            isDm: isDm,
            name: name,
            afterSeen: afterSeen,
            onAnswer: controller.answer,
          );
        } else {
          child = const SizedBox.shrink();
        }
        return AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
    );
  }
}

/// The quiet line above the composer once a vanishing message runs long.
class VanishLongHint extends StatelessWidget {
  const VanishLongHint({
    super.key,
    required this.text,
    required this.enabled,
    this.threshold = kVanishLongMessage,
  });

  final ValueListenable<TextEditingValue> text;
  final bool enabled;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: text,
      builder: (context, v, _) {
        final theme = ThemeScope.of(context);
        final show = v.text.characters.length > threshold;
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: show
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: Text(
                    AppLocalizations.of(context).vanishLongHint,
                    textAlign: TextAlign.center,
                    style: theme.bodySoft.copyWith(
                      fontSize: 12,
                      letterSpacing: 0,
                      color: theme.inkMuted,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

/// Past this many characters the composer says a vanishing message may go
/// before it is finished.
const int kVanishLongMessage = 160;

/// The chat's wash while vanish is on: one flat colour layer, drawn as a circle
/// that grows from where the swipe began (the violet wave) and shrinks back
/// when vanish turns off. A painted circle, not a blur and not a clip path, so
/// it costs one fill per frame while it moves and nothing once settled.
class VanishTint extends StatefulWidget {
  const VanishTint({
    super.key,
    required this.on,
    this.origin = const Alignment(0, 1),
  });

  final bool on;

  /// Where the wave starts, in the box's alignment space. The swipe begins at
  /// the bottom edge.
  final Alignment origin;

  @override
  State<VanishTint> createState() => _VanishTintState();
}

class _VanishTintState extends State<VanishTint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    value: widget.on ? 1 : 0,
  );
  late final Animation<double> _eased =
      CurvedAnimation(parent: _wave, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

  @override
  void didUpdateWidget(VanishTint old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    if (widget.on) {
      _wave.forward();
    } else {
      _wave.reverse();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TintPainter(
            animation: _eased,
            color: VanishPalette(theme).tint,
            origin: widget.origin,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TintPainter extends CustomPainter {
  _TintPainter({
    required this.animation,
    required this.color,
    required this.origin,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0) return;
    final c = origin.alongSize(size);
    // Far enough that the circle covers the whole box at t = 1.
    final far = [
      (c - Offset.zero).distance,
      (c - Offset(size.width, 0)).distance,
      (c - Offset(0, size.height)).distance,
      (c - Offset(size.width, size.height)).distance,
    ].reduce((a, b) => a > b ? a : b);
    if (t >= 1) {
      canvas.drawRect(Offset.zero & size, Paint()..color = color);
    } else {
      canvas.drawCircle(c, far * t, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TintPainter old) =>
      old.color != color || old.origin != origin || old.animation != animation;
}

/// [s] with its last space made a no-break space, so the final word stays on
/// the same line as whatever follows it.
String _glueLastWord(String s) {
  final i = s.lastIndexOf(' ');
  return i < 0 ? s : '${s.substring(0, i)}\u00A0${s.substring(i + 1)}';
}
