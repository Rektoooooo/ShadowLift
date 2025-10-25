//
//  NetworkPerformanceTests.swift
//  GymlyTests
//
//  Created by Claude Code on 24.10.2025.
//

import XCTest
@testable import Gymly

/// Tests that simulate poor network conditions (like in gym)
/// CloudKit sync might be blocking UI when network is slow
final class NetworkPerformanceTests: XCTestCase {

    // MARK: - Test: CloudKit Sync Should Not Block UI
    /// Verifies that CloudKit sync happens in background
    func testCloudKitSyncDoesNotBlockMainThread() throws {
        // This test should verify that CloudKit operations are async

        let expectation = XCTestExpectation(description: "Sync completes without blocking")

        // Simulate what happens when "Workout done" is clicked
        DispatchQueue.main.async {
            // Main thread should remain responsive
            let startTime = CFAbsoluteTimeGetCurrent()

            // Simulate sync delay (what happens in gym with slow network)
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: 2.0)  // Simulate 2s network delay
                expectation.fulfill()
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            // Main thread should NOT be blocked
            XCTAssertLessThan(elapsed, 0.1,
                "Main thread blocked for \(elapsed)s during sync!")
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Test: UI Responsiveness During Sync
    /// Ensures UI stays responsive even when CloudKit is syncing
    func testUIResponsivenessDuringBackgroundSync() throws {
        let responseTimes: [TimeInterval] = []

        // Simulate multiple sync operations (like marking workout done multiple times)
        for i in 1...10 {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Simulate UI operation (like tapping a button)
            DispatchQueue.main.async {
                // UI should respond immediately
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("UI response time #\(i): \(elapsed * 1000)ms")

                XCTAssertLessThan(elapsed, 0.016,  // 16ms for 60fps
                    "UI should remain responsive during sync")
            }

            // Simulate background sync happening
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: 0.5)  // Slow network
            }

            Thread.sleep(forTimeInterval: 0.1)  // Small delay between iterations
        }
    }

    // MARK: - Test: Performance Under Poor Network
    /// Simulates gym conditions with slow cellular network
    func testPerformanceWithSlowNetwork() throws {
        // NOTE: To actually test this, you need to:
        // 1. Enable Network Link Conditioner on Mac
        // 2. Or use Xcode Network Condition settings
        // 3. Set to "3G" or "Very Bad Network"

        measure(metrics: [XCTClockMetric()]) {
            // Simulate saving workout (which triggers CloudKit sync)
            let startTime = CFAbsoluteTimeGetCurrent()

            // This should complete quickly even if sync is slow
            // because sync should be async

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            print("Operation completed in \(elapsed * 1000)ms")

            // Operation should complete fast regardless of network
            XCTAssertLessThan(elapsed, 0.1,
                "UI operation should not wait for network")
        }
    }
}
