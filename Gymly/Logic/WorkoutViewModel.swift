//
//  WorkoutViewModel.swift
//  Gymly
//
//  Created by Sebastián Kučera on 23.10.2024.
//

import Foundation
import SwiftData
import SwiftUI
import AuthenticationServices
import HealthKit
import CloudKit

final class WorkoutViewModel: ObservableObject {
    @Published var days: [Day] = []
    @Published var exercises:[Exercise] = []
    @Published var day:Day = Day(name: "", dayOfSplit: 0, exercises: [],date: "")
    @Published var muscleGroups:[MuscleGroup] = []
    @Published var editPlan:Bool = false
    @Published var addExercise:Bool = false
    @Published var exerciseAddedTrigger = false
    @Published var muscleGroupNames:[String] = ["Chest","Back","Biceps","Triceps","Shoulders","Quads","Hamstrings","Calves","Glutes","Abs"]
    @Published var exerciseId: UUID? = nil
    @Published var name:String = ""
    @Published var sets:String = ""
    @Published var reps:String = ""
    @Published var setNote:String = ""
    @Published var muscleGroup:String = "Chest"
    @Published var emptyDay: Day = Day(name: "", dayOfSplit: 0, exercises: [], date: "")
    @Published var activeExercise: Int = 1
    enum MuscleGroupEnum: String, CaseIterable, Identifiable {
        case chest, back, biceps, triceps, shoulders, quads, hamstrings, calves, glutes, abs
        
        var id: String { self.rawValue }
    }
    
    enum InsertionError: Error {
        case invalidReps(String)
        case invalidIndex(String)
    }
    var config: Config
    var context: ModelContext
    var userProfileManager: UserProfileManager?

    init(config: Config, context: ModelContext) {
        self.config = config
        self.context = context
    }

    func setUserProfileManager(_ manager: UserProfileManager) {
        self.userProfileManager = manager
    }

    // MARK: - TESTING ONLY - Remove before production
    /// Test helper: Simulate workout on a specific date
    @MainActor
    func testSimulateWorkout(daysAgo: Int) {
        let calendar = Calendar.current
        let simulatedDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!

        print("🧪 TEST: Simulating workout \(daysAgo) days ago (date: \(formattedDateString(from: simulatedDate)))")

        userProfileManager?.calculateStreak(workoutDate: simulatedDate)
    }
    
    // MARK: Split related funcs
    /// Create new split
    @MainActor
    func createNewSplit(name: String, numberOfDays: Int, startDate: Date, context: ModelContext) {
        print("🔧 Starting createNewSplit with name: \(name), days: \(numberOfDays)")

        var days: [Day] = []

        for i in 1...numberOfDays {
            let day = Day(name: "Day \(i)", dayOfSplit: i, exercises: [], date: "")
            days.append(day)
            print("🔧 Created day: \(day.name)")
        }

        print("🔧 Creating split with \(days.count) days")

        let newSplit = Split(name: name, days: days.isEmpty ? [] : days, isActive: false, startDate: startDate)
        print("🔧 Split created, inserting into context...")
        context.insert(newSplit)

        // Also insert each day into the context
        for day in days {
            print("🔧 Inserting day: \(day.name)")
            context.insert(day)
        }

        do {
            print("🔧 Attempting to save context...")
            try context.save()
            print("✅ New split '\(name)' created and saved.")

            // Verify the split was actually saved
            let allSplitsAfterSave = getAllSplits()
            print("🔧 After initial save: found \(allSplitsAfterSave.count) total splits")
            for split in allSplitsAfterSave {
                print("🔧 Found split: \(split.name), active: \(split.isActive)")
            }

            // Now switch it to active AFTER it's been saved
            print("🔧 Switching to active split...")
            switchActiveSplit(split: newSplit, context: context)

            // Verify the split is now active
            print("🔧 Verifying active split...")
            if let activeSplit = getActiveSplit() {
                print("✅ Verified active split: \(activeSplit.name)")

                // Force UI refresh by triggering objectWillChange
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            } else {
                print("❌ Failed to verify active split!")
            }

            // Sync to CloudKit if enabled
            if config.isCloudKitEnabled {
                print("🔧 CloudKit sync is enabled, syncing split...")
                syncSplitToCloudKit(newSplit)
            } else {
                print("🔧 CloudKit sync is disabled, skipping sync")
            }
        } catch {
            print("❌ Error saving split: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let swiftDataError = error as? SwiftDataError {
                print("❌ SwiftData specific error: \(swiftDataError)")
            }
        }
    }
    
    /// Fetch active split
    @MainActor
    func getActiveSplit() -> Split? {
        let fetchDescriptor = FetchDescriptor<Split>(predicate: #Predicate { $0.isActive })
        do {
            let activeSplits = try context.fetch(fetchDescriptor)
            print("🔧 Found \(activeSplits.count) active splits")
            if let activeSplit = activeSplits.first {
                print("🔧 Active split: \(activeSplit.name)")
                return activeSplit
            } else {
                print("🔧 No active split found in database")
                return nil
            }
        } catch {
            print("❌ Error fetching active split: \(error)")
            return nil
        }
    }
    
    /// Fetch all days for active split
    @MainActor
    func getActiveSplitDays() -> [Day] {
        guard let activeSplit = getActiveSplit() else {
            print("No active split found.")
            return []
        }
        return activeSplit.days ?? []
    }

    /// Set all splits as inactive
    @MainActor
    func deactivateAllSplits() {
        do {
            let splits = getAllSplits()
            for split in splits {
                split.isActive = false
            }
            try context.save()
            objectWillChange.send() // Force UI to refresh
            print("🔧 Deactivated \(splits.count) splits")
        } catch {
            print("❌ Error deactivating splits: \(error)")
        }
    }
    
    /// Switch split from inactive to active
    @MainActor
    func switchActiveSplit(split: Split, context: ModelContext) {
        print("🔧 Deactivating all splits...")

        // First deactivate all splits synchronously
        let allSplits = getAllSplits()
        print("🔧 Found \(allSplits.count) total splits to deactivate")
        for existingSplit in allSplits {
            print("🔧 Deactivating split: \(existingSplit.name)")
            existingSplit.isActive = false
        }

        print("🔧 Setting split '\(split.name)' as active...")
        split.isActive = true
        print("🔧 Split '\(split.name)' isActive = \(split.isActive)")

        do {
            print("🔧 Saving context in switchActiveSplit...")
            try context.save()
            print("✅ Context saved successfully in switchActiveSplit")

            // Immediately verify the save worked
            let activeSplitsAfterSave = getAllSplits().filter { $0.isActive }
            print("🔧 After save: found \(activeSplitsAfterSave.count) active splits")
            for activeSplit in activeSplitsAfterSave {
                print("🔧 Active split after save: \(activeSplit.name)")
            }

            objectWillChange.send() // Manually notify SwiftUI of changes
        } catch {
            print("❌ Error switching split: \(error)")
        }
    }
    
    /// Fetch all splits
    @MainActor
    func getAllSplits() -> [Split] {
        let predicate = #Predicate<Split> { _ in true }
        let fetchDescriptor = FetchDescriptor<Split>(predicate: predicate)
        return try! context.fetch(fetchDescriptor)
    }
    
    /// Delete split
    @MainActor
    func deleteSplit(split: Split) {
        let splitId = split.id
        context.delete(split)
        do {
            try context.save()
            debugPrint("Deleted split: \(split.name)")
            // Delete from CloudKit too
            if config.isCloudKitEnabled {
                Task {
                    try? await CloudKitManager.shared.deleteSplit(splitId)
                }
            }
        } catch {
            debugPrint(error)
        }
    }
    
    // MARK: Day related funcs
    
    /// Fetch day with dayOfSplit as input
    @MainActor
    func fetchDay(dayOfSplit: Int?) async -> Day {
        let activeSplitDays = getActiveSplitDays().filter { $0.dayOfSplit == dayOfSplit }
        
        if let existingDay = activeSplitDays.first {
            debugPrint("Returning existing day: \(existingDay.name)")
            return existingDay
        } else {
            debugPrint("No existing day found, creating new one.")

            let newDay = Day(name: "", dayOfSplit: 0, exercises: [], date: "")
            
            context.insert(newDay)
            try? context.save()

            return newDay
        }
    }
    
    /// Fetch day based on date
    @MainActor
    func fetchCalendarDay(date: String) async -> Day {
        let predicate = #Predicate<DayStorage> {
            $0.date == date
        }
        let descriptor = FetchDescriptor<DayStorage>(predicate: predicate)

        do {
            let fetchedData = try context.fetch(descriptor)
            debugPrint("📅 FETCH: Looking for date '\(date)' - found \(fetchedData.count) DayStorage entries")

            // Fetch the day from storage
            if let dayStorage = fetchedData.first {
                let dayId = dayStorage.dayId
                debugPrint("📅 FETCH: Found DayStorage with dayId: \(dayId)")

                let dayPredicate = #Predicate<Day> { day in
                    day.id == dayId
                }
                let dayDescriptor = FetchDescriptor<Day>(predicate: dayPredicate)
                let fetchedDays = try context.fetch(dayDescriptor)

                if let foundDay = fetchedDays.first {
                    debugPrint("✅ FETCH: Successfully found Day '\(foundDay.name)' with \(foundDay.exercises?.count ?? 0) exercises")
                    return foundDay
                } else {
                    debugPrint("⚠️ FETCH: No Day found with id \(dayId)")
                }
            } else {
                debugPrint("⚠️ FETCH: No DayStorage found for date '\(date)'")
            }

            return emptyDay

        } catch {
            debugPrint("❌ FETCH ERROR: \(error.localizedDescription)")
            return emptyDay
        }
    }

    /// Sort exercises to there respective muscle group from date
    @MainActor
    func sortDataForCalendar(date: String) async -> [MuscleGroup] {
        var newMuscleGroups: [MuscleGroup] = []
        
        let today = await fetchCalendarDay(date: date)

        for name in muscleGroupNames {
            let filteredExercises = (today.exercises ?? []).filter { exercise in
                exercise.muscleGroup == name
            }

            if !filteredExercises.isEmpty {
                let group = MuscleGroup(
                    name: name,
                    exercises: filteredExercises
                )
                newMuscleGroups.append(group)
            }
        }

        return newMuscleGroups
    }
    
    /// Sort exercises to there respective muscle group from dayOfSplit
    @MainActor
    func sortData(dayOfSplit: Int) async -> [MuscleGroup] {
        var newMuscleGroups: [MuscleGroup] = []
        
        let updatedDay = await fetchDay(dayOfSplit: dayOfSplit)
        debugPrint("Exercises fetch for day : \((updatedDay.exercises ?? []).count)")

        let freshExercises = updatedDay.exercises ?? []

        await MainActor.run {
            self.day = updatedDay
        }

        for name in muscleGroupNames {
            let filteredExercises = freshExercises.filter { $0.muscleGroup == name }
            if !filteredExercises.isEmpty {
                let group = MuscleGroup(
                    name: name,
                    exercises: filteredExercises.sorted { $0.createdAt < $1.createdAt }
                )
                newMuscleGroups.append(group)
            }
        }
        
        return newMuscleGroups
    }
    
    /// Helper function for creating days when creating split
    func addDay(name: String, index: Int) {
        debugPrint("Attempting to add: \(name) with index \(index)")
        
        if days.contains(where: { $0.dayOfSplit == index }) {
            debugPrint("Skipping duplicate day: \(name)")
            return
        }
        context.insert(Day(name: name, dayOfSplit: index, exercises: [], date: ""))
        debugPrint("Added day: \(name)")
    }

    // New method that accepts the day with completed exercises
    @MainActor
    func insertWorkout(from day: Day) async {
        let completedExercises = (day.exercises ?? []).filter { $0.done }
        debugPrint("💾 WORKOUT SAVE: Found \(completedExercises.count) completed exercises out of \(day.exercises?.count ?? 0) total")

        let todaysDate = formattedDateString(from: Date())

        // First, check if there's already a DayStorage for today and remove it
        let existingPredicate = #Predicate<DayStorage> { storage in
            storage.date == todaysDate
        }
        let existingDescriptor = FetchDescriptor<DayStorage>(predicate: existingPredicate)

        do {
            let existingStorages = try context.fetch(existingDescriptor)
            debugPrint("🔍 SAVE: Found \(existingStorages.count) existing DayStorage entries for date '\(todaysDate)'")

            // Delete old DayStorage entries only (DO NOT delete Day objects to avoid deleting template days)
            for storage in existingStorages {
                context.delete(storage)
                debugPrint("🗑️ SAVE: Deleted old DayStorage for date '\(todaysDate)'")
            }
        } catch {
            debugPrint("⚠️ SAVE: Error checking existing storage: \(error)")
        }

        let newDay = Day(
            name: day.name,
            dayOfSplit: day.dayOfSplit,
            exercises: completedExercises.map { $0.copy() },
            date: formattedDateString(from: Date())
        )

        // Insert the Day object first so it gets persisted with an ID
        context.insert(newDay)
        debugPrint("📝 SAVE: Inserted Day with id: \(newDay.id), name: '\(newDay.name)'")

        let dayStorage = DayStorage(id: UUID(), day: newDay, date: todaysDate)
        context.insert(dayStorage)
        debugPrint("📝 SAVE: Created DayStorage for date '\(todaysDate)' referencing Day id: \(newDay.id)")

        // Only add to daysRecorded if not already present
        if !config.daysRecorded.contains(todaysDate) {
            config.daysRecorded.insert(todaysDate, at: 0)
            print("🟢 CALENDAR: Added new date '\(todaysDate)' to daysRecorded. Array now has \(config.daysRecorded.count) dates")
        } else {
            print("🟡 CALENDAR: Date '\(todaysDate)' already exists in daysRecorded")
        }
        print("📅 CALENDAR: Current daysRecorded: \(config.daysRecorded)")


        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.config.objectWillChange.send()
        }

        do {
            try context.save()
            debugPrint("Day saved with date: \(formattedDateString(from: Date()))")
            syncDayStorageToCloudKit(dayStorage)

            // Update streak when workout is saved
            userProfileManager?.calculateStreak(workoutDate: Date())
        } catch {
            debugPrint(error)
        }
    }
    
    @MainActor
    func copyWorkout(from: Day, to: Day) {
        to.exercises?.removeAll()
        to.exercises = (from.exercises ?? []).map { $0.copy() }
    }
    
 // MARK: Calendar oriented functions

    /// Check if a DayStorage exists for the given date
    @MainActor
    func hasDayStorage(for dateString: String) -> Bool {
        let predicate = #Predicate<DayStorage> { storage in
            storage.date == dateString
        }
        let descriptor = FetchDescriptor<DayStorage>(predicate: predicate)

        do {
            let existingStorages = try context.fetch(descriptor)
            return !existingStorages.isEmpty
        } catch {
            debugPrint("❌ Error checking DayStorage for date '\(dateString)': \(error)")
            return false
        }
    }

    /// Remove duplicate dates from daysRecorded array and rebuild from actual DayStorage entries
    @MainActor
    func cleanupDuplicateDates() {
        // First, get all dates from actual DayStorage entries
        let descriptor = FetchDescriptor<DayStorage>()

        do {
            let allStorages = try context.fetch(descriptor)
            let storageDate = Set(allStorages.map { $0.date })

            // Combine with existing daysRecorded and remove duplicates
            let allDates = Set(config.daysRecorded).union(storageDate)

            // Sort by date, most recent first
            let sortedDates = allDates.sorted { date1, date2 in
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMMM yyyy"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let d1 = formatter.date(from: date1) ?? Date.distantPast
                let d2 = formatter.date(from: date2) ?? Date.distantPast
                return d1 > d2
            }

            if config.daysRecorded.count != sortedDates.count {
                config.daysRecorded = sortedDates
                debugPrint("🧹 CLEANUP: Rebuilt daysRecorded from DayStorage. Now has \(config.daysRecorded.count) dates")
                debugPrint("📅 CLEANUP: Dates found: \(sortedDates)")
            }
        } catch {
            debugPrint("❌ Error fetching DayStorage entries for cleanup: \(error)")

            // Fallback: just remove duplicates from existing array
            let uniqueDates = Array(Set(config.daysRecorded))
            if uniqueDates.count != config.daysRecorded.count {
                config.daysRecorded = uniqueDates.sorted { date1, date2 in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "d MMMM yyyy"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    let d1 = formatter.date(from: date1) ?? Date.distantPast
                    let d2 = formatter.date(from: date2) ?? Date.distantPast
                    return d1 > d2
                }
                debugPrint("🧹 CLEANUP: Fallback - removed duplicates from daysRecorded. Now has \(config.daysRecorded.count) unique dates")
            }
        }
    }

    /// Get time for comparing
    func formattedDateString(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")  // Ensure consistent formatting
        let formattedString = dateFormatter.string(from: date)
        return formattedString
    }
    
    /// Get year and moth for calnedar day titile
    func monthAndYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Get how many days ar ein a month for calendar
    func getDaysInMonth(for date: Date) -> [DayCalendar] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: date),
              let firstDayOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) else {
            return []
        }
        let firstWeekday = Calendar.current.component(.weekday, from: firstDayOfMonth)
        var days: [DayCalendar] = []

        let offset = (firstWeekday + 5) % 7
        days.append(contentsOf: Array(repeating: DayCalendar(day: 0, date: Date()), count: offset))

        days.append(contentsOf: range.compactMap { day -> DayCalendar? in
            if let date = Calendar.current.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                return DayCalendar(day: day, date: date)
            }
            return nil
        })

        return days
    }
    
    // MARK: Functions for keeping app to date
    
    /// Update day in split based on how many days user  dident open the app
    @MainActor func updateDayInSplit() -> Int {
        let calendar = Calendar.current

        if !calendar.isDateInToday(config.lastUpdateDate) {
            let daysPassed = numberOfDaysBetween(start: config.lastUpdateDate, end: Date())

            let totalDays = config.dayInSplit + daysPassed

            guard let activeSplit = getActiveSplit() else {
                print("No active split found, returning current day in split")
                return config.dayInSplit
            }

            let newDayInSplit = (totalDays - 1) % (activeSplit.days?.count ?? 1) + 1

            config.dayInSplit = newDayInSplit
            config.lastUpdateDate = Date()
            config.activeExercise = 1

            return config.dayInSplit
        } else {
            return config.dayInSplit
        }
    }
    
    /// Get number of days from last time user opened app
    func numberOfDaysBetween(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let startOfDayStart = calendar.startOfDay(for: start)
        let startOfDayEnd = calendar.startOfDay(for: end)
        debugPrint(startOfDayStart)
        debugPrint(startOfDayEnd)
        let components = calendar.dateComponents([.day], from: startOfDayStart, to: startOfDayEnd)
        return components.day ?? 0
    }
    
    // MARK: Functions for exercise
    
    /// Create new exercises and add it to respective day
    @MainActor
    func createExercise(to: Day) async {
        if !name.isEmpty && !sets.isEmpty && !reps.isEmpty {
            var setList: [Exercise.Set] = []
            
            guard let numSets = Int(sets) else {
                debugPrint("Invalid sets value: \(sets)")
                return
            }

            for _ in 1...numSets {
                let set = Exercise.Set.createDefault()
                setList.append(set)
            }

            do {
                let today = await fetchDay(dayOfSplit: config.dayInSplit)

                if (today.exercises ?? []).contains(where: { $0.name == name }) {
                    debugPrint("Exercise already exists in today's workout.")
                    return
                }

                
                let newExercise = Exercise(
                    id: UUID(),
                    name: name,
                    sets: setList,
                    repGoal: reps,
                    muscleGroup: muscleGroup,
                    createdAt: Date(),
                    exerciseOrder: (await fetchDay(dayOfSplit: config.dayInSplit).exercises ?? []).count + 1, done: false
                )

                await MainActor.run {
                    if to.exercises == nil {
                        to.exercises = []
                    }
                    to.exercises?.append(newExercise)
                    try? context.save()
                }

                debugPrint("Successfully added exercise \(name) to \(today.name)")
                
                /// Notify UI to refresh
                await MainActor.run {
                    self.exerciseAddedTrigger.toggle()
                }
                
            }
        } else {
            debugPrint("Not all text fields are filled")
        }
    }
    /// Delete exercise for day
    func deleteExercise(_ exercise: Exercise) {
        guard let day = exercise.day else {
            debugPrint("Exercise has no associated day.")
            return
        }
        day.exercises?.removeAll { $0.id == exercise.id }
        context.delete(exercise)
        do {
            try context.save()
            debugPrint("Deleted exercise: \(exercise.name)")
        } catch {
            debugPrint(error)
        }
    }
    
    
    /// Fetch exercise from id
    @MainActor
    func fetchExercise(id: UUID) async -> Exercise {
        let predicate = #Predicate<Exercise> {
            $0.id == id
        }
        let descriptor = FetchDescriptor<Exercise>(predicate: predicate)
        do {
            let fetchedData: [Exercise]
            do {
                fetchedData = try context.fetch(descriptor)
                debugPrint("Fetched exercises: \(fetchedData.count)")
            } catch {
                debugPrint("Error fetching data: \(error.localizedDescription)")
                return Exercise(id: UUID(), name: "", sets: [], repGoal: "", muscleGroup: "", exerciseOrder: 0)
            }
            guard !fetchedData.isEmpty else {
                return Exercise(id: UUID(), name: "", sets: [], repGoal: "", muscleGroup: "", exerciseOrder: 0)
            }
            
            return fetchedData.first!
        }
    }
    
    /// Fetch exercises for day
    @MainActor
    func fetchAllExerciseForDay(day: Day) async -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>()
        do {
            let fetchedData: [Exercise]
            do {
                fetchedData = try context.fetch(descriptor)
                debugPrint("Fetched exercises: \(fetchedData.count)")
            } catch {
                debugPrint("Error fetching data: \(error.localizedDescription)")
                return []
            }
            guard !fetchedData.isEmpty else {
                return []
            }
            return fetchedData
        }
    }
    
    // MARK: Functions for sets
    
    /// Delete set for exercise
    func deleteSet(_ set: Exercise.Set, exercise: Exercise) {
        if let sets = exercise.sets,
           let index = sets.firstIndex(where: { $0.id == set.id }) {
            withAnimation {
                _ = exercise.sets?.remove(at: index)
            }
        }
        context.delete(set)
    }
    /// Add set for exercise
    @MainActor
    func addSet(exercise: Exercise) async -> Exercise {
        let currentExercise = await fetchExercise(id: exercise.id)

        if currentExercise.sets == nil {
            currentExercise.sets = []
        }

        currentExercise.sets?.insert(
            Exercise.Set.createDefault(),
            at: currentExercise.sets?.endIndex ?? 0
        )

        do {
            try context.save()
        } catch {
            debugPrint(error)
        }
        return await fetchExercise(id : exercise.id)
    }
    
    // MARK: Functions for loading profile image
    
    /// Get url for image
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Load image from path (legacy local files) or CloudKit
    func loadImage(from path: String) -> UIImage? {
        // Check if this is a CloudKit image identifier
        if path == "cloudkit_profile_image" {
            // For CloudKit images, we'll need to use async loading
            // This sync method will return nil and we'll handle CloudKit loading elsewhere
            return nil
        }

        // Handle both full paths (legacy) and filenames (local files)
        let fileURL: URL
        if path.contains("/") {
            // Full path provided (legacy)
            fileURL = URL(fileURLWithPath: path)
        } else {
            // Just filename provided, construct path in Documents directory
            fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
        }

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let imageData = try? Data(contentsOf: fileURL),
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        return uiImage
    }

    /// Load profile image from CloudKit (async)
    func loadProfileImageFromCloudKit() async -> UIImage? {
        do {
            return try await CloudKitManager.shared.fetchProfileImage()
        } catch {
            debugPrint("❌ Failed to load profile image from CloudKit: \(error)")
            return nil
        }
    }
    
    /// Saves the UIImage to the Documents directory
    func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let filename = "profile_picture.jpg"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            // Return just the filename, not the full path (for CloudKit compatibility across reinstalls)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    // MARK: Authentication funcs
    
    private func handleSuccessfulLogin(with authorization: ASAuthorization) {
        if let userCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print(userCredential.user)
            
            if userCredential.authorizedScopes.contains(.fullName) {
                print(userCredential.fullName?.givenName ?? "No given name")
            }
            
            if userCredential.authorizedScopes.contains(.email) {
                print(userCredential.email ?? "No email")
            }
        }
    }
    
    private func handleLoginError(with error: Error) {
        print("Could not authenticate: \\(error.localizedDescription)")
    }
    
    // MARK: Import export SPLIT functions
    func importSplit(from url: URL) -> Split? {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Could not access security scoped resource.")
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ File not found at: \(url.path)")
                return nil
            }

            print("📂 Importing file from: \(url.path)")
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decodedSplit = try decoder.decode(Split.self, from: data)

            let newSplit = Split(
                id: UUID(),
                name: decodedSplit.name,
                days: [],
                isActive: decodedSplit.isActive,
                startDate: decodedSplit.startDate
            )

            for decodedDay in decodedSplit.days ?? [] {
                let newDay = Day(
                    id: UUID(),
                    name: decodedDay.name,
                    dayOfSplit: decodedDay.dayOfSplit,
                    exercises: [],
                    date: decodedDay.date
                )

                for decodedExercise in decodedDay.exercises ?? [] {
                    let newExercise = Exercise(
                        id: UUID(),
                        name: decodedExercise.name,
                        sets: decodedExercise.sets ?? [],
                        repGoal: decodedExercise.repGoal,
                        muscleGroup: decodedExercise.muscleGroup,
                        createdAt: decodedExercise.createdAt,
                        exerciseOrder: decodedExercise.exerciseOrder
                    )
                    if newDay.exercises == nil {
                        newDay.exercises = []
                    }
                    newDay.exercises?.append(newExercise)
                    context.insert(newExercise)  // Insert each exercise
                }

                newDay.split = newSplit
                if newSplit.days == nil {
                    newSplit.days = []
                }
                newSplit.days?.append(newDay)  // Add day to split
                context.insert(newDay)  // Insert each day
            }

            context.insert(newSplit)
            try context.save()
            print("✅ Split successfully saved: \(newSplit.name)")

            // Force UI refresh
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }

            return newSplit

        } catch {
            print("❌ Error importing split: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Export split
    func exportSplit(_ split: Split) -> URL? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(split)

            // Save to the Documents directory
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsURL.appendingPathComponent("\(split.name).gymlysplit")

            try data.write(to: fileURL, options: .atomic) // Ensure file is properly saved
            return fileURL
        } catch {
            print("Error exporting split: \(error)")
            return nil
        }
    }
    

    // MARK: Update muscle group for chart + persist to SwiftData
    @MainActor
    func updateMuscleGroupDataValues(
        from exercises: [Exercise],
        modelContext: ModelContext,
        referenceDate: Date = Date()   // allows backfilling other dates if needed
    ) {
        debugPrint("[Graph] updateMuscleGroupDataValues called with \(exercises.count) exercises")
        var muscleCounts: [MuscleGroupEnum: Double] = [:]

        // Initialize all muscle groups to 0
        for group in MuscleGroupEnum.allCases {
            muscleCounts[group] = 0.0
        }

        // Filter only done exercises (no need to track IDs - we recalculate from database)
        let doneExercises = exercises.filter { $0.done }
        debugPrint("[Graph] Processing \(doneExercises.count) completed exercises")

        // Count sets for each muscle group
        for exercise in doneExercises {
            if let group = MuscleGroupEnum(rawValue: exercise.muscleGroup.lowercased()) {
                muscleCounts[group, default: 0] += Double(exercise.sets?.count ?? 0)
            }
        }

        let orderedGroups = MuscleGroupEnum.allCases

        // Use raw values without artificial minimum
        let computedMax = muscleCounts.values.max() ?? 1.0
        let safeMax = max(computedMax, 1.0)

        let rawValues = orderedGroups.map { muscleCounts[$0] ?? 0 }

        // Update in-memory config for immediate UI feedback
        config.graphDataValues = rawValues
        config.graphMaxValue = safeMax

        debugPrint("[Graph] Updated values: \(rawValues), max: \(safeMax)")

        // ---- Persist to SwiftData: one entry per day ----
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: referenceDate)
        guard let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            debugPrint("[Graph] Failed to compute nextDay")
            return
        }

        do {
            // Find an existing GraphEntry for this day
            let predicate = #Predicate<GraphEntry> { entry in
                entry.date >= dayStart && entry.date < nextDay
            }
            var descriptor = FetchDescriptor<GraphEntry>(predicate: predicate,
                                                         sortBy: [SortDescriptor(\.date)])
            descriptor.fetchLimit = 1

            if let existing = try modelContext.fetch(descriptor).first {
                // Update the day's data
                existing.data = rawValues
            } else {
                // Insert a new day entry normalized to start-of-day
                let entry = GraphEntry(date: dayStart, data: rawValues)
                modelContext.insert(entry)
            }

            try modelContext.save()
            debugPrint("[Graph] Saved GraphEntry for \(dayStart): \(rawValues)")
        } catch {
            debugPrint("[Graph] Failed to save GraphEntry: \(error)")
        }
    }

    // MARK: - CloudKit Sync Methods
    @MainActor
    func syncSplitToCloudKit(_ split: Split) {
        guard config.isCloudKitEnabled else { return }

        Task {
            do {
                try await CloudKitManager.shared.saveSplit(split)
                debugPrint("✅ Split '\(split.name)' synced to CloudKit")
            } catch {
                debugPrint("❌ Failed to sync split to CloudKit: \(error)")
            }
        }
    }

    @MainActor
    func syncDayStorageToCloudKit(_ dayStorage: DayStorage) {
        guard config.isCloudKitEnabled else { return }

        Task {
            do {
                try await CloudKitManager.shared.saveDayStorage(dayStorage)
                debugPrint("✅ DayStorage for date '\(dayStorage.date)' synced to CloudKit")
            } catch {
                debugPrint("❌ Failed to sync DayStorage to CloudKit: \(error)")
            }
        }
    }

    @MainActor
    func syncWeightPointToCloudKit(_ weightPoint: WeightPoint) {
        guard config.isCloudKitEnabled else { return }

        Task {
            do {
                try await CloudKitManager.shared.saveWeightPoint(weightPoint)
                debugPrint("✅ WeightPoint synced to CloudKit")
            } catch {
                debugPrint("❌ Failed to sync WeightPoint to CloudKit: \(error)")
            }
        }
    }

    @MainActor
    func performFullCloudKitSync() {
        guard config.isCloudKitEnabled else { return }

        Task {
            await CloudKitManager.shared.performFullSync(context: context, config: config)
        }
    }

    @MainActor
    func fetchFromCloudKit() {
        guard config.isCloudKitEnabled else { return }

        Task {
            await CloudKitManager.shared.fetchAndMergeData(context: context, config: config)
        }
    }
}
    
