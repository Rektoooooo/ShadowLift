//
//  GymWorkflowTests.swift
//  GymlyUITests
//
//  Created by Claude Code on 24.10.2025.
//

import XCTest

/// UI Tests that simulate actual gym usage patterns
/// These tests automate the exact workflow you do in the gym to catch lag
final class GymWorkflowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // IMPORTANT: Set launch arguments for testing
        app.launchArguments = [
            "-UITestMode", "YES",  // Flag to indicate we're running tests
            "-SkipOnboarding", "YES",  // Skip login/onboarding
            "-UseMockData", "YES"  // Use mock workout data
        ]

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test: Single Set Edit (Baseline)
    /// Tests the most basic operation: tap set → edit → save
    func testSingleSetEdit() throws {
        // Navigate to an exercise
        let exerciseCell = app.tables.cells.containing(.staticText, identifier: "RDL").firstMatch
        XCTAssertTrue(exerciseCell.waitForExistence(timeout: 5), "Exercise should exist")

        exerciseCell.tap()

        // Wait for exercise detail view
        XCTAssertTrue(app.navigationBars["RDL"].waitForExistence(timeout: 2))

        // Tap first set
        let setCell = app.tables.cells.element(boundBy: 0)
        setCell.tap()

        // Wait for edit sheet
        let editSheet = app.sheets.firstMatch
        XCTAssertTrue(editSheet.waitForExistence(timeout: 2))

        // Increase weight
        let increaseWeightButton = app.buttons["increaseWeight"]
        if increaseWeightButton.exists {
            increaseWeightButton.tap()
        }

        // Save
        let doneButton = app.buttons["Done"]
        doneButton.tap()

        // Verify sheet dismissed (smooth transition = no lag)
        XCTAssertFalse(editSheet.exists)
    }

    // MARK: - Test: Gym Session Simulation (STRESS TEST)
    /// Simulates editing 50 sets like in a real gym session
    /// This is the CRITICAL test for catching lag
    func testGymSessionStressTest() throws {
        let numberOfSets = 50
        var editTimes: [TimeInterval] = []

        for i in 1...numberOfSets {
            let startTime = Date()

            // Navigate to exercise (if not already there)
            if i == 1 {
                let exerciseCell = app.tables.cells.element(boundBy: 0)
                XCTAssertTrue(exerciseCell.waitForExistence(timeout: 5))
                exerciseCell.tap()
            }

            // Tap a set
            let setCell = app.tables.cells.element(boundBy: i % 3)  // Cycle through first 3 sets
            setCell.tap()

            // Wait for edit sheet
            let editSheet = app.sheets.firstMatch
            XCTAssertTrue(editSheet.waitForExistence(timeout: 3),
                "Edit sheet should appear for set #\(i)")

            // Modify weight (simulates user action)
            let increaseButton = app.buttons["increaseWeight"]
            if increaseButton.exists {
                increaseButton.tap()
                increaseButton.tap()  // Tap twice
            }

            // Save
            let doneButton = app.buttons["Done"]
            doneButton.tap()

            // Measure how long this took
            let elapsed = Date().timeIntervalSince(startTime)
            editTimes.append(elapsed)

            // Log if slow
            if elapsed > 1.0 {  // Should take <1 second
                print("⚠️ Set #\(i) took \(elapsed)s (SLOW!)")
            }

            // Wait for sheet to dismiss before next iteration
            XCTAssertFalse(editSheet.waitForExistence(timeout: 1),
                "Sheet should dismiss quickly")
        }

        // Analyze results
        let avgTime = editTimes.reduce(0, +) / Double(editTimes.count)
        let maxTime = editTimes.max() ?? 0
        let slowOps = editTimes.filter { $0 > 1.0 }.count

        print("📊 GYM SESSION TEST RESULTS:")
        print("   Total sets edited: \(numberOfSets)")
        print("   Average time per set: \(avgTime)s")
        print("   Slowest operation: \(maxTime)s")
        print("   Operations >1s: \(slowOps)")

        // Assert performance is acceptable
        XCTAssertLessThan(avgTime, 0.5, "Average set edit should be <0.5s")
        XCTAssertLessThan(slowOps, 5, "No more than 5 slow operations allowed")
    }

    // MARK: - Test: Navigation Performance
    /// Tests navigating between views repeatedly (simulates browsing exercises)
    func testRepeatedNavigationPerformance() throws {
        let iterations = 20

        for i in 1...iterations {
            // Tap into exercise
            let exerciseCell = app.tables.cells.element(boundBy: i % 3)
            if exerciseCell.waitForExistence(timeout: 2) {
                exerciseCell.tap()
            }

            // Verify exercise detail loaded
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(backButton.waitForExistence(timeout: 2),
                "Exercise detail should load quickly (iteration \(i))")

            // Navigate back
            backButton.tap()

            // Verify we're back to main view
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2),
                "Should navigate back smoothly (iteration \(i))")
        }
    }

    // MARK: - Test: Workout Done Flow
    /// Tests the "Workout done" button repeatedly (simulates testing)
    func testRepeatedWorkoutDonePerformance() throws {
        // Mark some exercises as done first
        for i in 0..<3 {
            let exerciseCell = app.tables.cells.element(boundBy: i)
            if exerciseCell.waitForExistence(timeout: 2) {
                exerciseCell.tap()

                // Mark as done
                let doneButton = app.buttons["Done"]
                if doneButton.waitForExistence(timeout: 2) {
                    doneButton.tap()
                }

                // Navigate back
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }
        }

        // Click "Workout done" 5 times (simulates testing scenario)
        for i in 1...5 {
            let startTime = Date()

            let workoutDoneButton = app.buttons["Workout done"]
            XCTAssertTrue(workoutDoneButton.waitForExistence(timeout: 2))

            workoutDoneButton.tap()

            // Check if summary appeared (only if exercises were completed)
            let elapsed = Date().timeIntervalSince(startTime)

            print("⏱️ Workout done #\(i) took \(elapsed)s")

            // Should complete quickly
            XCTAssertLessThan(elapsed, 2.0, "Workout done should be fast")
        }
    }

    // MARK: - Test: Memory Stability During Extended Use
    /// Runs the app for extended time to check for memory issues
    func testMemoryStabilityDuringExtendedSession() throws {
        // Perform repetitive actions for 2 minutes
        let endTime = Date().addingTimeInterval(120)  // 2 minutes

        var actionCount = 0

        while Date() < endTime {
            // Navigate to exercise
            let exerciseCell = app.tables.cells.element(boundBy: actionCount % 3)
            if exerciseCell.exists {
                exerciseCell.tap()

                // Wait a bit
                sleep(1)

                // Navigate back
                app.navigationBars.buttons.element(boundBy: 0).tap()

                actionCount += 1
            }
        }

        print("📊 Performed \(actionCount) actions over 2 minutes")
        print("   App should still be responsive")

        // Verify app is still responsive
        let mainView = app.tables.firstMatch
        XCTAssertTrue(mainView.exists, "App should still be responsive after extended use")
    }

    // MARK: - Test: Swipe Actions Performance
    /// Tests the new swipe-to-mark-done feature
    func testSwipeActionPerformance() throws {
        // Navigate to exercise
        let exerciseCell = app.tables.cells.element(boundBy: 0)
        exerciseCell.tap()

        // Swipe on first set
        let setCell = app.tables.cells.element(boundBy: 0)
        XCTAssertTrue(setCell.waitForExistence(timeout: 2))

        let startTime = Date()

        setCell.swipeRight()

        // Tap the "Done" button that appears
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 1) {
            doneButton.tap()
        }

        let elapsed = Date().timeIntervalSince(startTime)

        print("⏱️ Swipe action took \(elapsed)s")
        XCTAssertLessThan(elapsed, 0.5, "Swipe action should be instant")
    }
}
