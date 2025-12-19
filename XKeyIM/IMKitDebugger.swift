//
//  IMKitDebugger.swift
//  XKeyIM
//
//  Helper for sending debug logs to XKey app's debug window
//

import Foundation
import os.log

/// Singleton debugger for IMKit logging
class IMKitDebugger {
    static let shared = IMKitDebugger()

    private let notificationCenter = DistributedNotificationCenter.default()
    private let debugNotification = Notification.Name("XKey.debugLog")
    private let osLog = OSLog(subsystem: "com.codetay.XKeyIM", category: "Debug")

    private init() {}

    /// Log a message to XKey app's debug window
    func log(_ message: String) {
        let userInfo: [String: Any] = [
            "message": message,
            "source": "XKeyIM",
            "timestamp": Date().timeIntervalSince1970
        ]

        // Post on main thread to ensure delivery
        DispatchQueue.main.async {
            self.notificationCenter.post(
                name: self.debugNotification,
                object: nil,
                userInfo: userInfo
            )
        }

        // Use print() instead of NSLog/os_log to avoid privacy redaction
        // print() outputs to stderr and is not subject to macOS privacy filtering
        print("[XKeyIM] \(message)")
    }

    /// Log with category
    func log(_ message: String, category: String) {
        log("[\(category)] \(message)")
    }
}
