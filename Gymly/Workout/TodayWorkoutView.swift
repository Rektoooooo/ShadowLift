//
//  TodayWorkoutView.swift
//  ShadowLift
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
    @EnvironmentObject var appearanceManager: AppearanceManager
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
    @State private var isLoadingInitialData = true

    // OPTIMIZATION: Cached grouped exercises to avoid recomputing on every render
    @State private var cachedGroupedExercises: [(String, [Exercise])] = []
    @State private var cachedGlobalOrderMap: [UUID: Int] = [:]

    // Skeleton loading view
    private var skeletonLoadingView: some View {
        WorkoutSkeletonView()
    }

    // Break down complex view for compiler
    private var daySelectionMenu: some View {
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
    }

    private var exercisesList: some View {
        List {
            // OPTIMIZATION: Use cached grouped exercises instead of recalculating
            ForEach(cachedGroupedExercises, id: \.0) { name, exercises in
                if !exercises.isEmpty {
                    Section(header: Text(name)) {
                        ForEach(exercises, id: \.id) { exercise in
                            NavigationLink(destination: ExerciseDetailView(viewModel: viewModel, exercise: exercise)) {
                                HStack {
                                    Text("\(cachedGlobalOrderMap[exercise.id] ?? 0)")
                                        .foregroundStyle(exercise.done ? Color.green.opacity(0.8) : appearanceManager.accentColor.color.opacity(0.8))
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

                        // Clear timestamps and reset done flags for next workout
                        if let exercises = selectedDay.exercises {
                            for i in exercises.indices {
                                exercises[i].done = false

                                // Clear all set timestamps for fresh next workout
                                if let sets = exercises[i].sets {
                                    for j in sets.indices {
                                        exercises[i].sets?[j].time = ""
                                    }
                                }
                            }
                        }
                        debugPrint("🧹 CLEANUP: Cleared all set timestamps for next workout")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                .foregroundStyle(appearanceManager.accentColor.color)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listRowBackground(Color.clear)
    }

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()

                // Fade transition wrapper
                ZStack {
                    if isLoadingInitialData {
                        /// Show skeleton loading while data is being fetched
                        skeletonLoadingView
                            .transition(.opacity)
                            .zIndex(1)
                    } else if !selectedDay.name.isEmpty {
                        VStack {
                            daySelectionMenu
                            exercisesList
                        }
                        .transition(.opacity)
                        .zIndex(2)
                    } else {
                        /// If no split is created show help message
                        VStack {
                            Text("Create your split with the \(Image(systemName: "line.2.horizontal.decrease.circle")) icon in the top right corner")
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isLoadingInitialData)
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
                /// OPTIMIZATION: Only update cache when exercises are added
                /// (refreshView() already handles cache updates for other changes)
                .onChange(of: viewModel.exerciseAddedTrigger) {
                    #if DEBUG
                    debugPrint("🔄 TODAYWORKOUTVIEW: Exercise added, updating cache")
                    #endif
                    updateCachedGroupedExercises()
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
                // OPTIMIZATION: Load profile image only on initial appear
                await loadProfileImage()

                // Don't call loadOrCreateProfile here - it's already loaded during sign-in
                // and calling it again will overwrite CloudKit data with default values
                await refreshView()
//                if WhatsNewManager.shouldShowWhatsNew && config.isUserLoggedIn {
//                    showWhatsNew = true
//                }
            }
            .onDisappear {
                // OPTIMIZATION: Cleanup to prevent memory leaks
                // Cancel any ongoing tasks and clear cached data
                #if DEBUG
                debugPrint("🧹 TODAYWORKOUTVIEW: View disappeared, cleaning up")
                #endif
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
                // OPTIMIZATION: Only reload profile image if weight unit changed (affects display)
                // No need to refresh muscle groups - they don't change from profile edits
                Task { @MainActor in
                    await loadProfileImage()
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
            .onChange(of: showWorkoutSummary) { _, isShowing in
                // Clear summary data when sheet is dismissed to allow showing it again
                if !isShowing {
                    workoutSummaryData = nil
                    print("🧹 WORKOUT SUMMARY: Sheet dismissed, cleared summary data")
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
        #if DEBUG
        print("🔄 TODAYWORKOUTVIEW: Starting refreshView")
        #endif

        // OPTIMIZATION: Fetch split days only ONCE (was being fetched twice before!)
        let splitDays = viewModel.getActiveSplitDays()
        #if DEBUG
        print("🔄 TODAYWORKOUTVIEW: Found \(splitDays.count) split days")
        #endif

        config.dayInSplit = viewModel.updateDayInSplit()
        config.lastUpdateDate = Date()  // Track last update time

        #if DEBUG
        print("🔧 TODAYWORKOUTVIEW: config.dayInSplit = \(config.dayInSplit)")
        print("🔧 TODAYWORKOUTVIEW: Available days: \(splitDays.map { "Day \($0.dayOfSplit): \($0.name)" }.joined(separator: ", "))")
        #endif

        // OPTIMIZATION: Filter split days directly instead of calling fetchDay()
        // which would call getActiveSplitDays() again (duplicate query)
        let updatedDay = splitDays.first(where: { $0.dayOfSplit == config.dayInSplit }) ?? Day(name: "", dayOfSplit: 0, exercises: [], date: "")
        #if DEBUG
        print("🔄 TODAYWORKOUTVIEW: Updated day: '\(updatedDay.name)', exercises: \(updatedDay.exercises?.count ?? 0)")
        #endif

        // Update all state variables together with animation to ensure UI updates
        withAnimation {
            allSplitDays = splitDays
            selectedDay = updatedDay
            viewModel.day = updatedDay
            #if DEBUG
            print("🔄 TODAYWORKOUTVIEW: Set selectedDay to '\(selectedDay.name)'")
            #endif
        }

        // OPTIMIZATION: Update cached grouped exercises after day changes
        updateCachedGroupedExercises()

        // OPTIMIZATION: Only refresh muscle groups if not already done by cache update
        // refreshMuscleGroups() does additional sorting but cache already has the data

        // Mark initial data loading as complete
        isLoadingInitialData = false

        #if DEBUG
        print("🔄 TODAYWORKOUTVIEW: Refresh complete")
        #endif
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

    /// OPTIMIZATION: Compute and cache grouped exercises
    @MainActor
    private func updateCachedGroupedExercises() {
        debugPrint("[OPTIMIZATION] Computing cached grouped exercises")

        // Build global order map
        cachedGlobalOrderMap = Dictionary(uniqueKeysWithValues: (selectedDay.exercises ?? []).map { ($0.id, $0.exerciseOrder) })

        // Build groups from selectedDay.exercises while preserving the order of first appearance
        var order: [String] = []
        var dict: [String: [Exercise]] = [:]
        for ex in (selectedDay.exercises ?? []).sorted(by: { $0.exerciseOrder < $1.exerciseOrder }) {
            if dict[ex.muscleGroup] == nil {
                order.append(ex.muscleGroup)
                dict[ex.muscleGroup] = []
            }
            dict[ex.muscleGroup]!.append(ex)
        }
        cachedGroupedExercises = order.map { ($0, dict[$0]!) }

        debugPrint("[OPTIMIZATION] Cached \(cachedGroupedExercises.count) muscle groups with \(selectedDay.exercises?.count ?? 0) total exercises")
    }
}
