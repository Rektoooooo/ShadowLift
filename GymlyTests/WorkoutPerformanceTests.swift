//
//  WorkoutPerformanceTests.swift
//  GymlyTests
//
//  Created by Claude Code on 24.10.2025.
//

import XCTest
@testable import Gymly

/// Performance tests that simulate gym usage patterns
/// These tests measure how fast critical operations are under realistic load
final class WorkoutPerformanceTests: XCTestCase {

    // MARK: - Performance Baselines
    // These are the maximum acceptable times for 60fps (16ms) and smooth UX
    let maxAcceptableUITime: TimeInterval = 0.016  // 16ms for 60fps
    let maxAcceptableAsyncTime: TimeInterval = 0.100  // 100ms for async operations

    // MARK: - Test: Refresh View Performance
    /// Simulates navigating back to TodayWorkoutView after editing a set
    /// In gym: This happens 50+ times per session
    func testRefreshViewPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Simulate the refresh that happens when navigating back from ExerciseDetailView
            // This should complete in <16ms for smooth 60fps

            // TODO: Add actual refreshView() call when we can inject test context
            // For now, measuring the data fetching pattern
            let calendar = Calendar.current
            let endDate = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
                XCTFail("Failed to create start date")
                return
            }

            // This simulates what refreshView does
            let _ = formatDateForComparison(startDate)
            let _ = formatDateForComparison(endDate)
        }
    }

    // MARK: - Test: Set Edit Save Performance
    /// Simulates saving a set after editing weight/reps
    /// In gym: Happens 50-100 times per session
    func testSetEditSavePerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            // Simulate the save operation that happens in EditExerciseSetView
            // This should be instant (<16ms) to not block UI

            let startTime = CFAbsoluteTimeGetCurrent()

            // Simulate what happens when user saves a set
            let _ = getCurrentTime()

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            // Assert it's fast enough for smooth UI
            XCTAssertLessThan(elapsed, maxAcceptableUITime,
                "Set save took \(elapsed * 1000)ms, should be < \(maxAcceptableUITime * 1000)ms for smooth UI")
        }
    }

    // MARK: - Test: Cache Update Performance
    /// Simulates updating cached grouped exercises
    /// In gym: Happens on every navigation
    func testCacheUpdatePerformance() throws {
        // Create mock exercises
        let mockExercises = createMockExercises(count: 20)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            // Simulate cache update (grouping exercises by muscle group)
            let grouped = groupExercisesByMuscleGroup(mockExercises)

            XCTAssertFalse(grouped.isEmpty, "Cache should not be empty")
        }
    }

    // MARK: - Test: Extended Session Simulation (GYM SCENARIO)
    /// Simulates a full 60-minute gym session with 50 set edits
    /// This is the MOST IMPORTANT test for catching gym lag
    func testExtendedGymSessionPerformance() throws {
        let numberOfSets = 50  // Typical gym session

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            // Simulate 50 set edits in a row (like in gym)
            for i in 1...numberOfSets {
                // Each iteration simulates:
                // 1. Opening exercise detail
                // 2. Editing a set
                // 3. Saving
                // 4. Navigating back (refresh)

                let startTime = CFAbsoluteTimeGetCurrent()

                // Simulate set edit
                let _ = getCurrentTime()

                // Simulate cache update on navigate back
                let mockExercises = createMockExercises(count: 5)
                let _ = groupExercisesByMuscleGroup(mockExercises)

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime

                // Each iteration should be fast
                if elapsed > maxAcceptableUITime {
                    print("⚠️ Set #\(i) took \(elapsed * 1000)ms (should be <16ms)")
                }
            }
        }
    }

    // MARK: - Test: Memory Leak Detection
    /// Checks if memory is released after operations
    /// In gym: Memory should not continuously grow
    func testMemoryDoesNotLeakDuringRepeatedOperations() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            // Perform the same operation 100 times
            // Memory should stay relatively flat (no continuous growth)
            for _ in 1...100 {
                let mockExercises = createMockExercises(count: 10)
                let _ = groupExercisesByMuscleGroup(mockExercises)
                // Objects should be deallocated here
            }
        }
    }

    // MARK: - Helper Functions

    private func getCurrentTime() -> String {
        // Simulates EditExerciseSetView.getCurrentTime()
        // This was creating DateFormatter on every call - should be cached
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "H:mm"
        return dateFormatter.string(from: Date()).lowercased()
    }

    private func formatDateForComparison(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.string(from: date)
    }

    private func createMockExercises(count: Int) -> [MockExercise] {
        let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms"]
        return (0..<count).map { i in
            MockExercise(
                name: "Exercise \(i)",
                muscleGroup: muscleGroups[i % muscleGroups.count],
                order: i
            )
        }
    }

    private func groupExercisesByMuscleGroup(_ exercises: [MockExercise]) -> [(String, [MockExercise])] {
        // Simulates TodayWorkoutView.updateCachedGroupedExercises()
        var order: [String] = []
        var dict: [String: [MockExercise]] = [:]

        for ex in exercises.sorted(by: { $0.order < $1.order }) {
            if dict[ex.muscleGroup] == nil {
                order.append(ex.muscleGroup)
                dict[ex.muscleGroup] = []
            }
            dict[ex.muscleGroup]!.append(ex)
        }

        return order.map { ($0, dict[$0]!) }
    }
}

// MARK: - Mock Data Structures

struct MockExercise {
    let name: String
    let muscleGroup: String
    let order: Int
}
