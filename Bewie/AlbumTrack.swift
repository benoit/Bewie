import CoreLocation
import Foundation

enum TrackDirection: Sendable {
    case previous
    case next
}

struct AlbumTrack: Identifiable, Sendable {
    let id: Int
    let title: String
    let latitude: Double
    let longitude: Double
    let filename: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func adjacent(to trackID: Int, direction: TrackDirection) -> AlbumTrack? {
        guard let index = all.firstIndex(where: { $0.id == trackID }) else { return nil }
        let offset = direction == .next ? 1 : -1
        return all[(index + offset + all.count) % all.count]
    }

    static let all: [AlbumTrack] = [
        AlbumTrack(id: 1, title: "Party Warriors", latitude: 40.414684, longitude: -3.701515, filename: "track-01.m4a"),
        AlbumTrack(id: 2, title: "Every Room Is Borrowed", latitude: 40.758624, longitude: -73.972454, filename: "track-02.m4a"),
        AlbumTrack(id: 3, title: "Next", latitude: 41.917283, longitude: 8.737683, filename: "track-03.m4a"),
        AlbumTrack(id: 4, title: "Glass Walls", latitude: 52.528349, longitude: 13.410546, filename: "track-04.m4a"),
        AlbumTrack(id: 5, title: "Local Time", latitude: 13.736403, longitude: 100.561318, filename: "track-05.m4a"),
        AlbumTrack(id: 6, title: "Noon Without End", latitude: 39.007425, longitude: 1.581133, filename: "track-06.m4a"),
        AlbumTrack(id: 7, title: "Zero", latitude: 0.000000, longitude: 0.000000, filename: "track-07.m4a"),
        AlbumTrack(id: 8, title: "Last Ones Home", latitude: 48.583120, longitude: 7.754075, filename: "track-08.m4a"),
        AlbumTrack(id: 9, title: "I Stayed", latitude: 43.482428, longitude: -1.559191, filename: "track-09.m4a")
    ]
}
