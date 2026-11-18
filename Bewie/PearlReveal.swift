import Foundation

enum PearlReveal {
    /// The anniversary is one local calendar day, rather than a permanent unlock.
    static func isVisible(on date: Date, calendar: Calendar = .current,
                          isInternalTestFlight: Bool = internalTestFlight) -> Bool {
        if isInternalTestFlight { return true }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let day = gregorian.dateComponents([.year, .month, .day], from: date)
        return day.year == 2026 && day.month == 11 && day.day == 30
    }

    static var internalTestFlight: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--preview-pearl")
        #elseif BEWIE_INTERNAL_PREVIEW
        // The release script makes this archive internal-only. A store build
        // has neither this compile flag nor a sandbox TestFlight receipt.
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #else
        return false
        #endif
    }
}
