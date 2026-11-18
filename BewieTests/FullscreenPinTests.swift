import XCTest
import MapKit
@testable import Bewie

final class FullscreenPinTests: XCTestCase {
    @MainActor
    func testZeroStaysOnLowerSideWhenTrackNineIsSelected() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let track = try XCTUnwrap(AlbumTrack.all.first(where: { $0.id == 9 }))
            let camera = SystemMapGeometry.centeredFocusCamera(for: track, in: size)
            let map = MKMapView(frame: CGRect(origin: .zero, size: size))
            map.setCamera(MKMapCamera(lookingAtCenter: camera.centerCoordinate,
                                     fromDistance: camera.distance, pitch: 0, heading: 0), animated: false)
            map.layoutIfNeeded()
            let bounds = CGRect(x: 0, y: 62, width: size.width, height: size.height - 62)
            let anchors = AlbumTrack.all.map { track in
                SystemMapGeometry.pinAnchor(for: track.coordinate, id: track.id,
                    projectedPoint: map.convert(track.coordinate, toPointTo: map), camera: camera, in: bounds)
            }
            let exclusions = SystemMapGeometry.pinExclusions(in: size, topSafeArea: 62, bottomSafeArea: 34,
                showsSystemIndicators: true, guideButton: SystemMapGeometry.guideButtonFrame(in: size, bottomSafeArea: 34))
            let pins = PinPlacement.resolve(anchors, in: bounds.size, selectedID: 9, origin: bounds.origin, exclusions: exclusions)
            let zero = try XCTUnwrap(pins.first(where: { $0.id == 7 }))
            XCTAssertGreaterThan(zero.center.y, size.height * 0.75, "Zero should stay near the lower edge: \(zero.center), \(size)")
        }
    }

    func testOffscreenPinUsesCloserAdjacentEdgeBeforeDistantPreferredEdge() throws {
        let size = CGSize(width: 402, height: 874)
        let anchor = PinAnchor(id: 7, point: CGPoint(x: 2000, y: 2000), isOffscreen: true)
        let obstacle = CGRect(x: 350, y: 600, width: 52, height: 274)
        let pin = try XCTUnwrap(PinPlacement.resolve([anchor], in: size, exclusions: [obstacle]).first)
        XCTAssertEqual(pin.center.y, 847, accuracy: 0.01)
        XCTAssertLessThan(pin.center.x, 324)
        XCTAssertGreaterThan(pin.center.x, 320)
    }

    func testPinsReachTopAndBottomWithoutBlanketSafeAreaStrips() throws {
        let size = CGSize(width: 402, height: 874)
        let areas = SystemMapGeometry.pinExclusions(in: size, topSafeArea: 62, bottomSafeArea: 34)
        let top = PinPlacement.resolve([PinAnchor(id: 1, point: CGPoint(x: 350, y: -1000), isOffscreen: true)], in: size, exclusions: areas)
        let bottom = PinPlacement.resolve([PinAnchor(id: 1, point: CGPoint(x: 350, y: 2000), isOffscreen: true)], in: size, exclusions: areas)
        XCTAssertEqual(try XCTUnwrap(top.first).center.y, 27, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(bottom.first).center.y, 847, accuracy: 0.01)
        XCTAssertEqual(SystemMapGeometry.pinLayoutBounds(in: size, bottomClearance: 0).height, 874)
    }

    func testNinePinsAvoidNotchAttributionAndEachOtherAcrossPhoneSizes() {
        var seed: UInt64 = 0x5045524C45
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1
            return CGFloat(seed >> 32) / CGFloat(UInt32.max)
        }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let areas = SystemMapGeometry.pinExclusions(in: size, topSafeArea: size.width == 320 ? 20 : 62, bottomSafeArea: size.width == 320 ? 0 : 34)
            for scene in 0..<40 {
                let anchors = (1...9).map { id -> PinAnchor in
                    let point: CGPoint
                    if scene == 0 { point = CGPoint(x: size.width/2, y: -1000) }
                    else if scene == 1 { point = CGPoint(x: size.width/2, y: size.height+1000) }
                    else { point = CGPoint(x: (next()*5-2)*size.width, y: (next()*5-2)*size.height) }
                    return PinAnchor(id: id, point: point, isOffscreen: !CGRect(origin: .zero, size: size).contains(point))
                }
                for selected in 0...9 {
                    let selectedID: Int? = selected == 0 ? nil : selected
                    let pins = PinPlacement.resolve(anchors, in: size, selectedID: selectedID, exclusions: areas)
                    XCTAssertEqual(Set(pins.map(\.id)), Set(1...9))
                    let targets = pins.map { pin in
                        CGRect(x: pin.center.x - 24, y: pin.center.y-24,
                               width: 48, height: 48)
                    }
                    for index in targets.indices {
                        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(targets[index]), "scene \(scene), selected \(selected), target \(targets[index]), size \(size)")
                        XCTAssertTrue(areas.allSatisfy { !targets[index].intersects($0) }, "scene \(scene), selected \(selected), size \(size)")
                        for other in targets.indices where other > index {
                            XCTAssertFalse(targets[index].intersects(targets[other]))
                        }
                        for other in pins.indices where other != index {
                            let radius: CGFloat = pins[other].id == selectedID ? 23 : 18
                            XCTAssertGreaterThanOrEqual(distanceSquared(pins[other].center, from: pins[index].center, to: pins[index].anchor),
                                                        radius * radius - 0.001)
                        }
                    }
                }
            }
        }
    }
    func testStatusAndBottomGuideControlRemainClearForAllSelections() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let top: CGFloat = size.width == 320 ? 20 : 62
            let bottom: CGFloat = size.width == 320 ? 0 : 34
            let button = SystemMapGeometry.guideButtonFrame(in: size, bottomSafeArea: bottom)
            let areas = SystemMapGeometry.pinExclusions(in: size, topSafeArea: top, bottomSafeArea: bottom,
                                                       showsSystemIndicators: true, guideButton: button)
            let origin = CGPoint(x: 0, y: top)
            let usable = CGSize(width: size.width, height: size.height-top)
            for scene in 0..<20 {
                let anchors = (1...9).map { id in
                    PinAnchor(id: id,
                              point: CGPoint(x: CGFloat((id*71+scene*37) % Int(size.width*3))-size.width,
                                             y: scene % 2 == 0 ? -1000 : size.height+1000),
                              isOffscreen: true)
                }
                for selected in 0...9 {
                    let selectedID: Int? = selected == 0 ? nil : selected
                    let pins = PinPlacement.resolve(anchors, in: usable, selectedID: selectedID,
                                                    origin: origin, exclusions: areas)
                    XCTAssertEqual(pins.count, 9)
                    for pin in pins {
                        let width: CGFloat = 48
                        let target = CGRect(x: pin.center.x-width/2, y: pin.center.y-24, width: width, height: 48)
                        XCTAssertGreaterThanOrEqual(target.minY, top)
                        XCTAssertTrue(areas.allSatisfy { !target.intersects($0) })
                        for other in pins where other.id != pin.id {
                            let otherWidth: CGFloat = 48
                            let otherTarget = CGRect(x: other.center.x-otherWidth/2, y: other.center.y-24, width: otherWidth, height: 48)
                            XCTAssertFalse(target.intersects(otherTarget))
                        }
                    }
                }
            }
        }
    }

    func testGuideButtonSitsAboveHomeIndicatorInBottomCentre() {
        let frame = SystemMapGeometry.guideButtonFrame(in: CGSize(width: 402, height: 874), bottomSafeArea: 34)
        XCTAssertEqual(frame.midX, 201)
        XCTAssertEqual(frame.maxY, 828)
        XCTAssertEqual(frame.size, CGSize(width: 48, height: 48))
    }

    @MainActor
    func testFallbackAndEverySelectedTrackKeepGeographicSidesAndUncrossedStems() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956),
                     CGSize(width: 834, height: 1210), CGSize(width: 1210, height: 834),
                     CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032),
                     CGSize(width: 375, height: 1000), CGSize(width: 600, height: 700)] {
            let map = MKMapView(frame: CGRect(origin: .zero, size: size))
            map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            let bounds = CGRect(x: 0, y: 62, width: size.width, height: size.height - 62)
            let exclusions = SystemMapGeometry.pinExclusions(in: size, topSafeArea: 62, bottomSafeArea: 34,
                showsSystemIndicators: true, guideButton: SystemMapGeometry.guideButtonFrame(in: size, bottomSafeArea: 34))
            for selected in 0...9 {
                let track = AlbumTrack.all.first { $0.id == selected }
                let camera = track.map { SystemMapGeometry.centeredFocusCamera(for: $0, in: size) }
                    ?? SystemMapGeometry.startCamera(at: MapStartLocation.fallbackCoordinate)
                map.setCamera(MKMapCamera(lookingAtCenter: camera.centerCoordinate,
                    fromDistance: camera.distance, pitch: 0, heading: 0), animated: false)
                map.layoutIfNeeded()
                let anchors = AlbumTrack.all.map { track in
                    SystemMapGeometry.pinAnchor(for: track.coordinate, id: track.id,
                        projectedPoint: map.convert(track.coordinate, toPointTo: map), camera: camera, in: bounds)
                }
                let pins = PinPlacement.resolve(anchors, in: bounds.size, selectedID: track?.id,
                    origin: bounds.origin, exclusions: exclusions)
                XCTAssertEqual(Set(pins.map(\.id)), Set(1...9))
                if size.width == 402 {
                    let payload: [String: Any] = ["selected": selected, "width": size.width, "height": size.height,
                        "anchors": anchors.map { ["id": $0.id, "x": $0.point.x, "y": $0.point.y, "offscreen": $0.isOffscreen] as [String: Any] },
                        "pins": pins.map { ["id": $0.id, "x": $0.center.x, "y": $0.center.y, "ax": $0.anchor.x, "ay": $0.anchor.y] },
                        "exclusions": exclusions.map { ["x": $0.minX, "y": $0.minY, "w": $0.width, "h": $0.height] }]
                    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = "geographic-pins-\(selected)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                if selected == 0 && size.width < 500 && size.height < 1000 {
                    XCTAssertGreaterThan(try XCTUnwrap(pins.first { $0.id == 6 }).center.y, size.height * 0.85)
                    XCTAssertGreaterThan(try XCTUnwrap(pins.first { $0.id == 7 }).center.y, size.height * 0.90)
                }
                for pin in pins {
                    let target = try XCTUnwrap(anchors.first { $0.id == pin.id })
                    let context = "view \(selected), pin \(pin.id), size \(size)"
                    if target.isOffscreen {
                        let left = abs(pin.center.x - 27) < 0.1 && target.point.x < bounds.minX
                        let right = abs(pin.center.x - (bounds.maxX - 27)) < 0.1 && target.point.x > bounds.maxX
                        let top = abs(pin.center.y - (bounds.minY + 27)) < 0.1 && target.point.y < bounds.minY
                        let bottom = abs(pin.center.y - (bounds.maxY - 27)) < 0.1 && target.point.y > bounds.maxY
                        XCTAssertTrue(left || right || top || bottom, "Wrong geographic edge: \(context), \(pin.center), target \(target.point)")
                    }
                    let touch = CGRect(x: pin.center.x-24,y:pin.center.y-24,width:48,height:48)
                    XCTAssertTrue(bounds.contains(touch), context)
                    XCTAssertTrue(exclusions.allSatisfy { !touch.intersects($0) }, context)
                    for other in pins where other.id != pin.id {
                        let radius: CGFloat = other.id == selected ? 23 : 18
                        XCTAssertGreaterThanOrEqual(distanceSquared(other.center, from: pin.center, to: pin.anchor), radius*radius-0.01, context)
                    }
                    for other in pins where other.id > pin.id {
                        XCTAssertFalse(CGRect(x: pin.center.x-24,y: pin.center.y-24,width:48,height:48)
                            .intersects(CGRect(x:other.center.x-24,y:other.center.y-24,width:48,height:48)), context)
                        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
                            (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
                        }
                        let crosses = cross(pin.center,pin.anchor,other.center)*cross(pin.center,pin.anchor,other.anchor) < -0.001
                            && cross(other.center,other.anchor,pin.center)*cross(other.center,other.anchor,pin.anchor) < -0.001
                        XCTAssertFalse(crosses, "Crossed stems: \(context), other \(other.id)")
                    }
                }
            }
        }
    }

    private func distanceSquared(_ point: CGPoint, from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x-start.x, dy = end.y-start.y
        let length = dx*dx+dy*dy
        let t = length > 0 ? min(1, max(0, ((point.x-start.x)*dx+(point.y-start.y)*dy)/length)) : 0
        let x = start.x+t*dx-point.x, y = start.y+t*dy-point.y
        return x*x+y*y
    }

}
