//
//  SplitTemplatesView.swift
//  ShadowLift
//
//  Created by Claude Code on 26.10.2025.
//

import SwiftUI
import SwiftData

struct SplitTemplatesView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var config: Config

    @State private var selectedTemplate: SplitTemplate?
    @State private var showTemplateDetail = false
    @State private var showPremiumSheet = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.accent(scheme, accentColor: appearanceManager.accentColor))
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Templates")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.primary)

                            Text("Science-backed splits designed by professionals")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                        // Templates List - Now with lazy loading
                        ForEach(SplitTemplate.allTemplates) { template in
                            TemplateCard(template: template, isPremiumUser: config.isPremium) {
                                selectedTemplate = template
                                if config.isPremium {
                                    showTemplateDetail = true
                                } else {
                                    showPremiumSheet = true
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(scheme == .dark ? .white : .primary)
                }
            }
            .sheet(isPresented: $showTemplateDetail) {
                if let template = selectedTemplate {
                    TemplateDetailView(
                        template: template,
                        viewModel: viewModel,
                        onAdd: {
                            addTemplateToSplits(template)
                            showTemplateDetail = false
                            dismiss()
                        }
                    )
                }
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumSubscriptionView()
            }
            .alert("Failed to Add Template", isPresented: $showSaveError) {
                Button("OK") {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    /// Converts template to actual Split and saves to database
    private func addTemplateToSplits(_ template: SplitTemplate) {
        // Deactivate all existing splits
        viewModel.deactivateAllSplits()

        // Create new split from template
        let newSplit = Split(
            name: template.name,
            days: [],
            isActive: true,
            startDate: Date()
        )

        // Create days from template
        var createdDays: [Day] = []
        for templateDay in template.days {
            let day = Day(
                name: templateDay.name,
                dayOfSplit: templateDay.dayNumber,
                exercises: [],
                date: DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none),
                split: newSplit
            )

            // Create exercises from template
            var createdExercises: [Exercise] = []
            for templateExercise in templateDay.exercises {
                let exercise = Exercise(
                    name: templateExercise.name,
                    sets: [],
                    repGoal: templateExercise.reps,
                    muscleGroup: templateExercise.muscleGroup,
                    exerciseOrder: templateExercise.exerciseOrder,
                    day: day
                )

                context.insert(exercise)

                // Create placeholder sets based on template
                var exerciseSets: [Exercise.Set] = []
                for _ in 1...templateExercise.sets {
                    let set = Exercise.Set.createDefault()
                    set.exercise = exercise
                    context.insert(set)
                    exerciseSets.append(set)
                }

                exercise.sets = exerciseSets
                createdExercises.append(exercise)
            }

            day.exercises = createdExercises
            context.insert(day)
            createdDays.append(day)
        }

        newSplit.days = createdDays
        context.insert(newSplit)

        // Save context
        do {
            try context.save()
            debugLog("✅ Template '\(template.name)' added to splits")
            dismiss()
        } catch {
            debugLog("❌ Error saving template: \(error)")
            saveErrorMessage = "Could not save '\(template.name)'. Please try again."
            showSaveError = true
        }
    }
}

// MARK: - Template Card Component

struct TemplateCard: View {
    let template: SplitTemplate
    let isPremiumUser: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager

    var body: some View {
        Button(action: {
            // Haptic feedback for better UX
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.title3)
                            .bold()
                            .foregroundColor(.primary)

                        Text(template.targetUser)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if template.isPremium && !isPremiumUser {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                    }
                }

                // Description
                Text(template.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Stats
                HStack(spacing: 20) {
                    StatBadge(icon: "calendar", text: template.frequency)
                    StatBadge(icon: "target", text: template.goal)
                    StatBadge(icon: "list.bullet", text: "\(template.days.count) days")
                }

                // CTA
                HStack {
                    Spacer()
                    Text("View Details")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(appearanceManager.accentColor.color)
                    Image(systemName: "arrow.right")
                        .foregroundColor(appearanceManager.accentColor.color)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(scheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(appearanceManager.accentColor.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    let template: SplitTemplate
    @ObservedObject var viewModel: WorkoutViewModel
    let onAdd: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager

    @State private var showConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
                // Removed duplicate FloatingClouds - parent view already renders it
                Color.clear
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Info
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(template.name)
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(.primary)

                                Spacer()
                            }

                            Text(template.description)
                                .font(.body)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                InfoPill(icon: "person.fill", text: template.targetUser, color: .blue)
                                InfoPill(icon: "calendar", text: template.frequency, color: .green)
                                InfoPill(icon: "target", text: template.goal, color: .orange)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.3))
                        )

                        // Days Breakdown
                        LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                            Text("Split Breakdown")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.primary)

                            ForEach(template.days) { day in
                                DayCard(day: day)
                            }
                        }

                        // Add Button
                        Button(action: {
                            showConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to My Splits")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(appearanceManager.accentColor.color)
                            .foregroundColor(.black)
                            .cornerRadius(15)
                        }
                        .padding(.vertical)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(scheme == .dark ? .white : .primary)
                }
            }
            .alert("Add Template?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    onAdd()
                }
            } message: {
                Text("This will deactivate your current split and activate '\(template.name)'. You can switch back anytime.")
            }
        }
    }
}

struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .bold()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

struct DayCard: View {
    let day: SplitTemplateDay
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day \(day.dayNumber): \(day.name)")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(day.exercises.count) exercises")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(scheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                )
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(day.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(scheme == .dark ? Color.black.opacity(0.1) : Color.white.opacity(0.4))
                )
            }
        }
    }
}

// MARK: - Exercise Row Component (Extracted for Performance)

struct ExerciseRow: View {
    let exercise: SplitTemplateExercise
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager

    var body: some View {
        HStack {
            Circle()
                .fill(appearanceManager.accentColor.color)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("\(exercise.sets) sets × \(exercise.reps) reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(exercise.muscleGroup)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                .foregroundColor(.secondary)
                .cornerRadius(6)
        }
        .padding(.horizontal)
    }
}
