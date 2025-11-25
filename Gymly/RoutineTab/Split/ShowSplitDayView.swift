//
//  WorkoutDayView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 13.05.2024.
//

import SwiftUI
import SwiftData

struct ShowSplitDayView: View {
    
    /// State variables for UI control
    @State var name: String = ""
    @State private var createExercise: Bool = false
    @State private var copyWorkout: Bool = false
    @State private var popup: Bool = false
    @State private var days: [Day] = []
    @State var day: Day
    // Reorder mode for exercises across the whole day
    @State private var isReorderingExercises: Bool = false
    @State private var editModeExercises: EditMode = .inactive
    @State private var reorderingBufferExercises: [Exercise] = []
    
    /// Environment and observed objects
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.colorScheme) var scheme
    
    /// Custom initializer
    init(viewModel: WorkoutViewModel, day: Day) {
        self.viewModel = viewModel
        self.day = day
    }
    
    private func orderNumber(for exercise: Exercise) -> Int {
        if let idx = reorderingBufferExercises.firstIndex(where: { $0.id == exercise.id }) {
            return idx + 1
        }
        return 0
    }
    
    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            VStack {
                if isReorderingExercises {
                    // Reorder mode: operate on a buffer to avoid SwiftData/UI conflicts
                    List {
                        ForEach(reorderingBufferExercises, id: \.id) { exercise in
                            HStack {
                                Text("\(orderNumber(for: exercise))")
                                    .foregroundStyle(appearanceManager.accentColor.color)
                                    .bold()
                                Text(exercise.name)
                                Spacer()
                                Text(exercise.muscleGroup)
                                    .foregroundStyle(.secondary)
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .listRowBackground(Color.black.opacity(0.1))
                        }
                        .onMove { indices, newOffset in
                            reorderingBufferExercises.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .environment(\.editMode, $editModeExercises)
                } else {
                    let globalOrderMap: [UUID: Int] = Dictionary(uniqueKeysWithValues: (day.exercises ?? []).map { ($0.id, $0.exerciseOrder) })
                    List {
                        // Build groups from day.exercises while preserving the order of first appearance
                        let grouped: [(String, [Exercise])] = {
                            var order: [String] = []
                            var dict: [String: [Exercise]] = [:]
                            for ex in (day.exercises ?? []).sorted(by: { $0.exerciseOrder < $1.exerciseOrder }) {
                                if dict[ex.muscleGroup] == nil {
                                    order.append(ex.muscleGroup)
                                    dict[ex.muscleGroup] = []
                                }
                                dict[ex.muscleGroup]!.append(ex)
                            }
                            return order.map { ($0, dict[$0]!) }
                        }()
                        
                        ForEach(grouped, id: \.0) { name, exercises in
                            if !exercises.isEmpty {
                                Section(header: Text(name)) {
                                    ForEach(exercises, id: \.id) { exercise in
                                        NavigationLink(destination: ShowSplitDayExerciseView(viewModel: viewModel, exercise: exercise)) {
                                            HStack {
                                                Text("\(globalOrderMap[exercise.id] ?? 0)")
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                Text(exercise.name)
                                            }
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task {
                                                    viewModel.deleteExercise(exercise)
                                                    day = await viewModel.fetchDay(dayOfSplit: day.dayOfSplit)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .listRowBackground(Color.black.opacity(0.1))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(day.name)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    /// Fetch updated day and refresh muscle groups
                    day = await viewModel.fetchDay(dayOfSplit: day.dayOfSplit)
                    await refreshMuscleGroups()
                }
            }
            .alert("Enter workout name", isPresented: $popup) {
                /// Popup for editing the workout name
                TextField("Workout name", text: $day.name)
                Button("OK", action: {})
            } message: {
                Text("Enter the name of new section")
            }
            .sheet(isPresented: $createExercise, onDismiss: {
                Task {
                    day = await viewModel.fetchDay(dayOfSplit: day.dayOfSplit)
                    await refreshMuscleGroups()
                }
            }) {
                CreateExerciseView(viewModel: viewModel, day: viewModel.day)
                    .navigationTitle("Create Exercise")
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $copyWorkout, onDismiss: {
                Task {
                    day = await viewModel.fetchDay(dayOfSplit: day.dayOfSplit)
                    await refreshMuscleGroups()
                }
            }) {
                CopyWorkoutView(viewModel: viewModel, day: day)
                    .navigationTitle("Create Exercise")
                    .presentationDetents([.medium])
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isReorderingExercises {
                        // Show prominent "Done" button when in reorder mode
                        Button {
                            // Commit: write buffer back to the day's exercises and persist once
                            day.exercises = reorderingBufferExercises
                            // Persist explicit order so it survives reloads/fetches
                            for (idx, ex) in reorderingBufferExercises.enumerated() {
                                ex.exerciseOrder = idx + 1
                            }
                            isReorderingExercises = false
                            editModeExercises = .inactive
                            do { try context.save() } catch { debugPrint(error) }
                            // Refetch to ensure UI reflects persisted order
                            Task {
                                day = await viewModel.fetchDay(dayOfSplit: day.dayOfSplit)
                            }
                        } label: {
                            Text("Done")
                                .bold()
                        }
                    } else {
                        // Normal mode: Primary action + Menu

                        // Primary action: Add Exercise (always visible with label)
                        Button {
                            createExercise.toggle()
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                        }

                        // Secondary actions in a menu
                        Menu {
                            Button {
                                popup.toggle()
                            } label: {
                                Label("Edit Name", systemImage: "pencil")
                            }

                            Button {
                                copyWorkout.toggle()
                            } label: {
                                Label("Copy Workout", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button {
                                // Enter: snapshot into buffer using persisted order
                                reorderingBufferExercises = (day.exercises ?? []).sorted { ($0.exerciseOrder) < ($1.exerciseOrder) }
                                isReorderingExercises = true
                                editModeExercises = .active
                            } label: {
                                Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
        }
    }
    
    /// Saves the edited workout name
    func saveDayName() {
        day.name = name
        do {
            try context.save()
        } catch {
            debugPrint(error)
        }
    }
    
    /// Refreshes muscle groups by fetching updated data
    func refreshMuscleGroups() async {
        // Grouping now derives directly from day.exercises in the view; no work needed here.
    }
}
