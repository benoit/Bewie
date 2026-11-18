import SwiftUI
import UIKit

/// Native TV focus item with Bewie's unmodified circle/progress/dot artwork.
struct TVPinButton: UIViewRepresentable {
    let id: Int
    let scale: CGFloat
    let selected: Bool
    let playing: Bool
    let progress: Double
    let wantsFocus: Bool
    let label: String
    let value: String
    let onFocus: () -> Void
    let onSelect: () -> Void

    func makeUIView(context: Context) -> PinButton {
        let button = PinButton(type: .custom)
        button.addAction(UIAction { _ in context.coordinator.select() }, for: .primaryActionTriggered)
        button.focusChanged = { context.coordinator.focus() }
        return button
    }

    func updateUIView(_ button: PinButton, context: Context) {
        context.coordinator.select = onSelect
        context.coordinator.focus = onFocus
        button.scale = scale
        button.number.text = String(id)
        button.number.font = UIFont(name: "HelveticaNeue-Medium", size: 17 * scale)
        button.playing = playing
        button.selectedTrack = selected
        button.progress = progress
        button.accessibilityLabel = label
        button.accessibilityValue = value
        button.accessibilityIdentifier = "track-pin-\(id)"
        button.setNeedsLayout()
        if wantsFocus && !button.isFocused {
            DispatchQueue.main.async { [weak button] in
                guard let button, button.window != nil, !button.isFocused,
                      let system = UIFocusSystem.focusSystem(for: button) else { return }
                system.requestFocusUpdate(to: button)
                system.updateFocusIfNeeded()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var select: () -> Void = { }
        var focus: () -> Void = { }
    }

    final class PinButton: UIButton {
        let head = CAShapeLayer()
        let ring = CAShapeLayer()
        let dot = CAShapeLayer()
        let number = UILabel()
        var scale: CGFloat = 1
        var playing = false
        var selectedTrack = false
        var progress: Double = 0
        var focusChanged: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(ring)
            layer.addSublayer(head)
            addSubview(number)
            layer.addSublayer(dot)
            number.textAlignment = .center
            number.textColor = UIColor(BewiePalette.ink)
            isAccessibilityElement = true
            accessibilityTraits = .button
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var canBecomeFocused: Bool { isEnabled && isUserInteractionEnabled && !isHidden }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let centre = CGPoint(x: bounds.midX, y: bounds.midY)
            let focusScale: CGFloat = isFocused ? 1.12 : 1
            let radius = 17 * scale * focusScale
            head.path = UIBezierPath(ovalIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)).cgPath
            head.fillColor = UIColor(BewiePalette.orange).cgColor
            head.shadowColor = UIColor.black.cgColor
            head.shadowOpacity = 0.12
            head.shadowRadius = 3 * scale
            head.shadowOffset = CGSize(width: 0, height: 2 * scale)
            ring.path = UIBezierPath(arcCenter: centre, radius: 21.25 * scale, startAngle: -.pi / 2, endAngle: 3 * .pi / 2, clockwise: true).cgPath
            ring.strokeColor = UIColor(BewiePalette.orange).withAlphaComponent(0.75).cgColor
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = 1.5 * scale
            ring.strokeEnd = selectedTrack ? min(1, max(0, progress)) : 0
            number.frame = bounds
            number.transform = CGAffineTransform(scaleX: focusScale, y: focusScale)
            let diameter = 3 * scale
            dot.path = UIBezierPath(ovalIn: CGRect(x: centre.x - diameter / 2, y: centre.y + 12 * scale - diameter / 2, width: diameter, height: diameter)).cgPath
            dot.fillColor = UIColor(BewiePalette.ink).cgColor
            dot.isHidden = !playing
            CATransaction.commit()
        }

        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)
            setNeedsLayout()
            if isFocused { focusChanged?() }
        }
    }
}
