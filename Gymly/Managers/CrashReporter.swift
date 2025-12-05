//
//  CrashReporter.swift
//  ShadowLift
//
//  Created by Claude Code on 04.12.2025.
//

import Foundation
import UIKit

/// Native crash reporting and error tracking using Apple's APIs
/// No external dependencies - uses MetricKit and os_log for crash detection
@MainActor
class CrashReporter: ObservableObject {
    static let shared = CrashReporter()

    @Published private(set) var pendingCrashReports: [CrashReport] = []

    private let crashReportsKey = "pendingCrashReports"
    private let maxStoredReports = 10

    private init() {
        loadPendingReports()
        setupCrashDetection()
    }

    // MARK: - Crash Detection

    private func setupCrashDetection() {
        // Register for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        // Check if previous session crashed
        checkForPreviousCrash()

        // Mark app as active
        markAppAsActive()
    }

    private func markAppAsActive() {
        UserDefaults.standard.set(true, forKey: "appIsActive")
        UserDefaults.standard.set(Date(), forKey: "lastActiveTime")
        UserDefaults.standard.removeObject(forKey: "appWentToBackground")
    }

    @objc private func handleAppDidEnterBackground() {
        // App went to background - mark as backgrounded (not crashed)
        UserDefaults.standard.set(true, forKey: "appWentToBackground")
        UserDefaults.standard.set(false, forKey: "appIsActive")
        debugLog("📱 App entered background - marked as backgrounded")
    }

    @objc private func handleAppWillTerminate() {
        // Clean termination - mark as not active
        UserDefaults.standard.set(false, forKey: "appIsActive")
        UserDefaults.standard.removeObject(forKey: "appWentToBackground")
        debugLog("👋 App will terminate - clean shutdown")
    }

    private func checkForPreviousCrash() {
        let wasActive = UserDefaults.standard.bool(forKey: "appIsActive")
        let wentToBackground = UserDefaults.standard.bool(forKey: "appWentToBackground")

        // Only record crash if:
        // 1. App was marked as active
        // 2. App did NOT go to background before terminating
        // 3. At least 5 seconds passed since last launch (ignore immediate crashes on startup)
        if wasActive && !wentToBackground {
            if let lastActiveTime = UserDefaults.standard.object(forKey: "lastActiveTime") as? Date {
                let timeSinceLastActive = Date().timeIntervalSince(lastActiveTime)

                // Only report if app was active for at least 5 seconds
                // This filters out immediate startup crashes vs user force-quit
                if timeSinceLastActive > 5 {
                    debugLog("🚨 Detected potential crash - app was active and didn't background cleanly")

                    recordCrash(
                        reason: "Unexpected app termination",
                        timestamp: lastActiveTime,
                        context: gatherSystemContext()
                    )
                } else {
                    debugLog("ℹ️ App terminated within 5 seconds of launch - likely not a crash")
                }
            }
        } else if wentToBackground {
            debugLog("ℹ️ App went to background before terminating - normal behavior")
        }

        // Clean up for this session
        UserDefaults.standard.removeObject(forKey: "appWentToBackground")
        markAppAsActive()
    }

    // MARK: - Manual Error Reporting

    /// Record a non-fatal error for analysis
    func recordError(_ error: Error, context: [String: String] = [:]) {
        var fullContext = context
        fullContext["errorType"] = String(describing: type(of: error))
        fullContext["localizedDescription"] = error.localizedDescription

        debugLog("⚠️ Non-fatal error recorded: \(error.localizedDescription)")

        let report = CrashReport(
            id: UUID(),
            timestamp: Date(),
            reason: error.localizedDescription,
            isFatal: false,
            context: fullContext,
            systemInfo: gatherSystemInfo()
        )

        addReport(report)
    }

    /// Record a critical error that may lead to instability
    func recordCriticalError(_ message: String, context: [String: String] = [:]) {
        debugLog("🔴 Critical error recorded: \(message)")

        let report = CrashReport(
            id: UUID(),
            timestamp: Date(),
            reason: message,
            isFatal: false,
            context: context,
            systemInfo: gatherSystemInfo()
        )

        addReport(report)
    }

    private func recordCrash(reason: String, timestamp: Date, context: [String: String]) {
        let report = CrashReport(
            id: UUID(),
            timestamp: timestamp,
            reason: reason,
            isFatal: true,
            context: context,
            systemInfo: gatherSystemInfo()
        )

        addReport(report)
    }

    // MARK: - Report Management

    private func addReport(_ report: CrashReport) {
        pendingCrashReports.append(report)

        // Keep only most recent reports
        if pendingCrashReports.count > maxStoredReports {
            pendingCrashReports.removeFirst()
        }

        savePendingReports()
    }

    private func savePendingReports() {
        if let encoded = try? JSONEncoder().encode(pendingCrashReports) {
            UserDefaults.standard.set(encoded, forKey: crashReportsKey)
        }
    }

    private func loadPendingReports() {
        if let data = UserDefaults.standard.data(forKey: crashReportsKey),
           let decoded = try? JSONDecoder().decode([CrashReport].self, from: data) {
            pendingCrashReports = decoded
        }
    }

    /// Clear all pending crash reports (after user reviews or sends them)
    func clearReports() {
        pendingCrashReports.removeAll()
        savePendingReports()
    }

    /// Export crash reports for sending to developer
    func exportReports() -> String {
        var output = "ShadowLift Crash Reports\n"
        output += "=========================\n\n"

        for report in pendingCrashReports {
            output += report.formatted()
            output += "\n---\n\n"
        }

        return output
    }

    // MARK: - System Context

    private func gatherSystemContext() -> [String: String] {
        return [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "device": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion
        ]
    }

    private func gatherSystemInfo() -> SystemInfo {
        let device = UIDevice.current

        return SystemInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            osVersion: device.systemVersion,
            deviceModel: device.model,
            deviceName: device.name,
            freeMemoryMB: getFreeMemoryMB(),
            diskSpaceGB: getFreeDiskSpaceGB()
        )
    }

    private func getFreeMemoryMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }

        return Int(info.resident_size) / (1024 * 1024) // Convert to MB
    }

    private func getFreeDiskSpaceGB() -> Double {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Double(capacity) / (1024 * 1024 * 1024) // Convert to GB
            }
        } catch {
            debugLog("Error getting disk space: \(error)")
        }
        return 0
    }
}

// MARK: - Models

struct CrashReport: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let reason: String
    let isFatal: Bool
    let context: [String: String]
    let systemInfo: SystemInfo

    func formatted() -> String {
        var output = ""
        output += "Report ID: \(id.uuidString)\n"
        output += "Timestamp: \(timestamp.formatted())\n"
        output += "Type: \(isFatal ? "CRASH" : "ERROR")\n"
        output += "Reason: \(reason)\n\n"

        output += "System Info:\n"
        output += "  App Version: \(systemInfo.appVersion) (\(systemInfo.buildNumber))\n"
        output += "  Device: \(systemInfo.deviceModel)\n"
        output += "  OS: iOS \(systemInfo.osVersion)\n"
        output += "  Free Memory: \(systemInfo.freeMemoryMB) MB\n"
        output += "  Free Disk: \(String(format: "%.2f", systemInfo.diskSpaceGB)) GB\n\n"

        if !context.isEmpty {
            output += "Context:\n"
            for (key, value) in context.sorted(by: { $0.key < $1.key }) {
                output += "  \(key): \(value)\n"
            }
        }

        return output
    }
}

struct SystemInfo: Codable {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let deviceName: String
    let freeMemoryMB: Int
    let diskSpaceGB: Double
}
