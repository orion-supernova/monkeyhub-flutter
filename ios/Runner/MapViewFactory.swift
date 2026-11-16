import Flutter
import MapKit
import UIKit

/// An interactive Apple Maps view for a location bubble's full-screen map —
/// `MKMapView` as a Flutter platform view (`monkeyhub/map_view`).
///
/// Creation params (standard message codec): `latitude`, `longitude`,
/// `accuracyM` (Double or null), `spanMeters` (initial visible width), `dark`.
/// Per-view channel `monkeyhub/map_view_<viewId>`: `update`, `recenter`,
/// `setDark`, `setMapType`, `setTraffic`, `setShowsUser`, `showBoth`. Optional
/// creation params: `pinImage` (+`pinScale`, `pinAnchorY`), `mapType`,
/// `traffic`, `showsUser`, `trail`, `picker` (no pin/accuracy/trail, wider margins).
/// Also `moveTo`. Events to Dart: `ready`, `gesture`, `cameraIdle`, and in
/// picker mode `cameraMoving`.
/// The macOS twin is `macos/Runner/MapViewFactory.swift`.
final class MapViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(MapViewFactory(messenger: registrar.messenger()),
                           withId: "monkeyhub/map_view")
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect,
                viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        MapPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
    }
}

private final class MapPlatformView: NSObject, FlutterPlatformView, MKMapViewDelegate {
    private let map: MKMapView
    private let channel: FlutterMethodChannel
    private let annotation = MKPointAnnotation()
    private var circle: MKCircle?
    private var trailLine: MKPolyline?
    private var trailCoords: [CLLocationCoordinate2D] = []
    private let originalSpan: Double
    private let picker: Bool
    private var dark: Bool
    private var pinImage: UIImage?
    private var pinAnchorY: Double = 1
    private var mapTypeName = "standard"
    private var trafficOn = false
    private var readyFired = false
    private var lastGestureAt = Date.distantPast
    private let pinId = "monkeyhub.pin"

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        let params = args as? [String: Any] ?? [:]
        let lat = params["latitude"] as? Double ?? 0
        let lng = params["longitude"] as? Double ?? 0
        let accuracy = params["accuracyM"] as? Double
        originalSpan = max(params["spanMeters"] as? Double ?? 500, 1)
        dark = params["dark"] as? Bool ?? false
        picker = params["picker"] as? Bool ?? false
        mapTypeName = params["mapType"] as? String ?? "standard"
        trafficOn = params["traffic"] as? Bool ?? false

        map = MKMapView(frame: frame)
        channel = FlutterMethodChannel(name: "monkeyhub/map_view_\(viewId)",
                                       binaryMessenger: messenger)
        super.init()

        let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        map.delegate = self
        applyMapStyle()
        map.showsCompass = true
        map.showsScale = true
        // Never asks for permission: Dart only sets this once it is granted.
        map.showsUserLocation = params["showsUser"] as? Bool ?? false
        // Keep Apple's logo, Legal link, compass and scale clear of the
        // Flutter chrome (top bar ~110pt, bottom card ~220pt).
        // Picker mode: Dart overlays a search bar (top) and a panel (bottom).
        let topMargin: CGFloat = picker ? 120 : 110
        let bottomMargin: CGFloat = picker ? 300 : 220
        map.layoutMargins = UIEdgeInsets(top: topMargin, left: 8, bottom: bottomMargin, right: 8)
        map.directionalLayoutMargins = NSDirectionalEdgeInsets(top: topMargin, leading: 8,
                                                               bottom: bottomMargin, trailing: 8)
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.overrideUserInterfaceStyle = dark ? .dark : .light
        map.setRegion(MKCoordinateRegion(center: centre,
                                         latitudinalMeters: originalSpan,
                                         longitudinalMeters: originalSpan),
                      animated: false)
        annotation.coordinate = centre
        if !picker {
            readPin(params)
            map.addAnnotation(annotation)
            setCircle(centre: centre, radius: accuracy)
            setTrail(Self.parseTrail(params["trail"]))
        }

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result) ?? result(nil)
        }
        // Fallback in case the map never reports a finished render.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.fireReady()
        }
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
        if let old = trailLine { map.removeOverlay(old) }
        trailLine = nil
        if coords.count >= 2 {
            let line = MKPolyline(coordinates: coords, count: coords.count)
            trailLine = line
            map.insertOverlay(line, at: 0)
        }
    }

    /// Reads `pinImage` / `pinScale` / `pinAnchorY`; returns true when a new
    /// image was supplied.
    @discardableResult
    private func readPin(_ args: [String: Any]) -> Bool {
        guard let data = (args["pinImage"] as? FlutterStandardTypedData)?.data else { return false }
        let scale = CGFloat((args["pinScale"] as? NSNumber)?.doubleValue ?? 1)
        guard let img = UIImage(data: data, scale: max(scale, 1)) else { return false }
        pinImage = img
        if let a = (args["pinAnchorY"] as? NSNumber)?.doubleValue { pinAnchorY = a }
        return true
    }

    private func refreshPinView() {
        guard let v = map.view(for: annotation) else { return }
        if pinImage != nil, v.reuseIdentifier == pinId {
            applyPin(to: v)
        } else {
            map.removeAnnotation(annotation)
            map.addAnnotation(annotation)
        }
    }

    private func applyPin(to v: MKAnnotationView) {
        guard let img = pinImage else { return }
        v.image = img
        v.centerOffset = CGPoint(x: 0, y: (0.5 - pinAnchorY) * img.size.height)
    }

    private func applyMapStyle() {
        if #available(iOS 16.0, *) {
            switch mapTypeName {
            case "satellite":
                map.preferredConfiguration = MKImageryMapConfiguration()
            case "hybrid":
                let c = MKHybridMapConfiguration()
                c.showsTraffic = trafficOn
                map.preferredConfiguration = c
            default:
                let c = MKStandardMapConfiguration()
                c.showsTraffic = trafficOn
                map.preferredConfiguration = c
            }
        } else {
            switch mapTypeName {
            case "satellite": map.mapType = .satellite
            case "hybrid": map.mapType = .hybrid
            default: map.mapType = .standard
            }
            map.showsTraffic = trafficOn
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }

    func view() -> UIView { map }

    private var tint: UIColor {
        dark ? UIColor(red: 0.25, green: 0.81, blue: 0.73, alpha: 1)
             : UIColor(red: 0.03, green: 0.49, blue: 0.44, alpha: 1)
    }

    private func setCircle(centre: CLLocationCoordinate2D, radius: Double?) {
        if let old = circle { map.removeOverlay(old) }
        circle = nil
        if let radius = radius, radius > 0 {
            let c = MKCircle(center: centre, radius: radius)
            circle = c
            map.addOverlay(c)
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
            UIView.animate(withDuration: 0.35) {
                self.annotation.coordinate = centre
            }
            setCircle(centre: centre, radius: args["accuracyM"] as? Double)
            if readPin(args) { refreshPinView() }
            setTrail(Self.parseTrail(args["trail"]))
            if args["follow"] as? Bool == true {
                map.setCenter(centre, animated: true)
            }
            result(nil)
        case "moveTo":
            guard let lat = (args["latitude"] as? NSNumber)?.doubleValue,
                  let lng = (args["longitude"] as? NSNumber)?.doubleValue else {
                result(nil)
                return
            }
            let target = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let animated = args["animated"] as? Bool ?? true
            if let span = (args["spanMeters"] as? NSNumber)?.doubleValue, span > 0 {
                map.setRegion(MKCoordinateRegion(center: target,
                                                 latitudinalMeters: span,
                                                 longitudinalMeters: span),
                              animated: animated)
            } else {
                map.setCenter(target, animated: animated)
            }
            result(nil)
        case "recenter":
            let centre = annotation.coordinate
            map.setRegion(MKCoordinateRegion(center: centre,
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
            map.showsUserLocation = args["on"] as? Bool ?? false
            result(nil)
        case "showBoth":
            if map.showsUserLocation, let loc = map.userLocation.location {
                let a = MKMapPoint(annotation.coordinate)
                let b = MKMapPoint(loc.coordinate)
                var rect = MKMapRect(origin: a, size: MKMapSize(width: 0, height: 0))
                    .union(MKMapRect(origin: b, size: MKMapSize(width: 0, height: 0)))
                if rect.size.width < 1 && rect.size.height < 1 {
                    map.setRegion(MKCoordinateRegion(center: annotation.coordinate,
                                                     latitudinalMeters: originalSpan,
                                                     longitudinalMeters: originalSpan),
                                  animated: true)
                } else {
                    // Keep a sane minimum so two very close points do not zoom to the rooftops.
                    let minSide = MKMapPointsPerMeterAtLatitude(annotation.coordinate.latitude) * 150
                    if rect.size.width < minSide || rect.size.height < minSide {
                        let grow = max(minSide - rect.size.width, minSide - rect.size.height, 0)
                        rect = rect.insetBy(dx: -grow / 2, dy: -grow / 2)
                    }
                    map.setVisibleMapRect(rect,
                                          edgePadding: UIEdgeInsets(top: 140, left: 60,
                                                                    bottom: 260, right: 60),
                                          animated: true)
                }
            } else {
                map.setRegion(MKCoordinateRegion(center: annotation.coordinate,
                                                 latitudinalMeters: originalSpan,
                                                 longitudinalMeters: originalSpan),
                              animated: true)
            }
            result(nil)
        case "setDark":
            dark = args["dark"] as? Bool ?? dark
            map.overrideUserInterfaceStyle = dark ? .dark : .light
            if let v = map.view(for: annotation) as? MKMarkerAnnotationView {
                v.markerTintColor = tint
            }
            // The renderer bakes colours at creation; rebuild the circle.
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
        guard annotation === self.annotation else { return nil }
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

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // centerCoordinate is the centre of the full bounds (layout margins
        // do not offset it), which is where Dart draws its centre pin.
        let c = mapView.centerCoordinate
        channel.invokeMethod("cameraIdle", arguments: ["latitude": c.latitude,
                                                       "longitude": c.longitude])
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        if picker { channel.invokeMethod("cameraMoving", arguments: nil) }
        guard let host = mapView.subviews.first,
              host.gestureRecognizers?.contains(where: {
                  $0.state == .began || $0.state == .changed
              }) == true else { return }
        let now = Date()
        guard now.timeIntervalSince(lastGestureAt) >= 0.5 else { return }
        lastGestureAt = now
        channel.invokeMethod("gesture", arguments: nil)
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
