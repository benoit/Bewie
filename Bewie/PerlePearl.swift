#if os(iOS) && !targetEnvironment(macCatalyst)
import SwiftUI

struct PerlePearl: View {
    @State private var isOpening = false
    @State private var showsFailure = false

    var body: some View {
        Button {
            guard !isOpening else { return }
            isOpening = true
            Task {
                showsFailure = !(await PerleDestination.open())
                isOpening = false
            }
        } label: {
            Image("PearlPin")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isOpening)
        .accessibilityLabel(Self.label)
        .accessibilityIdentifier("perle-pearl")
        .alert(Self.label, isPresented: $showsFailure) {
            Button("OK", role: .cancel) {}
        } message: { Text("Perle could not be opened. Please try again.") }
    }

    private static var label: String {
        switch Locale.current.language.languageCode?.identifier {
        case "fr": return "Ouvrir Perle"
        case "es": return "Abrir Perle"
        case "de": return "Perle öffnen"
        case "it": return "Apri Perle"
        case "pt": return "Abrir Perle"
        case "ja": return "Perleを開く"
        default: return "Open Perle"
        }
    }
}
#endif
