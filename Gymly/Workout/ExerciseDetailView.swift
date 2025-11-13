//
//  ExerciseDetailView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera.
//

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {

    /// Environment and observed objects
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @State var exercise: Exercise
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var userProfileManager: UserProfileManager


    /// Sheet management for set editing
    @State private var showSetEditSheet = false
    @State private var selectedSet: Exercise.Set?

    // OPTIMIZATION: Cached sorted sets to avoid recomputing on every render
    @State private var cachedSortedSets: [(index: Int, set: Exercise.Set)] = []

    // PR tracking
    @State private var personalRecords: ExercisePR?
    @StateObject private var prManager = PRManager.shared

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            VStack {
                /// Displays set and rep count
                HStack {
                    Text("\(exercise.sets?.count ?? 0) Sets")
                        .foregroundStyle(appearanceManager.accentColor.color)
                        .padding()
                        .bold()
                    Spacer()
                    Text("\(exercise.repGoal) Reps")
                        .foregroundStyle(appearanceManager.accentColor.color)
                        .padding()
                        .bold()
                }

                /// PR Display Header
                if let pr = personalRecords, pr.hasPRs, let display = pr.displayPR {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.yellow)
                            .font(.caption)

                        Text("Best:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let weightUnit = userProfileManager.currentProfile?.weightUnit ?? "Kg"
                        let displayWeight = weightUnit == "Kg" ? display.value : display.value * 2.20462262

                        Text("\(String(format: "%.1f", displayWeight)) \(weightUnit)")
                            .font(.caption)
                            .bold()

                        Text("×")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(display.reps) reps")
                            .font(.caption)
                            .bold()

                        Spacer()

                        if let date = pr.bestWeightDate {
                            Text(date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                Form {
                    /// List of exercise sets - OPTIMIZATION: Use cached sorted sets
                    ForEach(cachedSortedSets, id: \.set.id) { item in
                        SetCell(
                            viewModel: viewModel,
                            index: item.index,
                            set: item.set,
                            config: config,
                            exercise: exercise,
                            setForCalendar: false,
                            onSetTap: { tappedSet in
                                print("📱 ExerciseDetailView received set tap for set ID: \(tappedSet.id)")
                                selectedSet = tappedSet
                                showSetEditSheet = true
                            }
                        )
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .listRowBackground(Color.black.opacity(0.1))
                        .swipeActions(edge: .leading) {
                            Button {
                                markSetAsDone(item.set)
                            } label: {
                                Label("Done", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            /// Swipe-to-delete action for a set
                            Button(role: .destructive) {
                                viewModel.deleteSet(item.set, exercise: exercise)
                                // OPTIMIZATION: Update cache after deletion
                                updateCachedSortedSets()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                        }
                    }
                    /// Dismiss button
                    Section("") {
                        Button("Done") {
                            config.activeExercise = exercise.exerciseOrder + 1
                            exercise.done = true
                            exercise.completedAt = Date() // Set completion time to now

                            // Graph will be updated when "Workout done" is tapped
                            // No need to update here to avoid double-counting

                            dismiss()
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .listRowBackground(Color.black.opacity(0.1))
                        .foregroundStyle(appearanceManager.accentColor.color)
                    }
                }
                .toolbar {
                    /// Add set button
                    Button {
                        let exerciseID = exercise.id
                        Task { @MainActor in
                            let fetchedExercise = await viewModel.fetchExercise(id: exerciseID)
                            _ = await viewModel.addSet(exercise: fetchedExercise)
                        }
                    } label: {
                        Label("Add set", systemImage: "plus.circle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            .navigationTitle("\(exercise.name)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // OPTIMIZATION: Initialize cached sorted sets on appear
                updateCachedSortedSets()

                // Disable CloudKit sync during active workout to prevent lag
                CloudKitManager.shared.setWorkoutSessionActive(true)

                // Load PR for this exercise
                Task {
                    personalRecords = await prManager.getPR(for: exercise.name)
                }
            }
            .onDisappear {
                // Re-enable CloudKit sync when leaving workout view
                CloudKitManager.shared.setWorkoutSessionActive(false)
            }
            .onChange(of: exercise.sets?.count) { _, _ in
                // OPTIMIZATION: Update cache only when set count changes (add/delete)
                // No need to update on every sheet dismiss since SwiftData auto-updates
                #if DEBUG
                debugPrint("🔄 EXERCISEDETAILVIEW: Set count changed, updating cache")
                #endif
                updateCachedSortedSets()
            }
            .sheet(isPresented: $showSetEditSheet) {
                if let selectedSet = selectedSet {
                    EditExerciseSetView(
                        targetSet: selectedSet,
                        exercise: exercise,
                        unit: .constant(userProfileManager.currentProfile?.weightUnit ?? "Kg")
                    )
                    .presentationDetents([.fraction(0.68)])
                    .onAppear {
                        print("📱 EditExerciseSetView appeared for set ID: \(selectedSet.id)")
                    }
                    .onDisappear {
                        print("📱 EditExerciseSetView disappeared for set ID: \(selectedSet.id)")
                    }
                }
            }
        }
    }
    
    /// Refreshes the exercise data
    func refreshExercise() {
        Task {
            exercise = await viewModel.fetchExercise(id: exercise.id)
        }
    }

    /// OPTIMIZATION: Compute and cache sorted sets
    private func updateCachedSortedSets() {
        let sortedSets = (exercise.sets ?? []).sorted(by: { $0.createdAt < $1.createdAt })
        cachedSortedSets = sortedSets.enumerated().map { (index: $0.offset, set: $0.element) }
        debugPrint("[OPTIMIZATION] Cached \(cachedSortedSets.count) sorted sets for exercise '\(exercise.name)'")
    }

    /// Quick mark set as done via swipe action
    private func markSetAsDone(_ targetSet: Exercise.Set) {
        Task { @MainActor in
            // Fetch fresh exercise to ensure we have latest data
            let exerciseId = exercise.id
            let freshExercise = await viewModel.fetchExercise(id: exerciseId)

            guard let freshSets = freshExercise.sets,
                  let setIndex = freshSets.firstIndex(where: { $0.id == targetSet.id }) else {
                debugPrint("❌ Set not found in exercise")
                return
            }

            // Get fresh set reference
            let freshSet = freshSets[setIndex]

            // Mark as done by setting timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "H:mm"
            freshSet.time = dateFormatter.string(from: Date()).lowercased()

            // PERFORMANCE: Don't save to disk during active workout
            // SwiftData keeps changes in memory - they'll be persisted when workout completes
            debugPrint("✅ Quick marked set as done - Weight: \(freshSet.weight), Reps: \(freshSet.reps), Time: \(freshSet.time)")
            debugPrint("💡 Changes in memory, will save when workout completes")

            // Update local exercise reference
            exercise = freshExercise

            // Update cache to reflect changes
            updateCachedSortedSets()
        }
    }
}

