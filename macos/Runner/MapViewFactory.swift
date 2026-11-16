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
    private var trailLine: MKPolyline?
    private var trailCoords: [CLLocationCoordinate2D] = []
    private let originalSpan: Double
    private var isDark: Bool
    private var pinImage: NSImage?
    private var pinAnchorY: Double = 1
    private var mapTypeName = "standard"
    private var trafficOn = false
    private var readyFired = false
    private var lastGestureAt = Date.distantPast
    /// Region changes before this instant are ours (setRegion/setCenter).
    private var programmaticUntil = Date.distantPast
    private let pinId = "monkeyhub.pin"

    init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        let params = args as? [String: Any] ?? [:]
        let lat = params["latitude"] as? Double ?? 0
        let lng = params["longitude"] as? Double ?? 0
        let accuracy = params["accuracyM"] as? Double
        originalSpan = max(params["spanMeters"] as? Double ?? 500, 1)
        isDark = params["dark"] as? Bool ?? false
        mapTypeName = params["mapType"] as? String ?? "standard"
        trafficOn = params["traffic"] as? Bool ?? false
        channel = FlutterMethodChannel(name: "monkeyhub/map_view_\(viewId)",
                                       binaryMessenger: messenger)
        super.init(frame: .zero)

        let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        delegate = self
        applyMapStyle()
        showsCompass = true
        showsScale = true
        // Never asks for permission: Dart only sets this once it is granted.
        showsUserLocation = params["showsUser"] as? Bool ?? false
        // Keeps Apple's logo/Legal/compass/scale clear of the Flutter chrome
        // (top ~110pt, bottom ~220pt). macOS has no layoutMargins on MKMapView.
        additionalSafeAreaInsets = NSEdgeInsets(top: 110, left: 8, bottom: 220, right: 8)
        isZoomEnabled = true
        isScrollEnabled = true
        isRotateEnabled = true
        isPitchEnabled = true
        appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        markProgrammatic()
        setRegion(MKCoordinateRegion(center: centre,
                                     latitudinalMeters: originalSpan,
                                     longitudinalMeters: originalSpan),
                  animated: false)
        readPin(params)
        pin.coordinate = centre
        addAnnotation(pin)
        setCircle(centre: centre, radius: accuracy)
        setTrail(Self.parseTrail(params["trail"]))

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result) ?? result(nil)
        }
        // Fallback in case the map never reports a finished render.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.fireReady()
        }
    }

    private func markProgrammatic() {
        programmaticUntil = Date().addingTimeInterval(1.2)
    }

    private func fireReady() {
        guard !readyFired else { return }
        readyFired = true
        channel.invokeMethod("ready", arguments: nil)
    }

    private static func parseTrail(_ raw: Any?) -> [CLLocationCoordinate2D]? {
        guard let list = raw as? [Any] else { return nil }
        return list.compactMap { item -> CLLocationCoordinate2D? in
            guard let pair = item as? [Any], pair.count >= 2,
                  let la = (pair[0] as? NSNumber)?.doubleValue,
                  let lo = (pair[1] as? NSNumber)?.doubleValue else { return nil }
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }
    }

    private func setTrail(_ coords: [CLLocationCoordinate2D]?) {
        guard let coords = coords else { return }
        trailCoords = coords
        if let old = trailLine { removeOverlay(old) }
        trailLine = nil
        if coords.count >= 2 {
            let line = MKPolyline(coordinates: coords, count: coords.count)
            trailLine = line
            insertOverlay(line, at: 0)
        }
    }

    /// Reads `pinImage` / `pinScale` / `pinAnchorY`; true when a new image came.
    @discardableResult
    private func readPin(_ args: [String: Any]) -> Bool {
        guard let data = (args["pinImage"] as? FlutterStandardTypedData)?.data,
              let rep = NSBitmapImageRep(data: data),
              let img = NSImage(data: data) else { return false }
        let scale = max((args["pinScale"] as? NSNumber)?.doubleValue ?? 1, 1)
        img.size = NSSize(width: Double(rep.pixelsWide) / scale,
                          height: Double(rep.pixelsHigh) / scale)
        pinImage = img
        if let a = (args["pinAnchorY"] as? NSNumber)?.doubleValue { pinAnchorY = a }
        return true
    }

    private func refreshPinView() {
        guard let v = view(for: pin) else { return }
        if pinImage != nil, v.reuseIdentifier == pinId {
            applyPin(to: v)
        } else {
            removeAnnotation(pin)
            addAnnotation(pin)
        }
    }

    private func applyPin(to v: MKAnnotationView) {
        guard let img = pinImage else { return }
        v.image = img
        v.centerOffset = NSPoint(x: 0, y: (0.5 - pinAnchorY) * Double(img.size.height))
    }

    private func applyMapStyle() {
        if #available(macOS 13.0, *) {
            switch mapTypeName {
            case "satellite":
                preferredConfiguration = MKImageryMapConfiguration()
            case "hybrid":
                let c = MKHybridMapConfiguration()
                c.showsTraffic = trafficOn
                preferredConfiguration = c
            default:
                let c = MKStandardMapConfiguration()
                c.showsTraffic = trafficOn
                preferredConfiguration = c
            }
        } else {
            switch mapTypeName {
            case "satellite": mapType = .satellite
            case "hybrid": mapType = .hybrid
            default: mapType = .standard
            }
            showsTraffic = trafficOn
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
            if readPin(args) { refreshPinView() }
            setTrail(Self.parseTrail(args["trail"]))
            if args["follow"] as? Bool == true {
                markProgrammatic()
                setCenter(centre, animated: true)
            }
            result(nil)
        case "recenter":
            markProgrammatic()
            setRegion(MKCoordinateRegion(center: pin.coordinate,
                                         latitudinalMeters: originalSpan,
                                         longitudinalMeters: originalSpan),
                      animated: true)
            result(nil)
        case "setMapType":
            mapTypeName = args["type"] as? String ?? "standard"
            applyMapStyle()
            result(nil)
        case "setTraffic":
            trafficOn = args["on"] as? Bool ?? false
            applyMapStyle()
            result(nil)
        case "setShowsUser":
            showsUserLocation = args["on"] as? Bool ?? false
            result(nil)
        case "showBoth":
            markProgrammatic()
            if showsUserLocation, let loc = userLocation.location {
                let a = MKMapPoint(pin.coordinate)
                let b = MKMapPoint(loc.coordinate)
                var rect = MKMapRect(origin: a, size: MKMapSize(width: 0, height: 0))
                    .union(MKMapRect(origin: b, size: MKMapSize(width: 0, height: 0)))
                if rect.size.width < 1 && rect.size.height < 1 {
                    setRegion(MKCoordinateRegion(center: pin.coordinate,
                                                 latitudinalMeters: originalSpan,
                                                 longitudinalMeters: originalSpan),
                              animated: true)
                } else {
                    let minSide = MKMapPointsPerMeterAtLatitude(pin.coordinate.latitude) * 150
                    if rect.size.width < minSide || rect.size.height < minSide {
                        let grow = max(minSide - rect.size.width, minSide - rect.size.height, 0)
                        rect = rect.insetBy(dx: -grow / 2, dy: -grow / 2)
                    }
                    setVisibleMapRect(rect,
                                      edgePadding: NSEdgeInsets(top: 140, left: 60,
                                                                bottom: 260, right: 60),
                                      animated: true)
                }
            } else {
                setRegion(MKCoordinateRegion(center: pin.coordinate,
                                             latitudinalMeters: originalSpan,
                                             longitudinalMeters: originalSpan),
                          animated: true)
            }
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
            if trailLine != nil { setTrail(trailCoords) }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation === pin else { return nil }
        if pinImage != nil {
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: pinId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: pinId)
            v.annotation = annotation
            v.canShowCallout = false
            v.isEnabled = false
            applyPin(to: v)
            return v
        }
        let id = "monkeyhub.marker"
        let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        v.annotation = annotation
        v.markerTintColor = tint
        v.canShowCallout = false
        return v
    }

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        fireReady()
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let now = Date()
        guard now >= programmaticUntil,
              now.timeIntervalSince(lastGestureAt) >= 0.5 else { return }
        lastGestureAt = now
        channel.invokeMethod("gesture", arguments: nil)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        programmaticUntil = Date.distantPast
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let c = overlay as? MKCircle {
            let r = MKCircleRenderer(circle: c)
            r.fillColor = tint.withAlphaComponent(0.12)
            r.strokeColor = tint.withAlphaComponent(0.35)
            r.lineWidth = 1
            return r
        }
        if let l = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: l)
            r.strokeColor = tint.withAlphaComponent(0.55)
            r.lineWidth = 3
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
