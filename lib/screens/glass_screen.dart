import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/glass_config.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/value_slider.dart';
import 'navigation/native_tab_bar.dart' show NativeChrome;
import 'navigation/pill_bottom_nav.dart';

/// Live tuning for every glass surface, plus named slots to keep looks in.
///
/// Edits land on [SettingsStore.glass] immediately rather than behind an
/// "apply" — the whole point is watching the bar change under your finger, and
/// the preview at the top is the real [PillBottomNav] over real content, not a
/// schematic. A blur and a colour boost are invisible against a flat swatch, so
/// a fake preview here would be a preview of nothing.
class GlassScreen extends StatefulWidget {
  const GlassScreen({super.key});

  @override
  State<GlassScreen> createState() => _GlassScreenState();
}

/// The panels, in scroll order. Each owns a sticky header, and each says what
/// the preview above it should be showing.
enum _Panel {
  looks(_Shows.bar),
  bar(_Shows.bar),
  surfaces(_Shows.surfaces),
  layout(_Shows.bar);

  const _Panel(this.shows);
  final _Shows shows;
}

/// What the preview renders. The bottom bar and the rest of the app are tuned
/// separately, so previewing the bar while you drag the app-wide dials shows
/// you nothing — which is the state this screen shipped in.
enum _Shows { bar, surfaces }

/// Gutter down the preview's right edge kept clear of preview content, so the
/// floating collapse control never lands on top of it.
const double _previewChromeGutter = 92;

/// One duration for every transition on this screen, so the preview's height,
/// its contents and its glass all settle together instead of at three
/// different speeds.
const Duration _glassMotion = Duration(milliseconds: 260);

class _GlassScreenState extends State<GlassScreen> {
  // Chat, because it is the destination carrying a badge in the sample — so
  // the one case where the badge has to hold up, sitting on the selected
  // pill, is the case on screen by default.
  HomeSection _previewSection = HomeSection.chat;

  final _panelKeys = {for (final p in _Panel.values) p: GlobalKey()};
  _Panel _activePanel = _Panel.looks;
  final _scrollKey = GlobalKey();

  /// Guards against queueing a measurement per scroll event.
  ///
  /// A drag emits a notification every frame, and each was posting its own
  /// post-frame callback — so a single flick queued dozens of identical
  /// measurements, each capable of a setState. One in flight at a time is
  /// enough: the callback runs after the frame the last event belongs to.
  bool _syncQueued = false;

  void _queueSyncActivePanel() {
    if (_syncQueued) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (mounted) _syncActivePanel();
    });
  }

  /// Follows the sticky header currently parked at the top of the list.
  ///
  /// Read off the laid-out headers rather than from scroll offsets, because the
  /// preview's own height animates and the dial rows are lazily built, so there
  /// is no stable offset table to compare against. Headers come in panel order,
  /// so the last one at or above the fold is the one the reader is inside.
  void _syncActivePanel() {
    final scrollBox = _scrollKey.currentContext?.findRenderObject();
    if (scrollBox is! RenderBox || !scrollBox.hasSize) return;
    // The whole pinned zone, not just the preview: a header parked directly
    // under the preview sits up to its own height below it, so measuring to the
    // preview's bottom alone never counts the header that is actually stuck
    // there, and the panel never changed.
    final fold =
        scrollBox.localToGlobal(Offset.zero).dy +
        _livePreviewHeight +
        _PinnedLabel.height;

    _Panel? found;
    for (final p in _Panel.values) {
      final box = _panelKeys[p]!.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero).dy <= fold) found = p;
    }
    if (found != null && found != _activePanel) {
      setState(() => _activePanel = found!);
    }
  }

  bool _expanded = true;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  /// The preview height actually on screen this frame.
  ///
  /// Tracked because [_syncActivePanel] measures against it, and during a
  /// transition the target height is not where the header currently is — using
  /// the target would misjudge the fold for the length of every animation.
  double _livePreviewHeight = 0;

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    // A drag that ended less than the debounce ago has not been written yet,
    // and leaving this screen is exactly when that happens.
    SettingsStore.instance.flushGlassWrites();
    super.dispose();
  }

  SettingsStore get _store => SettingsStore.instance;

  /// Every edit routes through here, and every edit *keeps* the look it is
  /// based on.
  ///
  /// Dropping to "no preset" on the first slider move was the obvious thing and
  /// the wrong one: with nothing to measure against, the baseline fell back to
  /// the untuned recipe, and Frosted's own two dials immediately lit up as
  /// though the user had moved them. Holding the pointer means "edited" keeps
  /// meaning edited, and gives reset somewhere to go.
  void _edit(GlassProfile next) =>
      _store.setGlassProfile(next, presetId: _store.glassPresetId);

  /// What "reset" goes back to: the look you picked, or the untuned recipe when
  /// you are on Custom.
  ///
  /// Not the raw recipe unconditionally, which is what this did first and which
  /// read as a bug: selecting Frosted left every reset control lit up, because
  /// Frosted *is* two dials away from the raw recipe — and pressing one took
  /// you to a third look that was neither. Marking edits against the active
  /// preset means the accent values and the undo buttons show your changes, not
  /// the preset's.
  GlassProfile get _baseline {
    final id = _store.glassPresetId;
    if (id == null) return const GlassProfile();
    return _store.glassPresets
        .firstWhere(
          (p) => p.id == id,
          orElse: () =>
              const GlassPreset(id: '', name: '', profile: GlassProfile()),
        )
        .profile;
  }

  String get _baselineName {
    final id = _store.glassPresetId;
    if (id == null) return '';
    final l10n = AppLocalizations.of(context);
    for (final p in _store.glassPresets) {
      if (p.id == id) return glassPresetName(l10n, p);
    }
    return '';
  }

  /// Removes the override when the baseline is standard there, so a config
  /// that has been reset back to a plain look stays sparse rather than
  /// accumulating explicit copies of every default.
  GlassConfig _resetKnob(GlassConfig config, GlassConfig base, GlassKnob k) =>
      base.isStandard(k) ? config.reset(k) : config.set(k, base.of(k));

  /// The panel's sticky-header title, in display order.
  String _panelLabel(_Panel panel) {
    final l10n = AppLocalizations.of(context);
    switch (panel) {
      case _Panel.looks:
        return l10n.glassScreenPanelLooks;
      case _Panel.bar:
        return l10n.glassScreenPanelBottomBar;
      case _Panel.surfaces:
        return l10n.glassScreenPanelOtherSurfaces;
      case _Panel.layout:
        return l10n.glassScreenPanelBarLayout;
    }
  }

  /// Where the preview is heading: depends on the panel being read, on whether
  /// it is collapsed, and on the layout dials, all of which can change at once.
  double _targetPreviewHeight() => _expanded
      ? _GlassPreview.expandedHeightFor(
          _store.glass.geometry,
          _activePanel.shows,
        )
      : _GlassPreview.collapsedHeightFor(
          _store.glass.geometry,
          _activePanel.shows,
        );

  /// A panel: its sticky header, then its rows.
  ///
  /// Grouped, so the header pins only while its own rows are on screen and is
  /// then pushed out by the next panel's. Four bare pinned headers simply
  /// accumulate at the top — all four ended up stacked under the preview,
  /// eating 184pt of screen and never handing over, so nothing downstream could
  /// tell which panel was actually being read.
  ///
  /// [lead] sits above the rows on the page itself (a note, the look list,
  /// an action); [dials] are the sliders, drawn as one inset grouped plate —
  /// the same 16pt gutter and rounded block as every other settings page —
  /// but still built lazily, one sliver item per dial.
  Widget _panel(
    AppTheme theme,
    _Panel panel, {
    String? note,
    VoidCallback? onReset,
    List<Widget> lead = const [],
    List<Widget> dials = const [],
  }) => SliverMainAxisGroup(
    slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedLabel(
          signature: Object.hash(panel, onReset != null, theme.accent),
          child: GroupedHeader(
            _panelLabel(panel),
            key: _panelKeys[panel],
            trailing: onReset == null
                ? null
                : _MiniAction(
                    key: glassPanelResetKey(_panelLabel(panel)),
                    icon: CupertinoIcons.arrow_counterclockwise,
                    tip: AppLocalizations.of(
                      context,
                    ).glassScreenResetTooltip(_panelLabel(panel)),
                    onTap: onReset,
                  ),
          ),
        ),
      ),
      // Nothing above the dials: no padding either, or the header sits a
      // further 16pt off its plate than every other header on the page.
      SliverPadding(
        padding: note == null && lead.isEmpty
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(16, 0, 16, dials.isEmpty ? 28 : 12),
        sliver: SliverList.list(
          children: [
            if (note != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(note, style: groupedFooterStyle(theme)),
              ),
              const SizedBox(height: 12),
            ],
            ...lead,
          ],
        ),
      ),
      if (dials.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList.builder(
            itemCount: dials.length,
            itemBuilder: (context, i) =>
                _PlateItem(first: i == 0, last: i == dials.length - 1, child: dials[i]),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final profile = _store.glass;
    final activeId = _store.glassPresetId;
    final base = _baseline;
    final dirty = profile != base;
    final liquid = NativeChrome.supported &&
        _store.glassEngine == GlassEngine.native;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // A flat fill, not theme.backgroundLayer, and this is the one screen
          // where that is right.
          //
          // Every theme's background layer is position-dependent — an accent
          // wash over the top third, a vignette, and on Retro Wave a hard
          // purple sky that is not the background colour at all. This screen
          // pins two opaque bands over it (the preview, and whichever panel
          // title is stuck under it), and an opaque band can only match a
          // gradient at one scroll position. On light themes the seam was
          // plainly visible; on Retro Wave the band was a different colour
          // entirely. Flat, everything matches at every offset, on all
          // thirteen. The colour on this screen comes from the preview.
          Positioned.fill(child: ColoredBox(color: theme.background)),
          SafeArea(
            child: AdaptivePageBody(
              // The pinned header's extent is animated, and a sliver's extent
              // is read at layout time — so the scroll view itself has to
              // rebuild each frame of the expand. Only the visible dial rows
              // are built, so this is a handful of widgets, not seventeen.
              // One tween drives every height change — collapsing, switching
              // panel, and dragging a layout dial all move the same number, so
              // they cannot fight each other. A sliver's extent is read at
              // layout time, which is why the scroll view itself rebuilds
              // rather than something inside the header.
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _targetPreviewHeight()),
                duration: _glassMotion,
                curve: Curves.easeOutCubic,
                builder: (context, previewHeight, _) {
                  _livePreviewHeight = previewHeight;
                  return NotificationListener<ScrollNotification>(
                    // After the frame, so the headers being measured have
                    // already been laid out at their new positions.
                    onNotification: (_) {
                      _queueSyncActivePanel();
                      return false;
                    },
                    child: CustomScrollView(
                      key: _scrollKey,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (Navigator.of(context).canPop())
                                  const GlassBackButton(),
                                const SizedBox(height: 14),
                                // IosPage's title gutter: 20pt, so the large
                                // title lands where it does on every other
                                // settings page — the back button keeps 16.
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).glassScreenHeading,
                                        style: theme.displayLarge
                                            .copyWith(letterSpacing: 0.37),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        ).glassScreenLead,
                                        style: theme.bodySoft,
                                      ),
                                    ],
                                  ),
                                ),
                                if (NativeChrome.supported) ...[
                                  const SizedBox(height: 22),
                                  const _GlassStyleChooser(),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Under Liquid Glass iOS owns the look: no preview, no
                        // dials, nothing that would move only half the glass.
                        if (!liquid) ...[
                        // Sticks to the top once it gets there, so every dial below
                        // is judged against the thing it changes. Seventeen sliders
                        // is far more than one screen, and a preview you have to
                        // scroll back to is a preview you stop using.
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedPreview(
                            height: previewHeight,
                            // The delegate is rebuilt whenever any of this changes —
                            // the whole profile, because a glass dial has to repaint
                            // the preview and a layout dial has to resize it too.
                            signature: Object.hash(
                              profile,
                              _previewSection,
                              _expanded,
                              _activePanel.shows,
                            ),
                            child: _GlassPreview(
                              shows: _activePanel.shows,
                              section: _previewSection,
                              onSelect: (s) =>
                                  setState(() => _previewSection = s),
                              expanded: _expanded,
                              onToggle: _toggleExpanded,
                            ),
                          ),
                        ),

                        _panel(
                          theme,
                          _Panel.looks,
                          lead: [
                            // One grouped list, the chosen look checked —
                            // not a stack of separate cards.
                            GroupedSection(
                              margin: EdgeInsets.zero,
                              children: _presetRows(theme, activeId, dirty),
                            ),
                            const SizedBox(height: 16),
                            _ActionRow(
                              icon: CupertinoIcons.plus,
                              label: _store.glassSlotsFull
                                  ? AppLocalizations.of(
                                      context,
                                    ).glassScreenSaveSlotsFull(kMaxGlassSlots)
                                  : AppLocalizations.of(
                                      context,
                                    ).glassScreenSaveCurrentAs,
                              enabled: !_store.glassSlotsFull,
                              onTap: _promptSave,
                            ),
                            const SizedBox(height: 8),
                            _ActionRow(
                              icon: CupertinoIcons.arrow_counterclockwise,
                              label: base == const GlassProfile()
                                  ? AppLocalizations.of(
                                      context,
                                    ).glassScreenResetEveryDial
                                  : AppLocalizations.of(
                                      context,
                                    ).glassScreenResetToPreset(
                                      _baselineName,
                                    ),
                              // Undoes your edits, back to whatever the selected
                              // look says — or to the untuned recipe when nothing
                              // is selected.
                              enabled: dirty,
                              onTap: () => _store.setGlassProfile(
                                base,
                                presetId: _store.glassPresetId,
                              ),
                            ),
                          ],
                        ),

                        _panel(
                          theme,
                          _Panel.bar,
                          onReset: profile.nav == base.nav
                              ? null
                              : () => _edit(profile.copyWith(nav: base.nav)),
                          dials: _knobRows(
                            theme,
                            glassKnobs,
                            profile.nav,
                            base.nav,
                            (c) => _edit(profile.copyWith(nav: c)),
                          ),
                        ),

                        _panel(
                          theme,
                          _Panel.surfaces,
                          note: AppLocalizations.of(
                            context,
                          ).glassScreenSurfacesNote,
                          onReset: profile.app == base.app
                              ? null
                              : () => _edit(profile.copyWith(app: base.app)),
                          lead: [
                            // The two configs are separate because these
                            // surfaces sit over text rather than over scrolling
                            // content, so they usually want more fill. But once
                            // the bar is tuned, "the same, please" is the common
                            // next thought, and hand-matching eight dials to get
                            // there is miserable.
                            _ActionRow(
                              icon: CupertinoIcons.arrow_right_arrow_left,
                              label: AppLocalizations.of(
                                context,
                              ).glassScreenMatchBottomBar,
                              enabled: profile.app != profile.nav,
                              onTap: () =>
                                  _edit(profile.copyWith(app: profile.nav)),
                            ),
                            const SizedBox(height: 4),
                          ],
                          dials: _knobRows(
                            theme,
                            glassKnobs,
                            profile.app,
                            base.app,
                            (c) => _edit(profile.copyWith(app: c)),
                          ),
                        ),

                        _panel(
                          theme,
                          _Panel.layout,
                          onReset: profile.geometry == base.geometry
                              ? null
                              : () => _edit(
                                  profile.copyWith(geometry: base.geometry),
                                ),
                          dials: _knobRows(
                            theme,
                            navGeometryKnobs,
                            profile.geometry,
                            base.geometry,
                            (c) => _edit(profile.copyWith(geometry: c)),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 260)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _knobRows(
    AppTheme theme,
    List<GlassKnob> knobs,
    GlassConfig config,
    GlassConfig base,
    ValueChanged<GlassConfig> onChanged,
  ) => [
    for (final k in knobs)
      _KnobRow(
        knob: k,
        config: config,
        base: base,
        onChanged: (v) => onChanged(config.set(k, v)),
        onReset: () => onChanged(_resetKnob(config, base, k)),
      ),
  ];

  List<Widget> _presetRows(AppTheme theme, String? activeId, bool dirty) => [
    for (final p in _store.glassPresets)
      _presetRow(
        preset: p,
        active: p.id == activeId,
        // Only on the row you are actually wearing, and only once it has
        // drifted — this is what tells you the save and reset controls below
        // have something to act on.
        subtitle: p.id == activeId && dirty
            ? AppLocalizations.of(context).glassScreenPresetEditedSubtitle
            : null,
        onTap: () => _store.selectGlassPreset(p.id),
        onRename: p.builtIn ? null : () => _promptRename(p),
        onOverwrite: p.builtIn ? null : () => _store.updateGlassSlot(p.id),
        onDelete: p.builtIn ? null : () => _confirmDelete(p),
      ),
    // Only reachable by deleting the slot you were wearing, which keeps the
    // look on screen and just stops calling it by name.
    if (activeId == null)
      _presetRow(
        preset: GlassPreset(
          id: '',
          name: AppLocalizations.of(context).glassScreenCustomPresetName,
          profile: const GlassProfile(),
        ),
        active: true,
        subtitle: AppLocalizations.of(context).glassScreenUnsavedSubtitle,
        onTap: null,
      ),
  ];

  /// One look in the list: its name, a line only when it has drifted, the
  /// checkmark on the one you are wearing, and — on a slot you saved — the
  /// overwrite / rename / delete glyphs. No "Built in" line under the shipped
  /// two: every row saying it was the same nothing as no row saying it.
  Widget _presetRow({
    required GlassPreset preset,
    required bool active,
    required VoidCallback? onTap,
    String? subtitle,
    VoidCallback? onRename,
    VoidCallback? onOverwrite,
    VoidCallback? onDelete,
  }) {
    final l10n = AppLocalizations.of(context);
    final name = glassPresetName(l10n, preset);
    return GroupedRow(
      title: name,
      subtitle: subtitle,
      chevron: false,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tick(on: active),
          if (onOverwrite != null)
            _MiniAction(
              icon: CupertinoIcons.tray_arrow_down,
              tip: l10n.glassScreenOverwriteTooltip(name),
              onTap: onOverwrite,
            ),
          if (onRename != null)
            _MiniAction(
              icon: CupertinoIcons.pencil,
              tip: l10n.glassScreenRenameTooltip(name),
              onTap: onRename,
            ),
          if (onDelete != null)
            _MiniAction(
              icon: CupertinoIcons.trash,
              tip: l10n.glassScreenDeleteTooltip(name),
              onTap: onDelete,
            ),
        ],
      ),
    );
  }

  Future<void> _promptSave() async {
    final name = await _askName(
      title: AppLocalizations.of(context).glassScreenSaveDialogTitle,
    );
    if (name == null || !mounted) return;
    final ok = _store.saveGlassSlot(name);
    if (!ok && mounted) {
      _toast(AppLocalizations.of(context).glassScreenNoRoomToast);
    }
  }

  Future<void> _promptRename(GlassPreset p) async {
    final name = await _askName(
      title: AppLocalizations.of(context).glassScreenRenameDialogTitle,
      initial: p.name,
    );
    if (name == null) return;
    _store.renameGlassSlot(p.id, name);
  }

  Future<void> _confirmDelete(GlassPreset p) async {
    final l10n = AppLocalizations.of(context);
    // The iOS action sheet: the question, what it means, the red answer and
    // Cancel apart — like every other confirmation in the app.
    final yes = await showIosActionSheet<bool>(
      context,
      title: l10n.glassScreenDeleteConfirmTitle(p.name),
      message: l10n.glassScreenDeleteConfirmBody,
      actions: [
        IosSheetAction(
          label: l10n.glassScreenDeleteButton,
          value: true,
          destructive: true,
        ),
      ],
    );
    if (yes == true) _store.deleteGlassSlot(p.id);
  }

  /// "Name this look", the iOS way: a centred alert with a text field and
  /// Cancel / Save — what Photos and Notes ask a name with. The app's own
  /// themed alert, not `CupertinoAlertDialog`, whose stock purple-tinted
  /// buttons ignored the theme entirely.
  Future<String?> _askName({required String title, String initial = ''}) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    try {
      final save = await showIosAlert<bool>(
        context,
        title: title,
        field: IosAlertField(
          controller: controller,
          hint: l10n.glassScreenNameHint,
          maxLength: kMaxSlotNameLength,
        ),
        actions: [
          IosAlertAction(
            label: l10n.glassScreenCancelButton,
            value: false,
            cancel: true,
          ),
          IosAlertAction(
            label: l10n.glassScreenSaveButton,
            value: true,
            preferred: true,
          ),
        ],
      );
      return save == true ? controller.text : null;
    } finally {
      // After the alert's exit transition, not on the pop: the field is
      // still mounted while it fades.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Future<void>.delayed(
          const Duration(milliseconds: 400),
          controller.dispose,
        ),
      );
    }
  }

  void _toast(String message) => showAppToast(context, message);
}

/// The pinned preview's own box. A [SliverPersistentHeader] is a sliver, so a
/// test cannot measure it directly — it has to measure the box inside.
@visibleForTesting
const Key glassPreviewKey = Key('glass-preview');

/// A panel's reset control. Keyed because the dial rows live in a lazy sliver,
/// so which controls exist at any moment depends on where the list is
/// scrolled — indexing into `find.byIcon` finds whichever happened to be built.
@visibleForTesting
Key glassPanelResetKey(String panel) => Key('glass-reset-$panel');

/// The preview's expand/collapse control.
@visibleForTesting
const Key glassPreviewToggleKey = Key('glass-preview-toggle');

/// The real bar over real content.
///
/// Deliberately not a schematic like the navigation screen's preview cards: a
/// blur, a colour boost and a shadow are all invisible against a flat swatch,
/// so the well behind it is a band of saturated colour and text — the busiest
/// backdrop the bar will ever have to sit on, which is where these dials
/// actually have to be judged.
///
/// Full-bleed rather than inset in a card, for two reasons. Pinned, it has to
/// be opaque edge to edge or the sliders scroll visibly past its sides. And at
/// full screen width the bar's own side margins are true to scale, so the
/// layout dials can be judged against the width they will actually have.
class _GlassPreview extends StatelessWidget {
  const _GlassPreview({
    required this.shows,
    required this.section,
    required this.onSelect,
    required this.expanded,
    required this.onToggle,
  });

  /// Which surfaces to render. Follows the panel you have scrolled to, because
  /// the app-wide dials change nothing on the bottom bar — tuning them against
  /// a bar preview was tuning blind.
  final _Shows shows;

  final HomeSection section;
  final ValueChanged<HomeSection> onSelect;
  final bool expanded;
  final VoidCallback onToggle;

  /// Height of the bar itself as currently tuned.
  ///
  /// Derived rather than assumed because the layout dials can nearly treble it,
  /// and a fixed-height pinned header would simply clip the bar — the one dial
  /// you were watching would be the one off-screen.
  static double _barHeight(GlassConfig geo) =>
      geo.of(kShellPadV) * 2 +
      geo.of(kSegmentPadV) * 2 +
      geo.of(kIconSize) +
      geo.of(kIconLabelGap) +
      geo.of(kLabelSize) * 1.4 +
      geo.of(kBarBottom);

  /// Collapsed: the surfaces and nothing much else. Still enough backdrop to
  /// see the glass doing its job, but small enough to leave most of the screen
  /// for the dials.
  static double collapsedHeightFor(GlassConfig geo, _Shows shows) =>
      shows == _Shows.surfaces
      ? 132
      : (_barHeight(geo) + 26).clamp(72.0, 240.0);

  /// Expanded: plus a band of content to scroll under them.
  static double expandedHeightFor(GlassConfig geo, _Shows shows) =>
      shows == _Shows.surfaces
      ? 216
      : (_barHeight(geo) + 92).clamp(150.0, 300.0);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return DecoratedBox(
      key: glassPreviewKey,
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(child: _Backdrop(theme: theme)),
            ),
            // Eases the dials themselves, not just the box around them. A
            // preset or a reset moves a dozen values at once, and jumping
            // straight to the result reads as a glitch rather than a change.
            // Dragging a slider still tracks the finger — the tween only ever
            // has a frame or two to cover.
            Positioned.fill(
              child: TweenAnimationBuilder<GlassProfile>(
                tween: _GlassProfileTween(end: SettingsStore.instance.glass),
                duration: _glassMotion,
                curve: Curves.easeOutCubic,
                // A straight swap between the bar and the other surfaces, not
                // a crossfade: fading a glass surface animates a
                // BackdropFilter, the one thing this app never does.
                builder: (context, profile, _) => shows == _Shows.bar
                      // Its own Stack: PillBottomNav returns a Positioned,
                      // which needs a Stack to attach its parent data to.
                      ? Stack(
                          key: const ValueKey(_Shows.bar),
                          children: [
                            PillBottomNav(
                              active: section,
                              onSelect: onSelect,
                              badges: const {HomeSection.chat: 3},
                              profile: profile,
                            ),
                          ],
                        )
                      : _SurfacesPreview(
                          key: const ValueKey(_Shows.surfaces),
                          config: profile.app,
                        ),
              ),
            ),
            // On the page's 16pt gutter, like every other control.
            Positioned(
              top: 8,
              right: 16,
              child: _PreviewToggle(expanded: expanded, onTap: onToggle),
            ),
          ],
        ),
      ),
    );
  }
}

/// The other glass in the app: a room header, its two round buttons, and the
/// composer.
///
/// Every one is a real [LiquidGlass], built exactly as the real composer and
/// header are, so they cannot drift from what these dials actually do.
class _SurfacesPreview extends StatelessWidget {
  const _SurfacesPreview({super.key, required this.config});

  /// Passed in rather than resolved from settings, so these surfaces ease
  /// along with the rest of the preview instead of snapping while it animates.
  final GlassConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          // Keeps the row clear of the collapse control, which floats in the
          // same corner. Without it the header's trailing button sat directly
          // underneath it and neither could be read or hit.
          Padding(
            padding: const EdgeInsets.only(right: _previewChromeGutter),
            child: Row(
              children: [
                Expanded(
                  child: LiquidGlass(
                    shape: LiquidGlassShape.capsule,
                    config: config,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    // Flexible title, fixed trailing count. A Spacer between two
                    // natural-width Texts overflows the pill the moment the two
                    // together exceed it, which at large text scale they do.
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.glassScreenPreviewRoomName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.body,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.glassScreenPreviewOnlineCount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySoft,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LiquidGlass(
                  size: const Size(38, 38),
                  config: config,
                  child: Icon(
                    CupertinoIcons.phone,
                    size: 17,
                    color: theme.inkSoft,
                  ),
                ),
                const SizedBox(width: 8),
                LiquidGlass(
                  size: const Size(38, 38),
                  config: config,
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 17,
                    color: theme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              LiquidGlass(
                size: const Size(38, 38),
                config: config,
                child: Icon(CupertinoIcons.plus, size: 18, color: theme.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LiquidGlass(
                  shape: LiquidGlassShape.rounded,
                  config: config,
                  radius: 19,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.glassScreenPreviewMessageHint,
                        style: theme.bodySoft,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LiquidGlass(
                size: const Size(38, 38),
                config: config,
                tinted: true,
                child: Icon(
                  CupertinoIcons.arrow_up,
                  size: 18,
                  color: theme.accentInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shrinks the preview to just the bar, for when the dial you are chasing is
/// further down the panel than the preview leaves room for.
class _PreviewToggle extends StatelessWidget {
  const _PreviewToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SpringPress(
      key: glassPreviewToggleKey,
      onTap: onTap,
      semanticLabel: expanded
          ? l10n.glassScreenPreviewCollapseLabel
          : l10n.glassScreenPreviewExpandLabel,
      focusShape: FocusRingShape.capsule,
      scale: 0.94,
      child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
          decoration: ShapeDecoration(
            // Reads over whatever is behind it, which here is deliberately the
            // busiest content in the app.
            color: theme.background.withValues(alpha: 0.86),
            shape: StadiumBorder(
              side: BorderSide(color: theme.divider, width: 0.5),
            ),
          ),
          // Carries the word as well as the chevron. A strip of app chrome
          // sitting over unfamiliar chat rows in the middle of a settings
          // screen reads as something rendering on top of the page by mistake
          // — which is how it got reported. Saying "preview" on the control
          // that is already there costs no extra corner: a separate tag in the
          // opposite corner would have collided with the composer preview's
          // own header, which is what the right-hand gutter exists to avoid.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.glassScreenPreviewBadge,
                style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.inkSoft,
                ),
              ),
              const SizedBox(width: 3),
              AnimatedRotation(
                turns: expanded ? 0 : 0.5,
                duration: theme.motionFast,
                child: Icon(
                  CupertinoIcons.chevron_up,
                  size: 13,
                  color: theme.inkSoft,
                ),
              ),
            ],
          ),
      ),
    );
  }
}

/// Keeps a panel's title under the preview while its dials scroll past, so it
/// is always clear which of the two glass configs the sliders in front of you
/// are editing.
class _PinnedLabel extends SliverPersistentHeaderDelegate {
  const _PinnedLabel({required this.child, required this.signature});

  final Widget child;
  final Object signature;

  static const height = 46.0;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = ThemeScope.of(context);
    return Container(
      // Opaque, or the dial rows scroll visibly through the title.
      color: theme.background,
      // The page's 16pt gutter; [GroupedHeader] adds its own 16 inside, so
      // the title lines up with the plates' text below it.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Bottom, not centre: the header's own 8pt is then the whole gap to
      // its plate, as in a [GroupedSection]; the slack goes above it.
      alignment: Alignment.bottomLeft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedLabel old) => old.signature != signature;
}

/// Holds the preview at the top of the scroll once it reaches it.
class _PinnedPreview extends SliverPersistentHeaderDelegate {
  const _PinnedPreview({
    required this.height,
    required this.child,
    required this.signature,
  });

  final double height;
  final Widget child;

  /// Everything the preview's appearance depends on, hashed. A sliver delegate
  /// is rebuilt only when [shouldRebuild] says so, and the default identity
  /// check would leave the pinned preview frozen on the tuning it was built
  /// with — the one thing it must never do.
  final Object signature;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _PinnedPreview old) =>
      old.height != height || old.signature != signature;
}

/// Something worth looking through, and scrollable so you can drag it under
/// the bar.
///
/// Real rows rather than grey placeholder bars, because every dial here is
/// ultimately judged on one question — can you still read what is behind it —
/// and a row of flat rectangles cannot answer that. Text at real weights and
/// sizes can. The colour tiles are in for the other half: a blur and a colour
/// boost are invisible against anything flat.
///
/// Scrolling it is the point rather than a flourish. Glass that looks fine
/// over one patch of content often falls apart over the next, and a static
/// preview lets a tuning look good by luck.
class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.theme});

  final AppTheme theme;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  /// Filler with the shape of real traffic: names of different lengths, lines
  /// that wrap and lines that don't, and the odd one loud enough to be hard to
  /// sit glass on top of.
  List<(String, String, bool)> _rows(AppLocalizations l10n) => [
    ('Dilan', l10n.glassScreenBackdropMsgDilan, false),
    ('Mert', l10n.glassScreenBackdropMsgMert, false),
    (
      l10n.glassScreenBackdropGroupFamily,
      l10n.glassScreenBackdropMsgFamily,
      true,
    ),
    ('Zeynep', l10n.glassScreenBackdropMsgZeynep, false),
    ('Kerem', l10n.glassScreenBackdropMsgKerem, false),
    (l10n.glassScreenBackdropGroupWork, l10n.glassScreenBackdropMsgWork, true),
    ('Elif', l10n.glassScreenBackdropMsgElif, false),
    ('Baran', l10n.glassScreenBackdropMsgBaran, false),
    ('Ayşe', l10n.glassScreenBackdropMsgAyse, false),
    ('Can', l10n.glassScreenBackdropMsgCan, false),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final rows = _rows(AppLocalizations.of(context));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        // One saturated tile in the run, so the colour-bleed dial has
        // something to actually bleed.
        if (i == 2) return _MediaTile(theme: theme);
        final (name, message, group) = rows[i > 2 ? i - 1 : i];
        return _Row(theme: theme, name: name, message: message, group: group);
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              theme.accent,
              theme.accent.withValues(alpha: 0.45),
              theme.surfaceSunken,
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.name,
    required this.message,
    required this.group,
  });

  final AppTheme theme;
  final String name;
  final String message;
  final bool group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: group ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: group
                  ? BorderRadius.circular(theme.radiusSm)
                  : null,
              color: theme.accent.withValues(alpha: group ? 0.85 : 0.35),
            ),
            alignment: Alignment.center,
            child: Text(
              name.characters.first.toUpperCase(),
              style: groupedMetaStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: group ? theme.accentInk : theme.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.body),
                const SizedBox(height: 1),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySoft,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Languages that write a decimal comma. The dial values are plain
/// fixed-point numbers, so swapping the separator is all the localizing they
/// need — "0,45" in Turkish rather than "0.45".
const _decimalCommaLanguages = {'tr', 'es', 'fr', 'pt', 'sv'};

String _localNumber(BuildContext context, String fixed) {
  final lang = Localizations.maybeLocaleOf(context)?.languageCode;
  return _decimalCommaLanguages.contains(lang)
      ? fixed.replaceAll('.', ',')
      : fixed;
}

class _KnobRow extends StatelessWidget {
  const _KnobRow({
    required this.knob,
    required this.config,
    required this.base,
    required this.onChanged,
    required this.onReset,
  });

  final GlassKnob knob;
  final GlassConfig config;

  /// The active look's value for this dial. What "modified" is measured
  /// against, so the accent marking and the undo button mean "you changed
  /// this", not "this look differs from the raw recipe".
  final GlassConfig base;

  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final value = config.of(knob);
    final standard = value == base.of(knob);
    final label = glassKnobLabel(l10n, knob);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: groupedTitleStyle(theme)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _localNumber(context, knob.format(value)),
                  textAlign: TextAlign.right,
                  style: groupedSubtitleStyle(theme).copyWith(
                    // Standard values stay quiet so the dials you have actually
                    // moved are findable at a glance in a panel of seventeen.
                    color: standard ? theme.inkMuted : theme.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              // Appears only once the dial is off standard, so a panel you have
              // not touched carries no buttons at all. Double-tapping the
              // slider does the same thing, but nothing on screen says so.
              SizedBox(
                width: 30,
                child: standard
                    ? null
                    : _MiniAction(
                        icon: CupertinoIcons.arrow_uturn_left,
                        tip: l10n.glassScreenResetTooltip(label),
                        onTap: onReset,
                      ),
              ),
            ],
          ),
          ValueSlider(
            value: knob.toSlider(value),
            onChanged: (t) => onChanged(knob.fromSlider(t)),
            onReset: standard ? null : onReset,
          ),
          if (glassKnobHint(l10n, knob).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                glassKnobHint(l10n, knob),
                style: groupedSubtitleStyle(theme),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    super.key,
    required this.icon,
    required this.tip,
    required this.onTap,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: tip,
      focusShape: FocusRingShape.circle,
      scale: 0.86,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 17, color: theme.inkSoft),
      ),
    );
  }
}

/// A full-width secondary action: the shared tonal capsule. Dims rather
/// than disappearing when it has nothing to do, so the panel does not reflow
/// as you tune.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SheetActionButton(
        label: label,
        icon: icon,
        tonal: true,
        onTap: enabled ? onTap : null,
      );
}

/// One dial in a panel's grouped plate: the plate's fill, its rounded ends
/// on the first and last dial, and the inset hairline between dials. Drawn
/// per item so the dials stay a lazy sliver list.
class _PlateItem extends StatelessWidget {
  const _PlateItem({
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final r = Radius.circular(groupedRadius(theme));
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: first ? r : Radius.zero,
        bottom: last ? r : Radius.zero,
      ),
      child: ColoredBox(
        color: groupedFill(theme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!first)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Container(
                  height: 1 / MediaQuery.devicePixelRatioOf(context),
                  color: theme.ink.withValues(alpha: 0.10),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets [TweenAnimationBuilder] drive a whole profile at once.
class _GlassProfileTween extends Tween<GlassProfile> {
  _GlassProfileTween({super.end});

  @override
  GlassProfile lerp(double t) => GlassProfile.lerp(begin ?? end!, end!, t);
}

/// Apple's Liquid Glass or the app's Frosted glass — the first decision on
/// this screen, and on iOS 26+ the one that matters most, so it leads and
/// Liquid Glass is listed (and recommended) first.
///
/// Only built where iOS has Liquid Glass to give ([NativeChrome.supported]).
class _GlassStyleChooser extends StatelessWidget {
  const _GlassStyleChooser();

  // Listens for itself. It is built `const`, and a const widget is never
  // rebuilt by its parent — so reading the store straight in build left the
  // checkmark on the old choice after a tap, which read as "can't select".
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    final liquid = store.glassEngine == GlassEngine.native;
    return GroupedSection(
      header: l10n.glassStyleHeader,
      footer: liquid ? l10n.glassStyleLiquidFooter : null,
      margin: EdgeInsets.zero,
      children: [
        GroupedRow(
          icon: CupertinoIcons.drop_fill,
          tone: TileTone.teal,
          title: l10n.glassStyleLiquidTitle,
          subtitle: l10n.glassStyleLiquidBody,
          chevron: false,
          onTap: () => store.setGlassEngine(GlassEngine.native),
          titleTrailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: quietFill(theme),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.glassStyleRecommended,
              style: groupedMetaStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: theme.accent,
              ),
            ),
          ),
          trailing: _Tick(on: liquid),
        ),
        GroupedRow(
          icon: CupertinoIcons.circle_grid_hex_fill,
          tone: TileTone.indigo,
          title: l10n.glassStyleFrostedTitle,
          subtitle: l10n.glassStyleFrostedBody,
          chevron: false,
          onTap: () => store.setGlassEngine(GlassEngine.flutter),
          trailing: _Tick(on: !liquid),
        ),
      ],
    );
  }
}

/// The chooser's checkmark: springs in on the chosen row, and keeps its width
/// on the other so the two rows' text never shifts as the choice moves.
class _Tick extends StatelessWidget {
  const _Tick({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedScale(
      scale: on ? 1 : 0,
      duration: const Duration(milliseconds: 380),
      curve: on ? Curves.elasticOut : Curves.easeIn,
      child: Icon(CupertinoIcons.checkmark_alt, size: 22, color: theme.accent),
    );
  }
}
