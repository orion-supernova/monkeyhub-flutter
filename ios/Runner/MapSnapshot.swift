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
}
