//
//  WorkoutDataFetcher.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 22.09.2025.
//

import Foundation
import SwiftData

// Removed @MainActor - database fetching should NOT block UI thread
class WorkoutDataFetcher {
    private let context: ModelContext

    // Static DateFormatter for performance (expensive to create)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init(context: ModelContext) {
        self.context = context
    }

    nonisolated func fetchWeeklyWorkouts() -> [CompletedWorkout] {
        return fetchWorkouts(weeksBack: 0, numberOfWeeks: 1)
    }

    nonisolated func fetchWorkoutsForComparison() -> (thisWeek: [CompletedWorkout], lastWeek: [CompletedWorkout]) {
        let thisWeek = fetchWorkouts(weeksBack: 0, numberOfWeeks: 1)
        let lastWeek = fetchWorkouts(weeksBack: 1, numberOfWeeks: 1)
        return (thisWeek, lastWeek)
    }

    nonisolated private func fetchWorkouts(weeksBack: Int, numberOfWeeks: Int) -> [CompletedWorkout] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: Date()) ?? Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(numberOfWeeks * 7), to: endDate) else {
            #if DEBUG
            print("🔍 AI Fetch: Failed to create start date")
            #endif
            return []
        }

        let startDateString = Self.dateFormatter.string(from: startDate)
        let endDateString = Self.dateFormatter.string(from: endDate)

        #if DEBUG
        print("🔍 AI Fetch: Looking for workouts between '\(startDateString)' and '\(endDateString)'")
        #endif

        // Optimized: Fetch only DayStorage entries in date range using predicate
        let dayStorageDescriptor = FetchDescriptor<DayStorage>(
            predicate: #Predicate<DayStorage> { storage in
                storage.date >= startDateString && storage.date <= endDateString
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        do {
            // Fetch only relevant DayStorage entries (much faster!)
            let dayStorages = try context.fetch(dayStorageDescriptor)

            #if DEBUG
            print("🔍 AI Fetch: Found \(dayStorages.count) DayStorage entries in date range")
            // Log each DayStorage entry to check for duplicates
            for storage in dayStorages {
                print("   📋 DayStorage: date='\(storage.date)', dayName='\(storage.dayName)', dayId=\(storage.dayId)")
            }
            #endif

            var completedWorkouts: [CompletedWorkout] = []

            for dayStorage in dayStorages {
                // Fetch Day directly by ID
                let dayId = dayStorage.dayId
                let dayDescriptor = FetchDescriptor<Day>(
                    predicate: #Predicate<Day> { day in
                        day.id == dayId
                    }
                )

                guard let day = try context.fetch(dayDescriptor).first else {
                    #if DEBUG
                    print("❌ AI Fetch: No Day found with id \(dayId)")
                    #endif
                    continue
                }

                guard let exercises = day.exercises, !exercises.isEmpty else {
                    continue
                }

                // Separate completed and incomplete exercises
                let completedExercises = exercises.compactMap { exercise -> CompletedExercise? in
                    guard exercise.done,
                          let sets = exercise.sets,
                          !sets.isEmpty else {
                        return nil
                    }

                    let completedSets = sets.map { set in
                        CompletedSet(
                            weight: set.weight,
                            reps: set.reps,
                            failure: set.failure,
                            dropSet: set.dropSet,
                            restPause: set.restPause
                        )
                    }

                    return CompletedExercise(
                        name: exercise.name,
                        muscleGroup: exercise.muscleGroup,
                        sets: completedSets
                    )
                }

                // Get incomplete exercises for recommendations
                let incompleteExercises = exercises.compactMap { exercise -> IncompleteExercise? in
                    guard !exercise.done else { return nil }

                    return IncompleteExercise(
                        name: exercise.name,
                        muscleGroup: exercise.muscleGroup
                    )
                }

                guard !completedExercises.isEmpty else {
                    continue
                }

                let workoutDate = Self.dateFormatter.date(from: dayStorage.date) ?? Date()
                let duration = calculateDuration(from: completedExercises)

                completedWorkouts.append(
                    CompletedWorkout(
                        date: workoutDate,
                        dayName: dayStorage.dayName,
                        duration: duration,
                        exercises: completedExercises,
                        incompleteExercises: incompleteExercises
                    )
                )
            }

            #if DEBUG
            print("🔍 AI Fetch: Final result: \(completedWorkouts.count) completed workouts found")
            #endif

            return completedWorkouts.sorted { $0.date < $1.date }
        } catch {
            #if DEBUG
            print("❌ AI Fetch Error: \(error)")
            #endif
            return []
        }
    }

    nonisolated private func calculateDuration(from exercises: [CompletedExercise]) -> Int {
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let estimatedMinutesPerSet = 3
        let restTimeMinutes = 2
        return (totalSets * estimatedMinutesPerSet) + (totalSets * restTimeMinutes)
    }

    nonisolated func fetchHistoricalData(for exerciseName: String, weeks: Int = 4) -> [ExerciseHistory] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { exercise in
                exercise.name == exerciseName && exercise.done == true
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let exercises = try context.fetch(descriptor)
            return exercises.compactMap { exercise -> ExerciseHistory? in
                guard let sets = exercise.sets, !sets.isEmpty else { return nil }

                let maxWeight = sets.map { $0.weight }.max() ?? 0
                let totalVolume = sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }

                return ExerciseHistory(
                    date: exercise.completedAt ?? exercise.createdAt,
                    maxWeight: maxWeight,
                    totalVolume: totalVolume,
                    setCount: sets.count
                )
            }
        } catch {
            print("Error fetching historical data: \(error)")
            return []
        }
    }
}

struct ExerciseHistory {
    let date: Date
    let maxWeight: Double
    let totalVolume: Double
    let setCount: Int
}

struct IncompleteExercise {
    let name: String
    let muscleGroup: String
}