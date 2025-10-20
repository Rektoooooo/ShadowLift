//
//  ExerciseDetailView.swift
//  Gymly
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
                Form {
                    /// List of exercise sets
                    ForEach(Array((exercise.sets ?? []).sorted(by: { $0.createdAt < $1.createdAt }).enumerated()), id: \.element.id) { index, set in
                        SetCell(
                            viewModel: viewModel,
                            index: index,
                            set: set,
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
                        .swipeActions(edge: .trailing) {
                            /// Swipe-to-delete action for a set
                            Button(role: .destructive) {
                                viewModel.deleteSet(set, exercise: exercise)
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

                            // Update muscle group chart data when exercise is completed
                            Task {
                                    viewModel.updateMuscleGroupDataValues(
                                    from: [exercise],
                                    modelContext: context
                                )
                            }

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
}

