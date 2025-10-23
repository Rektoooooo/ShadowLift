//
//  ShowSplitDayExerciseView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 09.02.2025.
//


import SwiftUI
import SwiftData

struct ShowSplitDayExerciseView: View {

    /// Environment and observed objects
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @State var exercise: Exercise
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var userProfileManager: UserProfileManager

    /// UI State Variables
    @State var showSheet = false
    @State var sheetType: SheetType?
    @State var selectedSet: Exercise.Set?

    enum SheetType {
        case editExercise
        case editSet(Exercise.Set)
    }
    
    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
        VStack {
            /// Displays set and rep count
            HStack {
                Text("\((exercise.sets ?? []).count) Sets")
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
                        setForCalendar: true
                    )
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                    .swipeActions(edge: .trailing) {
                        /// Swipe-to-delete action for a set
                        Button(role: .destructive) {
                            viewModel.deleteSet(set, exercise: exercise)
                            refreshExercise()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                /// Dismiss button
                Section("") {
                    Button("Done") {
                        dismiss()
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
        }
        }
        .sheet(isPresented: $showSheet) {
            switch sheetType {
            case .editExercise:
                EditExerciseView(viewModel: viewModel, exercise: exercise)
                    .presentationDetents([.large])
            case .editSet(let set):
                EditExerciseSetView(
                    targetSet: set,
                    exercise: exercise,
                    unit: .constant(userProfileManager.currentProfile?.weightUnit ?? "Kg")
                )
                .onAppear {
                    print("📱 EditExerciseSetView appeared for set ID: \(set.id)")
                }
                .onDisappear {
                    print("📱 EditExerciseSetView disappeared for set ID: \(set.id)")
                }
            case .none:
                EmptyView()
            }
        }
        .toolbar {
            /// Edit exercise button
            Button {
                sheetType = .editExercise
                showSheet = true
            } label: {
                Label("Edit exercise", systemImage: "slider.horizontal.3")
            }
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
        .navigationTitle("\(exercise.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Refreshes the exercise data
    func refreshExercise() {
        Task {
            exercise = await viewModel.fetchExercise(id: exercise.id)
        }
    }
}
