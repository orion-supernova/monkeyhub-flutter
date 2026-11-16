import AppKit
import FlutterMacOS
import MapKit

/// A street-map picture for a location bubble — `MKMapSnapshotter`. The macOS
/// twin of `ios/Runner/MapSnapshot.swift`; see there for the contract.
final class MapSnapshot: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/map_snapshot",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            if call.method == "geocode" {
                geocode(call.arguments as? [String: Any] ?? [:], result)
                return
            }
            guard call.method == "snapshot" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let args = call.arguments as? [String: Any] ?? [:]
            guard let lat = args["latitude"] as? Double,
                  let lng = args["longitude"] as? Double,
                  let span = args["spanMeters"] as? Double,
                  let width = args["width"] as? Double,
                  let height = args["height"] as? Double,
                  width > 0, height > 0, span > 0 else {
                result(nil)
                return
            }
            let centre = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            guard CLLocationCoordinate2DIsValid(centre) else {
                result(nil)
                return
            }
            let scale = CGFloat(args["scale"] as? Double ?? 2)
            let dark = args["dark"] as? Bool ?? false

            let options = MKMapSnapshotter.Options()
            options.region = MKCoordinateRegion(center: centre,
                                                latitudinalMeters: span * height / width,
                                                longitudinalMeters: span)
            // Size in points, so map labels come out at their normal size; the
            // pixel size is chosen when the image is flattened below.
            options.size = CGSize(width: width, height: height)
            options.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            options.showsBuildings = true

            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, error in
                _ = snapshotter
                var png: Data?
                // Flatten at the bubble's pixel size (points × the Flutter
                // view's scale), so a Retina window gets Retina pixels whatever
                // screen MapKit rendered against.
                var rect = NSRect(x: 0, y: 0, width: width * scale, height: height * scale)
                if let image = snapshot?.image,
                   let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                    png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
                }
                if png == nil {
                    NSLog("[map_snapshot] failed: \(error?.localizedDescription ?? "no image")")
                }
                DispatchQueue.main.async {
                    result(png.map { FlutterStandardTypedData(bytes: $0) })
                }
            }
        }
    }

    /// Reverse geocode for the location bubble's address line.
    private static func geocode(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let lat = args["latitude"] as? Double,
              let lng = args["longitude"] as? Double,
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng)) else {
            result(nil)
            return
        }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lng),
                                        preferredLocale: Locale.current) { marks, _ in
            // Held until completion so the request is not cancelled.
            _ = geocoder
            var out: [String: String]?
            if let p = marks?.first {
                var title = p.thoroughfare ?? ""
                if !title.isEmpty, let n = p.subThoroughfare, !n.isEmpty { title += " " + n }
                if title.isEmpty { title = p.name ?? p.locality ?? "" }
                let place = p.locality ?? p.subAdministrativeArea
                var line = ""
                if let zip = p.postalCode, !zip.isEmpty {
                    line = place.map { zip + " " + $0 } ?? zip
                } else if let place = place {
                    line = place
                }
                if let country = p.country, let iso = p.isoCountryCode,
                   iso != Locale.current.regionCode {
                    line = line.isEmpty ? country : line + ", " + country
                }
                if !title.isEmpty || !line.isEmpty {
                    out = ["title": title, "subtitle": line]
                }
            }
            DispatchQueue.main.async { result(out) }
        }
    }
}
