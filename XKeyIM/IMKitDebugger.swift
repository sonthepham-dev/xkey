//
//  IMKitDebugger.swift
//  XKeyIM
//
//  Helper for sending debug logs to XKey app's debug window
//  Writes to shared log file that Debug Window reads periodically
//

import Foundation

/// Singleton debugger for IMKit logging
class IMKitDebugger {
    static let shared = IMKitDebugger()

    /// Shared log file URL (same as DebugViewModel uses)
    private let logFileURL: URL

    /// Background queue for async file writing
    private let logQueue = DispatchQueue(label: "com.xkeyim.logger", qos: .utility)

    /// Lock for thread-safe file writes
    private let writeLock = NSLock()

    private init() {
        // Use same log file as XKey's DebugViewModel
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        logFileURL = homeDirectory.appendingPathComponent("XKey_Debug.log")
    }

    /// Log a message to XKey app's debug window
    func log(_ message: String) {
        let formattedMessage = "[XKeyIM] \(message)"

        // Write to shared log file (fire-and-forget)
        // Debug Window reads this file every 0.5s
        writeToFile(formattedMessage)
    }

    /// Log with category
    func log(_ message: String, category: String) {
        log("[\(category)] \(message)")
    }

    /// Write to log file asynchronously (fire-and-forget)
    private func writeToFile(_ text: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            self.writeLock.lock()
            defer { self.writeLock.unlock() }

            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let line = "[\(timestamp)] \(text)\n"

            guard let data = line.data(using: .utf8) else { return }

            // Create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
                FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil)
            }

            do {
                let handle = try FileHandle(forWritingTo: self.logFileURL)
                handle.seekToEndOfFile()
                handle.write(data)
                try handle.close()
            } catch {
                // Ignore write errors - fire and forget
            }
        }
    }
}
