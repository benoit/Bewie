// Keep rectangular platform icons in sync with the active album-art icon.
import Foundation
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
process.arguments = [root.appendingPathComponent("tools/generate-album-icons.swift").path]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
