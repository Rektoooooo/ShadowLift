//
//  WhatsNewManager.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 25.03.2025.
//

import Foundation

struct WhatsNewManager {
    static let lastSeenBuildKey = "lastSeenBuild"

    static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var shouldShowWhatsNew: Bool {
        let lastSeen = UserDefaults.standard.string(forKey: lastSeenBuildKey)
        return lastSeen != currentBuild
    }

    static func markAsSeen() {
        UserDefaults.standard.set(currentBuild, forKey: lastSeenBuildKey)
    }
}
