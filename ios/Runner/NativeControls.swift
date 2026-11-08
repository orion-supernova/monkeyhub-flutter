import Flutter
import SwiftUI
import UIKit

// The Liquid Glass kit's real controls: SwiftUI views in one overlay above
// the Flutter view (`NativeOverlay`, channel `monkeyhub/native_overlay`).
//
// Dart owns all state (`lib/ui/native/native_control.dart`). It sends each
// control's spec (`set`: a plain map, `kind` plus that kind's fields), then
// after every frame where it moved, its rectangle and visible clip (`sync`),
// and hears back what the person did as `event` {id, name, value}: `tap`,
// `changed`, `changeEnd`, `submitted`, `select`, `focus`, `size`, `revealed`.
// This side never decides anything; it renders the spec it was last given,
// so a hot restart resyncs by sending `reset` and everything again.
//
// Lessons carried over from the React Native port (docs/native-ui.md there):
// - every host ignores the safe area, or SwiftUI offsets its content by the
//   safe-area overlap and the control draws and hit-tests apart;
// - a Slider is never given a zero step (SwiftUI traps);
// - a Menu's label takes `buttonStyle(.glass)`, never `glassEffect()`;
// - chrome buttons are 44 pt with a 17 pt semibold symbol: SwiftUI's own
//   control sizes are far smaller.

// MARK: - Overlay

/// The controls live in ONE plain view above the Flutter view, never in
/// platform views. A platform view is clipped by Flutter with a mask view
/// whenever any ancestor clips (every scroll view does), and a masked Liquid
/// Glass view renders offscreen as a flat grey rectangle: the "cut-outs".
/// Swirl's `NativeGlassOverlay` settled the same question the same way.
///
/// Dart measures where each control landed after every frame and sends the
/// rectangle, the visible clip (its scroll viewport, minus the page bars) and
/// whether it may show at all (`sync`). Device testing (2026-11-07) showed a
/// `clipsToBounds` ancestor that cuts into the glass, or into the swell of
/// interactive glass under a finger, paints it as a flat grey box. So Dart
/// reveals only a WHOLE control (a partly visible one shows its Flutter
/// stand-in) and a visible control's clip view does not clip at all.
/// Hiding is a clip to nothing, never alpha or `isHidden`: alpha does not
/// fade Liquid Glass, and a hidden view drops out of the backdrop group and
/// comes back with a frame of flat dark.
final class NativeOverlay: NSObject {
  static let channelName = "monkeyhub/native_overlay"

  private let channel: FlutterMethodChannel
  fileprivate weak var hostController: UIViewController?
  private var layer: NativeOverlayLayer?
  private var slots: [String: NativeOverlaySlot] = [:]

  init(messenger: FlutterBinaryMessenger, hostController: UIViewController) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.hostController = hostController
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      self.handle(call, result)
    }
  }

  private func hostLayer() -> NativeOverlayLayer? {
    if let layer, layer.superview != nil { return layer }
    guard let host = hostController?.viewIfLoaded, host.window != nil else { return nil }
    let view = NativeOverlayLayer(frame: host.bounds)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Below anything native already there (the tab bar), above Flutter.
    host.insertSubview(view, at: 0)
    layer = view
    return view
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "reset":
      slots.values.forEach { $0.remove() }
      slots = [:]
      result(nil)
    case "set":
      guard let id = args["id"] as? String,
            let spec = args["spec"] as? [String: Any] else {
        result(nil)
        return
      }
      if let slot = slots[id] {
        slot.update(spec)
      } else if let layer = hostLayer() {
        let slot = NativeOverlaySlot(id: id, spec: spec) { [weak self] name, value in
          self?.channel.invokeMethod(
            "event",
            arguments: ["id": id, "name": name, "value": value as Any]
          )
        }
        layer.addSubview(slot.clip)
        slots[id] = slot
      }
      result(nil)
    case "sync":
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      for item in args["items"] as? [[String: Any]] ?? [] {
        guard let id = item["id"] as? String else { continue }
        slots[id]?.place(item)
      }
      CATransaction.commit()
      result(nil)
    case "remove":
      if let id = args["id"] as? String {
        slots[id]?.remove()
        slots[id] = nil
      }
      result(nil)
    case "actionSheet":
      presentActionSheet(args, result)
    case "focus", "blur", "measure":
      if let id = args["id"] as? String, let slot = slots[id] {
        if call.method == "focus" { slot.model.focusTick += 1 }
        if call.method == "blur" { slot.model.blurTick += 1 }
        if call.method == "measure" { slot.reportSize(force: true) }
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension NativeOverlay {
  /// A system action sheet (an alert when [alert]): the real iOS sheet, glass
  /// on iOS 26. Answers the picked action's id, or nil when dismissed.
  fileprivate func presentActionSheet(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard var top = hostController else {
      result(nil)
      return
    }
    while let next = top.presentedViewController { top = next }
    let title = args["title"] as? String
    let message = args["message"] as? String
    let alert = UIAlertController(
      title: (title?.isEmpty ?? true) ? nil : title,
      message: (message?.isEmpty ?? true) ? nil : message,
      preferredStyle: (args["alert"] as? Bool ?? false) ? .alert : .actionSheet
    )
    var answered = false
    let answer: (String?) -> Void = { id in
      guard !answered else { return }
      answered = true
      result(id)
    }
    for action in args["actions"] as? [[String: Any]] ?? [] {
      let id = action["id"] as? String ?? ""
      let style: UIAlertAction.Style =
        (action["cancel"] as? Bool ?? false) ? .cancel
        : (action["destructive"] as? Bool ?? false) ? .destructive : .default
      alert.addAction(UIAlertAction(title: action["label"] as? String ?? "", style: style) { _ in
        answer(style == .cancel ? nil : id)
      })
    }
    if let popover = alert.popoverPresentationController {
      popover.sourceView = top.view
      popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
    top.present(alert, animated: true)
  }
}

/// Touches on bare overlay fall through to Flutter.
final class NativeOverlayLayer: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    if hit === self || hit is NativeOverlayClip { return nil }
    return hit
  }
}

final class NativeOverlayClip: UIView {}

/// One control: a clip view (the visible part of its scroll viewport, in the
/// layer's coordinates) holding the SwiftUI host at the control's rectangle.
final class NativeOverlaySlot {
  let clip = NativeOverlayClip()
  let model: NativeControlModel
  private let host: UIHostingController<NativeControlRoot>
  private let emit: (String, Any?) -> Void
  private var lastReported: CGSize = .zero
  private var wantsVisible = false
  private var revealed = false
  /// A fresh glass view paints before its first backdrop sample; it stays
  /// cut away this long so it never flashes flat.
  private var settled = false
  private var clipRect: CGRect = .zero

  /// The scrim of a sheet or dialog above, drawn natively over the control
  /// (in its own shape) so it can stay native under the barrier instead of
  /// swapping to its Flutter stand-in. A sibling above the host, never an
  /// ancestor: an effect on a glass ancestor paints the glass flat.
  private let dimView: UIView = {
    let v = UIView()
    v.backgroundColor = .black
    v.alpha = 0
    v.isUserInteractionEnabled = false
    v.layer.cornerCurve = .continuous
    return v
  }()
  private var dim: CGFloat = 0

  private var kindName: String { model.spec.kind }

  init(id: String, spec: [String: Any], emit: @escaping (String, Any?) -> Void) {
    self.emit = emit
    model = NativeControlModel(spec: NativeControlSpec(spec))
    passthrough = spec["passthrough"] as? Bool ?? false
    host = UIHostingController(rootView: NativeControlRoot(model: model, emit: emit))
    host.view.backgroundColor = .clear
    if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
    clip.backgroundColor = .clear
    clip.clipsToBounds = true
    clip.frame = .zero
    clip.addSubview(host.view)
    clip.addSubview(dimView)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
      self?.settled = true
      self?.applyReveal()
    }
    DispatchQueue.main.async { [weak self] in self?.reportSize(force: true) }
  }

  func update(_ spec: [String: Any]) {
    model.spec = NativeControlSpec(spec)
    passthrough = spec["passthrough"] as? Bool ?? false
    applyInteraction()
    reportSize()
  }

  /// Touches go to the control only when it is shown, not a draw-only one,
  /// and not under a scrim: a tap there belongs to the barrier (it closes
  /// the sheet), exactly as on the Flutter side.
  private func applyInteraction() {
    clip.isUserInteractionEnabled = revealed && !passthrough && dim <= 0
  }

  /// The control's outline for the scrim: capsules and discs are round on
  /// their short side; the pinned bar and plain fields use their radius.
  private func dimRadius(_ size: CGSize) -> CGFloat {
    let spec = model.spec
    switch spec.kind {
    case "pinBar", "textField", "tile": return min(spec.cornerRadius, min(size.width, size.height) / 2)
    default: return min(size.width, size.height) / 2
    }
  }

  /// Draws only: touches go to Flutter under it.
  private var passthrough = false

  func place(_ item: [String: Any]) {
    func num(_ key: String) -> CGFloat { CGFloat((item[key] as? NSNumber)?.doubleValue ?? 0) }
    clipRect = CGRect(x: num("cx"), y: num("cy"), width: num("cw"), height: num("ch"))
    let rect = CGRect(x: num("x"), y: num("y"), width: num("w"), height: num("h"))
    host.view.frame = rect.offsetBy(dx: -clipRect.minX, dy: -clipRect.minY)
    dim = CGFloat((item["dim"] as? NSNumber)?.doubleValue ?? 0)
    dimView.frame = host.view.frame
    dimView.layer.cornerRadius = dimRadius(rect.size)
    dimView.alpha = dim
    applyInteraction()
    let wants = item["visible"] as? Bool ?? false
    #if DEBUG
    // Why a control hid (`route`, `clipped`, `ticker`...): read with
    // `log show --predicate 'eventMessage CONTAINS "[nativeOverlay]"'`.
    if wants != wantsVisible {
      NSLog("[nativeOverlay] %@ %@ %@", kindName, wants ? "show" : "hide", item["why"] as? String ?? "")
    }
    #endif
    wantsVisible = wants
    applyReveal()
  }

  private func applyReveal() {
    let next = wantsVisible && settled
    // Swirl's rule (NativeGlassOverlay): a visible control is NEVER clipped.
    // Interactive glass swells past its bounds when pressed; a clipsToBounds
    // ancestor cut that swell, the render server drew the glass offscreen,
    // and every press showed a flat grey square. Dart only reveals a control
    // that is whole (a partly visible one shows its Flutter stand-in), so
    // there is nothing to cut while visible; the clip only hides, to nothing.
    // No implicit actions: animating a glass ancestor also paints it flat.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    clip.clipsToBounds = !next
    clip.frame = next ? clipRect : CGRect(origin: clipRect.origin, size: .zero)
    CATransaction.commit()
    // The host stays where the clip origin puts it while cut, so a reveal
    // never jumps.
    if next != revealed {
      revealed = next
      applyInteraction()
      if !next { model.blurTick += 1 }
      emit("revealed", next)
    }
  }

  func reportSize(force: Bool = false) {
    let fit = host.sizeThatFits(
      in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    )
    guard force || fit != lastReported else { return }
    lastReported = fit
    emit("size", ["width": fit.width, "height": fit.height])
  }

  func remove() {
    clip.removeFromSuperview()
  }
}

// MARK: - Spec

/// The Dart spec, decoded once per update. Every field has a safe default, so
/// an older Dart talking to a newer native side (or the reverse) still draws.
struct NativeControlSpec {
  let kind: String
  let dark: Bool
  let tint: Color?
  let enabled: Bool
  let label: String
  let symbol: String?
  let prominent: Bool
  let destructive: Bool
  let size: CGFloat
  let symbolSize: CGFloat
  let boolValue: Bool
  let doubleValue: Double
  let min: Double
  let max: Double
  let step: Double
  let selected: String?
  let options: [NativeOption]
  let items: [NativeMenuItem]
  let placeholder: String
  let text: String
  let secure: Bool
  let contentType: String?
  let keyboard: String?
  let cornerRadius: CGFloat
  let fill: Bool
  let leadingSymbol: String?
  let submitLabel: String?
  let plain: Bool
  let clearButton: Bool
  let dateMs: Double
  let minDateMs: Double?
  let maxDateMs: Double?
  let dateMode: String
  let dateStyle: String
  let textRev: Int
  let capitalization: String?
  let autocorrect: Bool?
  let spacing: CGFloat
  let blend: CGFloat?
  /// Settings › Glass › Interactive glass: the press stretch and shine.
  let interactive: Bool
  /// titlePill / pinBar.
  let subtitle: String
  let subtitleColor: Color?
  let avatarPath: String?
  let avatarSymbol: String?
  let initials: String
  let avatarColor: Color?
  let avatarSize: CGFloat
  let count: Int
  let activeIndex: Int
  let accentLabel: Bool
  /// composerField: the selection Dart wants applied with [textRev] (UTF-16
  /// offsets, Dart's own), and how many lines the field grows to.
  let selStart: Int?
  let selEnd: Int?
  let maxLines: Int
  /// symbolButton: a count capsule straddling the top edge (quiet = neutral
  /// instead of the tint), and a tick that bounces the symbol.
  let badge: String?
  let badgeQuiet: Bool
  let kickTick: Int

  init(_ map: [String: Any]) {
    kind = map["kind"] as? String ?? "symbolButton"
    dark = map["dark"] as? Bool ?? false
    tint = (map["tint"] as? Int).map(Color.init(argb:))
    enabled = map["enabled"] as? Bool ?? true
    label = map["label"] as? String ?? ""
    symbol = map["symbol"] as? String
    prominent = map["prominent"] as? Bool ?? false
    destructive = map["destructive"] as? Bool ?? false
    size = CGFloat(map["size"] as? Double ?? 44)
    symbolSize = CGFloat(map["symbolSize"] as? Double ?? 17)
    boolValue = map["value"] as? Bool ?? false
    doubleValue = map["doubleValue"] as? Double ?? 0
    min = map["min"] as? Double ?? 0
    max = map["max"] as? Double ?? 1
    step = map["step"] as? Double ?? 0
    selected = map["selected"] as? String
    options = (map["options"] as? [[String: Any]] ?? []).map(NativeOption.init)
    items = (map["items"] as? [[String: Any]] ?? []).map(NativeMenuItem.init)
    placeholder = map["placeholder"] as? String ?? ""
    text = map["text"] as? String ?? ""
    secure = map["secure"] as? Bool ?? false
    contentType = map["contentType"] as? String
    keyboard = map["keyboard"] as? String
    cornerRadius = CGFloat(map["cornerRadius"] as? Double ?? 22)
    fill = map["fill"] as? Bool ?? false
    leadingSymbol = map["leadingSymbol"] as? String
    submitLabel = map["submitLabel"] as? String
    plain = map["plain"] as? Bool ?? false
    clearButton = map["clearButton"] as? Bool ?? false
    dateMs = map["dateMs"] as? Double ?? Date().timeIntervalSince1970 * 1000
    minDateMs = map["minDateMs"] as? Double
    maxDateMs = map["maxDateMs"] as? Double
    dateMode = map["dateMode"] as? String ?? "dateTime"
    dateStyle = map["dateStyle"] as? String ?? "compact"
    textRev = map["textRev"] as? Int ?? 0
    capitalization = map["capitalization"] as? String
    autocorrect = map["autocorrect"] as? Bool
    spacing = CGFloat(map["spacing"] as? Double ?? 8)
    blend = (map["blend"] as? Double).map { CGFloat($0) }
    interactive = map["interactive"] as? Bool ?? true
    subtitle = map["subtitle"] as? String ?? ""
    subtitleColor = (map["subtitleColor"] as? Int).map(Color.init(argb:))
    avatarPath = map["avatarPath"] as? String
    avatarSymbol = map["avatarSymbol"] as? String
    initials = map["initials"] as? String ?? ""
    avatarColor = (map["avatarColor"] as? Int).map(Color.init(argb:))
    avatarSize = CGFloat(map["avatarSize"] as? Double ?? 34)
    count = map["count"] as? Int ?? 0
    selStart = map["selStart"] as? Int
    selEnd = map["selEnd"] as? Int
    maxLines = map["maxLines"] as? Int ?? 5
    badge = map["badge"] as? String
    badgeQuiet = map["badgeQuiet"] as? Bool ?? false
    kickTick = map["kickTick"] as? Int ?? 0
    activeIndex = map["activeIndex"] as? Int ?? 0
    accentLabel = map["accentLabel"] as? Bool ?? false
  }
}

struct NativeOption: Identifiable {
  let id: String
  let label: String
  let symbol: String?
  let disabled: Bool
  let destructive: Bool

  init(_ map: [String: Any]) {
    id = map["value"] as? String ?? ""
    label = map["label"] as? String ?? ""
    symbol = map["symbol"] as? String
    disabled = map["disabled"] as? Bool ?? false
    destructive = map["destructive"] as? Bool ?? false
  }
}

struct NativeMenuItem: Identifiable {
  let id: String
  let label: String
  let symbol: String?
  let destructive: Bool
  let disabled: Bool
  let checked: Bool?
  let divider: Bool

  init(_ map: [String: Any]) {
    id = map["id"] as? String ?? UUID().uuidString
    label = map["label"] as? String ?? ""
    symbol = map["symbol"] as? String
    destructive = map["destructive"] as? Bool ?? false
    disabled = map["disabled"] as? Bool ?? false
    checked = map["checked"] as? Bool
    divider = map["divider"] as? Bool ?? false
  }
}

final class NativeControlModel: ObservableObject {
  @Published var spec: NativeControlSpec

  /// Bumped by Dart's `focus` / `blur` calls; a text field follows them.
  @Published var focusTick = 0
  @Published var blurTick = 0

  init(spec: NativeControlSpec) {
    self.spec = spec
  }
}

extension Color {
  /// A Flutter `Color.value` (0xAARRGGBB).
  init(argb: Int) {
    let v = UInt32(truncatingIfNeeded: argb)
    self.init(
      .sRGB,
      red: Double((v >> 16) & 0xFF) / 255,
      green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255,
      opacity: Double((v >> 24) & 0xFF) / 255
    )
  }
}

// MARK: - Views

struct NativeControlRoot: View {
  @ObservedObject var model: NativeControlModel
  let emit: (String, Any?) -> Void

  var body: some View {
    let spec = model.spec
    content(spec)
      .tint(spec.tint)
      .disabled(!spec.enabled)
      .environment(\.colorScheme, spec.dark ? .dark : .light)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea()
  }

  @ViewBuilder
  private func content(_ spec: NativeControlSpec) -> some View {
    switch spec.kind {
    case "button": NativeTextButton(spec: spec, emit: emit)
    case "toggle": NativeToggle(spec: spec, emit: emit)
    case "segmented": NativeSegmented(spec: spec, emit: emit)
    case "slider": NativeSlider(spec: spec, emit: emit)
    case "menu": NativeMenu(spec: spec, emit: emit)
    case "textField", "searchField": NativeTextField(model: model, spec: spec, emit: emit)
    case "toolbar": NativeToolbar(spec: spec, emit: emit)
    case "buttonGroup": NativeButtonGroup(spec: spec, emit: emit)
    case "datePicker": NativeDatePicker(spec: spec, emit: emit)
    case "composerField": NativeComposerField(model: model, spec: spec, emit: emit)
    case "glassLabel": NativeGlassLabel(spec: spec)
    case "tile": NativeTile(spec: spec, emit: emit)
    case "titlePill", "pinBar":
      if #available(iOS 26.0, *) {
        if spec.kind == "titlePill" {
          NativeTitlePill(spec: spec, emit: emit)
        } else {
          NativePinBar(spec: spec, emit: emit)
        }
      }
    default: NativeSymbolButton(spec: spec, emit: emit)
    }
  }
}

/// The round chrome button: back, close, more, compose. A 44 pt glass circle
/// with a 17 pt semibold SF Symbol, the iOS 26 navigation-bar button.
struct NativeSymbolButton: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let ink: Color = spec.destructive ? .red : (spec.accentLabel ? (spec.tint ?? .accentColor) : .primary)
    let image = Image(systemName: spec.symbol ?? "circle")
      .font(.system(size: spec.symbolSize, weight: .semibold))
    let glyph = Group {
      if #available(iOS 17.0, *) {
        image.symbolEffect(.bounce, value: spec.kickTick)
      } else {
        image
      }
    }
    .frame(width: spec.size, height: spec.size)
    .contentShape(Circle())
    let button = Button { emit("tap", nil) } label: { glyph }
      .accessibilityLabel(Text(spec.label))
    Group {
      if #available(iOS 26.0, *) {
        if spec.prominent {
          button.buttonStyle(.glassProminent).buttonBorderShape(.circle)
        } else {
          button.buttonStyle(.plain)
            .foregroundStyle(ink)
            .glassEffect(.regular.interactive(spec.interactive), in: Circle())
        }
      } else {
        // Below iOS 26 this kit is never resolved; the capsule is only a
        // safe fallback (.circle needs iOS 17).
        button.buttonStyle(.bordered).buttonBorderShape(.capsule)
      }
    }
    .overlay(alignment: .top) {
      if let badge = spec.badge {
        // The count, straddling the disc's top edge like the Flutter one.
        Text(badge)
          .font(.system(size: 11, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(spec.badgeQuiet ? Color.primary : Color.white)
          .padding(.horizontal, 4.5)
          .frame(minWidth: 17, minHeight: 17)
          .background(
            Capsule().fill(spec.badgeQuiet ? Color(uiColor: .secondarySystemBackground) : (spec.tint ?? .accentColor))
          )
          .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
          .offset(y: -9)
          .allowsHitTesting(false)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: spec.badge)
  }
}

/// An action tile: a symbol over a one- or two-line label on a rounded glass
/// plate (call, video, message on a profile or the call details sheet). The
/// accent inks both, red when destructive; the plate is interactive glass.
/// `value` true (busy) shows a spinner in place of the symbol.
struct NativeTile: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let ink: Color = !spec.enabled
      ? .secondary
      : (spec.destructive ? .red : (spec.tint ?? .accentColor))
    let shape = RoundedRectangle(cornerRadius: spec.cornerRadius, style: .continuous)
    let label = VStack(spacing: 5) {
      Group {
        if spec.boolValue {
          // Busy: the system spinner in the tile's ink, same 22pt slot.
          ProgressView().tint(ink)
        } else {
          Image(systemName: spec.symbol ?? "circle")
            .font(.system(size: 20, weight: .medium))
        }
      }
      .frame(height: 22)
      Text(spec.label)
        .font(.system(size: 12.5, weight: .medium))
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
    .foregroundStyle(ink)
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(shape)
    let button = Button { emit("tap", nil) } label: { label }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(spec.label))
    if #available(iOS 26.0, *) {
      button.glassEffect(.regular.interactive(spec.interactive), in: shape)
    } else {
      button.background(shape.fill(.thinMaterial))
    }
  }
}

/// A labelled button: the primary action of a sheet, a row's pill.
struct NativeTextButton: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let label = HStack(spacing: 6) {
      if let s = spec.symbol { Image(systemName: s) }
      Text(spec.label).lineLimit(1)
    }
    .font(.system(size: spec.size <= 34 ? 15 : 17, weight: .semibold))
    .frame(maxWidth: spec.fill ? .infinity : nil)
    let button = Button(role: spec.destructive ? .destructive : nil) {
      emit("tap", nil)
    } label: { label }
      .controlSize(spec.size <= 34 ? .small : (spec.size < 50 ? .regular : .large))
      // Glass styles ignore the destructive role's colour: say it.
      .tint(spec.destructive ? Color.red : spec.tint)
    if #available(iOS 26.0, *) {
      if spec.prominent {
        button.buttonStyle(.glassProminent)
      } else {
        button.buttonStyle(.glass)
      }
    } else {
      if spec.prominent {
        button.buttonStyle(.borderedProminent)
      } else {
        button.buttonStyle(.bordered)
      }
    }
  }
}

/// The system switch (a UISwitch underneath), with the app's tint.
struct NativeToggle: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var on: Bool

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _on = State(initialValue: spec.boolValue)
  }

  var body: some View {
    Toggle(spec.label, isOn: $on)
      .labelsHidden()
      .accessibilityLabel(Text(spec.label))
      .onChange(of: spec.boolValue) { on = $0 }
      .onChange(of: on) { value in
        if value != spec.boolValue { emit("changed", value) }
      }
  }
}

/// The system segmented control.
struct NativeSegmented: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var selection: String

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _selection = State(initialValue: spec.selected ?? spec.options.first?.id ?? "")
  }

  var body: some View {
    Picker(spec.label, selection: $selection) {
      ForEach(spec.options) { option in
        if let s = option.symbol {
          Label(option.label, systemImage: s).tag(option.id)
        } else {
          Text(option.label).tag(option.id)
        }
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .onChange(of: spec.selected) { if let v = $0 { selection = v } }
    .onChange(of: selection) { value in
      if value != spec.selected { emit("changed", value) }
    }
  }
}

/// The system slider. Never handed a zero step: SwiftUI traps on one.
struct NativeSlider: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var value: Double

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _value = State(initialValue: spec.doubleValue)
  }

  var body: some View {
    let range = spec.min...Swift.max(spec.max, spec.min + 0.0001)
    let onEditing: (Bool) -> Void = { editing in
      if !editing { emit("changeEnd", value) }
    }
    Group {
      if spec.step > 0 {
        Slider(value: $value, in: range, step: spec.step, onEditingChanged: onEditing)
      } else {
        Slider(value: $value, in: range, onEditingChanged: onEditing)
      }
    }
    .labelsHidden()
    .accessibilityLabel(Text(spec.label))
    .onChange(of: spec.doubleValue) { value = $0 }
    .onChange(of: value) { v in
      if v != spec.doubleValue { emit("changed", v) }
    }
  }
}

/// A pull-down menu from a glass button; on iOS 26 the button morphs into the
/// menu. Items report their `id` back as `select`.
struct NativeMenu: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let menu = Menu {
      ForEach(spec.items) { item in
        if item.divider {
          Divider()
        } else if let checked = item.checked {
          Toggle(isOn: Binding(get: { checked }, set: { _ in emit("select", item.id) })) {
            itemLabel(item)
          }
          .disabled(item.disabled)
        } else {
          Button(role: item.destructive ? .destructive : nil) {
            emit("select", item.id)
          } label: {
            itemLabel(item)
          }
          .disabled(item.disabled)
        }
      }
    } label: {
      if let s = spec.symbol, spec.label.isEmpty {
        // The glass button style pads its label; this inner box plus that
        // padding comes out at the requested disc size.
        Image(systemName: s)
          .font(.system(size: spec.symbolSize, weight: .semibold))
          .frame(width: spec.size - 14, height: spec.size - 14)
      } else {
        HStack(spacing: 4) {
          if let s = spec.symbol { Image(systemName: s) }
          Text(spec.label)
          Image(systemName: "chevron.up.chevron.down").font(.caption)
        }
      }
    }
    .accessibilityLabel(Text(spec.label))
    if #available(iOS 26.0, *) {
      if spec.label.isEmpty {
        menu.buttonStyle(.glass).buttonBorderShape(.circle)
      } else {
        menu.buttonStyle(.glass)
      }
    } else {
      menu
    }
  }

  @ViewBuilder
  private func itemLabel(_ item: NativeMenuItem) -> some View {
    if let s = item.symbol {
      Label(item.label, systemImage: s)
    } else {
      Text(item.label)
    }
  }
}

/// A one-line text field (or, as `searchField`, the search capsule): glass
/// rounded rect, optional leading symbol and clear button. Text flows back as
/// `changed`, return as `submitted`, focus as `focus`; Dart moves focus with
/// the `focus` / `blur` channel calls.
struct NativeTextField: View {
  @ObservedObject var model: NativeControlModel
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var text: String
  @FocusState private var focused: Bool

  init(
    model: NativeControlModel,
    spec: NativeControlSpec,
    emit: @escaping (String, Any?) -> Void
  ) {
    self.model = model
    self.spec = spec
    self.emit = emit
    _text = State(initialValue: spec.text)
  }

  private var isSearch: Bool { spec.kind == "searchField" }

  var body: some View {
    let leading = spec.leadingSymbol ?? (isSearch ? "magnifyingglass" : nil)
    let row = HStack(spacing: 8) {
      if let leading {
        Image(systemName: leading)
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(.secondary)
      }
      field
      if (spec.clearButton || isSearch) && !text.isEmpty {
        Button {
          text = ""
          emit("changed", "")
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 17))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Clear"))
      }
    }
    .padding(.horizontal, isSearch ? 14 : 16)
    .frame(maxWidth: .infinity, minHeight: spec.size, maxHeight: .infinity)
    .contentShape(Rectangle())
    .onTapGesture { focused = true }
    .onChange(of: model.focusTick) { _ in focused = true }
    .onChange(of: model.blurTick) { _ in focused = false }
    if spec.plain {
      row
    } else if #available(iOS 26.0, *) {
      row.glassEffect(
        .regular.interactive(spec.interactive),
        in: RoundedRectangle(cornerRadius: isSearch ? spec.size / 2 : spec.cornerRadius)
      )
    } else {
      row.background(
        RoundedRectangle(cornerRadius: spec.cornerRadius).fill(.thinMaterial)
      )
    }
  }

  @ViewBuilder
  private var field: some View {
    Group {
      if spec.secure {
        SecureField(spec.placeholder, text: $text)
      } else {
        TextField(spec.placeholder, text: $text)
      }
    }
    .textFieldStyle(.plain)
    .font(.system(size: 17))
    .focused($focused)
    .textContentType(contentType)
    .keyboardType(keyboardType)
    .textInputAutocapitalization(autocap)
    .autocorrectionDisabled(!(spec.autocorrect ?? !(isSearch || spec.contentType != nil)))
    .submitLabel(submitLabel)
    .onSubmit { emit("submitted", text) }
    .onChange(of: spec.textRev) { _ in if spec.text != text { text = spec.text } }
    .onChange(of: text) { if $0 != spec.text { emit("changed", $0) } }
    .onChange(of: focused) { emit("focus", $0) }
  }

  private var autocap: TextInputAutocapitalization {
    switch spec.capitalization {
    case "words": return .words
    case "characters": return .characters
    case "sentences": return .sentences
    case "none": return .never
    default: return isSearch || spec.contentType != nil ? .never : .sentences
    }
  }

  private var submitLabel: SubmitLabel {
    switch spec.submitLabel {
    case "search": return .search
    case "next": return .next
    case "go": return .go
    case "send": return .send
    case "join": return .join
    case "continue": return .continue
    default: return isSearch ? .search : .done
    }
  }

  private var contentType: UITextContentType? {
    switch spec.contentType {
    case "username": return .username
    case "password": return .password
    case "newPassword": return .newPassword
    case "oneTimeCode": return .oneTimeCode
    case "emailAddress": return .emailAddress
    case "url": return .URL
    case "name": return .name
    default: return nil
    }
  }

  private var keyboardType: UIKeyboardType {
    switch spec.keyboard {
    case "email": return .emailAddress
    case "url": return .URL
    case "number": return .numberPad
    case "phone": return .phonePad
    default: return isSearch ? .webSearch : .default
    }
  }
}

/// Several symbol buttons sharing one glass capsule, the iOS 26 toolbar
/// group (the chat list's add-person and compose pair). Taps report the
/// option's `value` as `select`.
struct NativeButtonGroup: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let row = HStack(spacing: 0) {
      ForEach(spec.options) { option in
        Button { emit("select", option.id) } label: {
          Image(systemName: option.symbol ?? "circle")
            .font(.system(size: spec.symbolSize, weight: .semibold))
            .frame(width: spec.size, height: spec.size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(option.destructive ? Color.red : Color.primary)
        .disabled(option.disabled)
        .opacity(option.disabled ? 0.4 : 1)
        .accessibilityLabel(Text(option.label))
      }
    }
    if #available(iOS 26.0, *) {
      row.glassEffect(.regular.interactive(spec.interactive), in: Capsule())
    } else {
      row.background(Capsule().fill(.thinMaterial))
    }
  }
}

/// The system date picker. Values travel as epoch milliseconds.
struct NativeDatePicker: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void
  @State private var date: Date

  init(spec: NativeControlSpec, emit: @escaping (String, Any?) -> Void) {
    self.spec = spec
    self.emit = emit
    _date = State(initialValue: Date(timeIntervalSince1970: spec.dateMs / 1000))
  }

  private var components: DatePickerComponents {
    switch spec.dateMode {
    case "date": return [.date]
    case "time": return [.hourAndMinute]
    default: return [.date, .hourAndMinute]
    }
  }

  var body: some View {
    let lower = spec.minDateMs.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .distantPast
    let upper = spec.maxDateMs.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .distantFuture
    let picker = DatePicker(
      spec.label,
      selection: $date,
      in: lower...Swift.max(upper, lower),
      displayedComponents: components
    )
    .labelsHidden()
    .onChange(of: spec.dateMs) { date = Date(timeIntervalSince1970: $0 / 1000) }
    .onChange(of: date) { emit("changed", $0.timeIntervalSince1970 * 1000) }
    switch spec.dateStyle {
    case "graphical": picker.datePickerStyle(.graphical)
    case "wheel": picker.datePickerStyle(.wheel)
    default: picker.datePickerStyle(.compact)
    }
  }
}

/// A row of glass actions that blend and morph together, the iOS 26 toolbar.
/// Each option is an action; a tap reports its `value` as `select`.
struct NativeToolbar: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: spec.blend ?? spec.spacing) {
        HStack(spacing: spec.spacing) {
          ForEach(spec.options) { option in
            Button { emit("select", option.id) } label: {
              Image(systemName: option.symbol ?? "circle")
                .font(.system(size: spec.symbolSize, weight: .semibold))
                .frame(width: spec.size, height: spec.size)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(option.destructive ? Color.red : Color.primary)
            .disabled(option.disabled)
            .opacity(option.disabled ? 0.4 : 1)
            .accessibilityLabel(Text(option.label))
            .glassEffect(.regular.interactive(spec.interactive), in: Circle())
          }
        }
      }
    } else {
      HStack(spacing: spec.spacing) {
        ForEach(spec.options) { option in
          Button { emit("select", option.id) } label: {
            Image(systemName: option.symbol ?? "circle")
              .frame(width: spec.size, height: spec.size)
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .accessibilityLabel(Text(option.label))
        }
      }
    }
  }
}

/// A line of text on a glass capsule that is not a control: a hint, a
/// tooltip (the composer's "hold to record"). Draws only; touches pass to
/// Flutter.
struct NativeGlassLabel: View {
  let spec: NativeControlSpec

  var body: some View {
    let text = Text(spec.label)
      .font(.system(size: spec.symbolSize, weight: .semibold))
      .multilineTextAlignment(.center)
      .foregroundStyle(.primary)
      .padding(.horizontal, 11)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    if #available(iOS 26.0, *) {
      text.glassEffect(.regular, in: Capsule())
    } else {
      text.background(Capsule().fill(.thinMaterial))
    }
  }
}

// MARK: - Composer

/// The chat composer's text: a real UITextView (system selection and loupe,
/// dictation, Writing Tools, autocorrect, Genmoji) in a native glass
/// capsule that grows from one line to [NativeControlSpec.maxLines], then
/// scrolls. Dart owns the text through the same rules as the one-line field
/// (typing flows out as `changed` {text, start, end}; Dart's own edits come
/// back only with a new `textRev`), and sizes the control to the `height`
/// this reports. The trailing symbol (the expressions smiley) reports
/// `trailing`.
struct NativeComposerField: View {
  @ObservedObject var model: NativeControlModel
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    let row = HStack(alignment: .bottom, spacing: 0) {
      NativeComposerTextView(model: model, spec: spec, emit: emit)
      if let symbol = spec.symbol {
        Button { emit("trailing", nil) } label: {
          Image(systemName: spec.boolValue ? "keyboard" : symbol)
            .font(.system(size: 20))
            .foregroundStyle(.secondary)
            .frame(width: 40, height: spec.size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(spec.label))
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, spec.symbol == nil ? 16 : 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    let shape = RoundedRectangle(cornerRadius: spec.cornerRadius, style: .continuous)
    if #available(iOS 26.0, *) {
      // Interactive like every other native control (Settings › Glass ›
      // Interactive glass): it presses and shines under the finger.
      row.glassEffect(.regular.interactive(spec.interactive), in: shape)
    } else {
      row.background(shape.fill(.thinMaterial))
    }
  }
}

final class NativeComposerUITextView: UITextView {
  var onLayout: (() -> Void)?
  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }
}

struct NativeComposerTextView: UIViewRepresentable {
  @ObservedObject var model: NativeControlModel
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  static let font = UIFont.systemFont(ofSize: 17)

  func makeCoordinator() -> Coordinator { Coordinator(emit: emit) }

  func makeUIView(context: Context) -> NativeComposerUITextView {
    let tv = NativeComposerUITextView()
    tv.backgroundColor = .clear
    tv.font = Self.font
    tv.textColor = .label
    tv.textContainer.lineFragmentPadding = 0
    tv.autocapitalizationType = .sentences
    tv.autocorrectionType = .default
    tv.returnKeyType = .default
    tv.delegate = context.coordinator
    tv.text = spec.text
    let placeholder = UILabel()
    placeholder.font = Self.font
    placeholder.textColor = .placeholderText
    placeholder.numberOfLines = 1
    placeholder.lineBreakMode = .byTruncatingTail
    tv.addSubview(placeholder)
    let c = context.coordinator
    c.textView = tv
    c.placeholder = placeholder
    c.lastRev = spec.textRev
    c.focusTick = model.focusTick
    c.blurTick = model.blurTick
    tv.onLayout = { [weak c] in c?.layoutChanged() }
    return tv
  }

  func updateUIView(_ tv: NativeComposerUITextView, context: Context) {
    let c = context.coordinator
    c.emit = emit
    c.maxLines = max(1, spec.maxLines)
    c.minHeight = spec.size
    tv.keyboardAppearance = spec.dark ? .dark : .light
    if let tint = spec.tint { tv.tintColor = UIColor(tint) }
    tv.isEditable = spec.enabled
    c.placeholder?.text = spec.placeholder
    if spec.textRev != c.lastRev {
      c.lastRev = spec.textRev
      if tv.text != spec.text { tv.text = spec.text }
      let length = (tv.text as NSString).length
      if let start = spec.selStart, let end = spec.selEnd {
        let a = min(max(0, start), length)
        let b = min(max(a, end), length)
        tv.selectedRange = NSRange(location: a, length: b - a)
      }
      c.textChangedLocally()
    }
    if model.focusTick != c.focusTick {
      c.focusTick = model.focusTick
      if !tv.isFirstResponder { tv.becomeFirstResponder() }
    }
    if model.blurTick != c.blurTick {
      c.blurTick = model.blurTick
      if tv.isFirstResponder { tv.resignFirstResponder() }
    }
    c.layoutChanged()
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    var emit: (String, Any?) -> Void
    weak var textView: NativeComposerUITextView?
    weak var placeholder: UILabel?
    var lastRev = 0
    var focusTick = 0
    var blurTick = 0
    var maxLines = 5
    var minHeight: CGFloat = 44
    private var lastHeight: CGFloat = 0
    private var lastWidth: CGFloat = 0

    init(emit: @escaping (String, Any?) -> Void) { self.emit = emit }

    /// One line sits centred in the resting capsule; more lines grow it.
    private var verticalInset: CGFloat {
      max(0, (minHeight - NativeComposerTextView.font.lineHeight) / 2)
    }

    func layoutChanged() {
      guard let tv = textView else { return }
      let inset = verticalInset
      if tv.textContainerInset.top != inset {
        tv.textContainerInset = UIEdgeInsets(top: inset, left: 0, bottom: inset, right: 0)
      }
      placeholder?.frame = CGRect(
        x: 0,
        y: inset,
        width: tv.bounds.width,
        height: NativeComposerTextView.font.lineHeight
      )
      placeholder?.isHidden = !tv.text.isEmpty
      let width = tv.bounds.width
      guard width > 0 else { return }
      if width != lastWidth {
        lastWidth = width
        reportHeight()
      }
    }

    func textChangedLocally() {
      placeholder?.isHidden = !(textView?.text.isEmpty ?? true)
      reportHeight()
    }

    /// The content's height for this width, capped at [maxLines] lines;
    /// past the cap the view scrolls instead of growing.
    private func reportHeight() {
      guard let tv = textView, tv.bounds.width > 0 else { return }
      let fit = tv.sizeThatFits(
        CGSize(width: tv.bounds.width, height: .greatestFiniteMagnitude)
      ).height
      let cap = NativeComposerTextView.font.lineHeight * CGFloat(maxLines)
        + verticalInset * 2
      let h = max(minHeight, min(fit, cap)).rounded(.up)
      tv.isScrollEnabled = fit > cap
      if abs(h - lastHeight) >= 0.5 {
        lastHeight = h
        emit("height", Double(h))
      }
    }

    private func report(_ tv: UITextView) {
      let r = tv.selectedRange
      emit("changed", [
        "text": tv.text ?? "",
        "start": r.location,
        "end": r.location + r.length,
      ])
    }

    func textViewDidChange(_ tv: UITextView) {
      textChangedLocally()
      report(tv)
    }

    func textViewDidChangeSelection(_ tv: UITextView) {
      let r = tv.selectedRange
      emit("selection", ["start": r.location, "end": r.location + r.length])
    }

    func textViewDidBeginEditing(_ tv: UITextView) { emit("focus", true) }
    func textViewDidEndEditing(_ tv: UITextView) { emit("focus", false) }
  }
}

// MARK: - Chat chrome

/// Decoded avatars, so a header rebuild never reads the file again.
private let nativeAvatarCache = NSCache<NSString, UIImage>()

/// A chat's face: the cached picture, a symbol on a quiet disc (Saved
/// Messages), or initials on the room's colour.
struct NativeAvatar: View {
  let spec: NativeControlSpec

  var body: some View {
    let d = spec.avatarSize
    Group {
      if let path = spec.avatarPath, let image = Self.image(path) {
        Image(uiImage: image).resizable().scaledToFill()
      } else if let symbol = spec.avatarSymbol {
        Image(systemName: symbol)
          .font(.system(size: d * 0.42, weight: .semibold))
          .foregroundStyle(spec.tint ?? .accentColor)
          .frame(width: d, height: d)
          .background(Color.primary.opacity(0.08))
      } else {
        Text(spec.initials)
          .font(.system(size: d * 0.4, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: d, height: d)
          .background(spec.avatarColor ?? Color.gray)
      }
    }
    .frame(width: d, height: d)
    .clipShape(Circle())
  }

  static func image(_ path: String) -> UIImage? {
    if let hit = nativeAvatarCache.object(forKey: path as NSString) { return hit }
    guard let image = UIImage(contentsOfFile: path) else { return nil }
    nativeAvatarCache.setObject(image, forKey: path as NSString)
    return image
  }
}

/// The chat header's title capsule: avatar, name, and the status line, on
/// interactive glass. A tap is `tap` (room info), the avatar alone `avatar`.
@available(iOS 26.0, *)
struct NativeTitlePill: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    HStack(spacing: 9) {
      NativeAvatar(spec: spec)
        .contentShape(Circle())
        .highPriorityGesture(TapGesture().onEnded { emit("avatar", nil) })
      VStack(alignment: .leading, spacing: 1) {
        Text(spec.label)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
        if !spec.subtitle.isEmpty {
          Text(spec.subtitle)
            .font(.system(size: 13))
            .foregroundStyle(spec.subtitleColor ?? .secondary)
            .lineLimit(1)
            .contentTransition(.opacity)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.leading, 5)
    .padding(.trailing, 16)
    .frame(height: spec.size)
    .contentShape(Capsule())
    .onTapGesture { emit("tap", nil) }
    .glassEffect(.regular.interactive(spec.interactive), in: Capsule())
    .animation(.easeOut(duration: 0.22), value: spec.subtitle)
  }
}

/// The pinned-message bar: position ticks, the pin, sender and preview on one
/// line (`tap` jumps to it), and the list button (`list`).
@available(iOS 26.0, *)
struct NativePinBar: View {
  let spec: NativeControlSpec
  let emit: (String, Any?) -> Void

  var body: some View {
    HStack(spacing: 0) {
      if spec.count > 1 {
        VStack(spacing: 2) {
          ForEach(0..<min(spec.count, 5), id: \.self) { i in
            Capsule()
              .fill(i == min(spec.activeIndex, 4) ? (spec.tint ?? .accentColor) : Color.primary.opacity(0.16))
              .frame(width: 2.5)
          }
        }
        .frame(height: 22)
        .padding(.leading, 12)
      }
      Image(systemName: "pin.fill")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(.leading, spec.count > 1 ? 10 : 14)
      (Text(spec.label).fontWeight(.semibold).foregroundColor(.primary)
        + Text(spec.subtitle.isEmpty ? "" : "  " + spec.subtitle).foregroundColor(.secondary))
        .font(.system(size: 15))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 8)
        .contentShape(Rectangle())
        .onTapGesture { emit("tap", nil) }
        .id(spec.activeIndex)
        .transition(.push(from: .bottom))
      Button { emit("list", nil) } label: {
        Image(systemName: "list.bullet")
          .font(.system(size: 17))
          .foregroundStyle(.secondary)
          .frame(width: 44, height: spec.size)
      }
      .buttonStyle(.plain)
      .padding(.trailing, 4)
    }
    .frame(height: spec.size)
    .glassEffect(
      .regular.interactive(spec.interactive),
      in: RoundedRectangle(cornerRadius: spec.cornerRadius, style: .continuous)
    )
    .animation(.snappy, value: spec.activeIndex)
  }
}
