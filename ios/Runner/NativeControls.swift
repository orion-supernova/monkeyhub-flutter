import Flutter
import SwiftUI
import UIKit

// The Liquid Glass kit's real controls: SwiftUI views hosted one per Flutter
// platform view (`UiKitView`, view type `monkeyhub/native_control`).
//
// Dart owns all state (`lib/ui/native/native_control.dart`). It creates a view
// with a spec — a plain map: `kind` plus that kind's fields — pushes a new spec
// over `monkeyhub/native_control/<id>` whenever it changes (`update`), and
// hears back what the person did (`tap`, `changed`, `submitted`, `select`,
// `size`). This side never decides anything; it renders the spec it was last
// given, so a hot restart or a rebuilt widget resyncs by sending it again.
//
// Cost, read before using one in a list: any platform view on screen drops
// every Flutter list from 120 Hz to bursts of 60 (flutter/flutter#190815) and
// doubles the cost of a BackdropFilter beside it (flutter/flutter#138656). See
// `NativeChrome.swift` for the sibling-view alternative fixed chrome can use,
// and docs/architecture/ui-architecture.html §4 for when each is right.
//
// Lessons carried over from the React Native port (docs/native-ui.md there):
// - every host ignores the safe area, or SwiftUI offsets its content by the
//   safe-area overlap and the control draws and hit-tests apart;
// - a Slider is never given a zero step (SwiftUI traps);
// - a Menu's label takes `buttonStyle(.glass)`, never `glassEffect()`;
// - chrome buttons are 44 pt with a 17 pt semibold symbol: SwiftUI's own
//   control sizes are far smaller.

// MARK: - Factory

final class NativeControlFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "monkeyhub/native_control"

  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeControlPlatformView(
      frame: frame,
      viewId: viewId,
      spec: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  /// Registers the factory. Call once per engine, beside the app's channels.
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeControlFactory(messenger: registrar.messenger()),
      withId: viewType
    )
  }
}

// MARK: - Platform view

final class NativeControlPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel
  private let model: NativeControlModel
  private var host: UIHostingController<NativeControlRoot>?
  private var lastReported: CGSize = .zero

  init(
    frame: CGRect,
    viewId: Int64,
    spec: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    // The box Flutter laid out is the control's box: a SwiftUI control a few
    // points taller than asked must not paint over its neighbours.
    container.clipsToBounds = true
    channel = FlutterMethodChannel(
      name: "monkeyhub/native_control/\(viewId)",
      binaryMessenger: messenger
    )
    model = NativeControlModel(spec: NativeControlSpec(spec))
    super.init()

    let emit: (String, Any?) -> Void = { [weak self] event, value in
      self?.channel.invokeMethod(event, arguments: value)
    }
    let host = UIHostingController(
      rootView: NativeControlRoot(model: model, emit: emit)
    )
    host.view.backgroundColor = .clear
    host.view.frame = container.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if #available(iOS 16.4, *) {
      host.safeAreaRegions = []
    }
    container.addSubview(host.view)
    self.host = host

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "update":
        self.model.spec = NativeControlSpec(call.arguments as? [String: Any] ?? [:])
        self.reportSize()
        result(nil)
      case "focus":
        self.model.focusTick += 1
        result(nil)
      case "blur":
        self.model.blurTick += 1
        result(nil)
      case "measure":
        self.reportSize(force: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    DispatchQueue.main.async { [weak self] in self?.reportSize(force: true) }
  }

  func view() -> UIView { container }

  /// The size the control wants, for a Dart wrapper that sizes to its content
  /// (a text button, a menu label). Fixed-size controls ignore it.
  private func reportSize(force: Bool = false) {
    guard let host else { return }
    let fit = host.sizeThatFits(
      in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    )
    guard force || fit != lastReported else { return }
    lastReported = fit
    channel.invokeMethod("size", arguments: ["width": fit.width, "height": fit.height])
  }

  deinit {
    channel.setMethodCallHandler(nil)
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
    let glyph = Image(systemName: spec.symbol ?? "circle")
      .font(.system(size: spec.symbolSize, weight: .semibold))
      .frame(width: spec.size, height: spec.size)
      .contentShape(Circle())
    let button = Button { emit("tap", nil) } label: { glyph }
      .accessibilityLabel(Text(spec.label))
    if #available(iOS 26.0, *) {
      if spec.prominent {
        button.buttonStyle(.glassProminent).buttonBorderShape(.circle)
      } else {
        button.buttonStyle(.plain)
          .foregroundStyle(spec.destructive ? Color.red : Color.primary)
          .glassEffect(.regular.interactive(), in: Circle())
      }
    } else {
      // Below iOS 26 this kit is never resolved; the capsule is only a
      // safe fallback (.circle needs iOS 17).
      button.buttonStyle(.bordered).buttonBorderShape(.capsule)
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
        .regular.interactive(),
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
      row.glassEffect(.regular.interactive(), in: Capsule())
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
            .glassEffect(.regular.interactive(), in: Circle())
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
