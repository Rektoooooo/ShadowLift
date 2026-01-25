//
//  WorkoutViewModel.swift
//  ShadowLift
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

    #if DEBUG
    // MARK: - TESTING ONLY
    /// Test helper: Simulate workout on a specific date
    @MainActor
    func testSimulateWorkout(daysAgo: Int) {
        let calendar = Calendar.current
        let simulatedDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!

        debugLog("🧪 TEST: Simulating workout \(daysAgo) days ago (date: \(formattedDateString(from: simulatedDate)))")

        userProfileManager?.calculateStreak(workoutDate: simulatedDate)
    }
    #endif

    // MARK: Split related funcs
    /// Create new split
    @MainActor
    func createNewSplit(name: String, numberOfDays: Int, startDate: Date, context: ModelContext) {
        debugLog("🔧 Starting createNewSplit with name: \(name), days: \(numberOfDays)")

        var days: [Day] = []

        for i in 1...numberOfDays {
            let day = Day(name: "Day \(i)", dayOfSplit: i, exercises: [], date: "")
            days.append(day)
            debugLog("🔧 Created day: \(day.name)")
        }

        debugLog("🔧 Creating split with \(days.count) days")

        let newSplit = Split(name: name, days: days.isEmpty ? [] : days, isActive: false, startDate: startDate)
        debugLog("🔧 Split created, inserting into context...")
        context.insert(newSplit)

        // Also insert each day into the context
        for day in days {
            debugLog("🔧 Inserting day: \(day.name)")
            context.insert(day)
        }

        do {
            debugLog("🔧 Attempting to save context...")
            try context.save()
            debugLog("✅ New split '\(name)' created and saved.")

            // Verify the split was actually saved
            let allSplitsAfterSave = getAllSplits()
            debugLog("🔧 After initial save: found \(allSplitsAfterSave.count) total splits")
            for split in allSplitsAfterSave {
                debugLog("🔧 Found split: \(split.name), active: \(split.isActive)")
            }

            // Now switch it to active AFTER it's been saved
            debugLog("🔧 Switching to active split...")
            switchActiveSplit(split: newSplit, context: context)

            // Verify the split is now active
            debugLog("🔧 Verifying active split...")
            if let activeSplit = getActiveSplit() {
                debugLog("✅ Verified active split: \(activeSplit.name)")

                // Force UI refresh by triggering objectWillChange
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            } else {
                debugLog("❌ Failed to verify active split!")
            }

            // Sync to CloudKit if enabled
            if CloudKitManager.shared.isCloudKitEnabled {
                debugLog("🔧 CloudKit sync is enabled, syncing split...")
                syncSplitToCloudKit(newSplit)
            } else {
                debugLog("🔧 CloudKit sync is disabled, skipping sync")
            }
        } catch {
            debugLog("❌ Error saving split: \(error)")
            debugLog("❌ Error details: \(error.localizedDescription)")
            if let swiftDataError = error as? SwiftDataError {
                debugLog("❌ SwiftData specific error: \(swiftDataError)")
            }
        }
    }
    
    /// Fetch active split
    @MainActor
    func getActiveSplit() -> Split? {
        let fetchDescriptor = FetchDescriptor<Split>(predicate: #Predicate { $0.isActive })
        do {
            let activeSplits = try context.fetch(fetchDescriptor)
            debugLog("🔧 Found \(activeSplits.count) active splits")
            if let activeSplit = activeSplits.first {
                debugLog("🔧 Active split: \(activeSplit.name)")
                return activeSplit
            } else {
                debugLog("🔧 No active split found in database")
                return nil
            }
        } catch {
            debugLog("❌ Error fetching active split: \(error)")
            return nil
        }
    }
    
    /// Fetch all days for active split
    @MainActor
    func getActiveSplitDays() -> [Day] {
        guard let activeSplit = getActiveSplit() else {
            debugLog("No active split found.")
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
            debugLog("🔧 Deactivated \(splits.count) splits")
        } catch {
            debugLog("❌ Error deactivating splits: \(error)")
        }
    }
    
    /// Switch split from inactive to active
    @MainActor
    func switchActiveSplit(split: Split, context: ModelContext) {
        debugLog("🔧 Deactivating all splits...")

        // First deactivate all splits synchronously
        let allSplits = getAllSplits()
        debugLog("🔧 Found \(allSplits.count) total splits to deactivate")
        for existingSplit in allSplits {
            debugLog("🔧 Deactivating split: \(existingSplit.name)")
            existingSplit.isActive = false
        }

        debugLog("🔧 Setting split '\(split.name)' as active...")
        split.isActive = true
        debugLog("🔧 Split '\(split.name)' isActive = \(split.isActive)")

        do {
            debugLog("🔧 Saving context in switchActiveSplit...")
            try context.save()
            debugLog("✅ Context saved successfully in switchActiveSplit")

            // Immediately verify the save worked
            let activeSplitsAfterSave = getAllSplits().filter { $0.isActive }
            debugLog("🔧 After save: found \(activeSplitsAfterSave.count) active splits")
            for activeSplit in activeSplitsAfterSave {
                debugLog("🔧 Active split after save: \(activeSplit.name)")
            }

            objectWillChange.send() // Manually notify SwiftUI of changes
        } catch {
            debugLog("❌ Error switching split: \(error)")
        }
    }
    
    /// Fetch all splits
    @MainActor
    func getAllSplits() -> [Split] {
        let predicate = #Predicate<Split> { _ in true }
        let fetchDescriptor = FetchDescriptor<Split>(predicate: predicate)
        do {
            return try context.fetch(fetchDescriptor)
        } catch {
            debugLog("❌ Failed to fetch splits: \(error)")
            return []
        }
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
            if CloudKitManager.shared.isCloudKitEnabled {
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
            do {
                try context.save()
                debugLog("✅ Created new day successfully")
            } catch {
                debugLog("❌ Failed to save new day: \(error)")
            }

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
        debugPrint("📅 WORKOUT SAVE: Today's date is '\(todaysDate)'")

        // First, check if there's already a DayStorage for today and remove it
        let existingPredicate = #Predicate<DayStorage> { storage in
            storage.date == todaysDate
        }
        let existingDescriptor = FetchDescriptor<DayStorage>(predicate: existingPredicate)

        do {
            let existingStorages = try context.fetch(existingDescriptor)
            debugPrint("🔍 SAVE: Found \(existingStorages.count) existing DayStorage entries for date '\(todaysDate)'")

            // Delete old DayStorage entries AND their associated Day objects
            for storage in existingStorages {
                debugPrint("🗑️ SAVE: Deleting DayStorage id: \(storage.id), dayId: \(storage.dayId), date: '\(storage.date)'")

                // Also delete the associated Day object AND its exercises to prevent orphans
                let dayIdToDelete = storage.dayId
                let dayToDeletePredicate = #Predicate<Day> { day in
                    day.id == dayIdToDelete
                }
                let dayToDeleteDescriptor = FetchDescriptor<Day>(predicate: dayToDeletePredicate)
                if let dayToDelete = try context.fetch(dayToDeleteDescriptor).first {
                    // Delete all exercises in the day first to prevent orphans
                    let exerciseCount = dayToDelete.exercises?.count ?? 0
                    if let exercises = dayToDelete.exercises {
                        for exercise in exercises {
                            // Delete all sets in the exercise
                            if let sets = exercise.sets {
                                for set in sets {
                                    context.delete(set)
                                }
                            }
                            context.delete(exercise)
                        }
                    }
                    context.delete(dayToDelete)
                    debugPrint("🗑️ SAVE: Deleted Day id: \(dayToDelete.id) and \(exerciseCount) exercises")
                }

                context.delete(storage)
            }

            if existingStorages.count > 0 {
                debugPrint("✅ SAVE: Deleted \(existingStorages.count) old workout(s) for '\(todaysDate)'")
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
        debugPrint("📝 SAVE: Inserted NEW Day with id: \(newDay.id), name: '\(newDay.name)', exercises: \(completedExercises.count)")

        let dayStorage = DayStorage(id: UUID(), day: newDay, date: todaysDate)
        context.insert(dayStorage)
        debugPrint("📝 SAVE: Created NEW DayStorage for date '\(todaysDate)' referencing Day id: \(newDay.id)")
        debugPrint("🎯 SAVE: This workout should REPLACE any previous workout for '\(todaysDate)'")

        // Only add to daysRecorded if not already present
        if !config.daysRecorded.contains(todaysDate) {
            config.daysRecorded.insert(todaysDate, at: 0)
            debugLog("🟢 CALENDAR: Added new date '\(todaysDate)' to daysRecorded. Array now has \(config.daysRecorded.count) dates")
        } else {
            debugLog("🟡 CALENDAR: Date '\(todaysDate)' already exists in daysRecorded")
        }
        debugLog("📅 CALENDAR: Current daysRecorded: \(config.daysRecorded)")


        // Force a UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.config.objectWillChange.send()
        }

        do {
            // CRITICAL SAVE: This persists ALL workout changes to disk at once
            // - All set edits (weight, reps, notes, types)
            // - Exercise completion status
            // - Workout metadata
            // By batching all saves until workout completion, we eliminate lag during active workout
            try context.save()
            debugPrint("✅ Day saved with date: \(formattedDateString(from: Date()))")
            debugPrint("💾 All workout changes persisted to disk successfully")
            syncDayStorageToCloudKit(dayStorage)

            // Update streak when workout is saved
            userProfileManager?.calculateStreak(workoutDate: Date())

            // Analyze workout for volume PRs and update workout counters
            let volumePRs = await PRManager.shared.analyzeWorkoutForPRs(
                exercises: completedExercises,
                workoutDate: Date(),
                workoutID: dayStorage.id
            )
            if !volumePRs.isEmpty {
                debugPrint("🏆 WORKOUT COMPLETE: Detected \(volumePRs.count) volume PR(s)!")
            }
            debugPrint("✅ WORKOUT COMPLETE: PR analysis complete, updated workout counters")

            // Cleanup old workouts for free users (1.5 month history limit)
            if !config.isPremium {
                await cleanupOldWorkoutsForFreeUsers()
            }
        } catch {
            debugPrint(error)
        }
    }

    /// Deletes DayStorage entries older than 1.5 months for free users
    private func cleanupOldWorkoutsForFreeUsers() async {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -45, to: Date()) else {
            debugPrint("⚠️ FREE USER CLEANUP: Failed to calculate cutoff date")
            return
        }

        let cutoffDateString = formattedDateString(from: cutoffDate)
        debugPrint("🧹 FREE USER CLEANUP: Deleting workouts older than \(cutoffDateString) (1.5 months)")

        do {
            // Fetch ALL DayStorage entries - we'll filter by actual date comparison
            // String comparison doesn't work for "d MMMM yyyy" format (e.g., "5 January" vs "10 January")
            let descriptor = FetchDescriptor<DayStorage>()
            let allEntries = try context.fetch(descriptor)

            // Parse dates and filter entries older than cutoff
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            let oldEntries = allEntries.filter { storage in
                guard let storageDate = dateFormatter.date(from: storage.date) else {
                    // If date can't be parsed, don't delete it
                    return false
                }
                return storageDate < cutoffDate
            }

            if oldEntries.isEmpty {
                debugPrint("✅ FREE USER CLEANUP: No old workouts to delete")
                return
            }

            debugPrint("🗑️ FREE USER CLEANUP: Found \(oldEntries.count) workouts to delete")

            // Delete each old entry and its associated Day
            for storage in oldEntries {
                // Delete associated Day object
                let dayIdToDelete = storage.dayId
                let dayPredicate = #Predicate<Day> { day in
                    day.id == dayIdToDelete
                }
                let dayDescriptor = FetchDescriptor<Day>(predicate: dayPredicate)
                if let dayToDelete = try context.fetch(dayDescriptor).first {
                    context.delete(dayToDelete)
                }

                // Delete DayStorage
                context.delete(storage)

                // Remove from daysRecorded array
                if let index = config.daysRecorded.firstIndex(of: storage.date) {
                    config.daysRecorded.remove(at: index)
                }
            }

            // Save changes
            try context.save()
            debugPrint("✅ FREE USER CLEANUP: Deleted \(oldEntries.count) old workouts successfully")
        } catch {
            debugPrint("❌ FREE USER CLEANUP: Error deleting old workouts - \(error)")
        }
    }

    @MainActor
    func copyWorkout(from: Day, to: Day) {
        // Initialize exercises array if nil to prevent potential issues
        if to.exercises == nil {
            to.exercises = []
        }
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

    /// Get all workout dates from DayStorage (for efficient calendar rendering)
    @MainActor
    func getAllWorkoutDates() -> Set<String> {
        let descriptor = FetchDescriptor<DayStorage>()

        do {
            let allStorages = try context.fetch(descriptor)
            return Set(allStorages.map { $0.date })
        } catch {
            debugPrint("❌ Error fetching all workout dates: \(error)")
            return []
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

        #if DEBUG
        debugLog("🔧 updateDayInSplit: current config.dayInSplit = \(config.dayInSplit)")
        debugLog("🔧 updateDayInSplit: lastUpdateDate = \(config.lastUpdateDate)")
        debugLog("🔧 updateDayInSplit: isDateInToday = \(calendar.isDateInToday(config.lastUpdateDate))")
        #endif

        if !calendar.isDateInToday(config.lastUpdateDate) {
            let daysPassed = numberOfDaysBetween(start: config.lastUpdateDate, end: Date())

            let totalDays = config.dayInSplit + daysPassed

            #if DEBUG
            debugLog("🔧 updateDayInSplit: daysPassed = \(daysPassed), totalDays = \(totalDays)")
            #endif

            guard let activeSplit = getActiveSplit() else {
                debugLog("No active split found, returning current day in split")
                return config.dayInSplit
            }

            let splitDaysCount = activeSplit.days?.count ?? 1
            var newDayInSplit = (totalDays - 1) % splitDaysCount + 1

            #if DEBUG
            debugLog("🔧 updateDayInSplit: splitDaysCount = \(splitDaysCount), raw calculation = \(newDayInSplit)")
            #endif

            // Fix negative day numbers (can happen with time travel or clock changes)
            if newDayInSplit <= 0 {
                newDayInSplit = ((newDayInSplit % splitDaysCount) + splitDaysCount) % splitDaysCount + 1
                #if DEBUG
                debugLog("🔧 updateDayInSplit: Fixed negative to = \(newDayInSplit)")
                #endif
            }

            // Ensure day is within valid range (1 to splitDaysCount)
            newDayInSplit = max(1, min(newDayInSplit, splitDaysCount))

            #if DEBUG
            debugLog("🔧 updateDayInSplit: Final newDayInSplit = \(newDayInSplit)")
            #endif

            config.dayInSplit = newDayInSplit
            config.lastUpdateDate = Date()
            config.activeExercise = 1

            return config.dayInSplit
        } else {
            #if DEBUG
            debugLog("🔧 updateDayInSplit: Date is today, returning existing dayInSplit = \(config.dayInSplit)")
            #endif
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
                    do {
                        try context.save()
                        debugLog("✅ Exercise '\(name)' saved successfully")
                    } catch {
                        debugLog("❌ CRITICAL: Failed to save exercise '\(name)': \(error)")
                    }
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

    /// Duplicate exercise in day
    func duplicateExercise(_ exercise: Exercise, inDay day: Day) {
        // Create a deep copy of the exercise
        let duplicatedExercise = Exercise(
            id: UUID(), // New UUID
            name: exercise.name + " (Copy)",
            sets: [], // Start empty, will add sets below
            repGoal: exercise.repGoal,
            muscleGroup: exercise.muscleGroup,
            createdAt: Date(),
            completedAt: nil,
            animationId: UUID(),
            exerciseOrder: (day.exercises?.count ?? 0) + 1, // Place at end
            done: false, // Not done yet
            day: day
        )

        // Deep copy sets with proper initialization
        if let originalSets = exercise.sets {
            duplicatedExercise.sets = originalSets.map { set in
                Exercise.Set(
                    id: UUID(),
                    weight: set.weight,
                    reps: set.reps,
                    failure: set.failure,
                    warmUp: set.warmUp,
                    restPause: set.restPause,
                    dropSet: set.dropSet,
                    time: set.time,
                    note: set.note,
                    createdAt: Date(),
                    bodyWeight: set.bodyWeight,
                    exercise: duplicatedExercise
                )
            }
        }

        // Add to day
        if day.exercises == nil {
            day.exercises = []
        }
        day.exercises?.append(duplicatedExercise)
        context.insert(duplicatedExercise)

        do {
            try context.save()
            debugLog("✅ Duplicated exercise: \(exercise.name)")
        } catch {
            debugLog("❌ Failed to duplicate exercise: \(error)")
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
            guard let firstExercise = fetchedData.first else {
                return Exercise(id: UUID(), name: "", sets: [], repGoal: "", muscleGroup: "", exerciseOrder: 0)
            }

            return firstExercise
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

        // Save the context to persist the deletion
        do {
            try context.save()
            debugLog("✅ Deleted set and saved context")
        } catch {
            debugLog("❌ Failed to save after set deletion: \(error)")
        }
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
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if Documents is unavailable (extremely rare)
            debugLog("⚠️ Documents directory unavailable, using temp directory")
            return FileManager.default.temporaryDirectory
        }
        return documentsURL
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
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                debugLog("⚠️ Documents directory unavailable for loading image")
                return nil
            }
            fileURL = documentsURL.appendingPathComponent(path)
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
            debugLog("Error saving image: \(error)")
            return nil
        }
    }
    
    // MARK: Authentication funcs
    
    private func handleSuccessfulLogin(with authorization: ASAuthorization) {
        if let userCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            debugLog(userCredential.user)
            
            if userCredential.authorizedScopes.contains(.fullName) {
                debugLog(userCredential.fullName?.givenName ?? "No given name")
            }
            
            if userCredential.authorizedScopes.contains(.email) {
                debugLog(userCredential.email ?? "No email")
            }
        }
    }
    
    private func handleLoginError(with error: Error) {
        debugLog("Could not authenticate: \\(error.localizedDescription)")
    }
    
    // MARK: Import export SPLIT functions
    func importSplit(from url: URL) throws -> Split {
        guard url.startAccessingSecurityScopedResource() else {
            debugLog("❌ Could not access security scoped resource.")
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Validate file extension
        guard url.pathExtension.lowercased() == "gymlysplit" else {
            debugLog("❌ Invalid file extension: \(url.pathExtension)")
            throw ImportError.invalidFileExtension
        }

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            debugLog("❌ File not found at: \(url.path)")
            throw ImportError.fileNotFound
        }

        debugLog("📂 Importing file from: \(url.path)")

        // Read and decode file
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            debugLog("❌ Failed to read file data: \(error.localizedDescription)")
            throw ImportError.corruptData("Could not read file contents")
        }

        let decodedSplit: Split
        do {
            let decoder = JSONDecoder()
            decodedSplit = try decoder.decode(Split.self, from: data)
        } catch let error as DecodingError {
            let errorMessage = decodingErrorMessage(from: error)
            debugLog("❌ Decoding failed: \(errorMessage)")
            throw ImportError.decodingFailed(errorMessage)
        } catch {
            debugLog("❌ Unknown decoding error: \(error.localizedDescription)")
            throw ImportError.decodingFailed(error.localizedDescription)
        }

        // Validate required fields
        guard !decodedSplit.name.isEmpty else {
            debugLog("❌ Split name is empty")
            throw ImportError.missingRequiredData("split name")
        }

        guard let days = decodedSplit.days, !days.isEmpty else {
            debugLog("❌ Split has no days")
            throw ImportError.missingRequiredData("workout days")
        }

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
            debugLog("✅ Split successfully saved: \(newSplit.name)")

            // Force UI refresh
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }

            return newSplit
    }

    /// Import a shared split from CloudKit (deep link import)
    /// Re-encodes the split to avoid SwiftData @Model state issues from fetchSharedSplit
    func importSharedSplit(_ split: Split, context: ModelContext) throws -> Split {
        debugLog("🔗 Importing shared split: \(split.name)")

        // Re-encode to JSON data - this strips away any SwiftData internal state
        // from the @Model objects that were decoded in fetchSharedSplit
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(split)

        // Decode fresh - this creates new @Model objects without SwiftData baggage
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSplit = try decoder.decode(Split.self, from: data)

        // Validate required fields
        guard !decodedSplit.name.isEmpty else {
            debugLog("❌ Split name is empty")
            throw ImportError.missingRequiredData("split name")
        }

        guard let days = decodedSplit.days, !days.isEmpty else {
            debugLog("❌ Split has no days")
            throw ImportError.missingRequiredData("workout days")
        }

        // Create new split with new UUIDs (deep copy)
        let newSplit = Split(
            id: UUID(),
            name: decodedSplit.name,
            days: [],
            isActive: false, // Don't auto-activate imported splits
            startDate: Date()
        )

        for decodedDay in days {
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
                context.insert(newExercise)
            }

            newDay.split = newSplit
            if newSplit.days == nil {
                newSplit.days = []
            }
            newSplit.days?.append(newDay)
            context.insert(newDay)
        }

        context.insert(newSplit)
        try context.save()
        debugLog("✅ Shared split successfully imported: \(newSplit.name)")

        return newSplit
    }

    /// Helper to create user-friendly messages from DecodingError
    private func decodingErrorMessage(from error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing field: \(key.stringValue)"
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Wrong data type for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        @unknown default:
            return "Unknown decoding error"
        }
    }
    
    /// Export split
    func exportSplit(_ split: Split) -> URL? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(split)

            // Save to the Documents directory
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                debugLog("❌ Documents directory unavailable for exporting split")
                return nil
            }
            let fileURL = documentsURL.appendingPathComponent("\(split.name).shadowliftsplit")

            try data.write(to: fileURL, options: .atomic) // Ensure file is properly saved
            return fileURL
        } catch {
            debugLog("Error exporting split: \(error)")
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
        guard CloudKitManager.shared.isCloudKitEnabled else { return }

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
        guard CloudKitManager.shared.isCloudKitEnabled else { return }

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
        guard CloudKitManager.shared.isCloudKitEnabled else { return }

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
        guard CloudKitManager.shared.isCloudKitEnabled else { return }

        Task {
            await CloudKitManager.shared.performFullSync(context: context, config: config)
        }
    }

    @MainActor
    func fetchFromCloudKit() {
        guard CloudKitManager.shared.isCloudKitEnabled else { return }

        Task {
            await CloudKitManager.shared.fetchAndMergeData(context: context, config: config)
        }
    }
}
    
