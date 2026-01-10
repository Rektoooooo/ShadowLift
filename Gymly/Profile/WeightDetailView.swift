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
    @State private var hasUserEdited = false  // Track if user has edited the field
    @State private var isHistoryExpanded = false  // Track if weight history is expanded
    @State private var isEditingWeight = false  // Track if user is editing the big weight display
    @FocusState private var weightFieldFocused: Bool

    // MARK: - Performance: Cached Weight Change Calculations
    @State private var cachedWeekChange: Double = 0
    @State private var cachedMonthChange: Double = 0
    @State private var cachedAllTimeChange: Double = 0

    // MARK: - Computed Properties (lightweight, no logging)

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

    // MARK: - Weight Change Calculation (called once on appear/change)

    private func updateCachedWeightChanges() {
        cachedWeekChange = calculateWeightChange(daysBack: 7)
        cachedMonthChange = calculateWeightChange(daysBack: 30)
        cachedAllTimeChange = calculateAllTimeChange()
        debugLog("📊 WeightDetailView: Updated cached weight changes (7d: \(cachedWeekChange), 30d: \(cachedMonthChange), all: \(cachedAllTimeChange))")
    }

    private func calculateAllTimeChange() -> Double {
        guard let firstPoint = weightPoints.last else {
            return 0
        }
        return (currentWeight - firstPoint.weight) * weightConversionFactor
    }

    private func calculateWeightChange(daysBack: Int) -> Double {
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
            return 0
        }

        // Find the weight point closest to the target date
        guard !weightPoints.isEmpty else { return 0 }

        let closestPoint = weightPoints.min(by: { abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate)) })

        guard let point = closestPoint else { return 0 }

        // Adaptive tolerance based on time period
        // 7 days = ±3 days tolerance (4-10 days range)
        // 30 days = ±7 days tolerance (23-37 days range)
        let tolerance = daysBack <= 7 ? 3 : 7
        let daysDifference = abs(calendar.dateComponents([.day], from: point.date, to: targetDate).day ?? 0)

        guard daysDifference <= tolerance else {
            return 0
        }

        return (currentWeight - point.weight) * weightConversionFactor
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                
                List {
                    // MARK: - Current Weight Hero Card (Tappable to Edit)
                    Section {
                        VStack(spacing: 12) {
                            if isEditingWeight {
                                // Editing mode - show text field
                                VStack(spacing: 16) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        TextField("0.0", text: $bodyWeight)
                                            .font(.system(size: 56, weight: .bold))
                                            .foregroundColor(.primary)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.center)
                                            .focused($weightFieldFocused)
                                            .frame(width: 180)
                                            .onChange(of: bodyWeight) { _, _ in
                                                hasUserEdited = true
                                            }

                                        Text(weightUnit)
                                            .font(.title3)
                                            .foregroundColor(.secondary)
                                    }

                                    // Save button
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                isEditingWeight = false
                                                weightFieldFocused = false
                                            }
                                        }) {
                                            Text("Cancel")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 10)
                                                .background(Color.secondaryBackground(for: scheme))
                                                .cornerRadius(10)
                                        }

                                        Button(action: {
                                            saveWeight()
                                            withAnimation(.spring(response: 0.3)) {
                                                isEditingWeight = false
                                                weightFieldFocused = false
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "checkmark")
                                                    .font(.subheadline.weight(.semibold))
                                                Text("Save")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 10)
                                            .background(appearanceManager.accentColor.color)
                                            .cornerRadius(10)
                                        }
                                        .disabled(bodyWeight.isEmpty || parseWeight(bodyWeight) == nil)
                                    }
                                }
                            } else {
                                // Display mode - tappable
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        isEditingWeight = true
                                        weightFieldFocused = true
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text(String(format: "%.1f", displayWeight))
                                                .font(.system(size: 56, weight: .bold))
                                                .foregroundColor(.primary)

                                            Text(weightUnit)
                                                .font(.title3)
                                                .foregroundColor(.secondary)
                                        }

                                        // Tap to edit hint
                                        HStack(spacing: 4) {
                                            Image(systemName: "pencil")
                                                .font(.caption2)
                                            Text("Tap to update")
                                                .font(.caption)
                                        }
                                        .foregroundColor(appearanceManager.accentColor.color.opacity(0.8))
                                    }
                                }
                                .buttonStyle(.plain)
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
                    .listRowBackground(Color.listRowBackground(for: scheme))
                    
                    // MARK: - Quick Stats Row
                    if !weightPoints.isEmpty {
                        Section {
                            HStack(spacing: 12) {
                                WeightStatCard(
                                    period: "7D",
                                    change: cachedWeekChange,
                                    unit: weightUnit,
                                    accentColor: appearanceManager.accentColor.color
                                )

                                WeightStatCard(
                                    period: "30D",
                                    change: cachedMonthChange,
                                    unit: weightUnit,
                                    accentColor: appearanceManager.accentColor.color
                                )

                                WeightStatCard(
                                    period: "All",
                                    change: cachedAllTimeChange,
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
                    .listRowBackground(Color.listRowBackground(for: scheme))
                    
                    // MARK: - Weight History Timeline
                    if !weightPoints.isEmpty {
                        Section("Weight History") {
                            ForEach(weightPoints.prefix(isHistoryExpanded ? weightPoints.count : 3)) { point in
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
                            
                            // Show More / Show Less Button
                            if weightPoints.count > 3 {
                                Button(action: {
                                    withAnimation {
                                        isHistoryExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Spacer()
                                        Text(isHistoryExpanded ? "Show Less" : "Show More (\(weightPoints.count - 3) more)")
                                            .font(.subheadline)
                                            .foregroundColor(appearanceManager.accentColor.color)
                                        Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(appearanceManager.accentColor.color)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .listRowBackground(Color.listRowBackground(for: scheme))
                    }
                }
                .navigationTitle("My Weight")
                .navigationBarTitleDisplayMode(.large)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.clear)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            // If editing, save and close editing mode first
                            if isEditingWeight {
                                if hasUserEdited && !bodyWeight.isEmpty && parseWeight(bodyWeight) != nil {
                                    saveWeight()
                                }
                                withAnimation(.spring(response: 0.3)) {
                                    isEditingWeight = false
                                    weightFieldFocused = false
                                }
                                // Small delay then dismiss
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismiss()
                                }
                            } else {
                                dismiss()
                            }
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
            // Only set initial value if user hasn't edited the field
            if !hasUserEdited {
                let displayWeight = currentWeight * weightConversionFactor
                bodyWeight = String(format: "%.1f", displayWeight)
            }
            // Initialize cached weight changes
            updateCachedWeightChanges()
        }
        .onChange(of: weightPoints) { _, _ in
            // Update cache when weight data changes
            updateCachedWeightChanges()
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
            debugLog("✅ Weight point deleted successfully")
            
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
            debugLog("❌ Failed to delete weight point: \(error)")
        }
    }
    
    // MARK: - Parse Weight (handles both comma and period decimal separators)
    private func parseWeight(_ input: String) -> Double? {
        // Replace comma with period to handle European locale
        let normalizedInput = input.replacingOccurrences(of: ",", with: ".")
        return Double(normalizedInput)
    }

    // MARK: - Save Weight Function
    private func saveWeight() {
        guard let inputWeight = parseWeight(bodyWeight), inputWeight > 0 else {
            debugLog("❌ Invalid weight input: \(bodyWeight)")
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
        
        debugLog("💾 Saving weight: \(inputWeight) \(weightUnit) = \(weightInKg) kg")
        debugLog("💾 Current profile weight before save: \(userProfileManager.currentProfile?.weight ?? 0) kg")

        // Save to HealthKit FIRST (always in kg)
        healthKitManager.saveWeight(weightInKg)

        // Update user profile directly (always store in kg internally)
        if let profile = userProfileManager.currentProfile {
            profile.weight = weightInKg
            debugLog("💾 Updated profile weight to: \(profile.weight) kg")
            profile.updateBMI()
            debugLog("💾 Updated BMI to: \(profile.bmi)")
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
                    debugLog("📊 Updated existing WeightPoint for today: \(weightInKg) kg")
                } else {
                    // Create new point for today
                    let newPoint = WeightPoint(date: Date(), weight: weightInKg)
                    context.insert(newPoint)
                    debugLog("📊 Created new WeightPoint: \(weightInKg) kg")
                }
                
                // Save context
                try context.save()
                debugLog("✅ Weight saved to database successfully: \(weightInKg) kg")
                debugLog("✅ Profile weight after save: \(profile.weight) kg")
                
                // Trigger UserProfileManager to update and sync
                userProfileManager.objectWillChange.send()
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
            } catch {
                debugLog("❌ Failed to save weight to database: \(error)")
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
    @Environment(\.colorScheme) private var scheme
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
        .background(Color.secondaryBackground(for: scheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Split.self, configurations: config)
    return WeightDetailView(viewModel: WorkoutViewModel(config: Config(), context: ModelContext(container)))
        .environmentObject(Config())
        .environmentObject(UserProfileManager.shared)
        .environmentObject(AppearanceManager())
}
