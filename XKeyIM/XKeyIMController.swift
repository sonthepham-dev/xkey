//
//  XKeyIMController.swift
//  XKeyIM
//
//  IMKit Input Controller for Vietnamese typing
//  Provides native text composition without flickering
//

import Cocoa
import InputMethodKit

/// IMKit-based Vietnamese input controller
/// This is the main class that handles keyboard input for the Input Method
@objc(XKeyIMController)
class XKeyIMController: IMKInputController {
    
    // MARK: - Properties
    
    /// Vietnamese processing engine
    private var engine: VNEngine!
    
    /// Current composing text
    private var composingText: String = ""
    
    /// Settings from shared App Group
    private var settings: XKeyIMSettings!
    
    /// Whether currently in Vietnamese mode
    private var isVietnameseEnabled: Bool = true
    
    // MARK: - Initialization
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)

        // Initialize engine
        engine = VNEngine()

        // Load settings
        settings = XKeyIMSettings()
        applySettings()

        // Listen for settings changes from XKey app
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: Notification.Name("XKey.settingsDidChange"),
            object: nil
        )

        NSLog("XKeyIMController: Initialized")
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// Handle settings changed notification from XKey app
    @objc private func handleSettingsChanged(_ notification: Notification) {
        NSLog("XKeyIMController: Settings changed, reloading...")
        reloadSettings()
    }
    
    // MARK: - Settings
    
    private func applySettings() {
        var engineSettings = VNEngine.EngineSettings()
        engineSettings.inputMethod = settings.inputMethod
        engineSettings.codeTable = settings.codeTable
        engineSettings.modernStyle = settings.modernStyle
        engineSettings.spellCheckEnabled = settings.spellCheckEnabled
        engineSettings.quickTelexEnabled = settings.quickTelexEnabled
        engineSettings.freeMarking = settings.freeMarkEnabled
        engineSettings.restoreIfWrongSpelling = settings.restoreIfWrongSpelling
        engine.updateSettings(engineSettings)
    }
    
    /// Reload settings (called when settings change)
    private func reloadSettings() {
        settings.reload()
        applySettings()
    }
    
    // MARK: - IMKInputController Overrides
    
    /// Handle keyboard events
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else {
            return false
        }
        
        guard let client = sender as? IMKTextInput else {
            return false
        }
        
        // Get character info
        guard let characters = event.characters,
              let character = characters.first else {
            return false
        }
        
        let keyCode = UInt16(event.keyCode)
        let isUppercase = character.isUppercase
        
        // Handle modifier keys
        if event.modifierFlags.contains(.command) {
            // Cmd+key: pass through
            commitComposition(client)
            return false
        }
        
        // Handle special keys
        switch event.keyCode {
        case 0x33: // Backspace
            return handleBackspace(client: client)
            
        case 0x24, 0x4C: // Return, Enter
            commitComposition(client)
            engine.reset()
            return false
            
        case 0x30: // Tab
            commitComposition(client)
            engine.reset()
            return false
            
        case 0x35: // Escape
            cancelComposition(client)
            return true
            
        case 0x31: // Space
            // Process space as word break
            let result = engine.processWordBreak(character: " ")
            if result.shouldConsume {
                handleResult(result, client: client)
            }
            commitComposition(client)
            engine.reset()
            return false // Let space pass through
            
        default:
            break
        }
        
        // Skip non-printable characters
        guard character.isLetter || character.isNumber || character.isPunctuation else {
            return false
        }
        
        // Check if Vietnamese is enabled
        guard isVietnameseEnabled else {
            return false
        }
        
        // Process through Vietnamese engine
        let result = engine.processKey(
            character: character,
            keyCode: keyCode,
            isUppercase: isUppercase
        )
        
        if result.shouldConsume {
            handleResult(result, client: client)
            return true
        }
        
        return false
    }
    
    /// Handle engine result
    private func handleResult(_ result: VNEngine.ProcessResult, client: IMKTextInput) {
        // Build new text
        let newText = result.newCharacters.map {
            $0.unicode(codeTable: settings.codeTable)
        }.joined()
        
        if settings.useMarkedText {
            // Use marked text (with underline)
            setMarkedText(newText, client: client)
        } else {
            // Direct replacement (no underline) - PREFERRED
            replaceText(
                newText: newText,
                deleteCount: result.backspaceCount,
                client: client
            )
        }
    }
    
    /// Replace text atomically (no flickering)
    private func replaceText(newText: String, deleteCount: Int, client: IMKTextInput) {
        // IMPORTANT: Clear any existing marked text first to prevent underline
        // When useMarkedText is false, we should not have any marked text showing
        if !composingText.isEmpty {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        }

        let selectedRange = client.selectedRange()

        if deleteCount > 0 && selectedRange.location >= deleteCount {
            // Calculate replacement range
            let replaceRange = NSRange(
                location: selectedRange.location - deleteCount,
                length: deleteCount
            )

            // Atomic replacement - insert as committed text (no underline)
            client.insertText(newText, replacementRange: replaceRange)
        } else {
            // Just insert as committed text (no underline)
            client.insertText(
                newText,
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        }

        // Reset composingText since text is now committed (not composing)
        composingText = ""
    }
    
    /// Set marked text (with underline)
    private func setMarkedText(_ text: String, client: IMKTextInput) {
        composingText = text
        
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: text.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
    }
    
    /// Handle backspace
    private func handleBackspace(client: IMKTextInput) -> Bool {
        let result = engine.processBackspace()
        
        if result.shouldConsume {
            handleResult(result, client: client)
            return true
        }
        
        // If engine doesn't handle, let it pass through
        return false
    }
    
    /// Commit current composition
    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        
        if !composingText.isEmpty {
            // If using marked text, commit it
            if settings.useMarkedText {
                client.insertText(
                    composingText,
                    replacementRange: NSRange(location: NSNotFound, length: 0)
                )
            }
            composingText = ""
        }
    }
    
    /// Cancel composition
    private func cancelComposition(_ client: IMKTextInput) {
        if settings.useMarkedText && !composingText.isEmpty {
            // Clear marked text
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
        }
        composingText = ""
        engine.reset()
    }
    
    /// Called when input method is activated
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        reloadSettings()
        engine.reset()
        composingText = ""
        NSLog("XKeyIMController: Activated")
    }
    
    /// Called when input method is deactivated
    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
        NSLog("XKeyIMController: Deactivated")
    }
    
    /// Return candidates (not used)
    override func candidates(_ sender: Any!) -> [Any]! {
        return nil
    }
    
    // MARK: - Menu
    
    /// Input method menu
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        
        // Vietnamese toggle
        let vnItem = NSMenuItem(
            title: isVietnameseEnabled ? "✓ Tiếng Việt" : "Tiếng Việt",
            action: #selector(toggleVietnamese),
            keyEquivalent: ""
        )
        vnItem.target = self
        menu.addItem(vnItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open XKey settings
        let settingsItem = NSMenuItem(
            title: "Mở XKey Settings...",
            action: #selector(openXKeySettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        return menu
    }
    
    @objc private func toggleVietnamese() {
        isVietnameseEnabled.toggle()
        engine.reset()
        composingText = ""
        NSLog("XKeyIMController: Vietnamese = \(isVietnameseEnabled)")
    }
    
    @objc private func openXKeySettings() {
        // Open main XKey app
        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.codetay.XKey",
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
    }
}

// MARK: - Settings Helper

/// Settings wrapper for XKeyIM
class XKeyIMSettings {
    
    private let defaults: UserDefaults?
    
    var inputMethod: InputMethod = .telex
    var codeTable: CodeTable = .unicode
    var modernStyle: Bool = true
    var spellCheckEnabled: Bool = true
    var quickTelexEnabled: Bool = true
    var freeMarkEnabled: Bool = false
    var restoreIfWrongSpelling: Bool = true
    var useMarkedText: Bool = false
    
    init() {
        // Try App Group first - must match the App Group in entitlements
        defaults = UserDefaults(suiteName: "group.com.codetay.inputmethod.XKey")
        reload()
    }
    
    func reload() {
        guard let defaults = defaults else { return }
        
        if let method = InputMethod(rawValue: defaults.integer(forKey: "XKey.inputMethod")) {
            inputMethod = method
        }
        
        if let table = CodeTable(rawValue: defaults.integer(forKey: "XKey.codeTable")) {
            codeTable = table
        }
        
        modernStyle = defaults.bool(forKey: "XKey.modernStyle")
        spellCheckEnabled = defaults.bool(forKey: "XKey.spellCheckEnabled")
        quickTelexEnabled = defaults.bool(forKey: "XKey.quickTelexEnabled")
        freeMarkEnabled = defaults.bool(forKey: "XKey.freeMarkEnabled")
        restoreIfWrongSpelling = defaults.bool(forKey: "XKey.restoreIfWrongSpelling")
        useMarkedText = defaults.bool(forKey: "XKey.imkitUseMarkedText")
    }
}
