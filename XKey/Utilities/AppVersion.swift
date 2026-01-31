//
//  AppVersion.swift
//  XKey
//
//  Utility to get app version from Info.plist
//

import Foundation

struct AppVersion {
    /// Get the app version from CFBundleShortVersionString in Info.plist
    static var current: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0" // Fallback
    }
    
    /// Get the build number from CFBundleVersion in Info.plist
    static var build: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "1" // Fallback
    }
    
    /// Get full version string (e.g., "1.0.0 (1)")
    static var fullVersion: String {
        return "\(current) (\(build))"
    }

    /// Git revision (commit SHA) at build time, from XKeyGitRevision in Info.plist. Nil if not set (e.g. dev build).
    static var gitRevision: String? {
        let rev = Bundle.main.infoDictionary?["XKeyGitRevision"] as? String
        return rev?.trimmingCharacters(in: .whitespaces).isEmpty == false ? rev : nil
    }

    /// Git revision for origin (sonthepham-dev/xkey) at build time, from XKeyGitRevisionOrigin. Nil if not set.
    static var gitRevisionOrigin: String? {
        let rev = Bundle.main.infoDictionary?["XKeyGitRevisionOrigin"] as? String
        return rev?.trimmingCharacters(in: .whitespaces).isEmpty == false ? rev : nil
    }

    /// Returns true if (remoteMarketing, remoteBuild) is newer than current app version
    static func isNewer(remoteMarketing: String, remoteBuild: String) -> Bool {
        let cmp = compareMarketingVersions(remoteMarketing, current)
        if cmp > 0 { return true }
        if cmp < 0 { return false }
        return compareBuilds(remoteBuild, build) > 0
    }

    /// Compare two marketing versions (e.g. "1.2.20"). Returns -1 if a < b, 0 if equal, 1 if a > b
    static func compareMarketingVersions(_ a: String, _ b: String) -> Int {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(partsA.count, partsB.count)
        for i in 0..<maxLen {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va < vb { return -1 }
            if va > vb { return 1 }
        }
        return 0
    }

    /// Compare two build strings (e.g. "20260130"). Returns -1 if a < b, 0 if equal, 1 if a > b
    static func compareBuilds(_ a: String, _ b: String) -> Int {
        let na = Int(a) ?? 0
        let nb = Int(b) ?? 0
        if na < nb { return -1 }
        if na > nb { return 1 }
        return 0
    }
}
