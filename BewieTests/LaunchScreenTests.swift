import XCTest
import UIKit
import SwiftUI
@testable import Bewie

final class LaunchScreenTests: XCTestCase {
    @MainActor
    func testArtworkCoversPhoneAndTabletWithoutStretchingInEitherOrientation() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UILaunchStoryboardName") as? String, "LaunchScreen")
        let sizes: [(String, CGSize)] = [
            ("phone-tall", CGSize(width: 402, height: 874)),
            ("phone-wide", CGSize(width: 874, height: 402)),
            ("tablet-tall", CGSize(width: 1032, height: 1376)),
            ("tablet-wide", CGSize(width: 1376, height: 1032))
        ]
        for (name, size) in sizes {
            let controller = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
            let view = try XCTUnwrap(controller.view)
            view.frame = CGRect(origin: .zero, size: size)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            let artwork = try XCTUnwrap(view.subviews.compactMap { $0 as? UIImageView }.first)
            XCTAssertFalse(view.hasAmbiguousLayout, name)
            XCTAssertFalse(artwork.hasAmbiguousLayout, name)
            XCTAssertTrue(view.clipsToBounds, name)
            let image = try XCTUnwrap(artwork.image)
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertLessThan(cgImage.bytesPerRow * cgImage.height, 25_000_000,
                              "iOS rejects launch storyboards whose decoded image exceeds 25 MB")
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            // UIKit rounds solved frames to the display's physical pixel grid.
            let pixel = 1 / max(1, artwork.traitCollection.displayScale)
            XCTAssertEqual(artwork.frame.width, image.size.width * scale, accuracy: pixel, name)
            XCTAssertEqual(artwork.frame.height, image.size.height * scale, accuracy: pixel, name)
            XCTAssertEqual(artwork.frame.minX, 0, accuracy: 0.1, name)
            XCTAssertEqual(artwork.frame.maxY, size.height, accuracy: 0.1, name)
            let firstFrame = AlbumSleeveLayout.frame(in: size, progress: 0)
            XCTAssertEqual(artwork.frame.minX, firstFrame.minX, accuracy: pixel, name)
            XCTAssertEqual(artwork.frame.minY, firstFrame.minY, accuracy: pixel, name)
            XCTAssertEqual(artwork.frame.width, firstFrame.width, accuracy: pixel, name)
            XCTAssertEqual(artwork.frame.height, firstFrame.height, accuracy: pixel, name)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let render = UIGraphicsImageRenderer(size: size, format: format).image { context in
                view.layer.render(in: context.cgContext)
            }
            let attachment = XCTAttachment(image: render)
            attachment.name = "launch-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testSleeveTranslatesLeftWithoutChangingScaleAndFullyLeavesTheViewport() {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 874, height: 402),
                     CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032)] {
            let first = AlbumSleeveLayout.frame(in: size, progress: 0)
            for progress: CGFloat in [0, 1/3, 2/3, 1] {
                let frame = AlbumSleeveLayout.frame(in: size, progress: progress)
                XCTAssertEqual(frame.size, first.size)
                XCTAssertEqual(frame.minY, first.minY)
                XCTAssertEqual(frame.minX, -first.width * progress, accuracy: 0.001)
            }
            XCTAssertEqual(AlbumSleeveLayout.frame(in: size, progress: 1).maxX, 0, accuracy: 0.001)
        }
    }

    @MainActor
    func testRevealCompletesAndReducedMotionSkipsTheSlide() async throws {
        for reducedMotion in [false, true] {
            let started = ContinuousClock.now
            var presented = true
            let completed = expectation(description: "Reveal completed, reduced motion: \(reducedMotion)")
            let binding = Binding(get: { presented }, set: {
                presented = $0
                if !$0 { completed.fulfill() }
            })
            let controller = UIHostingController(rootView:
                AlbumSleeveReveal(size: CGSize(width: 402, height: 874), isPresented: binding,
                                  reduceMotion: reducedMotion, isActive: true))
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            await fulfillment(of: [completed], timeout: 6)
            XCTAssertFalse(presented)
            if !reducedMotion {
                XCTAssertGreaterThanOrEqual(started.duration(to: .now), .seconds(3.5))
            }
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
    }

    @MainActor
    func testCoverWaitsForOpeningCameraBeforeStartingItsSlide() async throws {
        var presented = true
        let completed = expectation(description: "Ready camera reveals the map")
        let binding = Binding(get: { presented }, set: {
            presented = $0
            if !$0 { completed.fulfill() }
        })
        let size = CGSize(width: 402, height: 874)
        let controller = UIHostingController(rootView:
            AlbumSleeveReveal(size: size, isPresented: binding, reduceMotion: false,
                              isActive: true, isMapReady: false))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(presented, "A delayed initial location must remain covered.")
        let readyAt = ContinuousClock.now
        controller.rootView = AlbumSleeveReveal(size: size, isPresented: binding, reduceMotion: false,
                                                isActive: true, isMapReady: true)
        await fulfillment(of: [completed], timeout: 6)
        XCTAssertFalse(presented)
        XCTAssertGreaterThanOrEqual(readyAt.duration(to: .now), .seconds(3.5))
    }
}
