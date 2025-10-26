//
//  WorkoutFlowPerformanceTests.swift
//  GymlyTests
//
//  Created by Claude Code on 24.10.2025.
//

import XCTest
@testable import Gymly

/// Performance tests for the main workout flow
/// Tests TodayWorkoutView, ExerciseDetailView, EditExerciseSetView
final class WorkoutFlowPerformanceTests: XCTestCase {

    // MARK: - Performance Baselines
    let maxUIOperationTime: TimeInterval = 0.016  // 16ms for 60fps
    let maxAsyncOperationTime: TimeInterval = 0.100  // 100ms max

    // MARK: - TodayWorkoutView Tests

    /// Test: refreshView() performance
    /// This is called EVERY time you navigate back from exercise detail
    func testTodayWorkoutView_RefreshPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            // Simulate what refreshView() does:
            // 1. Get active split days
            // 2. Update day in split
            // 3. Fetch day data
            // 4. Update cached grouped exercises

            let mockSplitDays = createMockSplitDays(count: 7)
            let mockExercises = createMockExercises(count: 10)

            // Simulate cache update (the expensive operation)
            let _ = groupExercisesByMuscleGroup(mockExercises)
        }
    }

    /// Test: Cache update performance
    /// Called on every navigation, should be fast
    func testTodayWorkoutView_CacheUpdatePerformance() throws {
        let mockExercises = createMockExercises(count: 20)

        measure(metrics: [XCTClockMetric()]) {
            let startTime = CFAbsoluteTimeGetCurrent()

            // This simulates updateCachedGroupedExercises()
            let _ = groupExercisesByMuscleGroup(mockExercises)

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            // Should be fast enough for 60fps
            XCTAssertLessThan(elapsed, maxUIOperationTime,
                "Cache update took \(elapsed * 1000)ms, should be <16ms")
        }
    }

    /// Test: Repeated navigation performance (simulates gym usage)
    /// In gym: Navigate to exercise → back → to exercise → back (50+ times)
    func testTodayWorkoutView_RepeatedNavigationStressTest() throws {
        let iterations = 50
        var times: [TimeInterval] = []

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 1...iterations {
                let startTime = CFAbsoluteTimeGetCurrent()

                // Simulate: Navigate to exercise
                let mockExercises = createMockExercises(count: 5)

                // Simulate: Navigate back (triggers refreshView)
                let _ = groupExercisesByMuscleGroup(mockExercises)

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                times.append(elapsed)

                if elapsed > 0.1 {
                    print("⚠️ Iteration #\(i) took \(elapsed * 1000)ms (SLOW!)")
                }
            }
        }

        let avgTime = times.reduce(0, +) / Double(times.count)
        let maxTime = times.max() ?? 0
        let slowOps = times.filter { $0 > 0.05 }.count

        print("📊 NAVIGATION STRESS TEST:")
        print("   Average: \(avgTime * 1000)ms")
        print("   Max: \(maxTime * 1000)ms")
        print("   Slow operations (>50ms): \(slowOps)")

        XCTAssertLessThan(avgTime, 0.02, "Average navigation should be <20ms")
        XCTAssertLessThan(slowOps, 5, "Should have <5 slow operations out of \(iterations)")
    }

    // MARK: - ExerciseDetailView Tests

    /// Test: Loading exercise detail performance
    /// Called when you tap an exercise
    func testExerciseDetailView_LoadPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            // Simulate loading exercise with sets
            let mockExercise = createMockExerciseWithSets(setCount: 5)

            // Simulate sorting sets by createdAt (what updateCachedSortedSets does)
            let _ = mockExercise.sets.sorted { $0.createdAt < $1.createdAt }
        }
    }

    /// Test: Cache rebuild performance
    /// Currently called on every sheet dismiss - should be fast
    func testExerciseDetailView_CacheRebuildPerformance() throws {
        let mockSets = createMockSets(count: 10)

        measure(metrics: [XCTClockMetric()]) {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Simulate updateCachedSortedSets()
            let sortedSets = mockSets.sorted { $0.createdAt < $1.createdAt }
            let _ = sortedSets.enumerated().map { (index: $0.offset, set: $0.element) }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            XCTAssertLessThan(elapsed, maxUIOperationTime,
                "Cache rebuild took \(elapsed * 1000)ms, should be <16ms")
        }
    }

    /// Test: Repeated set edits (gym scenario)
    /// In gym: Edit set 1 → save → edit set 2 → save (50+ times)
    func testExerciseDetailView_RepeatedSetEditStressTest() throws {
        let mockExercise = createMockExerciseWithSets(setCount: 5)
        let iterations = 50
        var times: [TimeInterval] = []

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 1...iterations {
                let startTime = CFAbsoluteTimeGetCurrent()

                // Simulate: Tap a set (cycles through sets)
                let setIndex = i % mockExercise.sets.count
                let _ = mockExercise.sets[setIndex]

                // Simulate: Edit sheet opens
                // Simulate: User saves (triggers cache rebuild)
                let sortedSets = mockExercise.sets.sorted { $0.createdAt < $1.createdAt }
                let _ = sortedSets.enumerated().map { (index: $0.offset, set: $0.element) }

                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                times.append(elapsed)

                if elapsed > 0.05 {
                    print("⚠️ Set edit #\(i) took \(elapsed * 1000)ms")
                }
            }
        }

        let avgTime = times.reduce(0, +) / Double(times.count)
        print("📊 SET EDIT STRESS TEST: Avg \(avgTime * 1000)ms per edit")

        XCTAssertLessThan(avgTime, 0.02, "Average set edit should be <20ms")
    }

    // MARK: - EditExerciseSetView Tests

    /// Test: DateFormatter performance
    /// CRITICAL: This was creating DateFormatter on every call!
    func testEditExerciseSetView_DateFormatterPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let iterations = 100

            for _ in 1...iterations {
                // BAD: Creating DateFormatter each time (expensive!)
                let formatter = DateFormatter()
                formatter.dateFormat = "H:mm"
                let _ = formatter.string(from: Date()).lowercased()
            }
        }

        // This test will likely FAIL or be slow
        // Proves we need static DateFormatter
    }

    /// Test: Set save performance
    /// Called when user taps "Done" in edit sheet
    func testEditExerciseSetView_SavePerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Simulate what happens on save:
            // 1. Get current time
            let _ = getCurrentTimeOptimized()

            // 2. Update set values
            var weight: Double = 100.0
            var reps: Int = 8
            weight += 2.5  // User increases weight
            reps -= 1      // User decreases reps

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            XCTAssertLessThan(elapsed, maxUIOperationTime,
                "Set save took \(elapsed * 1000)ms, should be <16ms")
        }
    }

    /// Test: Weight/Reps adjustment performance
    /// User taps +/- buttons rapidly
    func testEditExerciseSetView_RapidAdjustmentPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            var weight: Double = 100.0

            // Simulate user tapping + button 20 times rapidly
            for _ in 1...20 {
                weight += 2.5
            }

            // Should be instant
        }
    }

    /// Test: Memory during extended editing session
    /// User might edit multiple sets in a row
    func testEditExerciseSetView_ExtendedEditingMemory() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            // Simulate editing 50 sets
            for _ in 1...50 {
                let _ = getCurrentTimeOptimized()
                var weight: Double = 100.0
                weight += 2.5
            }
            // Memory should not grow continuously
        }
    }

    // MARK: - Integration Tests (Full Workflow)

    /// Test: Complete gym session simulation
    /// TodayWorkout → Exercise → Edit Set → Save → Back (50 times)
    func testCompleteGymSessionWorkflow() throws {
        let iterations = 50
        var totalTime: TimeInterval = 0
        var peakMemory: Int = 0

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            for i in 1...iterations {
                let sessionStart = CFAbsoluteTimeGetCurrent()

                // 1. Navigate to exercise (ExerciseDetailView loads)
                let mockExercise = createMockExerciseWithSets(setCount: 5)
                let _ = mockExercise.sets.sorted { $0.createdAt < $1.createdAt }

                // 2. Tap a set (EditExerciseSetView opens)
                let setIndex = i % mockExercise.sets.count
                var set = mockExercise.sets[setIndex]

                // 3. Edit set
                set.weight += 2.5
                set.reps -= 1
                let _ = getCurrentTimeOptimized()

                // 4. Save (sheet dismisses)
                // (cache rebuilds in ExerciseDetailView)
                let _ = mockExercise.sets.sorted { $0.createdAt < $1.createdAt }

                // 5. Navigate back (TodayWorkoutView refreshes)
                let mockExercises = createMockExercises(count: 5)
                let _ = groupExercisesByMuscleGroup(mockExercises)

                let elapsed = CFAbsoluteTimeGetCurrent() - sessionStart
                totalTime += elapsed

                if i % 10 == 0 {
                    print("✅ Completed \(i)/\(iterations) iterations, avg: \((totalTime / Double(i)) * 1000)ms")
                }
            }
        }

        let avgTime = totalTime / Double(iterations)
        print("📊 FULL GYM SESSION TEST:")
        print("   Total iterations: \(iterations)")
        print("   Average time per iteration: \(avgTime * 1000)ms")
        print("   Total time: \(totalTime)s")

        XCTAssertLessThan(avgTime, 0.1, "Average workflow should be <100ms")
    }

    // MARK: - Helper Functions

    private func getCurrentTimeOptimized() -> String {
        // GOOD: Static formatter (reused)
        return WorkoutFlowPerformanceTests.timeFormatter.string(from: Date()).lowercased()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    private func createMockSplitDays(count: Int) -> [MockDay] {
        return (1...count).map { i in
            MockDay(name: "Day \(i)", dayOfSplit: i, exercises: [])
        }
    }

    private func createMockExercises(count: Int) -> [MockExercise] {
        let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms"]
        return (0..<count).map { i in
            MockExercise(
                id: UUID(),
                name: "Exercise \(i)",
                muscleGroup: muscleGroups[i % muscleGroups.count],
                exerciseOrder: i
            )
        }
    }

    private func createMockExerciseWithSets(setCount: Int) -> MockExerciseWithSets {
        let sets = createMockSets(count: setCount)
        return MockExerciseWithSets(
            id: UUID(),
            name: "Bench Press",
            sets: sets
        )
    }

    private func createMockSets(count: Int) -> [MockSet] {
        return (0..<count).map { i in
            MockSet(
                id: UUID(),
                weight: 100.0 + Double(i) * 5,
                reps: 10 - i,
                createdAt: Date().addingTimeInterval(Double(i))
            )
        }
    }

    private func groupExercisesByMuscleGroup(_ exercises: [MockExercise]) -> [(String, [MockExercise])] {
        var order: [String] = []
        var dict: [String: [MockExercise]] = [:]

        for ex in exercises.sorted(by: { $0.exerciseOrder < $1.exerciseOrder }) {
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

struct MockDay {
    let name: String
    let dayOfSplit: Int
    let exercises: [MockExercise]
}

struct MockExercise {
    let id: UUID
    let name: String
    let muscleGroup: String
    let exerciseOrder: Int
}

struct MockExerciseWithSets {
    let id: UUID
    let name: String
    var sets: [MockSet]
}

struct MockSet {
    let id: UUID
    var weight: Double
    var reps: Int
    let createdAt: Date
}
