//
//  TestDataGenerator.swift
//  ShadowLift
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import SwiftData

#if DEBUG
/// Generates test workout data for AI Summary testing
class TestDataGenerator {

    /// Generates realistic workout data for the past week
    static func generateTestWorkouts(context: ModelContext) {
        debugLog("🧪 TEST DATA: Starting generation...")

        let calendar = Calendar.current
        let today = Date()

        // Create workouts for last 7 days (skip rest days)
        let workoutDays = [
            (daysAgo: 6, name: "Push", exercises: generatePushWorkout()),
            (daysAgo: 5, name: "Pull", exercises: generatePullWorkout()),
            (daysAgo: 4, name: "Legs", exercises: generateLegsWorkout()),
            (daysAgo: 2, name: "Push", exercises: generatePushWorkout()),
            (daysAgo: 1, name: "Pull", exercises: generatePullWorkout()),
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for workout in workoutDays {
            guard let workoutDate = calendar.date(byAdding: .day, value: -workout.daysAgo, to: today) else {
                continue
            }

            let dateString = dateFormatter.string(from: workoutDate)

            // Check if DayStorage already exists for this date
            let checkDescriptor = FetchDescriptor<DayStorage>(
                predicate: #Predicate<DayStorage> { storage in
                    storage.date == dateString
                }
            )

            if (try? context.fetch(checkDescriptor).first) != nil {
                debugLog("🧪 TEST DATA: Skipping \(dateString) - already exists")
                continue
            }

            // Create Day object with exercises
            let day = Day(
                name: workout.name,
                dayOfSplit: 1,
                exercises: workout.exercises,
                date: dateString
            )

            // Mark all exercises as completed
            for exercise in workout.exercises {
                exercise.done = true
                exercise.completedAt = workoutDate
                exercise.day = day
            }

            context.insert(day)

            // Create DayStorage reference
            let dayStorage = DayStorage(
                id: UUID(),
                day: day,
                date: dateString
            )
            context.insert(dayStorage)

            debugLog("🧪 TEST DATA: Created workout for \(dateString) - \(workout.name) with \(workout.exercises.count) exercises")
        }

        // Save everything
        do {
            try context.save()
            debugLog("🧪 TEST DATA: ✅ Successfully generated test workouts!")
            debugLog("🧪 TEST DATA: You can now test AI Summary")
        } catch {
            debugLog("🧪 TEST DATA: ❌ Error saving: \(error)")
        }
    }

    // MARK: - Workout Templates

    private static func generatePushWorkout() -> [Exercise] {
        let exercises = [
            createExercise(name: "Bench Press", muscleGroup: "Chest", sets: [
                (weight: 80.0, reps: 8),
                (weight: 85.0, reps: 6),
                (weight: 87.5, reps: 5),
                (weight: 90.0, reps: 4)
            ]),
            createExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: [
                (weight: 30.0, reps: 10),
                (weight: 32.5, reps: 9),
                (weight: 35.0, reps: 8)
            ]),
            createExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: [
                (weight: 50.0, reps: 8),
                (weight: 55.0, reps: 7),
                (weight: 57.5, reps: 6)
            ]),
            createExercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: [
                (weight: 12.5, reps: 12),
                (weight: 12.5, reps: 12),
                (weight: 12.5, reps: 10)
            ]),
            createExercise(name: "Tricep Pushdowns", muscleGroup: "Triceps", sets: [
                (weight: 30.0, reps: 12),
                (weight: 35.0, reps: 10),
                (weight: 35.0, reps: 10)
            ])
        ]
        return exercises
    }

    private static func generatePullWorkout() -> [Exercise] {
        let exercises = [
            createExercise(name: "Pull-ups", muscleGroup: "Back", sets: [
                (weight: 0.0, reps: 10),
                (weight: 0.0, reps: 9),
                (weight: 0.0, reps: 8),
                (weight: 0.0, reps: 7)
            ]),
            createExercise(name: "Barbell Rows", muscleGroup: "Back", sets: [
                (weight: 70.0, reps: 10),
                (weight: 75.0, reps: 9),
                (weight: 80.0, reps: 8)
            ]),
            createExercise(name: "Lat Pulldowns", muscleGroup: "Back", sets: [
                (weight: 60.0, reps: 12),
                (weight: 65.0, reps: 10),
                (weight: 65.0, reps: 10)
            ]),
            createExercise(name: "Face Pulls", muscleGroup: "Shoulders", sets: [
                (weight: 25.0, reps: 15),
                (weight: 25.0, reps: 15),
                (weight: 25.0, reps: 12)
            ]),
            createExercise(name: "Barbell Curls", muscleGroup: "Biceps", sets: [
                (weight: 30.0, reps: 10),
                (weight: 32.5, reps: 9),
                (weight: 35.0, reps: 7)
            ])
        ]
        return exercises
    }

    private static func generateLegsWorkout() -> [Exercise] {
        let exercises = [
            createExercise(name: "Squats", muscleGroup: "Quads", sets: [
                (weight: 100.0, reps: 8),
                (weight: 110.0, reps: 6),
                (weight: 120.0, reps: 5),
                (weight: 125.0, reps: 4)
            ]),
            createExercise(name: "Romanian Deadlifts", muscleGroup: "Hamstrings", sets: [
                (weight: 80.0, reps: 10),
                (weight: 85.0, reps: 9),
                (weight: 90.0, reps: 8)
            ]),
            createExercise(name: "Leg Press", muscleGroup: "Quads", sets: [
                (weight: 150.0, reps: 12),
                (weight: 160.0, reps: 11),
                (weight: 170.0, reps: 10)
            ]),
            createExercise(name: "Leg Curls", muscleGroup: "Hamstrings", sets: [
                (weight: 40.0, reps: 12),
                (weight: 45.0, reps: 10),
                (weight: 45.0, reps: 10)
            ]),
            createExercise(name: "Calf Raises", muscleGroup: "Calves", sets: [
                (weight: 80.0, reps: 15),
                (weight: 80.0, reps: 15),
                (weight: 80.0, reps: 12)
            ])
        ]
        return exercises
    }

    // MARK: - Helper Functions

    private static func createExercise(name: String, muscleGroup: String, sets: [(weight: Double, reps: Int)]) -> Exercise {
        let exercise = Exercise(
            name: name,
            sets: [],
            repGoal: "\(sets.first?.reps ?? 8)-\(sets.first?.reps ?? 12)",
            muscleGroup: muscleGroup,
            exerciseOrder: 0,
            done: false
        )

        // Create sets
        var exerciseSets: [Exercise.Set] = []
        for (index, setData) in sets.enumerated() {
            let set = Exercise.Set(
                id: UUID(),
                weight: setData.weight,
                reps: setData.reps,
                failure: index == sets.count - 1, // Last set to failure
                warmUp: false,
                restPause: false,
                dropSet: false,
                time: "",
                note: "",
                createdAt: Date(),
                bodyWeight: setData.weight == 0.0,
                exercise: exercise
            )
            exerciseSets.append(set)
        }

        exercise.sets = exerciseSets
        return exercise
    }

    /// Clears all test data (DayStorage entries from last 7 days)
    static func clearTestData(context: ModelContext) {
        debugLog("🗑️ TEST DATA: Clearing test workouts...")

        let calendar = Calendar.current
        let today = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Fetch all DayStorage
        let descriptor = FetchDescriptor<DayStorage>()
        guard let allStorage = try? context.fetch(descriptor) else {
            return
        }

        var deletedCount = 0
        for storage in allStorage {
            guard let storageDate = dateFormatter.date(from: storage.date) else {
                continue
            }

            // Delete if in last 7 days
            if storageDate >= sevenDaysAgo && storageDate <= today {
                // Also delete associated Day
                let dayIdToDelete = storage.dayId
                let dayDescriptor = FetchDescriptor<Day>(
                    predicate: #Predicate<Day> { day in
                        day.id == dayIdToDelete
                    }
                )
                if let day = try? context.fetch(dayDescriptor).first {
                    context.delete(day)
                }
                context.delete(storage)
                deletedCount += 1
            }
        }

        do {
            try context.save()
            debugLog("🗑️ TEST DATA: ✅ Deleted \(deletedCount) test workouts")
        } catch {
            debugLog("🗑️ TEST DATA: ❌ Error deleting: \(error)")
        }
    }
}
#endif
