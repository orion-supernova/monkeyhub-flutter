import Flutter
import MapKit
import UIKit

/// An interactive Apple Maps view for a location bubble's full-screen map —
/// `MKMapView` as a Flutter platform view (`monkeyhub/map_view`).
///
/// Creation params (standard message codec): `latitude`, `longitude`,
/// `accuracyM` (Double or null), `spanMeters` (initial visible width), `dark`.
/// Per-view channel `monkeyhub/map_view_<viewId>`: `update`, `recenter`,
/// `setDark`. The macOS twin is `macos/Runner/MapViewFactory.swift`.
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
    private let originalSpan: Double
    private var dark: Bool

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        let params = args as? [String: Any] ?? [:]
        let lat = params["latitude"] as? Double ?? 0
        let lng = params["longitude"] as? Double ?? 0
        let accuracy = params["accuracyM"] as? Double
        originalSpan = max(params["spanMeters"] as? Double ?? 500, 1)
        dark = params["dark"] as? Bool ?? false

        map = MKMapView(frame: frame)
        channel = FlutterMethodChannel(name: "monkeyhub/map_view_\(viewId)",
                                       binaryMessenger: messenger)
        super.init()

        let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        map.delegate = self
        map.mapType = .standard
        map.showsCompass = true
        map.showsScale = true
        map.showsUserLocation = false
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
        map.addAnnotation(annotation)
        setCircle(centre: centre, radius: accuracy)

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result) ?? result(nil)
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
            if args["follow"] as? Bool == true {
                map.setCenter(centre, animated: true)
            }
            result(nil)
        case "recenter":
            let centre = annotation.coordinate
            map.setRegion(MKCoordinateRegion(center: centre,
                                             latitudinalMeters: originalSpan,
                                             longitudinalMeters: originalSpan),
                          animated: true)
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
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation === self.annotation else { return nil }
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
