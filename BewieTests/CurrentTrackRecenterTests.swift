import MapKit
import XCTest
@testable import Bewie

final class CurrentTrackRecenterTests: XCTestCase {
    func testRenderedCircleMustBeCenteredAndOnscreen() {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 744, height: 1133),
                     CGSize(width: 1133, height: 744), CGSize(width: 834, height: 1210),
                     CGSize(width: 1210, height: 834), CGSize(width: 1440, height: 900)] {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let anchor = CGPoint(x: center.x, y: center.y + PinPlacement.stemHeight)
            XCTAssertTrue(SystemMapGeometry.isPinCentered(PlacedPin(id: 9, anchor: anchor, center: center), in: size))
            XCTAssertTrue(SystemMapGeometry.isPinCentered(PlacedPin(id: 9, anchor: anchor,
                center: CGPoint(x: center.x + 2, y: center.y - 2)), in: size))
            for point in [anchor, CGPoint(x: 27, y: center.y), CGPoint(x: center.x, y: 27),
                          CGPoint(x: center.x + 12, y: center.y)] {
                XCTAssertFalse(SystemMapGeometry.isPinCentered(PlacedPin(id: 9, anchor: anchor, center: point), in: size))
            }
            XCTAssertFalse(SystemMapGeometry.isPinCentered(PlacedPin(id: 9, anchor: anchor, center: center,
                isOffscreen: true), in: size))
        }
    }

    @MainActor
    func testAllTrackArrivalsCenterTheRenderedPinAcrossPhoneDuoPadAndMacWindows() throws {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 744, height: 1133),
                     CGSize(width: 1133, height: 744), CGSize(width: 834, height: 1210),
                     CGSize(width: 1210, height: 834), CGSize(width: 1440, height: 900)] {
            let map = MKMapView(frame: CGRect(origin: .zero, size: size))
            map.layoutIfNeeded()
            let bounds = SystemMapGeometry.pinLayoutBounds(in: size, bottomClearance: 0)
            let exclusions = SystemMapGeometry.pinExclusions(in: size, topSafeArea: 62, bottomSafeArea: 34,
                showsSystemIndicators: true, guideButton: SystemMapGeometry.guideButtonFrame(in: size, bottomSafeArea: 34))
            for track in AlbumTrack.all {
                let focus = SystemMapGeometry.centeredFocusCamera(for: track, in: size)
                map.setCamera(MKMapCamera(lookingAtCenter: focus.centerCoordinate, fromDistance: focus.distance,
                    pitch: focus.pitch, heading: focus.heading), animated: false)
                map.layoutIfNeeded()
                let anchors = AlbumTrack.all.map {
                    SystemMapGeometry.pinAnchor(for: $0.coordinate, id: $0.id,
                        projectedPoint: map.convert($0.coordinate, toPointTo: map), camera: focus, in: bounds)
                }
                let pins = PinPlacement.resolve(anchors, in: bounds.size, selectedID: track.id, exclusions: exclusions)
                let pin = try XCTUnwrap(pins.first { $0.id == track.id })
                XCTAssertTrue(SystemMapGeometry.isPinCentered(pin, in: size), "\(track.title), \(size): \(pin.center)")
            }
        }
    }
}
