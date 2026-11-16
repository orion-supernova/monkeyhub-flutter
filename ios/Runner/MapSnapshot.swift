import Flutter
import MapKit
import UIKit

/// A street-map picture for a location bubble — `MKMapSnapshotter`.
///
/// Apple Maps rendered off-screen to a still image: no API key, no quota, no
/// server of ours involved. Tiles come from Apple and are cached by MapKit on
/// the device, so a transcript scrolling past the same place again is cheap.
///
/// `snapshot` takes the centre, the width of the view in metres, the size in
/// points, the display scale and light/dark, and returns a PNG of the map with
/// no annotations: the Dart side draws the marker and the accuracy ring on top
/// (`lib/widgets/location_map_preview.dart`), so they stay in the app's style
/// and the live pulse animates without re-rendering the map. `nil` on any
/// failure (offline with nothing cached, bad arguments); the caller keeps its
/// drawn fallback.
///
/// The macOS twin is `macos/Runner/MapSnapshot.swift`.
final class MapSnapshot: NSObject {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "monkeyhub/map_snapshot",
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            if call.method == "search" {
                search(call.arguments as? [String: Any] ?? [:], result)
                return
            }
            if call.method == "nearby" {
                nearby(call.arguments as? [String: Any] ?? [:], result)
                return
            }
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
            let scale = (args["scale"] as? Double).map { CGFloat($0) } ?? UIScreen.main.scale
            let dark = args["dark"] as? Bool ?? false

            let options = MKMapSnapshotter.Options()
            // Width is the stated span; height keeps metres square on screen,
            // so the Dart overlay's metres-to-points scale matches the map's.
            options.region = MKCoordinateRegion(center: centre,
                                                latitudinalMeters: span * height / width,
                                                longitudinalMeters: span)
            options.size = CGSize(width: width, height: height)
            options.traitCollection = UITraitCollection(traitsFrom: [
                UITraitCollection(displayScale: scale),
                UITraitCollection(userInterfaceStyle: dark ? .dark : .light),
            ])
            options.showsBuildings = true

            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, error in
                // Held until completion; MapKit does not promise to keep a
                // snapshotter alive on its own.
                _ = snapshotter
                let png = snapshot?.image.pngData()
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

    // MARK: search / nearby

    private static func shortAddress(_ p: CLPlacemark) -> String {
        var street = p.thoroughfare ?? ""
        if !street.isEmpty, let n = p.subThoroughfare, !n.isEmpty { street += " " + n }
        return [street, p.locality ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private static func describe(_ item: MKMapItem) -> [String: Any]? {
        let p = item.placemark
        let c = p.coordinate
        guard CLLocationCoordinate2DIsValid(c) else { return nil }
        let title = item.name ?? p.title ?? ""
        var subtitle = shortAddress(p)
        if subtitle == title { subtitle = p.locality ?? "" }
        return ["title": title, "subtitle": subtitle,
                "latitude": c.latitude, "longitude": c.longitude]
    }

    /// Kept alive until their completion handler has run.
    private static var activeSearches: [ObjectIdentifier: MKLocalSearch] = [:]

    private static func run(_ search: MKLocalSearch, limit: Int, origin: CLLocation?,
                            _ result: @escaping FlutterResult) {
        let key = ObjectIdentifier(search)
        activeSearches[key] = search
        search.start { response, _ in
            var items = response?.mapItems ?? []
            if let origin = origin {
                items.sort {
                    CLLocation(latitude: $0.placemark.coordinate.latitude,
                               longitude: $0.placemark.coordinate.longitude).distance(from: origin)
                    < CLLocation(latitude: $1.placemark.coordinate.latitude,
                                 longitude: $1.placemark.coordinate.longitude).distance(from: origin)
                }
            }
            let out = items.compactMap { describe($0) }.prefix(limit)
            DispatchQueue.main.async {
                activeSearches[key] = nil
                result(Array(out))
            }
        }
    }

    private static func search(_ args: [String: Any], _ result: @escaping FlutterResult) {
        let query = (args["query"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let lat = (args["latitude"] as? NSNumber)?.doubleValue,
              let lng = (args["longitude"] as? NSNumber)?.doubleValue,
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng)) else {
            result([[String: Any]]())
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                            latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        if #available(iOS 13.0, *) {
            request.resultTypes = [.address, .pointOfInterest]
        }
        run(MKLocalSearch(request: request), limit: 12, origin: nil, result)
    }

    private static func nearby(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard let lat = (args["latitude"] as? NSNumber)?.doubleValue,
              let lng = (args["longitude"] as? NSNumber)?.doubleValue,
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng)) else {
            result([[String: Any]]())
            return
        }
        let radius = (args["radius"] as? NSNumber)?.doubleValue ?? 300
        if #available(iOS 14.0, *) {
            let request = MKLocalPointsOfInterestRequest(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                radius: max(radius, 1))
            run(MKLocalSearch(request: request), limit: 20,
                origin: CLLocation(latitude: lat, longitude: lng), result)
        } else {
            result([[String: Any]]())
        }
    }
}
