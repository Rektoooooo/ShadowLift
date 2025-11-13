//
//  PRManager.swift
//  ShadowLift
//
//  Created by Claude Code on 03.11.2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class PRManager: ObservableObject {
    static let shared = PRManager()

    @Published var cachedPRs: [String: ExercisePR] = [:]
    @Published var recentPRs: [PRNotification] = []  // For showing celebration notifications

    private var modelContext: ModelContext?
    private var userProfileManager: UserProfileManager?

    private init() {}

    // MARK: - Setup

    func setup(modelContext: ModelContext, userProfileManager: UserProfileManager) {
        self.modelContext = modelContext
        self.userProfileManager = userProfileManager
        print("✅ PR MANAGER: Initialized")
    }

    // MARK: - Core PR Checking

    /// Check if a set is a PR and update records accordingly
    func checkForPR(exercise: Exercise, set: Exercise.Set, workoutDate: Date = Date(), workoutID: UUID) async -> PRNotification? {
        guard let context = modelContext else {
            print("❌ PR MANAGER: No model context available")
            return nil
        }

        // Don't count warm-up sets as PRs
        guard isValidPRSet(set) else {
            return nil
        }

        let exerciseName = exercise.name.normalizedExerciseName
        let muscleGroup = exercise.muscleGroup

        // Get or create PR record
        let prRecord = await getOrCreatePR(for: exerciseName, muscleGroup: muscleGroup, context: context)

        // Get user weight for bodyweight exercises
        let userWeight = userProfileManager?.currentProfile?.weight

        // Store old values to detect if we got a new PR
        let oldBestWeight = prRecord.bestWeight
        let oldBest1RM = prRecord.best1RM

        // Update PRs from this set
        prRecord.updatePRsIfNeeded(from: set, workoutDate: workoutDate, workoutID: workoutID, userWeight: userWeight)

        // Save to database
        do {
            try context.save()
            cachedPRs[exerciseName] = prRecord

            // Check if we achieved a new PR
            if let newBest = prRecord.bestWeight, oldBestWeight == nil || newBest > oldBestWeight! {
                let notification = PRNotification(
                    exerciseName: exercise.name,
                    type: .weight,
                    value: newBest,
                    reps: set.reps,
                    date: workoutDate
                )
                recentPRs.append(notification)
                print("🏆 PR MANAGER: New Weight PR for \(exercise.name)! \(newBest) kg × \(set.reps) reps")
                return notification
            } else if let new1RM = prRecord.best1RM, oldBest1RM == nil || new1RM > oldBest1RM! {
                let notification = PRNotification(
                    exerciseName: exercise.name,
                    type: .oneRM,
                    value: new1RM,
                    reps: set.reps,
                    date: workoutDate
                )
                recentPRs.append(notification)
                print("🏆 PR MANAGER: New 1RM PR for \(exercise.name)! \(new1RM) kg")
                return notification
            }
        } catch {
            print("❌ PR MANAGER: Failed to save PR - \(error)")
        }

        return nil
    }

    /// Analyze entire workout for volume PRs
    func analyzeWorkoutForPRs(exercises: [Exercise], workoutDate: Date = Date(), workoutID: UUID) async -> [PRNotification] {
        guard let context = modelContext else {
            print("❌ PR MANAGER: No model context available")
            return []
        }

        var notifications: [PRNotification] = []

        // Group exercises by name to calculate total volume per exercise
        let exerciseGroups = Dictionary(grouping: exercises, by: { $0.name.normalizedExerciseName })

        for (exerciseName, exerciseInstances) in exerciseGroups {
            // Calculate total volume for this exercise in the workout
            var totalVolume: Double = 0
            var totalSets: Int = 0
            let userWeight = userProfileManager?.currentProfile?.weight

            for exercise in exerciseInstances {
                guard let sets = exercise.sets else { continue }

                for set in sets where isValidPRSet(set) {
                    let effectiveWeight = set.bodyWeight ? (userWeight ?? 0) + set.weight : set.weight
                    totalVolume += effectiveWeight * Double(set.reps)
                    totalSets += 1
                }
            }

            if totalVolume > 0 {
                // Get muscle group from first instance
                let muscleGroup = exerciseInstances.first?.muscleGroup ?? ""

                // Get or create PR record
                let prRecord = await getOrCreatePR(for: exerciseName, muscleGroup: muscleGroup, context: context)

                let oldBestVolume = prRecord.bestVolume

                // Update volume PR
                prRecord.updateVolumePR(totalVolume: totalVolume, sets: totalSets, workoutDate: workoutDate, workoutID: workoutID)
                prRecord.totalWorkouts += 1
                prRecord.lastPerformed = workoutDate

                // Check if volume PR was achieved
                if let newVolume = prRecord.bestVolume, oldBestVolume == nil || newVolume > oldBestVolume! {
                    let notification = PRNotification(
                        exerciseName: exerciseInstances.first?.name ?? exerciseName,
                        type: .volume,
                        value: newVolume,
                        sets: totalSets,
                        date: workoutDate
                    )
                    notifications.append(notification)
                    print("🏆 PR MANAGER: New Volume PR for \(exerciseName)! \(newVolume) kg total")
                }

                cachedPRs[exerciseName] = prRecord
            }
        }

        // Save all changes
        do {
            try context.save()
        } catch {
            print("❌ PR MANAGER: Failed to save PRs - \(error)")
        }

        recentPRs.append(contentsOf: notifications)
        return notifications
    }

    // MARK: - PR Lookup

    /// Get PR for an exercise (from cache or database)
    func getPR(for exerciseName: String) async -> ExercisePR? {
        let normalized = exerciseName.normalizedExerciseName

        // Check cache first
        if let cached = cachedPRs[normalized] {
            return cached
        }

        // Fetch from database
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ExercisePR>(
            predicate: #Predicate { $0.exerciseName == normalized }
        )

        do {
            let results = try context.fetch(descriptor)
            if let pr = results.first {
                cachedPRs[normalized] = pr
                return pr
            }
        } catch {
            print("❌ PR MANAGER: Failed to fetch PR - \(error)")
        }

        return nil
    }

    /// Check if a specific set would be a PR (for real-time UI feedback)
    func isSetPR(exerciseName: String, weight: Double, reps: Int) async -> Bool {
        guard let pr = await getPR(for: exerciseName) else {
            // No PR exists yet, so this would be the first PR
            return true
        }

        // Check if this set beats any existing PR
        if let bestWeight = pr.bestWeight, weight > bestWeight {
            return true
        }

        if let best1RM = pr.best1RM {
            let calculated1RM = calculate1RM(weight: weight, reps: reps)
            if calculated1RM > best1RM {
                return true
            }
        }

        if reps >= 5, let best5RM = pr.best5RM, weight > best5RM {
            return true
        }

        if reps >= 10, let best10RM = pr.best10RM, weight > best10RM {
            return true
        }

        return false
    }

    /// Get all PRs for display (premium feature)
    func getAllPRs() async -> [ExercisePR] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<ExercisePR>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ PR MANAGER: Failed to fetch all PRs - \(error)")
            return []
        }
    }

    // MARK: - Helper Methods

    private func getOrCreatePR(for exerciseName: String, muscleGroup: String, context: ModelContext) async -> ExercisePR {
        let normalized = exerciseName.normalizedExerciseName

        // Check cache first
        if let cached = cachedPRs[normalized] {
            return cached
        }

        // Try to fetch from database
        let descriptor = FetchDescriptor<ExercisePR>(
            predicate: #Predicate { $0.exerciseName == normalized }
        )

        do {
            let results = try context.fetch(descriptor)
            if let existing = results.first {
                cachedPRs[normalized] = existing
                return existing
            }
        } catch {
            print("❌ PR MANAGER: Failed to fetch PR - \(error)")
        }

        // Create new PR record
        let newPR = ExercisePR(exerciseName: normalized, muscleGroup: muscleGroup)
        context.insert(newPR)
        cachedPRs[normalized] = newPR

        print("✅ PR MANAGER: Created new PR record for \(exerciseName)")
        return newPR
    }

    private func isValidPRSet(_ set: Exercise.Set) -> Bool {
        // Exclude warm-up sets
        if set.warmUp { return false }

        // Must have weight and reps
        if set.weight <= 0 || set.reps <= 0 { return false }

        // Must be completed (has timestamp)
        if set.time.isEmpty { return false }

        return true
    }

    private func calculate1RM(weight: Double, reps: Int) -> Double {
        if reps == 1 { return weight }
        if reps > 12 { return weight }

        let epley = weight * (1 + Double(reps) / 30.0)
        let brzycki = weight * (36.0 / (37.0 - Double(reps)))
        return (epley + brzycki) / 2.0
    }

    // MARK: - Recalculation & Maintenance

    /// Recalculate all PRs from workout history (expensive operation)
    func recalculateAllPRs() async {
        guard let context = modelContext else {
            print("❌ PR MANAGER: No model context available")
            return
        }

        print("🔄 PR MANAGER: Starting full PR recalculation...")

        // Fetch all DayStorage entries (completed workouts)
        let dayStorageDescriptor = FetchDescriptor<DayStorage>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        do {
            let allDayStorage = try context.fetch(dayStorageDescriptor)

            // Clear existing PRs
            let prDescriptor = FetchDescriptor<ExercisePR>()
            let existingPRs = try context.fetch(prDescriptor)
            for pr in existingPRs {
                context.delete(pr)
            }
            cachedPRs.removeAll()

            // Process each workout chronologically
            for storage in allDayStorage {
                // Fetch the day with exercises
                let storageDayId = storage.dayId
                let dayDescriptor = FetchDescriptor<Day>(
                    predicate: #Predicate { $0.id == storageDayId }
                )
                guard let days = try? context.fetch(dayDescriptor),
                      let day = days.first,
                      let exercises = day.exercises else {
                    continue
                }

                // Parse workout date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMMM yyyy"
                guard let workoutDate = dateFormatter.date(from: storage.date) else {
                    continue
                }

                // Process each exercise
                for exercise in exercises where exercise.done {
                    guard let sets = exercise.sets else { continue }

                    for set in sets {
                        _ = await checkForPR(
                            exercise: exercise,
                            set: set,
                            workoutDate: workoutDate,
                            workoutID: storage.id
                        )
                    }
                }

                // Calculate volume PRs
                _ = await analyzeWorkoutForPRs(
                    exercises: exercises.filter { $0.done },
                    workoutDate: workoutDate,
                    workoutID: storage.id
                )
            }

            try context.save()
            print("✅ PR MANAGER: Recalculation complete! Processed \(allDayStorage.count) workouts")
        } catch {
            print("❌ PR MANAGER: Failed to recalculate PRs - \(error)")
        }
    }

    /// Clear recent PR notifications
    func clearRecentPRs() {
        recentPRs.removeAll()
    }
}

// MARK: - PR Notification Model

struct PRNotification: Identifiable {
    let id = UUID()
    let exerciseName: String
    let type: PRType
    let value: Double       // Weight or volume
    let reps: Int?          // For weight PRs
    let sets: Int?          // For volume PRs
    let date: Date

    enum PRType {
        case weight
        case oneRM
        case volume
        case fiveRM
        case tenRM

        var displayName: String {
            switch self {
            case .weight: return "Weight PR"
            case .oneRM: return "1RM PR"
            case .volume: return "Volume PR"
            case .fiveRM: return "5RM PR"
            case .tenRM: return "10RM PR"
            }
        }

        var icon: String {
            switch self {
            case .weight: return "star.fill"
            case .oneRM: return "trophy.fill"
            case .volume: return "flame.fill"
            case .fiveRM: return "star.circle.fill"
            case .tenRM: return "star.circle.fill"
            }
        }
    }

    init(exerciseName: String, type: PRType, value: Double, reps: Int? = nil, sets: Int? = nil, date: Date = Date()) {
        self.exerciseName = exerciseName
        self.type = type
        self.value = value
        self.reps = reps
        self.sets = sets
        self.date = date
    }
}
