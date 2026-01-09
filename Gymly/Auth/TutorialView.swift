//
//  TutorialView.swift
//  ShadowLift
//
//  Created by Claude Code on 09.01.2026.
//

import SwiftUI

// MARK: - Tutorial Step Definition

enum TutorialHighlight: Int, CaseIterable {
    case welcome
    case profile
    case splits
    case addExercise
    case daySelector
    case calendar
    case settings
    case done

    var title: String {
        switch self {
        case .welcome: return "Welcome to ShadowLift!"
        case .profile: return "Your Profile"
        case .splits: return "Your Workout Splits"
        case .addExercise: return "Add Exercises"
        case .daySelector: return "Switch Workout Days"
        case .calendar: return "Track Your History"
        case .settings: return "Customize Your Experience"
        case .done: return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's take a quick tour of the features that will help you crush your fitness goals."
        case .profile:
            return "Tap your profile picture to view your stats, streaks, and personal records."
        case .splits:
            return "Tap here to create, edit, and manage your workout splits. Choose from templates like Push/Pull/Legs or create your own!"
        case .addExercise:
            return "Quickly add new exercises to your current workout day with just a tap."
        case .daySelector:
            return "Tap the day name to switch between different workout days in your split."
        case .calendar:
            return "View your workout history, track consistency, and see your progress over time."
        case .settings:
            return "Connect HealthKit, customize themes, enable iCloud sync, and manage your account."
        case .done:
            return "You're ready to start training! Remember, consistency is key to reaching your goals."
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "figure.strengthtraining.traditional"
        case .profile: return "person.crop.circle"
        case .splits: return "list.bullet.rectangle"
        case .addExercise: return "plus.circle"
        case .daySelector: return "chevron.down"
        case .calendar: return "calendar"
        case .settings: return "gearshape"
        case .done: return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: return .orange
        case .profile: return .pink
        case .splits: return .purple
        case .addExercise: return .blue
        case .daySelector: return .green
        case .calendar: return .cyan
        case .settings: return .gray
        case .done: return .green
        }
    }

    // Whether to show spotlight circle for this step
    var showSpotlight: Bool {
        switch self {
        case .welcome, .daySelector, .done: return false
        default: return true
        }
    }

    // Tooltip position relative to spotlight
    var tooltipAlignment: TooltipAlignment {
        switch self {
        case .welcome: return .center
        case .profile: return .below
        case .splits: return .below
        case .addExercise: return .below
        case .daySelector: return .below
        case .calendar: return .above
        case .settings: return .above
        case .done: return .center
        }
    }
}

enum TooltipAlignment {
    case above
    case below
    case center
}

// MARK: - Tutorial Overlay View

struct TutorialView: View {
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var currentStep: TutorialHighlight = .welcome
    @State private var showContent = false
    @State private var spotlightOpacity: Double = 0

    private let steps = TutorialHighlight.allCases

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // App-like skeleton background
                SkeletonAppBackground(geometry: geometry, colorScheme: colorScheme)
                    .ignoresSafeArea()

                // Dark overlay
                Color.black.opacity(0.75)
                    .ignoresSafeArea()

                // Spotlight cutout (only for steps that show spotlight)
                if currentStep.showSpotlight {
                    SpotlightCutout(
                        position: spotlightPosition(for: currentStep, in: geometry),
                        size: CGSize(width: 50, height: 50)
                    )
                    .opacity(spotlightOpacity)
                }

                // Mock UI Elements for context
                MockUIOverlay(currentStep: currentStep, geometry: geometry)
                    .opacity(currentStep.showSpotlight || currentStep == .daySelector ? spotlightOpacity : 0)

                // Tooltip content
                VStack(spacing: 0) {
                    if currentStep.tooltipAlignment == .below || currentStep == .welcome || currentStep == .done {
                        Spacer()
                    }

                    TooltipCard(
                        step: currentStep,
                        accentColor: appearanceManager.accentColor.color,
                        isFirstStep: currentStep == .welcome,
                        isLastStep: currentStep == .done,
                        onNext: nextStep,
                        onBack: previousStep,
                        onSkip: completeTutorial
                    )
                    .padding(.horizontal, 24)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                    if currentStep.tooltipAlignment == .above {
                        Spacer()
                    }

                    if currentStep == .welcome || currentStep == .done {
                        Spacer()
                    }
                }
                .padding(.vertical, currentStep.tooltipAlignment == .center ? 0 : 100)

                // Progress indicators - positioned at top for tab bar steps, bottom otherwise
                VStack {
                    if currentStep == .calendar || currentStep == .settings {
                        ProgressIndicator(
                            currentIndex: currentStep.rawValue,
                            totalSteps: steps.count,
                            accentColor: appearanceManager.accentColor.color
                        )
                        .padding(.top, geometry.safeAreaInsets.top + 60)
                        .opacity(showContent ? 1 : 0)
                        Spacer()
                    } else {
                        Spacer()
                        ProgressIndicator(
                            currentIndex: currentStep.rawValue,
                            totalSteps: steps.count,
                            accentColor: appearanceManager.accentColor.color
                        )
                        .padding(.bottom, 50)
                        .opacity(showContent ? 1 : 0)
                    }
                }
            }
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Positioning Helpers

    private func spotlightPosition(for step: TutorialHighlight, in geometry: GeometryProxy) -> CGPoint {
        let safeArea = geometry.safeAreaInsets
        let width = geometry.size.width
        let height = geometry.size.height

        switch step {
        case .welcome, .done:
            return CGPoint(x: width / 2, y: height / 2)
        case .profile:
            // Top left - profile button (centered on 34pt icon with 16pt leading padding)
            return CGPoint(x: 33, y: safeArea.top + 22)
        case .splits:
            // Second from right in toolbar - aligned with the icon center
            return CGPoint(x: width - 60, y: safeArea.top + 22)
        case .addExercise:
            // Far right in toolbar - aligned with the icon center
            return CGPoint(x: width - 20, y: safeArea.top + 22)
        case .daySelector:
            // Below nav bar (no spotlight, just mock UI)
            return CGPoint(x: 100, y: safeArea.top + 80)
        case .calendar:
            // Center tab in tab bar (exact center)
            return CGPoint(x: width / 2, y: height - safeArea.bottom - 34)
        case .settings:
            // Right tab in tab bar (2/3 across + some offset)
            return CGPoint(x: width * 5 / 6, y: height - safeArea.bottom - 34)
        }
    }

    // MARK: - Actions

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            showContent = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            spotlightOpacity = 1
        }
    }

    private func nextStep() {
        let currentIndex = currentStep.rawValue
        if currentIndex < steps.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = false
                spotlightOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                currentStep = steps[currentIndex + 1]
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showContent = true
                    spotlightOpacity = 1
                }
            }
        } else {
            completeTutorial()
        }
    }

    private func previousStep() {
        let currentIndex = currentStep.rawValue
        if currentIndex > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = false
                spotlightOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                currentStep = steps[currentIndex - 1]
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showContent = true
                    spotlightOpacity = 1
                }
            }
        }
    }

    private func completeTutorial() {
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
            spotlightOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            config.hasSeenTutorial = true
            dismiss()
        }
    }
}

// MARK: - Skeleton App Background

struct SkeletonAppBackground: View {
    let geometry: GeometryProxy
    let colorScheme: ColorScheme

    private var bgColor: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
    }

    private var cardColor: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.88)
    }

    private var shimmerColor: Color {
        colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.82)
    }

    var body: some View {
        ZStack {
            // Base background
            bgColor

            VStack(spacing: 0) {
                // Navigation bar area
                HStack {
                    // Profile placeholder
                    Circle()
                        .fill(cardColor)
                        .frame(width: 34, height: 34)
                        .padding(.leading, 16)

                    Spacer()

                    // Title placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cardColor)
                        .frame(width: 100, height: 20)

                    Spacer()

                    // Toolbar buttons placeholder
                    HStack(spacing: 16) {
                        Circle()
                            .fill(cardColor)
                            .frame(width: 28, height: 28)
                        Circle()
                            .fill(cardColor)
                            .frame(width: 28, height: 28)
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, geometry.safeAreaInsets.top + 8)
                .padding(.bottom, 12)

                // Day title placeholder
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardColor)
                        .frame(width: 140, height: 32)
                        .padding(.leading, 16)
                    Spacer()
                }
                .padding(.vertical, 16)

                // Exercise list skeleton
                VStack(spacing: 12) {
                    // Section header
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(shimmerColor)
                            .frame(width: 60, height: 14)
                            .padding(.leading, 16)
                        Spacer()
                    }

                    // Exercise rows
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonExerciseRow(cardColor: cardColor, shimmerColor: shimmerColor)
                    }

                    // Another section
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(shimmerColor)
                            .frame(width: 80, height: 14)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.top, 8)

                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonExerciseRow(cardColor: cardColor, shimmerColor: shimmerColor)
                    }
                }

                Spacer()

                // Tab bar skeleton
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(cardColor)
                                .frame(width: 24, height: 24)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cardColor)
                                .frame(width: 44, height: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
            }
        }
    }
}

struct SkeletonExerciseRow: View {
    let cardColor: Color
    let shimmerColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Number
            Circle()
                .fill(shimmerColor)
                .frame(width: 24, height: 24)

            // Exercise name
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerColor)
                .frame(width: CGFloat.random(in: 100...180), height: 16)

            Spacer()

            // Chevron
            RoundedRectangle(cornerRadius: 2)
                .fill(cardColor)
                .frame(width: 8, height: 14)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardColor)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Spotlight Cutout

struct SpotlightCutout: View {
    let position: CGPoint
    let size: CGSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Create a path that covers everything except the spotlight area
                Rectangle()
                    .fill(Color.black.opacity(0.001)) // Nearly invisible but captures taps

                // Spotlight circle with glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width
                        )
                    )
                    .frame(width: size.width * 2, height: size.height * 2)
                    .position(position)

                // Pulsing ring
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: size.width + 20, height: size.height + 20)
                    .position(position)
                    .modifier(PulseAnimation())
            }
        }
    }
}

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Mock UI Overlay (shows context)

struct MockUIOverlay: View {
    let currentStep: TutorialHighlight
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            // Mock toolbar items
            VStack {
                HStack(alignment: .center) {
                    // Profile button area (left side)
                    if currentStep == .profile {
                        ZStack {
                            Circle()
                                .fill(Color.pink.opacity(0.3))
                                .frame(width: 44, height: 44)

                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 12)
                    } else if currentStep == .splits || currentStep == .addExercise {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 34, height: 34)
                            .padding(.leading, 16)
                    }

                    Spacer()

                    // Toolbar buttons (right side) - splits then add exercise
                    HStack(spacing: 16) {
                        if currentStep == .splits || currentStep == .addExercise {
                            // Splits button (second from right)
                            ZStack {
                                if currentStep == .splits {
                                    Circle()
                                        .fill(Color.purple.opacity(0.3))
                                        .frame(width: 44, height: 44)
                                }

                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(currentStep == .splits ? .white : .white.opacity(0.4))
                            }

                            // Add exercise button (far right)
                            ZStack {
                                if currentStep == .addExercise {
                                    Circle()
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: 44, height: 44)
                                }

                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(currentStep == .addExercise ? .white : .white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }
                .padding(.top, geometry.safeAreaInsets.top + 4)

                // Day selector mock
                if currentStep == .daySelector {
                    HStack {
                        HStack(spacing: 8) {
                            Text("Push Day")
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)

                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.2))
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        )
                        .padding(.leading, 16)

                        Spacer()
                    }
                    .padding(.top, 16)
                }

                Spacer()

                // Mock tab bar
                if currentStep == .calendar || currentStep == .settings {
                    HStack(spacing: 0) {
                        TabBarMockItem(
                            icon: "dumbbell",
                            label: "Routine",
                            isHighlighted: false
                        )
                        .frame(maxWidth: .infinity)

                        TabBarMockItem(
                            icon: "calendar",
                            label: "Calendar",
                            isHighlighted: currentStep == .calendar
                        )
                        .frame(maxWidth: .infinity)

                        TabBarMockItem(
                            icon: "gearshape",
                            label: "Settings",
                            isHighlighted: currentStep == .settings
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
                }
            }
        }
    }
}

struct TabBarMockItem: View {
    let icon: String
    let label: String
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isHighlighted ? .cyan : .white.opacity(0.4))

            Text(label)
                .font(.caption2)
                .foregroundColor(isHighlighted ? .cyan : .white.opacity(0.4))
        }
    }
}

// MARK: - Tooltip Card

struct TooltipCard: View {
    let step: TutorialHighlight
    let accentColor: Color
    let isFirstStep: Bool
    let isLastStep: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                step.iconColor.opacity(0.3),
                                step.iconColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: step.icon)
                    .font(.system(size: 36))
                    .foregroundColor(step.iconColor)
            }

            // Title
            Text(step.title)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Description
            Text(step.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Buttons
            HStack(spacing: 16) {
                if !isFirstStep && !isLastStep {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button(action: isLastStep ? onSkip : onNext) {
                    HStack {
                        Text(isLastStep ? "Get Started" : "Next")
                            .fontWeight(.semibold)
                        if !isLastStep {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: isFirstStep || isLastStep ? .infinity : nil)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Skip button (not on last step)
            if !isLastStep && !isFirstStep {
                Button(action: onSkip) {
                    Text("Skip Tutorial")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.15))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentIndex: Int
    let totalSteps: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? accentColor : Color.white.opacity(0.3))
                    .frame(width: index == currentIndex ? 10 : 8, height: index == currentIndex ? 10 : 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
            }
        }
    }
}

// MARK: - Preview

#Preview("Tutorial") {
    TutorialView()
        .environmentObject(Config())
        .environmentObject(AppearanceManager.shared)
        .preferredColorScheme(.dark)
}

#Preview("Tutorial - Splits Step") {
    TutorialPreviewWrapper(step: .splits)
}

#Preview("Tutorial - Calendar Step") {
    TutorialPreviewWrapper(step: .calendar)
}

struct TutorialPreviewWrapper: View {
    let step: TutorialHighlight

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()

                MockUIOverlay(currentStep: step, geometry: geometry)

                VStack {
                    if step.tooltipAlignment == .below {
                        Spacer()
                    }

                    TooltipCard(
                        step: step,
                        accentColor: .blue,
                        isFirstStep: false,
                        isLastStep: false,
                        onNext: {},
                        onBack: {},
                        onSkip: {}
                    )
                    .padding(.horizontal, 24)

                    if step.tooltipAlignment == .above {
                        Spacer()
                    }
                }
                .padding(.vertical, 100)
            }
        }
        .preferredColorScheme(.dark)
    }
}
