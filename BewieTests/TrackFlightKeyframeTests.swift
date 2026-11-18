import MapKit
import SwiftUI
import XCTest
@testable import Bewie

@MainActor
final class TrackFlightKeyframeTests: XCTestCase {
    func testCameraTimelineHasSlowContinuousTranslationAndOneFinalZoom() throws {
        let start = SystemMapGeometry.startCamera(at: MapStartLocation.fallbackCoordinate)
        let target = try XCTUnwrap(AlbumTrack.all.first { $0.id == 2 })
        let plan = SystemMapGeometry.trackFlight(for: target, from: start, in: CGSize(width: 402, height: 874))
        let timeline = KeyframeTimeline(initialValue: start) {
            TrackFlightKeyframes.frames(from: start, to: plan)
        }
        XCTAssertEqual(timeline.duration, 7.9, accuracy: 0.0001)
        let transferStart = 1.4
        let transferEnd = 3.9
        let first = timeline.value(time: transferStart)
        XCTAssertEqual(first.distance, plan.departure.distance, accuracy: 0.01)
        XCTAssertEqual(first.centerCoordinate.longitude, start.centerCoordinate.longitude, accuracy: 0.00001)
        // Samples throughout the whole travel interval must move at constant
        // speed, with no ease-to-rest or timer pause at either end.
        for index in 0..<10 {
            let t0 = transferStart + Double(index) * 0.23
            let t1 = t0 + 0.1
            let a = timeline.value(time: t0)
            let b = timeline.value(time: t1)
            XCTAssertEqual(a.distance, plan.departure.distance, accuracy: 0.01)
            let expected = (plan.translation.centerCoordinate.longitude - start.centerCoordinate.longitude) * 0.1 / 2.5
            XCTAssertEqual(b.centerCoordinate.longitude - a.centerCoordinate.longitude, expected, accuracy: 0.00001)
        }
        let reached = timeline.value(time: transferEnd)
        XCTAssertEqual(reached.centerCoordinate.longitude, plan.translation.centerCoordinate.longitude, accuracy: 0.00001)
        XCTAssertLessThan(timeline.value(time: transferEnd + 0.1).distance, reached.distance)
        XCTAssertEqual(timeline.value(time: timeline.duration).distance, 2_000, accuracy: 0.01)
    }

    func testCancellationTimelineStaysAtTheCurrentCamera() {
        let camera = SystemMapGeometry.startCamera(at: AlbumTrack.all[4].coordinate)
        let timeline = KeyframeTimeline(initialValue: camera) {
            TrackFlightKeyframes.frames(from: camera, to: nil)
        }
        XCTAssertEqual(timeline.duration, 0)
        let stopped = timeline.value(time: 0)
        XCTAssertEqual(stopped.distance, camera.distance)
        XCTAssertEqual(stopped.centerCoordinate.latitude, camera.centerCoordinate.latitude)
        XCTAssertEqual(stopped.centerCoordinate.longitude, camera.centerCoordinate.longitude)
    }
}
