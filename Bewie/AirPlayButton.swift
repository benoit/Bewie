import AVKit
import SwiftUI

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor(BewiePalette.ink)
        view.activeTintColor = UIColor(BewiePalette.orange)
        view.prioritizesVideoDevices = false
        view.accessibilityLabel = PublicText.airPlayOutput.text
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
