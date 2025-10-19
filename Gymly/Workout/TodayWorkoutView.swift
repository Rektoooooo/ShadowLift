//
//  TodayWorkoutView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 20.08.2024.
//

import SwiftUI
import Foundation
import SwiftData
import Combine

struct WorkoutSummaryData {
    let completedExercises: [Exercise]
    let workoutDurationMinutes: Int
    let startTime: String
    let endTime: String
}

struct TodayWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.colorScheme) var scheme
    @State var showProfileView: Bool = false
    let loginRefreshTrigger: Bool
    @State private var profileImage: UIImage?
    @State private var navigationTitle: String = ""
    @State var muscleGroups:[MuscleGroup] = []
    @State var selectedDay: Day = Day(name: "", dayOfSplit: 0, exercises: [], date: "")
    @State var allSplitDays: [Day] = []
    @State private var showWhatsNew = false
    @State var orderExercises: [String] = []
    @State private var showWorkoutSummary = false
    @State private var workoutSummaryData: WorkoutSummaryData?
    
    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                VStack {
                    if !selectedDay.name.isEmpty {
                        VStack {
                            /// Display the navigation title with menu day selection
                            Menu {
                                ForEach(allSplitDays.sorted(by: { $0.dayOfSplit < $1.dayOfSplit }), id: \.self) { day in
                                    Button(action: {
                                        selectedDay = day
                                        viewModel.day = selectedDay
                                        config.dayInSplit = day.dayOfSplit
                                        Task { @MainActor in
                                            await refreshView()
                                        }
                                    }) {
                                        HStack {
                                            Text("\(day.dayOfSplit) - \(day.name)")
                                            if day == selectedDay {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(selectedDay.name)")
                                        .font(.largeTitle)
                                        .bold()
                                        .padding(.leading)
                                    Text(Image(systemName: "chevron.down"))
                                        .font(.title2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                                .foregroundStyle(Color.primary)
                            }
                            /// Display exercises in a day
                            let globalOrderMap: [UUID: Int] = Dictionary(uniqueKeysWithValues: (selectedDay.exercises ?? []).map { ($0.id, $0.exerciseOrder) })
                            List {
                                ForEach(muscleGroups) { group in
                                    if !group.exercises.isEmpty {
                                        Section(header: Text(group.name)) {
                                            ForEach(group.exercises.sorted(by: { $0.exerciseOrder < $1.exerciseOrder }), id: \.id) { exercise in
                                                NavigationLink(destination: ExerciseDetailView(viewModel: viewModel, exercise: exercise)) {
                                                    HStack {
                                                        Text("\(globalOrderMap[exercise.id] ?? 0)")
                                                            .foregroundStyle(exercise.done ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                                                        Text(exercise.name)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .listRowBackground(Color.black.opacity(0.1))
                                /// Save workout to the calendar button
                                Section("") {
                                    Button("Workout done") {
                                        // Calculate workout summary before clearing exercises
                                        if let summaryData = calculateWorkoutDuration() {
                                            workoutSummaryData = summaryData
                                            // Add workout duration to total time
                                            config.totalWorkoutTimeMinutes += summaryData.workoutDurationMinutes
                                            showWorkoutSummary = true
                                        }

                                        Task { @MainActor in
                                            // Set completion time for all done exercises
                                            let now = Date()
                                            let doneCount = selectedDay.exercises?.filter { $0.done }.count ?? 0
                                            debugPrint("🏃‍♂️ WORKOUT DONE: \(doneCount) exercises marked as done")

                                            if let exercises = selectedDay.exercises {
                                                for i in exercises.indices {
                                                    if exercises[i].done {
                                                        exercises[i].completedAt = now
                                                    }
                                                }
                                            }

                                            viewModel.updateMuscleGroupDataValues(from: selectedDay.exercises ?? [], modelContext: context)
                                            await viewModel.insertWorkout(from: selectedDay)
                                            if let exercises = selectedDay.exercises {
                                                for i in exercises.indices {
                                                    exercises[i].done = false
                                                }
                                            }
                                        }
                                    }
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .listRowBackground(Color.black.opacity(0.1))
                                    .foregroundStyle(Color.accentColor)
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        /// If no split is created show help message
                        VStack {
                            Text("Create your split with the \(Image(systemName: "line.2.horizontal.decrease.circle")) icon in the top right corner")
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .toolbar {
                    /// Display user profile image as a button for getting to setting view
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showProfileView = true
                        }) {
                            ProfileImageCell(profileImage: profileImage, frameSize: 34)
                        }
                    }
                    /// Button for showing splits view
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.editPlan = true
                        } label: {
                            Label("", systemImage: "line.2.horizontal.decrease.circle")
                        }
                    }
                    /// Button for adding exercise
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.addExercise = true
                        } label: {
                            Label("", systemImage: "plus.circle")
                        }
                    }
                }
                /// On change of adding exercise refresh the exercises
                .onChange(of: viewModel.exerciseAddedTrigger) {
                    Task { @MainActor in
                        await refreshMuscleGroups()
                    }
                }
                .onReceive(Publishers.Merge(
                    NotificationCenter.default.publisher(for: Notification.Name.importSplit),
                    NotificationCenter.default.publisher(for: Notification.Name.cloudKitDataSynced)
                )) { notification in
                    Task { @MainActor in
                        if notification.name == .cloudKitDataSynced {
                            print("🔄 REFRESH: CloudKit sync completed, refreshing TodayWorkoutView")
                        }
                        await refreshView()
                    }
                }
            }
            /// Refresh on every appear
            .task {
                // Don't call loadOrCreateProfile here - it's already loaded during sign-in
                // and calling it again will overwrite CloudKit data with default values
                await refreshView()
//                if WhatsNewManager.shouldShowWhatsNew && config.isUserLoggedIn {
//                    showWhatsNew = true
//                }
            }
            /// Refresh when user logs in
            .onChange(of: loginRefreshTrigger) {
                Task { @MainActor in
                    await refreshView()
                    // Also refresh profile image after login/CloudKit sync
                    await loadProfileImage()
                    print("🖼️ PROFILE: Refreshed profile image after login")
                }
            }
            /// Sheet for showing splits view
            .sheet(isPresented: $viewModel.editPlan, onDismiss: {
                Task { @MainActor in
                    await refreshView()
                    navigationTitle = viewModel.day.name
                }
            }) {
                SplitsView(viewModel: viewModel)
            }
            /// Sheet for showing profile view
            .sheet(isPresented: $showProfileView, onDismiss: {
                Task { @MainActor in
                    await loadProfileImage()
                    await refreshMuscleGroups()
                }
            }) {
                ProfileView(viewModel: viewModel)
            }
            /// Sheet for adding exercises
            .sheet(isPresented: $viewModel.addExercise, onDismiss: {
                Task { @MainActor in
                    await refreshView()
                }
                viewModel.name = ""
                viewModel.sets = ""
                viewModel.reps = ""
            } ,content: {
                CreateExerciseView(viewModel: viewModel, day: selectedDay)
                    .navigationTitle("Create Exercise")
                    .presentationDetents([.medium])
                
            })
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView(isPresented: $showWhatsNew)
            }
            .sheet(isPresented: $showWorkoutSummary) {
                if let summaryData = workoutSummaryData {
                    WorkoutSummaryView(
                        completedExercises: summaryData.completedExercises,
                        workoutDurationMinutes: summaryData.workoutDurationMinutes,
                        startTime: summaryData.startTime,
                        endTime: summaryData.endTime
                    )
                }
            }
        }
    }
    
    // TODO: When adding exercise, adding new exercise into new muscle group works fine with animation and everything, but when adding second exercise to already existing muscle group there is no animation Sadge
    
    /// Func for refreshing exercises so UI updates correctly
    @MainActor
    func refreshMuscleGroups() async {
        let newMuscleGroups = await viewModel.sortData(dayOfSplit: config.dayInSplit)
        await MainActor.run {
            withAnimation {
                for newGroup in newMuscleGroups {
                    if let index = muscleGroups.firstIndex(where: { $0.id == newGroup.id }) {
                        muscleGroups[index] = MuscleGroup(id: newGroup.id, name: newGroup.name, exercises: newGroup.exercises)
                    } else {
                        muscleGroups.append(newGroup)
                    }
                }
                muscleGroups.removeAll { oldGroup in
                    !newMuscleGroups.contains(where: { $0.id == oldGroup.id })
                }
            }
        }
    }
    
    /// Func for keeping up view up to date
    @MainActor
    func refreshView() async {
        print("🔄 TODAYWORKOUTVIEW: Starting refreshView")

        let splitDays = viewModel.getActiveSplitDays()
        print("🔄 TODAYWORKOUTVIEW: Found \(splitDays.count) split days")

        config.dayInSplit = viewModel.updateDayInSplit()
        config.lastUpdateDate = Date()  // Track last update time

        let updatedDay = await viewModel.fetchDay(dayOfSplit: config.dayInSplit)
        print("🔄 TODAYWORKOUTVIEW: Updated day: '\(updatedDay.name)', exercises: \(updatedDay.exercises?.count ?? 0)")

        // Update all state variables together with animation to ensure UI updates
        withAnimation {
            allSplitDays = splitDays
            selectedDay = updatedDay
            viewModel.day = updatedDay
            print("🔄 TODAYWORKOUTVIEW: Set selectedDay to '\(selectedDay.name)'")
        }

        await loadProfileImage()
        await refreshMuscleGroups()
        print("🔄 TODAYWORKOUTVIEW: Refresh complete")
    }

    /// Calculates workout duration from first completed set to last completed set
    private func calculateWorkoutDuration() -> WorkoutSummaryData? {
        let completedExercises = (selectedDay.exercises ?? []).filter { $0.done }

        guard !completedExercises.isEmpty else { return nil }

        var allCompletedSets: [(time: String, date: Date)] = []

        // Collect all sets from completed exercises with their times
        for exercise in completedExercises {
            for set in exercise.sets ?? [] {
                if !set.time.isEmpty {
                    // Parse time string "H:mm" and create date for today
                    let timeComponents = set.time.split(separator: ":").map(String.init)
                    if timeComponents.count == 2,
                       let hour = Int(timeComponents[0]),
                       let minute = Int(timeComponents[1]) {

                        let calendar = Calendar.current
                        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                        dateComponents.hour = hour
                        dateComponents.minute = minute

                        if let setDate = calendar.date(from: dateComponents) {
                            allCompletedSets.append((time: set.time, date: setDate))
                        }
                    }
                }
            }
        }

        guard !allCompletedSets.isEmpty else { return nil }

        // Sort by date to find first and last
        allCompletedSets.sort { $0.date < $1.date }

        let startTime = allCompletedSets.first!.time
        let endTime = allCompletedSets.last!.time
        let startDate = allCompletedSets.first!.date
        let endDate = allCompletedSets.last!.date

        // Calculate duration in minutes
        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)

        return WorkoutSummaryData(
            completedExercises: completedExercises,
            workoutDurationMinutes: max(durationMinutes, 1), // At least 1 minute
            startTime: startTime,
            endTime: endTime
        )
    }

    /// Load profile image from UserProfile
    @MainActor
    private func loadProfileImage() async {
        profileImage = userProfileManager.currentProfile?.profileImage
    }
}
