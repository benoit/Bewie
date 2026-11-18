import MapKit
import SwiftUI

/// One MapKit timeline, without timer gaps or an ease-to-rest at each join.
enum TrackFlightKeyframes {
    static let zoomOutDuration: TimeInterval = 1.4
    static let travelDuration: TimeInterval = 2.5
    static let zoomInDuration: TimeInterval = 4.0
    static let duration = zoomOutDuration + travelDuration + zoomInDuration

    @KeyframesBuilder<MapCamera>
    static func frames(from initial: MapCamera, to plan: SystemMapGeometry.TrackFlight?) -> some Keyframes<MapCamera> {
        KeyframeTrack(\.distance) {
            if let plan {
                LinearKeyframe(plan.departure.distance, duration: zoomOutDuration, timingCurve: .easeIn)
                LinearKeyframe(plan.departure.distance, duration: travelDuration)
                LinearKeyframe(plan.arrival.distance, duration: zoomInDuration, timingCurve: .easeOut)
            } else {
                MoveKeyframe(initial.distance)
            }
        }
        KeyframeTrack(\.centerCoordinate) {
            if let plan {
                LinearKeyframe(initial.centerCoordinate, duration: zoomOutDuration)
                LinearKeyframe(plan.translation.centerCoordinate, duration: travelDuration)
                LinearKeyframe(plan.arrival.centerCoordinate, duration: zoomInDuration, timingCurve: .easeOut)
            } else {
                MoveKeyframe(initial.centerCoordinate)
            }
        }
    }
}
