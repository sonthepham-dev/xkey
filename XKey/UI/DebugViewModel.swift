//
//  DebugViewModel.swift
//  XKey
//
//  ViewModel for Debug Window - Optimized with file-based log reading
//  Logs are written directly to file, Debug Window reads from file periodically
//

import SwiftUI
import Combine

class DebugViewModel: ObservableObject {
    @Published var statusText = "Status: Initializing..."
    @Published var logLines: [String] = []  // Changed from logText to array for better performance
    @Published var isLoggingEnabled = true
    @Published var isVerboseLogging = false {
        didSet {
            verboseLoggingCallback?(isVerboseLogging)
        }
    }
    @Published var inputText = ""
    @Published var isAlwaysOnTop = true {
        didSet {
            alwaysOnTopCallback?(isAlwaysOnTop)
        }
    }
    
    // MARK: - File-Based Logging Properties
    
    /// Log file URL
    let logFileURL: URL
    
    /// Log file reader for incremental reads
    private let logReader: LogFileReader
    
    /// Background queue for file writes (fire-and-forget)
    private let writeQueue = DispatchQueue(label: "com.xkey.debuglog.write", qos: .utility)
    
    /// Timer for reading new log entries from file
    private var readTimer: Timer?
    
    /// Read interval - how often to check for new logs (500ms is a good balance)
    private let readInterval: TimeInterval = 0.5
    
    /// Maximum lines to keep in memory
    private let maxDisplayLines = 1000
    
    /// Lock for file write operations
    private let writeLock = NSLock()
    
    /// Track if window is visible (skip reading when hidden)
    @Published var isWindowVisible = true
    
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var readWordCallback: (() -> Void)?
    var alwaysOnTopCallback: ((Bool) -> Void)?
    var verboseLoggingCallback: ((Bool) -> Void)?
    
    // MARK: - Computed Properties
    
    /// Combined log text for display (computed from lines)
    var logText: String {
        logLines.joined(separator: "\n")
    }
    
    // MARK: - Initialization
    
    init() {
        // Create log file in user's home directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        logFileURL = homeDirectory.appendingPathComponent("XKey_Debug.log")
        
        // Initialize log reader
        logReader = LogFileReader(fileURL: logFileURL, maxLines: maxDisplayLines)

        // Initialize log file with timestamp header
        initializeLogFile()
        
        // Load existing log content
        loadExistingLogs()
        
        // Start the periodic log reader
        startReadTimer()
        
        // Listen for debug logs from XKeyIM
        setupIMKitDebugListener()
    }
    
    deinit {
        readTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    // MARK: - Log File Initialization
    
    private func initializeLogFile() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let header = "=== XKey Debug Log ===\nStarted: \(timestamp)\nLog file: \(logFileURL.path)\n\n"
        
        // Create/overwrite file with header
        try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
        
        writeToFileAsync("Debug window initialized")
        writeToFileAsync("Using file-based logging for better performance")
    }
    
    private func loadExistingLogs() {
        logReader.readAllLines { [weak self] lines in
            self?.logLines = lines
        }
    }
    
    // MARK: - Fire-and-Forget Logging (Write Only)
    
    /// Add a log event - writes directly to file, no UI blocking
    func logEvent(_ event: String) {
        guard isLoggingEnabled else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(event)"
        
        // Write to file asynchronously (fire-and-forget)
        writeToFileAsync(logLine)
    }
    
    /// Write to file asynchronously (non-blocking)
    private func writeToFileAsync(_ text: String) {
        writeQueue.async { [weak self] in
            self?.writeToFileSync(text + "\n")
        }
    }
    
    /// Write to file synchronously (called from background queue)
    private func writeToFileSync(_ text: String) {
        writeLock.lock()
        defer { writeLock.unlock() }
        
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            handle.seekToEndOfFile()
            handle.write(data)
            try handle.close()
        } catch {
            // Ignore write errors to avoid blocking
        }
    }
    
    // MARK: - Periodic Log Reading (Read from File)
    
    /// Start timer for periodic log file reading
    private func startReadTimer() {
        readTimer = Timer.scheduledTimer(withTimeInterval: readInterval, repeats: true) { [weak self] _ in
            self?.readNewLogs()
        }
    }
    
    /// Read new log entries from file
    private func readNewLogs() {
        // Skip reading if window is not visible or logging is disabled
        guard isWindowVisible && isLoggingEnabled else { return }
        
        logReader.readNewLines { [weak self] newLines in
            guard let self = self, !newLines.isEmpty else { return }
            
            // Append new lines
            self.logLines.append(contentsOf: newLines)
            
            // Trim to max lines
            if self.logLines.count > self.maxDisplayLines {
                let excess = self.logLines.count - self.maxDisplayLines
                self.logLines.removeFirst(excess)
            }
        }
    }
    
    // MARK: - IMKit Debug Listener
    
    private func setupIMKitDebugListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("XKey.debugLog"),
            object: nil,
            queue: nil // Use caller's queue, we handle threading ourselves
        ) { [weak self] notification in
            // Try to get message from object first (for InputSourceSwitcher)
            if let message = notification.object as? String {
                self?.logEvent(message)
                return
            }

            // Fallback to userInfo for XKeyIM messages with source
            guard let userInfo = notification.userInfo,
                  let message = userInfo["message"] as? String,
                  let source = userInfo["source"] as? String else {
                return
            }

            self?.logEvent("[\(source)] \(message)")
        }
    }
    
    // MARK: - Public Methods
    
    func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.statusText = "Status: \(status)"
        }
        logEvent("STATUS: \(status)")
    }
    
    func logKeyEvent(character: Character, keyCode: UInt16, result: String) {
        logEvent("KEY: '\(character)' (code: \(keyCode)) → \(result)")
    }
    
    func logEngineResult(input: String, output: String, backspaces: Int) {
        logEvent("ENGINE: '\(input)' → '\(output)' (bs: \(backspaces))")
    }
    
    func copyLogs() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
        
        updateStatus("Logs copied to clipboard!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateStatus("Ready")
        }
    }
    
    func clearLogs() {
        // Clear in-memory logs
        logLines.removeAll()
        
        // Reset log reader
        logReader.reset()
        
        // Reinitialize log file
        initializeLogFile()
        
        updateStatus("Logs cleared")
    }
    
    func toggleLogging() {
        if isLoggingEnabled {
            updateStatus("Logging enabled")
            logEvent("=== Logging Enabled ===")
        } else {
            updateStatus("Logging disabled")
        }
    }
    
    func readWordBeforeCursor() {
        logEvent("=== Read Word Before Cursor ===")
        readWordCallback?()
    }
    
    func openLogFile() {
        // Reveal log file in Finder
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
        logEvent("Opened log file in Finder")
    }
    
    // MARK: - Window Visibility
    
    func windowDidBecomeVisible() {
        isWindowVisible = true
        // Force read when window becomes visible
        readNewLogs()
    }
    
    func windowDidBecomeHidden() {
        isWindowVisible = false
    }
}
