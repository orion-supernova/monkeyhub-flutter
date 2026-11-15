import AppKit
import FlutterMacOS
import MapKit

/// An interactive Apple Maps view for a location bubble's full-screen map —
/// `MKMapView` as a Flutter platform view (`monkeyhub/map_view`). The macOS
/// twin of `ios/Runner/MapViewFactory.swift`; see there for the contract.
final class MapViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(MapViewFactory(messenger: registrar.messenger),
                           withId: "monkeyhub/map_view")
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        MapHostView(viewId: viewId, args: args, messenger: messenger)
    }
}

private final class MapHostView: MKMapView, MKMapViewDelegate {
    private let channel: FlutterMethodChannel
    private let pin = MKPointAnnotation()
    private var circle: MKCircle?
    private let originalSpan: Double
    private var isDark: Bool

    init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        let params = args as? [String: Any] ?? [:]
        let lat = params["latitude"] as? Double ?? 0
        let lng = params["longitude"] as? Double ?? 0
        let accuracy = params["accuracyM"] as? Double
        originalSpan = max(params["spanMeters"] as? Double ?? 500, 1)
        isDark = params["dark"] as? Bool ?? false
        channel = FlutterMethodChannel(name: "monkeyhub/map_view_\(viewId)",
                                       binaryMessenger: messenger)
        super.init(frame: .zero)

        let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        delegate = self
        mapType = .standard
        showsCompass = true
        showsScale = true
        showsUserLocation = false
        isZoomEnabled = true
        isScrollEnabled = true
        isRotateEnabled = true
        isPitchEnabled = true
        appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        setRegion(MKCoordinateRegion(center: centre,
                                     latitudinalMeters: originalSpan,
                                     longitudinalMeters: originalSpan),
                  animated: false)
        pin.coordinate = centre
        addAnnotation(pin)
        setCircle(centre: centre, radius: accuracy)

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result) ?? result(nil)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }

    private var tint: NSColor {
        isDark ? NSColor(red: 0.25, green: 0.81, blue: 0.73, alpha: 1)
               : NSColor(red: 0.03, green: 0.49, blue: 0.44, alpha: 1)
    }

    private func setCircle(centre: CLLocationCoordinate2D, radius: Double?) {
        if let old = circle { removeOverlay(old) }
        circle = nil
        if let radius = radius, radius > 0 {
            let c = MKCircle(center: centre, radius: radius)
            circle = c
            addOverlay(c)
        }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "update":
            guard let lat = args["latitude"] as? Double,
                  let lng = args["longitude"] as? Double else {
                result(nil)
                return
            }
            let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.allowsImplicitAnimation = true
                self.pin.coordinate = centre
            }
            setCircle(centre: centre, radius: args["accuracyM"] as? Double)
            if args["follow"] as? Bool == true {
                setCenter(centre, animated: true)
            }
            result(nil)
        case "recenter":
            setRegion(MKCoordinateRegion(center: pin.coordinate,
                                         latitudinalMeters: originalSpan,
                                         longitudinalMeters: originalSpan),
                      animated: true)
            result(nil)
        case "setDark":
            isDark = args["dark"] as? Bool ?? isDark
            appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
            if let v = view(for: pin) as? MKMarkerAnnotationView {
                v.markerTintColor = tint
            }
            if let c = circle {
                setCircle(centre: c.coordinate, radius: c.radius)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation === pin else { return nil }
        let id = "monkeyhub.marker"
        let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        v.annotation = annotation
        v.markerTintColor = tint
        v.canShowCallout = false
        return v
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let c = overlay as? MKCircle {
            let r = MKCircleRenderer(circle: c)
            r.fillColor = tint.withAlphaComponent(0.12)
            r.strokeColor = tint.withAlphaComponent(0.35)
            r.lineWidth = 1
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
