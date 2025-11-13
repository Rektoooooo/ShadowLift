//
//  WeightDetailView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 26.03.2025.
//

import SwiftUI
import SwiftData

struct WeightDetailView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @StateObject var healthKitManager = HealthKitManager()
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \WeightPoint.date, order: .reverse) var weightPoints: [WeightPoint]

    @State var bodyWeight: String = ""
    @State private var showingSaveSuccess = false
    @State private var saveMessage = ""

    // MARK: - Computed Properties

    private var currentWeight: Double {
        userProfileManager.currentProfile?.weight ?? 0.0
    }

    private var weightUnit: String {
        userProfileManager.currentProfile?.weightUnit ?? "Kg"
    }

    private var weightConversionFactor: Double {
        weightUnit == "Kg" ? 1.0 : 2.20462
    }

    private var displayWeight: Double {
        currentWeight * weightConversionFactor
    }

    // MARK: - Weight Change Calculations

    private var weekChange: Double {
        calculateWeightChange(daysBack: 7)
    }

    private var monthChange: Double {
        calculateWeightChange(daysBack: 30)
    }

    private var allTimeChange: Double {
        guard let firstPoint = weightPoints.last else { return 0 }
        return (currentWeight - firstPoint.weight) * weightConversionFactor
    }

    private func calculateWeightChange(daysBack: Int) -> Double {
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
            return 0
        }

        // Find closest weight point to target date
        let sortedPoints = weightPoints.sorted { $0.date < $1.date }
        guard let closestPoint = sortedPoints.first(where: { $0.date >= targetDate }) ?? sortedPoints.last else {
            return 0
        }

        return (currentWeight - closestPoint.weight) * weightConversionFactor
    }

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()

                List {
                    // MARK: - Current Weight Hero Card
                    Section {
                        VStack(spacing: 12) {
                            // Large weight display
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", displayWeight))
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundColor(.primary)

                                Text(weightUnit)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }

                            // Month change indicator
                            if !weightPoints.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: monthChange >= 0 ? "arrow.up" : "arrow.down")
                                        .font(.caption)
                                    Text("\(abs(monthChange), specifier: "%.1f") \(weightUnit) from last month")
                                        .font(.subheadline)
                                }
                                .foregroundColor(monthChange >= 0 ? .red.opacity(0.8) : .green.opacity(0.8))
                            }

                            // BMI display
                            if let bmi = userProfileManager.currentProfile?.bmi {
                                Text("BMI: \(bmi, specifier: "%.1f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // MARK: - Quick Stats Row
                    if !weightPoints.isEmpty {
                        Section {
                            HStack(spacing: 12) {
                                WeightStatCard(
                                    period: "7D",
                                    change: weekChange,
                                    unit: weightUnit,
                                    accentColor: appearanceManager.accentColor.color
                                )

                                WeightStatCard(
                                    period: "30D",
                                    change: monthChange,
                                    unit: weightUnit,
                                    accentColor: appearanceManager.accentColor.color
                                )

                                WeightStatCard(
                                    period: "All",
                                    change: allTimeChange,
                                    unit: weightUnit,
                                    accentColor: appearanceManager.accentColor.color
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.clear)
                    }

                    // MARK: - Weight Chart
                    Section("Weight Progress") {
                        WeightChart()
                            .padding(.vertical, 8)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))

                    // MARK: - Weight History Timeline
                    if !weightPoints.isEmpty {
                        Section("Weight History") {
                            ForEach(weightPoints.prefix(10)) { point in
                                WeightHistoryRow(
                                    weightPoint: point,
                                    weightUnit: weightUnit,
                                    conversionFactor: weightConversionFactor,
                                    accentColor: appearanceManager.accentColor.color
                                )
                            }
                            .onDelete { indexSet in
                                deleteWeightPoints(at: indexSet)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .listRowBackground(Color.black.opacity(0.1))
                    }

                    // MARK: - Update Weight
                    Section("Update Weight") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Weight (\(weightUnit))")
                                    .foregroundStyle(.white.opacity(0.6))

                                Spacer()

                                TextField("0.0", text: $bodyWeight)
                                    .keyboardType(.numbersAndPunctuation)
                                    .multilineTextAlignment(.trailing)
                                    .font(.headline)
                                    .frame(width: 100)
                                    .onSubmit {
                                        saveWeight()
                                    }
                            }

                            Button(action: saveWeight) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Weight")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(appearanceManager.accentColor.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(bodyWeight.isEmpty || Double(bodyWeight) == nil)
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                }
                .navigationTitle("My Weight")
                .navigationBarTitleDisplayMode(.large)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.clear)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            saveWeight()
                            dismiss()
                        }
                        .foregroundColor(appearanceManager.accentColor.color)
                        .bold()
                    }
                }

                // MARK: - Toast Notification
                if showingSaveSuccess {
                    VStack {
                        Spacer()

                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.title3)

                            Text(saveMessage)
                                .foregroundColor(.white)
                                .font(.subheadline)
                                .bold()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        )
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingSaveSuccess)
                    }
                }
            }
        }
        .onAppear {
            let displayWeight = currentWeight * weightConversionFactor
            bodyWeight = String(format: "%.1f", displayWeight)
        }
    }

    // MARK: - Delete Weight Points
    private func deleteWeightPoints(at indexSet: IndexSet) {
        for index in indexSet {
            let point = Array(weightPoints.prefix(10))[index]
            context.delete(point)
        }

        do {
            try context.save()
            print("✅ Weight point deleted successfully")

            // Update user profile if we deleted today's weight
            if let profile = userProfileManager.currentProfile {
                if let latestPoint = weightPoints.first {
                    profile.weight = latestPoint.weight
                    profile.updateBMI()
                    profile.markAsUpdated()
                    userProfileManager.objectWillChange.send()
                }
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("❌ Failed to delete weight point: \(error)")
        }
    }

    // MARK: - Save Weight Function
    private func saveWeight() {
        guard let inputWeight = Double(bodyWeight), inputWeight > 0 else {
            print("❌ Invalid weight input: \(bodyWeight)")
            return
        }

        // Convert input weight to kg (HealthKit always stores in kg)
        let weightInKg: Double
        if weightUnit == "Kg" {
            weightInKg = inputWeight
        } else {
            // Convert from lbs to kg
            weightInKg = inputWeight / 2.20462262
        }

        print("💾 Saving weight: \(inputWeight) \(weightUnit) = \(weightInKg) kg")

        // Save to HealthKit (always in kg)
        healthKitManager.saveWeight(weightInKg)

        // Update user profile directly (always store in kg internally)
        if let profile = userProfileManager.currentProfile {
            profile.weight = weightInKg
            profile.updateBMI()
            profile.markAsUpdated()

            // Create or update WeightPoint for today
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            let fetchDescriptor = FetchDescriptor<WeightPoint>(
                predicate: #Predicate { point in
                    point.date >= today && point.date < tomorrow
                }
            )

            do {
                let existingPoints = try context.fetch(fetchDescriptor)

                if let existingPoint = existingPoints.first {
                    // Update existing point for today
                    existingPoint.weight = weightInKg
                    existingPoint.date = Date() // Update to current time
                    print("📊 Updated existing WeightPoint for today: \(weightInKg) kg")
                } else {
                    // Create new point for today
                    let newPoint = WeightPoint(date: Date(), weight: weightInKg)
                    context.insert(newPoint)
                    print("📊 Created new WeightPoint: \(weightInKg) kg")
                }

                // Save context
                try context.save()
                print("✅ Weight saved to database successfully: \(weightInKg) kg")
                print("✅ Profile weight after save: \(profile.weight) kg")

                // Trigger UserProfileManager to update and sync
                userProfileManager.objectWillChange.send()

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

            } catch {
                print("❌ Failed to save weight to database: \(error)")
            }
        }

        // Show toast notification
        saveMessage = "Weight saved: \(inputWeight) \(weightUnit)"
        withAnimation {
            showingSaveSuccess = true
        }

        // Hide success message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSaveSuccess = false
            }
        }
    }
}

// MARK: - Weight History Row Component
struct WeightHistoryRow: View {
    let weightPoint: WeightPoint
    let weightUnit: String
    let conversionFactor: Double
    let accentColor: Color

    private var displayWeight: Double {
        weightPoint.weight * conversionFactor
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: weightPoint.date)
    }

    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(weightPoint.date) {
            return "Today"
        } else if calendar.isDateInYesterday(weightPoint.date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: weightPoint.date, to: now).day {
            if daysAgo < 7 {
                return "\(daysAgo) days ago"
            } else if daysAgo < 30 {
                let weeks = daysAgo / 7
                return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
            } else {
                let months = daysAgo / 30
                return "\(months) \(months == 1 ? "month" : "months") ago"
            }
        }
        return formattedDate
    }

    var body: some View {
        HStack(spacing: 12) {
            // Date indicator circle
            VStack(spacing: 4) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)

                Rectangle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 2)
            }

            // Weight info
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", displayWeight))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(weightUnit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(relativeDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Exact timestamp
            VStack(alignment: .trailing, spacing: 2) {
                let timeFormatter = DateFormatter()
                let _ = timeFormatter.dateFormat = "h:mm a"

                Text(timeFormatter.string(from: weightPoint.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                let dateFormatter = DateFormatter()
                let _ = dateFormatter.dateFormat = "MMM d, yyyy"

                Text(dateFormatter.string(from: weightPoint.date))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Weight Stat Card Component
struct WeightStatCard: View {
    let period: String
    let change: Double
    let unit: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(period)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 3) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(String(format: "%.1f", abs(change)))
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(change >= 0 ? .red.opacity(0.8) : .green.opacity(0.8))

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    WeightDetailView(viewModel: WorkoutViewModel(config: Config(), context: ModelContext(try! ModelContainer(for: Split.self))))
        .environmentObject(Config())
        .environmentObject(UserProfileManager.shared)
        .environmentObject(AppearanceManager())
}
