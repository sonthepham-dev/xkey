//
//  PreferencesViewModel.swift
//  XKey
//
//  ViewModel for Preferences
//

import SwiftUI
import Combine

import ServiceManagement

class PreferencesViewModel: ObservableObject {
    @Published var preferences: Preferences

    init() {
        // Load from SharedSettings (App Group UserDefaults)
        self.preferences = SharedSettings.shared.loadPreferences()
    }

    func save() {
        // Save to SharedSettings (App Group UserDefaults)
        SharedSettings.shared.savePreferences(preferences)

        // Apply launch at login setting
        setLaunchAtLogin(preferences.startAtLogin)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            SMLoginItemSetEnabled("group.com.codetay.inputmethod.XKey.debug" as CFString, enabled)
        }
    }
}
