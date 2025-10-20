//
//  FloatingClouds.swift
//  Gymly
//
//  Created by Sebastián Kučera on 10.09.2025.
//

import SwiftUI
import CoreFoundation
import Combine

struct CloudsTheme {
    var background: Color
    var topLeading: Color
    var topTrailing: Color
    var bottomLeading: Color
    var bottomTrailing: Color

    // MARK: Presets (light/dark aware where useful)
    static func red(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: Color(red: 0.40, green: 0.00, blue: 0.00),
            topLeading: scheme == .dark ? Color(red: 0.50, green: 0.00, blue: 0.00, opacity: 0.8)
                                        : Color(red: 0.80, green: 0.20, blue: 0.20, opacity: 0.8),
            topTrailing: scheme == .dark ? Color(red: 0.70, green: 0.20, blue: 0.20, opacity: 0.6)
                                         : Color(red: 0.90, green: 0.40, blue: 0.30, opacity: 0.5),
            bottomLeading: scheme == .dark ? Color(red: 0.70, green: 0.20, blue: 0.20, opacity: 0.45)
                                           : Color(red: 0.90, green: 0.30, blue: 0.30, opacity: 0.55),
            bottomTrailing: Color(red: 0.90, green: 0.50, blue: 0.50, opacity: 0.7)
        )
    }

    // Dynamic accent color theme (replaces red theme based on user selection)
    static func accent(_ scheme: ColorScheme, accentColor: AccentColorOption) -> CloudsTheme {
        switch accentColor {
        case .red:
            return red(scheme)
        case .purple:
            return purple(scheme)
        case .blue:
            return blueAccent(scheme)
        case .green:
            return green(scheme)
        case .orange:
            return orange(scheme)
        case .pink:
            return pink(scheme)
        }
    }

    static func purple(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: Color(red: 0.25, green: 0.00, blue: 0.35),
            topLeading: scheme == .dark ? Color(red: 0.40, green: 0.15, blue: 0.55, opacity: 0.8)
                                        : Color(red: 0.60, green: 0.30, blue: 0.75, opacity: 0.8),
            topTrailing: scheme == .dark ? Color(red: 0.55, green: 0.25, blue: 0.70, opacity: 0.6)
                                         : Color(red: 0.70, green: 0.40, blue: 0.85, opacity: 0.5),
            bottomLeading: scheme == .dark ? Color(red: 0.50, green: 0.20, blue: 0.65, opacity: 0.45)
                                           : Color(red: 0.65, green: 0.35, blue: 0.80, opacity: 0.55),
            bottomTrailing: Color(red: 0.75, green: 0.50, blue: 0.90, opacity: 0.7)
        )
    }

    static func blueAccent(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: Color(red: 0.00, green: 0.15, blue: 0.40),
            topLeading: scheme == .dark ? Color(red: 0.00, green: 0.30, blue: 0.60, opacity: 0.8)
                                        : Color(red: 0.20, green: 0.45, blue: 0.80, opacity: 0.8),
            topTrailing: scheme == .dark ? Color(red: 0.10, green: 0.40, blue: 0.75, opacity: 0.6)
                                         : Color(red: 0.30, green: 0.55, blue: 0.90, opacity: 0.5),
            bottomLeading: scheme == .dark ? Color(red: 0.05, green: 0.35, blue: 0.70, opacity: 0.45)
                                           : Color(red: 0.25, green: 0.50, blue: 0.85, opacity: 0.55),
            bottomTrailing: Color(red: 0.40, green: 0.65, blue: 1.00, opacity: 0.7)
        )
    }

    static func pink(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: Color(red: 0.40, green: 0.00, blue: 0.30),
            topLeading: scheme == .dark ? Color(red: 0.60, green: 0.05, blue: 0.45, opacity: 0.8)
                                        : Color(red: 0.90, green: 0.20, blue: 0.70, opacity: 0.8),
            topTrailing: scheme == .dark ? Color(red: 0.75, green: 0.10, blue: 0.55, opacity: 0.6)
                                         : Color(red: 1.00, green: 0.30, blue: 0.75, opacity: 0.5),
            bottomLeading: scheme == .dark ? Color(red: 0.70, green: 0.08, blue: 0.50, opacity: 0.45)
                                           : Color(red: 0.95, green: 0.25, blue: 0.65, opacity: 0.55),
            bottomTrailing: Color(red: 1.00, green: 0.40, blue: 0.80, opacity: 0.7)
        )
    }
    
    static func green(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: Color(red: 0.0, green: 0.35, blue: 0.0),
            topLeading: scheme == .dark
                ? Color(red: 0.0, green: 0.45, blue: 0.0, opacity: 0.8)
                : Color(red: 0.2, green: 0.7, blue: 0.2, opacity: 0.8),
            topTrailing: scheme == .dark
                ? Color(red: 0.0, green: 0.5, blue: 0.0, opacity: 0.6)
                : Color(red: 0.3, green: 0.9, blue: 0.3, opacity: 0.5),
            bottomLeading: scheme == .dark
                ? Color(red: 0.0, green: 0.6, blue: 0.0, opacity: 0.45)
                : Color(red: 0.4, green: 0.9, blue: 0.4, opacity: 0.55),
            bottomTrailing: Color(red: 0.5, green: 1.0, blue: 0.5, opacity: 0.7)
        )
    }
    
    static func appleIntelligence(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            // Inky base with an indigo tint (dark) / airy off-white with lavender cast (light)
            background: scheme == .dark
                ? Color(red: 0.05, green: 0.06, blue: 0.10)                 // near-black indigo
                : Color(red: 0.97, green: 0.97, blue: 1.00),                // soft cool white

            // Luminous electric blue/cyan up top-left
            topLeading: scheme == .dark
                ? Color(red: 0.20, green: 0.60, blue: 1.00, opacity: 0.85)  // electric blue glow
                : Color(red: 0.40, green: 0.70, blue: 1.00, opacity: 0.70),

            // Violet/magenta bloom top-right
            topTrailing: scheme == .dark
                ? Color(red: 0.75, green: 0.40, blue: 1.00, opacity: 0.75)  // vibrant violet
                : Color(red: 0.85, green: 0.55, blue: 1.00, opacity: 0.65),

            // Pink warmth bottom-left to balance the cool tones
            bottomLeading: scheme == .dark
                ? Color(red: 1.00, green: 0.45, blue: 0.70, opacity: 0.65)  // rosy glow
                : Color(red: 1.00, green: 0.55, blue: 0.80, opacity: 0.60),

            // Mint/cyan shimmer bottom-right for that “intelligent” sparkle
            bottomTrailing: scheme == .dark
                ? Color(red: 0.30, green: 1.00, blue: 0.95, opacity: 0.78)  // cool mint
                : Color(red: 0.45, green: 1.00, blue: 0.95, opacity: 0.70)
        )
    }
    
    static func orange(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: Color(red: 0.45, green: 0.25, blue: 0.0),
            topLeading: scheme == .dark
                ? Color(red: 0.55, green: 0.3, blue: 0.0, opacity: 0.8)
                : Color(red: 0.9, green: 0.5, blue: 0.2, opacity: 0.8),
            topTrailing: scheme == .dark
                ? Color(red: 0.65, green: 0.35, blue: 0.0, opacity: 0.6)
                : Color(red: 1.0, green: 0.6, blue: 0.2, opacity: 0.5),
            bottomLeading: scheme == .dark
                ? Color(red: 0.7, green: 0.4, blue: 0.0, opacity: 0.45)
                : Color(red: 1.0, green: 0.55, blue: 0.15, opacity: 0.55),
            bottomTrailing: Color(red: 1.0, green: 0.65, blue: 0.3, opacity: 0.7)
        )
    }

    static func black(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: scheme == .dark ? Color.black : Color(red: 0.05, green: 0.05, blue: 0.06),
            topLeading: Color(red: 0.20, green: 0.20, blue: 0.22, opacity: 0.75),
            topTrailing: Color(red: 0.25, green: 0.25, blue: 0.28, opacity: 0.5),
            bottomLeading: Color(red: 0.18, green: 0.18, blue: 0.20, opacity: 0.55),
            bottomTrailing: Color(red: 0.30, green: 0.30, blue: 0.33, opacity: 0.65)
        )
    }
    
    static func graphite(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            background: scheme == .dark ? Color.black : Color(red: 0.07, green: 0.07, blue: 0.08),
            topLeading: Color(red: 0.25, green: 0.25, blue: 0.28, opacity: 0.75),
            topTrailing: Color(red: 0.35, green: 0.35, blue: 0.38, opacity: 0.5),
            bottomLeading: Color(red: 0.20, green: 0.20, blue: 0.22, opacity: 0.55),
            bottomTrailing: Color(red: 0.40, green: 0.40, blue: 0.43, opacity: 0.65)
        )
    }

    static func blue(_ scheme: ColorScheme) -> CloudsTheme { // original-ish
        CloudsTheme(
            background: Color(red: 0.043, green: 0.467, blue: 0.494),
            topLeading: scheme == .dark ? Color(red: 0.000, green: 0.176, blue: 0.216, opacity: 0.8)
                                        : Color(red: 0.039, green: 0.388, blue: 0.502, opacity: 0.81),
            topTrailing: scheme == .dark ? Color(red: 0.408, green: 0.698, blue: 0.420, opacity: 0.61)
                                         : Color(red: 0.196, green: 0.796, blue: 0.329, opacity: 0.5),
            bottomLeading: scheme == .dark ? Color(red: 0.525, green: 0.859, blue: 0.655, opacity: 0.45)
                                           : Color(red: 0.196, green: 0.749, blue: 0.486, opacity: 0.55),
            bottomTrailing: Color(red: 0.541, green: 0.733, blue: 0.812, opacity: 0.7)
        )
    }

    static func iCloud(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            // Deep black background like iCloud interface
            background: Color(red: 0.0, green: 0.0, blue: 0.0),

            // Bright electric blue (iCloud brand color) - top left
            topLeading: Color(red: 0.0, green: 0.48, blue: 1.0, opacity: 0.85),

            // Lighter sky blue - top right
            topTrailing: Color(red: 0.2, green: 0.6, blue: 1.0, opacity: 0.7),

            // Deep blue with slight cyan tint - bottom left
            bottomLeading: Color(red: 0.0, green: 0.3, blue: 0.7, opacity: 0.6),

            // Bright cyan/light blue - bottom right
            bottomTrailing: Color(red: 0.3, green: 0.7, blue: 1.0, opacity: 0.75)
        )
    }

    static func premium(_ scheme: ColorScheme) -> CloudsTheme {
        CloudsTheme(
            // Deep indigo/purple-black background for sophisticated luxury
            background: scheme == .dark
                ? Color(red: 0.05, green: 0.03, blue: 0.10)              // Deep indigo black
                : Color(red: 0.08, green: 0.06, blue: 0.12),             // Dark purple charcoal

            // Royal purple shimmer - top left
            topLeading: scheme == .dark
                ? Color(red: 0.45, green: 0.20, blue: 0.75, opacity: 0.80)  // Royal purple
                : Color(red: 0.50, green: 0.25, blue: 0.70, opacity: 0.70),

            // Deep violet glow - top right
            topTrailing: scheme == .dark
                ? Color(red: 0.60, green: 0.30, blue: 0.85, opacity: 0.70)  // Deep violet
                : Color(red: 0.55, green: 0.30, blue: 0.75, opacity: 0.60),

            // Rich plum warmth - bottom left
            bottomLeading: scheme == .dark
                ? Color(red: 0.35, green: 0.15, blue: 0.55, opacity: 0.65)  // Rich plum
                : Color(red: 0.40, green: 0.20, blue: 0.55, opacity: 0.55),

            // Lavender/light purple - bottom right
            bottomTrailing: scheme == .dark
                ? Color(red: 0.65, green: 0.45, blue: 0.90, opacity: 0.75)  // Lavender purple
                : Color(red: 0.60, green: 0.40, blue: 0.80, opacity: 0.65)
        )
    }
}
    
class CloudProvider: ObservableObject {
    let offset: CGSize
    let frameHeightRatio: CGFloat
    
    init() {
        frameHeightRatio = CGFloat.random(in: 0.7 ..< 1.4)
        offset = CGSize(width: CGFloat.random(in: -150 ..< 150),
                        height: CGFloat.random(in: -150 ..< 150))
    }
}
    
struct Cloud: View {
    @StateObject var provider = CloudProvider()
    let proxy: GeometryProxy
    let color: Color
    let rotationStart: Double
    let duration: Double
    let alignment: Alignment

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let progress = (t.truncatingRemainder(dividingBy: duration)) / duration
            let angle = rotationStart + progress * 360

            Circle()
                .fill(color)
                .frame(height: proxy.size.height / provider.frameHeightRatio)
                .offset(provider.offset)
                .rotationEffect(.degrees(angle))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .opacity(0.8)
        }
    }
}
    
struct FloatingClouds: View {
    @Environment(\.colorScheme) var scheme
    
    var theme: CloudsTheme?
    let blur: CGFloat

    init(theme: CloudsTheme? = nil, blur: CGFloat = 60) {
        // Defer scheme-based default to runtime via a placeholder; will be overridden in body
        self.theme = theme
        self.blur = blur
    }
    
    var body: some View {
        let t = theme ?? CloudsTheme.red(scheme)
        
        GeometryReader { proxy in
            ZStack {
                t.background
                Cloud(proxy: proxy,
                      color: t.bottomTrailing,
                      rotationStart: 0,
                      duration: 60,
                      alignment: .bottomTrailing)
                Cloud(proxy: proxy,
                      color: t.topTrailing,
                      rotationStart: 240,
                      duration: 50,
                      alignment: .topTrailing)
                Cloud(proxy: proxy,
                      color: t.bottomLeading,
                      rotationStart: 120,
                      duration: 80,
                      alignment: .bottomLeading)
                Cloud(proxy: proxy,
                      color: t.topLeading,
                      rotationStart: 180,
                      duration: 70,
                      alignment: .topLeading)
            }
            .blur(radius: blur)
            .ignoresSafeArea()
        }
    }
}

// Example usage:
// FloatingClouds(theme: CloudsTheme.red(scheme))    // red background
// FloatingClouds(theme: CloudsTheme.black(scheme))  // black/graphite background
// FloatingClouds(theme: CloudsTheme.blue(scheme))   // original-ish blue
