import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart' show DateFormat;
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../legal_links.dart';
import '../services/link_opener.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_kit.dart';
import 'session_guard.dart';

/// The age check, client side. The rules mirror `backend/convex/ageCore.ts`,
/// which is what actually decides: under [kMinAgeApp] no account, under
/// [kMinAgeOwnAccount] only a family account a parent creates, otherwise
/// their own. The app asks first so a refused child never sends anything.
///
/// Two entry points:
///  * [askAgeForSignUp], before password and Apple/Google sign-up.
///  * [ensureAgeGiven], once per launch for accounts that never gave an age.
///
/// Both pick a month and year on wheels, then confirm ("you're 12, is that
/// right?") because the answer is locked once saved: only staff can change it.

const int kMinAgeApp = 9;
const int kMinAgeOwnAccount = 13;

/// A birth month. The day is never asked (`ageCore.ts` says why).
@immutable
class BirthMonth {
  const BirthMonth(this.year, this.month);
  final int year;

  /// 1 to 12.
  final int month;
}

enum AgeBand { tooYoung, needsGuardian, ok }

/// Whole years old at [now], counting the birthday as the last day of the
/// month, exactly like `ageCore.ageInYears`.
int ageInYears(BirthMonth b, DateTime now) {
  final utc = now.toUtc();
  final months = (utc.year * 12 + utc.month) - (b.year * 12 + b.month);
  return (months - 1) ~/ 12;
}

AgeBand ageBand(int age) {
  if (age < kMinAgeApp) return AgeBand.tooYoung;
  if (age < kMinAgeOwnAccount) return AgeBand.needsGuardian;
  return AgeBand.ok;
}

/// Remembers on this install that a sign-up was refused for age, so closing
/// the sheet and picking an older year is not the way past it. Cleared only by
/// reinstalling: a typo is what the confirm step and support are for.
class AgeGateLock {
  static const _key = 'mh.ageGate.refused';

  static Future<AgeBand?> read() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_key);
      return AgeBand.values.where((b) => b.name == v).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(AgeBand band) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, band.name);
    } catch (_) {}
  }
}

/// Asks the age before a sign-up. Returns the month to send, or null when the
/// person backed out or is too young (the sheet has already told them why).
Future<BirthMonth?> askAgeForSignUp(BuildContext context) async {
  final locked = await AgeGateLock.read();
  if (!context.mounted) return null;
  return showAdaptiveSheet<BirthMonth>(
    context,
    builder: (_) => _AgeSheet(existing: false, lockedBand: locked),
  );
}

/// Shows the age sheet if this account never gave an age, and does not return
/// until it has. Like `ensureTermsAccepted`: asks once per launch, blocks only
/// on a definite "needed", and cannot be swiped away. An answer under 13
/// restricts the account on the server, and this signs the device out to the
/// paused notice.
Future<void> ensureAgeGiven(BuildContext context, ChatApi api) async {
  final needed = await api.ageNeeded();
  if (needed != true || !context.mounted) return;
  final restricted = await showAdaptiveSheet<bool>(
    context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _AgeSheet(existing: true, api: api),
  );
  if (restricted == true) SessionGuard.instance.ageRestrictedNow();
}

enum _Step { pick, confirm, refused }

class _AgeSheet extends StatefulWidget {
  const _AgeSheet({required this.existing, this.api, this.lockedBand});

  /// An existing account (blocking, saves to the server) rather than sign-up.
  final bool existing;
  final ChatApi? api;

  /// A refusal already recorded on this install: open straight on it.
  final AgeBand? lockedBand;

  @override
  State<_AgeSheet> createState() => _AgeSheetState();
}

class _AgeSheetState extends State<_AgeSheet> {
  static const double _row = 38;

  late final DateTime _now = DateTime.now();

  /// Newest year first, back to 100 years ago.
  late final List<int> _years = [
    for (var y = _now.year; y >= _now.year - 100; y--) y,
  ];

  late _Step _step = widget.lockedBand == null ? _Step.pick : _Step.refused;
  late AgeBand _band = widget.lockedBand ?? AgeBand.ok;

  // Start on January, 15 years ago: a neutral spot that reads as neither a
  // suggestion to be an adult nor a child.
  int _month = 1;
  late int _yearIndex = 15;

  late final _months = FixedExtentScrollController(initialItem: _month - 1);
  late final _yearsCtl = FixedExtentScrollController(initialItem: _yearIndex);

  bool _busy = false;
  String? _error;

  BirthMonth get _birth => BirthMonth(_years[_yearIndex], _month);
  int get _age => ageInYears(_birth, _now);

  /// A month after this one has not happened yet.
  bool get _inFuture =>
      _birth.year * 12 + _birth.month > _now.year * 12 + _now.month;

  @override
  void dispose() {
    _months.dispose();
    _yearsCtl.dispose();
    super.dispose();
  }

  String _monthName(int month) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.MMMM(locale).format(DateTime(2000, month));
  }

  void _toConfirm() {
    if (_inFuture) {
      setState(() => _error = AppLocalizations.of(context).authErrorAgeInvalid);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _step = _Step.confirm;
    });
  }

  Future<void> _confirm() async {
    if (_busy) return;
    if (!widget.existing) {
      final band = ageBand(_age);
      if (band == AgeBand.ok) {
        Navigator.of(context).pop(_birth);
        return;
      }
      await AgeGateLock.write(band);
      if (!mounted) return;
      setState(() {
        _band = band;
        _step = _Step.refused;
      });
      return;
    }
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      // Restricted: the server already revoked this session, so every open
      // subscription is about to fail. Close now and let the caller sign out;
      // the login screen explains the pause and offers the delete.
      nav.pop(await widget.api!.submitAge(_birth));
    } catch (e) {
      // Already given (another device answered first): nothing left to ask.
      if (e.toString().contains('AGE_ALREADY_SET')) {
        nav.pop(false);
        return;
      }
      toast.error(l10n.termsAcceptFailed);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (_step) {
      _Step.pick => l10n.ageSheetTitle,
      _Step.confirm => l10n.ageConfirmTitle,
      _Step.refused => _band == AgeBand.tooYoung
          ? l10n.ageTooYoungTitle
          : l10n.ageNeedsGuardianTitle,
    };
    // An existing account cannot leave without answering. Sign-up can always
    // back out. (The refused step is sign-up only: see [_confirm].)
    final canClose = !widget.existing;
    return PopScope(
      canPop: canClose,
      child: SheetFrame(
        title: title,
        showClose: canClose,
        handle: canClose,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (_step) {
            _Step.pick => _pick(context),
            _Step.confirm => _confirmStep(context),
            _Step.refused => _refused(context),
          },
        ),
      ),
    );
  }

  Widget _text(BuildContext context, String text) {
    final theme = ThemeScope.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.bodySoft.copyWith(color: theme.inkMuted),
    );
  }

  Widget _pick(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('pick'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          context,
          widget.existing ? l10n.ageSheetBodyExisting : l10n.ageSheetBodySignUp,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: _row * 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The selection band behind the centre row of both wheels.
              Container(
                height: _row,
                decoration: BoxDecoration(
                  color: theme.ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Wheel(
                      semanticLabel: l10n.ageMonthLabel,
                      controller: _months,
                      count: 12,
                      label: (i) => _monthName(i + 1),
                      onSelected: (i) => setState(() {
                        _month = i + 1;
                        _error = null;
                      }),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _Wheel(
                      semanticLabel: l10n.ageYearLabel,
                      controller: _yearsCtl,
                      count: _years.length,
                      label: (i) => '${_years[i]}',
                      onSelected: (i) => setState(() {
                        _yearIndex = i;
                        _error = null;
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          FormErrorBanner(_error!),
        ],
        const SizedBox(height: 18),
        SheetActionButton(label: l10n.ageContinue, onTap: _toConfirm),
      ],
    );
  }

  Widget _confirmStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey('confirm'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          context,
          l10n.ageConfirmBody(
            _monthName(_birth.month),
            '${_birth.year}',
            '$_age',
          ),
        ),
        const SizedBox(height: 18),
        SheetActionButton(
          label: l10n.ageConfirmYes,
          busy: _busy,
          onTap: _confirm,
        ),
        const SizedBox(height: 10),
        SheetActionButton(
          label: l10n.ageConfirmChange,
          tonal: true,
          onTap: _busy ? null : () => setState(() => _step = _Step.pick),
        ),
      ],
    );
  }

  Widget _refused(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    return Column(
      key: const ValueKey('refused'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _text(
          context,
          _band == AgeBand.tooYoung
              ? l10n.ageTooYoungBody
              : l10n.ageNeedsGuardianBody,
        ),
        const SizedBox(height: 18),
        SheetActionButton(label: l10n.ageGateOk, onTap: () => nav.pop()),
        const SizedBox(height: 10),
        SheetActionButton(
          label: l10n.ageWrongContactSupport,
          tonal: true,
          onTap: () => LinkOpener.open(context, kSupportMailto),
        ),
      ],
    );
  }
}

/// One flat wheel, styled like the schedule picker's (`schedule_time_picker`).
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.semanticLabel,
    required this.controller,
    required this.count,
    required this.label,
    required this.onSelected,
  });

  final String semanticLabel;
  final FixedExtentScrollController controller;
  final int count;
  final String Function(int row) label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = ThemeScope.of(context);
    return Semantics(
      label: semanticLabel,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _AgeSheetState._row,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 100,
        perspective: 0.0001,
        overAndUnderCenterOpacity: 0.38,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onSelected(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, row) => Center(
            child: Text(
              label(row),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(
                fontSize: 21,
                color: theme.ink,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
