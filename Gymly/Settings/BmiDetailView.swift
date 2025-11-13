//
//  WeightAndBmiDetailView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 26.03.2025.
//

import SwiftUI

struct BmiDetailView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @Environment(\.dismiss) var dismiss
    @StateObject var healthKitManager = HealthKitManager()
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.colorScheme) private var scheme

    // Values passed from parent - never recalculated
    let initialBMI: Double
    let initialBmiColor: Color
    let initialBmiText: String

    @State var bodyWeight: String = ""
    @State var bmi: Double = 0.0
    @State var bmiRangeLow:Double = 0.0
    @State var bmiRangeHigh:Double = 0.0
    @State var bmiColor: Color = .green
    @State var bmiText: String = "Normal weight"
    @State private var isVisible: Bool = false
    @State private var hasLoaded: Bool = false

    init(viewModel: WorkoutViewModel, bmi: Double, bmiColor: Color, bmiText: String) {
        self.viewModel = viewModel
        self.initialBMI = bmi
        self.initialBmiColor = bmiColor
        self.initialBmiText = bmiText
        // Initialize @State variables with passed values
        _bmi = State(initialValue: bmi)
        _bmiColor = State(initialValue: bmiColor)
        _bmiText = State(initialValue: bmiText)
    }

    // Computed properties to break down complex expressions
    private var currentHeight: Double {
        userProfileManager.currentProfile?.height ?? 0.0
    }

    private var currentWeight: Double {
        userProfileManager.currentProfile?.weight ?? 0.0
    }

    private var weightUnit: String {
        userProfileManager.currentProfile?.weightUnit ?? "Kg"
    }

    private var isKgUnit: Bool {
        weightUnit == "Kg"
    }

    private var weightConversionFactor: Double {
        isKgUnit ? 1.0 : 2.20462
    }

    private var maxWeightThreshold: Double {
        isKgUnit ? 102.7 : 226.4
    }

    private var weightRangeText: String {
        let heightSquared = currentHeight / 100.0 * currentHeight / 100.0
        let minWeightKg = heightSquared * bmiRangeLow
        let maxWeightKg = heightSquared * bmiRangeHigh

        // Convert to display units
        let minWeight = minWeightKg * weightConversionFactor
        let maxWeight = maxWeightKg * weightConversionFactor
        let formattedMin = String(format: "%.1f", minWeight)
        let formattedMax = String(format: "%.1f", maxWeight)

        if maxWeight > maxWeightThreshold {
            return "\(formattedMin)+ \(weightUnit)"
        } else {
            return "\(formattedMin) - \(formattedMax) \(weightUnit)"
        }
    }

    var body: some View {
        ZStack {
            switch bmiColor {
            case .green: FloatingClouds(theme: CloudsTheme.green(scheme))
                    .ignoresSafeArea()
            case .orange: FloatingClouds(theme: CloudsTheme.orange(scheme))
                    .ignoresSafeArea()
            case .red: FloatingClouds(theme: CloudsTheme.red(scheme))
                    .ignoresSafeArea()
            default:
                FloatingClouds(theme: CloudsTheme.green(scheme))
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 20) {
                    // MARK: BMI Gauge
                    BMIGaugeView(bmi: bmi, bmiColor: bmiColor, bmiText: bmiText)
                        .padding(.top, 30)
                        .frame(height: 260)

                    // MARK: Weight Input Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Weight")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)

                                HStack(spacing: 8) {
                                    TextField("0.0", text: $bodyWeight)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .keyboardType(.numbersAndPunctuation)
                                        .frame(maxWidth: 120)
                                        .onSubmit {
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                                calculateBMI(from: bodyWeight)
                                            }
                                        }

                                    Text(weightUnit)
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Weight Range")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)

                                Text(weightRangeText)
                                    .font(.headline)
                                    .foregroundStyle(bmiColor)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // MARK: Category Cards
                    VStack(spacing: 12) {
                        ForEach(bmiCategories) { category in
                            CategoryCard(
                                category: category,
                                isActive: category.range.contains(bmi),
                                bmi: bmi
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
            }
            .onAppear() {
                // Only load data once to prevent double refresh and animation reset
                guard !hasLoaded else { return }
                hasLoaded = true

                // BMI is already set in init() from parent - don't recalculate!
                // Just display current weight and calculate range
                let displayWeight = currentWeight * weightConversionFactor
                bodyWeight = String(format: "%.1f", displayWeight)
                changeRange()

                // Fade in animation
                withAnimation(.easeOut(duration: 0.5)) {
                    isVisible = true
                }
            }
        }
        .navigationTitle("BMI Calculator")
        .navigationBarTitleDisplayMode(.large)
    }
    
    func calculateBMI(from weightString: String) {
        let oldCategory = bmiText

        guard let weight = Double(weightString), weight > 0 else {
            // Invalid input - keep current BMI from profile
            bmi = userProfileManager.currentProfile?.bmi ?? 0.0
            let (color, status) = getBmiStyle(bmi: bmi)
            bmiColor = color
            bmiText = status
            changeRange()
            return
        }

        // Convert weight to kg if needed for BMI calculation
        let weightInKg = isKgUnit ? weight : weight / 2.20462

        // CRITICAL FIX: Convert height from cm to meters before calculating
        let heightInMeters = currentHeight / 100.0
        let heightSquared = heightInMeters * heightInMeters

        // Calculate BMI: weight(kg) / height(m)²
        bmi = weightInKg / heightSquared

        // Update UI
        let (color, status) = getBmiStyle(bmi: bmi)
        bmiColor = color
        bmiText = status
        changeRange()

        // Haptic feedback if category changed
        if oldCategory != bmiText {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }

    func changeRange() {
        switch bmiText {
            case "Underweight":
            bmiRangeLow = 0.0
            bmiRangeHigh = 18.5
        case "Normal weight":
            bmiRangeLow = 18.5
            bmiRangeHigh = 24.9
        case "Overweight":
            bmiRangeLow = 25.0
            bmiRangeHigh = 29.9
        case "Obese":
            bmiRangeLow = 30.0
            bmiRangeHigh = 100.0
        default:
            bmiRangeLow = 0.0
            bmiRangeHigh = 0.0
        }
    }
}


struct BMICategory: Identifiable {
    let id = UUID()
    let title: String
    let range: ClosedRange<Double>
    let rangeText: String
    let color: Color
}

let bmiCategories: [BMICategory] = [
    BMICategory(title: "Underweight", range: 0.0...18.5, rangeText: "≤ 18.5", color: .orange),
    BMICategory(title: "Normal weight", range: 18.5...24.9, rangeText: "18.5 - 24.9", color: .green),
    BMICategory(title: "Overweight", range: 25.0...29.9, rangeText: "25.0 - 29.9", color: .orange),
    BMICategory(title: "Obese", range: 30.0...100.0, rangeText: "≥ 30.0", color: .red)
]

// MARK: - Category Card Component

struct CategoryCard: View {
    let category: BMICategory
    let isActive: Bool
    let bmi: Double

    @State private var pulseScale: CGFloat = 1.0

    var categoryIcon: String {
        switch category.title {
        case "Underweight": return "arrow.down.circle.fill"
        case "Normal weight": return "checkmark.circle.fill"
        case "Overweight": return "arrow.up.circle.fill"
        case "Obese": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }

    var progressPercentage: CGFloat {
        guard category.range.contains(bmi) else { return 0 }

        let rangeSpan = category.range.upperBound - category.range.lowerBound
        let positionInRange = bmi - category.range.lowerBound
        return min(max(positionInRange / rangeSpan, 0), 1)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundStyle(isActive ? category.color : .secondary)
                .frame(width: 32)
                .scaleEffect(isActive ? pulseScale : 1.0)

            VStack(alignment: .leading, spacing: 6) {
                // Title and Range
                HStack {
                    Text(category.title)
                        .font(.headline)
                        .foregroundStyle(isActive ? category.color : .primary)

                    Spacer()

                    Text(category.rangeText)
                        .font(.subheadline)
                        .foregroundStyle(isActive ? category.color : .secondary)
                }

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        // Active progress
                        if isActive {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(category.color)
                                .frame(width: geometry.size.width * progressPercentage, height: 6)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progressPercentage)
                        }
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? category.color.opacity(0.1) : Color.black.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? category.color.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .onAppear {
            if isActive {
                startPulse()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startPulse()
            }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}
