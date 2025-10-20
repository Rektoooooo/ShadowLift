//
//  AppearanceManager.swift
//  Gymly
//
//  Created by Sebastián Kučera on 20.10.2025.
//

import SwiftUI
import Combine

// MARK: - Accent Color Options
public enum AccentColorOption: String, Codable, CaseIterable, Identifiable {
    case red = "Red"
    case purple = "Purple"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .red:
            return Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30 - iOS Red
        case .purple:
            return Color(red: 0.69, green: 0.32, blue: 0.87) // #AF52DE - iOS Purple
        case .blue:
            return Color(red: 0.0, green: 0.48, blue: 1.0) // #007AFF - iOS Blue
        case .green:
            return Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759 - iOS Green
        case .orange:
            return Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9500 - iOS Orange
        case .pink:
            return Color(red: 1.0, green: 0.11, blue: 0.68) // #FF1CAD - Hot Pink
        }
    }

    public var displayName: String {
        return rawValue
    }

    public var icon: String {
        switch self {
        case .red: return "flame.fill"
        case .purple: return "sparkles"
        case .blue: return "drop.fill"
        case .green: return "leaf.fill"
        case .orange: return "sun.max.fill"
        case .pink: return "heart.fill"
        }
    }
}

// MARK: - Appearance Manager
@MainActor
public class AppearanceManager: ObservableObject {
    public static let shared = AppearanceManager()

    @Published public var accentColor: AccentColorOption {
        didSet {
            saveAccentColor()
            // Note: App icon is NOT updated here automatically
            // Only updated when explicitly calling updateAccentColor()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let accentColorKey = "selectedAccentColor"

    public init() {
        // Load saved accent color or default to red
        if let savedColorRaw = userDefaults.string(forKey: accentColorKey),
           let savedColor = AccentColorOption(rawValue: savedColorRaw) {
            self.accentColor = savedColor
        } else {
            self.accentColor = .red // Default
        }

        debugPrint("🎨 AppearanceManager initialized with color: \(accentColor.rawValue)")
    }

    public func updateAccentColor(_ color: AccentColorOption) {
        withAnimation(.easeInOut(duration: 0.3)) {
            accentColor = color
        }
        debugPrint("🎨 Accent color changed to: \(color.rawValue)")

        // Update app icon to match accent color
        updateAppIcon(for: color)
    }

    public func updateAppIcon(for color: AccentColorOption) {
        let iconName: String? = {
            switch color {
            case .red: return nil // nil = default icon (AppIcon)
            case .purple: return "AppIconPurple"
            case .blue: return "AppIconBlue"
            case .green: return "AppIconGreen"
            case .orange: return "AppIconOrange"
            case .pink: return "AppIconPink"
            }
        }()

        guard UIApplication.shared.supportsAlternateIcons else {
            debugPrint("⚠️ Alternate icons not supported on this device")
            return
        }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                debugPrint("❌ Error setting app icon: \(error.localizedDescription)")
            } else {
                debugPrint("✅ App icon changed to: \(iconName ?? "default (Red)")")
            }
        }
    }

    private func saveAccentColor() {
        userDefaults.set(accentColor.rawValue, forKey: accentColorKey)
        debugPrint("🎨 Accent color saved: \(accentColor.rawValue)")
    }
}

// MARK: - Color Extension Helper
public extension Color {
    @MainActor
    static var appAccent: Color {
        AppearanceManager.shared.accentColor.color
    }
}
