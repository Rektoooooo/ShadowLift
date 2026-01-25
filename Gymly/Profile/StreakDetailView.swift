//
//  StreakDetailView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 03.11.2025.
//

import SwiftUI
import SwiftData

struct StreakDetailView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) var context

    @State private var showCalendar = false
    @State private var showSuccessToast = false
    @State private var toastMessage = ""

    // MARK: - Computed Properties

    private var currentStreak: Int {
        userProfileManager.currentProfile?.currentStreak ?? 0
    }

    private var longestStreak: Int {
        userProfileManager.currentProfile?.longestStreak ?? 0
    }

    private var restDaysPerWeek: Int {
        userProfileManager.currentProfile?.restDaysPerWeek ?? 2
    }

    private var isStreakPaused: Bool {
        userProfileManager.currentProfile?.streakPaused ?? false
    }

    private var streakStatus: String {
        if isStreakPaused {
            return "Paused"
        } else if currentStreak == 0 {
            return "Start Your Journey!"
        } else if currentStreak >= longestStreak && currentStreak > 0 {
            return "New Record! 🎉"
        } else if currentStreak >= 7 {
            return "On Fire! 🔥"
        } else if currentStreak >= 3 {
            return "Building Momentum!"
        } else {
            return "Keep Going!"
        }
    }

    private var streakStatusColor: Color {
        if isStreakPaused {
            return .gray
        } else if currentStreak >= longestStreak && currentStreak > 0 {
            return .green
        } else if currentStreak >= 7 {
            return .orange
        } else {
            return appearanceManager.accentColor.color
        }
    }

    private var daysUntilStreakBreaks: Int {
        guard let lastWorkout = userProfileManager.currentProfile?.lastWorkoutDate else {
            return 0
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWorkoutDay = calendar.startOfDay(for: lastWorkout)
        let daysSince = calendar.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0

        let maxAllowedGap = restDaysPerWeek + 1
        let daysRemaining = maxAllowedGap - daysSince

        return max(0, daysRemaining)
    }

    private var thisWeekWorkouts: Int {
        let calendar = Calendar.current

        // Get start of current week (Monday)
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return 0
        }

        // Get end of current week (Sunday)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return 0
        }

        let weekStartString = formattedDateString(from: weekStart)
        let weekEndString = formattedDateString(from: weekEnd)

        let fetchDescriptor = FetchDescriptor<DayStorage>(
            predicate: #Predicate { dayStorage in
                dayStorage.date >= weekStartString && dayStorage.date < weekEndString
            }
        )

        do {
            let workouts = try context.fetch(fetchDescriptor)
            debugLog("🔧 STREAK: This week workouts: \(workouts.count) (from \(weekStartString) to \(weekEndString))")
            return workouts.count
        } catch {
            debugLog("❌ STREAK: Failed to fetch this week workouts: \(error)")
            return 0
        }
    }

    private var daysFromRecord: Int {
        return max(0, longestStreak - currentStreak)
    }

    private var totalWorkoutDays: Int {
        let fetchDescriptor = FetchDescriptor<DayStorage>()
        do {
            let allWorkouts = try context.fetch(fetchDescriptor)
            return allWorkouts.count
        } catch {
            return 0
        }
    }

    private var averageWorkoutsPerWeek: Double {
        let calendar = Calendar.current

        // Calculate average over last 12 weeks
        guard let twelveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -12, to: Date()) else {
            return 0.0
        }

        let startString = formattedDateString(from: twelveWeeksAgo)
        let fetchDescriptor = FetchDescriptor<DayStorage>(
            predicate: #Predicate { dayStorage in
                dayStorage.date >= startString
            }
        )

        do {
            let recentWorkouts = try context.fetch(fetchDescriptor)

            // If we have recent workouts, calculate average over 12 weeks
            if !recentWorkouts.isEmpty {
                return Double(recentWorkouts.count) / 12.0
            }

            // If no recent workouts, calculate lifetime average
            let allWorkoutsDescriptor = FetchDescriptor<DayStorage>(
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            let allWorkouts = try context.fetch(allWorkoutsDescriptor)
            guard !allWorkouts.isEmpty else { return 0.0 }

            // Get first and last workout dates
            guard let firstDate = parseDate(allWorkouts.first?.date ?? ""),
                  let _ = parseDate(allWorkouts.last?.date ?? "") else {
                return 0.0
            }

            let daysBetween = calendar.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
            let weeksBetween = max(1, Double(daysBetween) / 7.0) // At least 1 week

            return Double(allWorkouts.count) / weeksBetween
        } catch {
            debugLog("❌ STREAK: Failed to calculate avg workouts: \(error)")
            return 0.0
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()

                List {
                    // MARK: - Hero Card
                    Section {
                        VStack(spacing: 16) {
                            // Animated flame icon
                            Image(systemName: "flame.fill")
                                .font(.system(size: 50))
                                .foregroundColor(streakStatusColor)

                            // Large streak number
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(currentStreak)")
                                    .font(.system(size: 72, weight: .bold))
                                    .foregroundColor(.primary)

                                Text(currentStreak == 1 ? "Day" : "Days")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }

                            // Status badge
                            Text(streakStatus)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(streakStatusColor)
                                )

                            // Days until break warning
                            if !isStreakPaused && currentStreak > 0 && daysUntilStreakBreaks <= 2 {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(daysUntilStreakBreaks == 0 ? "Workout today to preserve streak!" : "Workout within \(daysUntilStreakBreaks) \(daysUntilStreakBreaks == 1 ? "day" : "days")")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .listRowBackground(Color.listRowBackground(for: scheme))

                    // MARK: - Quick Stats Row
                    Section {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                StreakStatCard(
                                    label: "Current",
                                    value: "\(currentStreak)",
                                    icon: "flame.fill",
                                    color: .orange
                                )

                                StreakStatCard(
                                    label: "Record",
                                    value: "\(longestStreak)",
                                    icon: "trophy.fill",
                                    color: .yellow
                                )

                                StreakStatCard(
                                    label: "This Week",
                                    value: "\(thisWeekWorkouts)/7",
                                    icon: "calendar",
                                    color: .green
                                )
                            }

                            HStack(spacing: 12) {
                                StreakStatCard(
                                    label: "Total Hours",
                                    value: "\(config.totalWorkoutTimeMinutes / 60)",
                                    icon: "clock.fill",
                                    color: .blue
                                )

                                StreakStatCard(
                                    label: "Avg/Week",
                                    value: String(format: "%.1f", averageWorkoutsPerWeek),
                                    icon: "chart.bar.fill",
                                    color: .purple
                                )

                                StreakStatCard(
                                    label: "Total Days",
                                    value: "\(totalWorkoutDays)",
                                    icon: "checkmark.circle.fill",
                                    color: appearanceManager.accentColor.color
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)

                    // MARK: - Insights
                    if let insight = generateInsight() {
                        Section("Insight") {
                            HStack(spacing: 12) {
                                Image(systemName: insight.icon)
                                    .font(.title2)
                                    .foregroundColor(insight.color)
                                    .frame(width: 40)

                                Text(insight.message)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.listRowBackground(for: scheme))
                    }

                    // MARK: - Rest Day Configuration
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Rest Days Per Week")
                                    .font(.headline)

                                Spacer()

                                HStack(spacing: 16) {
                                    Button {
                                        updateRestDays(restDaysPerWeek - 1)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(restDaysPerWeek > 0 ? appearanceManager.accentColor.color : .gray)
                                    }
                                    .disabled(restDaysPerWeek <= 0)

                                    Text("\(restDaysPerWeek)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .frame(minWidth: 30)

                                    Button {
                                        updateRestDays(restDaysPerWeek + 1)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(restDaysPerWeek < 7 ? appearanceManager.accentColor.color : .gray)
                                    }
                                    .disabled(restDaysPerWeek >= 7)
                                }
                            }

                            Text("Your streak allows \(restDaysPerWeek) missed \(restDaysPerWeek == 1 ? "day" : "days") per week")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Configuration")
                    }
                    .listRowBackground(Color.listRowBackground(for: scheme))

                    // MARK: - Pause Toggle
                    Section {
                        Toggle(isOn: Binding(
                            get: { isStreakPaused },
                            set: { newValue in
                                toggleStreakPause(newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pause Streak Tracking")
                                    .font(.headline)

                                Text("Preserve your streak during breaks or injuries")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(appearanceManager.accentColor.color)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.listRowBackground(for: scheme))

                    // MARK: - Weekly Pattern Chart
                    Section("Your Weekly Pattern") {
                        WeeklyPatternChart(viewModel: viewModel)
                            .frame(height: 220)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.listRowBackground(for: scheme))

                    // MARK: - Milestones
                    Section("Milestones") {
                        ForEach(getMilestones(), id: \.id) { milestone in
                            MilestoneRow(milestone: milestone, currentStreak: currentStreak, longestStreak: longestStreak)
                        }
                    }
                    .listRowBackground(Color.listRowBackground(for: scheme))
                }
                .navigationTitle("Streak Analytics")
                .navigationBarTitleDisplayMode(.large)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(appearanceManager.accentColor.color)
                        .bold()
                    }
                }

                // MARK: - Toast Notification
                if showSuccessToast {
                    VStack {
                        Spacer()

                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.title3)

                            Text(toastMessage)
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
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSuccessToast)
                    }
                }
            }
        }
        .onAppear {
            // Debug: Check initial state
            debugLog("🔧 STREAK VIEW: Appeared")
            debugLog("🔧 STREAK: Current paused state: \(isStreakPaused)")
            debugLog("🔧 STREAK: Profile exists: \(userProfileManager.currentProfile != nil)")
            if let profile = userProfileManager.currentProfile {
                debugLog("🔧 STREAK: Profile streakPaused value: \(profile.streakPaused)")
            }
        }
    }

    // MARK: - Helper Functions

    private func formattedDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func updateRestDays(_ newValue: Int) {
        let clamped = max(0, min(7, newValue))
        userProfileManager.updateRestDays(clamped)

        toastMessage = "Rest days updated to \(clamped) per week"
        showToast()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func toggleStreakPause(_ paused: Bool) {
        guard let profile = userProfileManager.currentProfile else { return }

        // Update the profile directly
        profile.streakPaused = paused
        profile.markAsUpdated()

        // Save to persist the change
        userProfileManager.saveProfile()

        // Force UI refresh
        userProfileManager.objectWillChange.send()

        // Debug log
        debugLog("🔧 STREAK: Pause toggled to \(paused), saved to profile")

        toastMessage = paused ? "Streak tracking paused" : "Streak tracking resumed"
        showToast()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func showToast() {
        withAnimation {
            showSuccessToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSuccessToast = false
            }
        }
    }

    private func generateInsight() -> StreakInsight? {
        // No workout history yet
        if currentStreak == 0 && longestStreak == 0 {
            return StreakInsight(
                icon: "figure.walk",
                message: "Complete your first workout to start building your streak!",
                color: appearanceManager.accentColor.color
            )
        }

        // Close to record
        if daysFromRecord > 0 && daysFromRecord <= 3 {
            return StreakInsight(
                icon: "trophy.fill",
                message: "You're just \(daysFromRecord) \(daysFromRecord == 1 ? "day" : "days") away from your longest streak!",
                color: .orange
            )
        }

        // New record
        if currentStreak > 0 && currentStreak == longestStreak {
            return StreakInsight(
                icon: "star.fill",
                message: "Congratulations! You've reached a new personal record!",
                color: .yellow
            )
        }

        // Danger zone
        if !isStreakPaused && daysUntilStreakBreaks == 1 {
            return StreakInsight(
                icon: "exclamationmark.triangle.fill",
                message: "Workout today to preserve your \(currentStreak)-day streak!",
                color: .red
            )
        }

        // Weekly pattern
        if thisWeekWorkouts >= 5 {
            return StreakInsight(
                icon: "checkmark.circle.fill",
                message: "Great week! You've worked out \(thisWeekWorkouts) times already.",
                color: .green
            )
        }

        // Paused
        if isStreakPaused {
            return StreakInsight(
                icon: "pause.circle.fill",
                message: "Your streak is paused. Resume tracking when you're ready!",
                color: .gray
            )
        }

        // Default encouragement
        return StreakInsight(
            icon: "flame.fill",
            message: "Keep up the consistency! Every workout counts.",
            color: .orange
        )
    }

    private func getMilestones() -> [StreakMilestone] {
        return [
            StreakMilestone(
                id: "3day",
                title: "3-Day Starter",
                description: "Complete 3 consecutive workouts",
                requiredDays: 3,
                icon: "figure.walk",
                color: .blue
            ),
            StreakMilestone(
                id: "7day",
                title: "7-Day Warrior",
                description: "One full week of consistency",
                requiredDays: 7,
                icon: "flame",
                color: .orange
            ),
            StreakMilestone(
                id: "14day",
                title: "2-Week Champion",
                description: "Two weeks of dedication",
                requiredDays: 14,
                icon: "star.fill",
                color: .yellow
            ),
            StreakMilestone(
                id: "30day",
                title: "30-Day Legend",
                description: "A full month of commitment",
                requiredDays: 30,
                icon: "crown.fill",
                color: .purple
            ),
            StreakMilestone(
                id: "100day",
                title: "100-Day Master",
                description: "Elite level consistency",
                requiredDays: 100,
                icon: "trophy.fill",
                color: .yellow
            )
        ]
    }
}

// MARK: - Supporting Models

struct StreakInsight {
    let icon: String
    let message: String
    let color: Color
}

struct StreakMilestone {
    let id: String
    let title: String
    let description: String
    let requiredDays: Int
    let icon: String
    let color: Color

    var isAchieved: Bool {
        false // Will be computed based on currentStreak
    }
}

// MARK: - Streak Stat Card Component
struct StreakStatCard: View {
    @Environment(\.colorScheme) private var scheme
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.secondaryBackground(for: scheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Milestone Row Component
struct MilestoneRow: View {
    let milestone: StreakMilestone
    let currentStreak: Int
    let longestStreak: Int  // Used to determine if badge was ever earned

    // Badge stays unlocked once earned (based on longest streak ever)
    private var isAchieved: Bool {
        longestStreak >= milestone.requiredDays
    }

    private var progress: Double {
        min(1.0, Double(currentStreak) / Double(milestone.requiredDays))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isAchieved ? milestone.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: milestone.icon)
                    .font(.title3)
                    .foregroundColor(isAchieved ? milestone.color : .gray)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.headline)
                    .foregroundColor(isAchieved ? .primary : .secondary)

                Text(milestone.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Progress bar for locked milestones
                if !isAchieved {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(milestone.color)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(currentStreak)/\(milestone.requiredDays) days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Checkmark or lock
            Image(systemName: isAchieved ? "checkmark.circle.fill" : "lock.fill")
                .font(.title3)
                .foregroundColor(isAchieved ? .green : .gray)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Split.self, configurations: config)
    return StreakDetailView(viewModel: WorkoutViewModel(config: Config(), context: ModelContext(container)))
        .environmentObject(Config())
        .environmentObject(UserProfileManager.shared)
        .environmentObject(AppearanceManager())
}
