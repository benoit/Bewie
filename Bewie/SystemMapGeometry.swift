import MapKit
import SwiftUI

/// Shared framing and overlay limits for the native map and its projection tests.
enum SystemMapGeometry {
    private static let neighborhoodDistance: CLLocationDistance = 4_000
    private static let arrivalDistance: CLLocationDistance = 2_000

    static func startCamera(at coordinate: CLLocationCoordinate2D) -> MapCamera {
        MapCamera(centerCoordinate: coordinate, distance: neighborhoodDistance, heading: 0, pitch: 0)
    }

    /// Track arrivals use the closer view; launch/foreground use a wider overview.
    static func focusCamera(for track: AlbumTrack) -> MapCamera {
        MapCamera(centerCoordinate: track.coordinate, distance: arrivalDistance, heading: 0, pitch: 0)
    }

    struct TrackFlight {
        let departure: MapCamera
        let translation: MapCamera
        let arrival: MapCamera
    }

    /// Separate zoom from translation: retain exactly the same wide distance
    /// while moving to the destination, then make one final zoom to arrival.
    @MainActor
    static func trackFlight(for track: AlbumTrack, from source: MapCamera, in viewport: CGSize) -> TrackFlight {
        let departure = travelCamera(from: source, to: track.coordinate)
        let translation = centeredFocusCamera(for: track, in: viewport, distance: departure.distance)
        let arrival = centeredFocusCamera(for: track, in: viewport)
        return TrackFlight(departure: departure, translation: translation, arrival: arrival)
    }

    /// Center the visible circle, with the stem still pointing to the exact place.
    /// Use MapKit's own projection at the destination scale to move the camera
    /// north by one stem height, independently of latitude and phone dimensions.
    @MainActor
    static func centeredFocusCamera(for track: AlbumTrack, in viewport: CGSize,
                                    distance: CLLocationDistance? = nil) -> MapCamera {
        let focus = MapCamera(centerCoordinate: track.coordinate, distance: distance ?? arrivalDistance,
                              heading: 0, pitch: 0)
        guard viewport.width > 0, viewport.height > 0 else { return focus }
        let projection = MKMapView(frame: CGRect(origin: .zero, size: viewport))
        projection.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        projection.setCamera(MKMapCamera(lookingAtCenter: focus.centerCoordinate,
                                         fromDistance: focus.distance,
                                         pitch: focus.pitch,
                                         heading: focus.heading), animated: false)
        projection.layoutIfNeeded()
        let center = projection.convert(CGPoint(x: viewport.width / 2,
                                                y: viewport.height / 2 - PinPlacement.stemHeight),
                                        toCoordinateFrom: projection)
        return MapCamera(centerCoordinate: center, distance: focus.distance, heading: 0, pitch: 0)
    }

    /// Pull away far enough to travel between the two places before arriving.
    static func travelCamera(from camera: MapCamera, to track: AlbumTrack) -> MapCamera {
        travelCamera(from: camera, to: track.coordinate)
    }

    static func travelCamera(from camera: MapCamera, to coordinate: CLLocationCoordinate2D) -> MapCamera {
        let source = CLLocation(latitude: camera.centerCoordinate.latitude, longitude: camera.centerCoordinate.longitude)
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = min(30_000_000, max(camera.distance * 1.4, source.distance(from: destination) * 4, 3_000))
        return MapCamera(centerCoordinate: camera.centerCoordinate, distance: distance, heading: 0, pitch: 0)
    }

    /// Every track participates in layout, even when MapKit cannot project it
    /// during a long camera flight. Preserve offscreen direction until placement.
    static func pinAnchor(for coordinate: CLLocationCoordinate2D, id: Int,
                          projectedPoint: CGPoint?, camera: MapCamera?, in bounds: CGRect) -> PinAnchor {
        if let point = projectedPoint, point.x.isFinite, point.y.isFinite {
            return PinAnchor(id: id, point: point, isOffscreen: !bounds.contains(point))
        }
        let destination = MKMapPoint(coordinate)
        let source = MKMapPoint(camera?.centerCoordinate ?? MapStartLocation.fallbackCoordinate)
        var dx = destination.x - source.x
        let dy = destination.y - source.y
        let world = MKMapRect.world.width
        if dx > world / 2 { dx -= world }
        if dx < -world / 2 { dx += world }
        let length = hypot(dx, dy)
        guard length > 0.001, length.isFinite else {
            return PinAnchor(id: id, point: CGPoint(x: bounds.midX, y: bounds.midY))
        }
        let reach = max(bounds.width, bounds.height, 1) * 4
        return PinAnchor(id: id,
                         point: CGPoint(x: bounds.midX + dx / length * reach,
                                        y: bounds.midY + dy / length * reach),
                         isOffscreen: true)
    }

    /// Callers using safe-area-only viewports can retain the legacy attribution
    /// strip. The full-screen player instead reserves just the actual obstacles.
    static func pinLayoutBounds(in size: CGSize, bottomClearance: CGFloat = 44) -> CGRect {
        CGRect(x: 0, y: 0, width: max(0, size.width), height: max(0, size.height - bottomClearance))
    }

    static func guideButtonFrame(in size: CGSize, bottomSafeArea: CGFloat) -> CGRect {
        CGRect(x: size.width / 2 - 24, y: size.height - bottomSafeArea - 60, width: 48, height: 48)
    }

    /// Test the rendered circle, not the geographical anchor at the stem's tip.
    /// A small tolerance absorbs MapKit's final projection/rounding differences.
    static func isPinCentered(_ pin: PlacedPin, in size: CGSize) -> Bool {
        guard !pin.isOffscreen, size.width > 0, size.height > 0 else { return false }
        return hypot(pin.center.x - size.width / 2, pin.center.y - size.height / 2) <= 8
    }

    static func pinExclusions(in size: CGSize, topSafeArea: CGFloat, bottomSafeArea: CGFloat,
                              showsSystemIndicators: Bool = false, guideButton: CGRect? = nil) -> [CGRect] {
        var areas: [CGRect] = []
        if showsSystemIndicators && topSafeArea > 0 {
            areas.append(CGRect(x: 0, y: 0, width: size.width, height: topSafeArea))
        } else if topSafeArea > 20 {
            let width = min(size.width - 80, topSafeArea >= 59 ? 160.0 : 250.0)
            areas.append(CGRect(x: (size.width - width) / 2, y: 0, width: width, height: topSafeArea))
        }
        // Apple attribution is at the lower left; do not waste the entire row.
        areas.append(CGRect(x: 0, y: max(0, size.height - bottomSafeArea - 32),
                            width: min(160, size.width), height: bottomSafeArea + 32))
        if bottomSafeArea > 0 {
            // Small corner cutouts keep the heads inside rounded screen corners.
            for x in [CGFloat.zero, max(0, size.width - 20)] {
                for y in [CGFloat.zero, max(0, size.height - 20)] {
                    areas.append(CGRect(x: x, y: y, width: 20, height: 20))
                }
            }
        }
        if showsSystemIndicators && bottomSafeArea > 0 {
            areas.append(CGRect(x: size.width / 2 - 80, y: size.height - bottomSafeArea,
                                width: 160, height: bottomSafeArea))
        }
        if let guideButton { areas.append(guideButton) }
        return areas
    }
}
