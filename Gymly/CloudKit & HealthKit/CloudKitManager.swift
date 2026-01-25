//
//  CloudKitManager.swift
//  ShadowLift
//
//  Created by CloudKit Integration on 18.09.2025.
//

import Foundation
import CloudKit
import SwiftData
import SwiftUI
@preconcurrency import Dispatch
@preconcurrency import Network

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container = CKContainer(identifier: "iCloud.com.gymly.app")
    private let privateDatabase: CKDatabase

    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var isCloudKitEnabled = false
    @Published var lastSyncDate: Date?
    @Published var isInActiveWorkout = false // Track if user is actively working out
    @Published var networkQuality: NetworkQuality = .good

    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastCloudKitSync"
    private let cloudKitEnabledKey = "isCloudKitEnabled"

    // MARK: - Network Quality & Timeout Settings
    enum NetworkQuality {
        case excellent, good, poor, offline

        var shouldEnableAutoSync: Bool {
            switch self {
            case .excellent, .good: return true
            case .poor, .offline: return false
            }
        }
    }

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    // Timeout for individual CloudKit operations (prevents hanging on poor connection)
    private let operationTimeout: TimeInterval = 5.0

    // MARK: - Retry Queue for Failed Operations
    struct PendingOperation: Identifiable {
        let id = UUID()
        let description: String
        let operation: @Sendable () async throws -> Void
        var retryCount: Int = 0
        let maxRetries: Int = 3
        let createdAt: Date = Date()

        var canRetry: Bool {
            retryCount < maxRetries
        }
    }

    private var pendingOperations: [PendingOperation] = []
    private var isProcessingQueue = false
    @Published var pendingOperationsCount: Int = 0

    init() {
        self.privateDatabase = container.privateCloudDatabase
        self.lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date

        // Check if we have an existing preference saved
        let hasExistingPreference = userDefaults.object(forKey: cloudKitEnabledKey) != nil
        let savedCloudKitState = userDefaults.bool(forKey: cloudKitEnabledKey)

        if hasExistingPreference {
            self.isCloudKitEnabled = savedCloudKitState
            debugLog("🔥 INIT CLOUDKIT MANAGER - RESTORED EXISTING STATE: \(savedCloudKitState)")
        } else {
            // No existing preference - will be set based on availability check
            self.isCloudKitEnabled = false
            debugLog("🔥 INIT CLOUDKIT MANAGER - NO EXISTING PREFERENCE, WILL CHECK AVAILABILITY")
        }

        Task {
            await checkCloudKitStatus()
        }

        // Start network monitoring
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let previousQuality = self.networkQuality

                if path.status != .satisfied {
                    self.networkQuality = .offline
                } else if path.usesInterfaceType(.wifi) {
                    self.networkQuality = .excellent
                } else if path.usesInterfaceType(.cellular) {
                    self.networkQuality = .good
                } else {
                    self.networkQuality = .good
                }

                debugLog("📡 Network Quality: \(self.networkQuality), Auto-sync: \(self.networkQuality.shouldEnableAutoSync)")

                // If network quality improved from poor/offline to good/excellent, process pending operations
                if !previousQuality.shouldEnableAutoSync && self.networkQuality.shouldEnableAutoSync {
                    debugLog("📡 Network improved - processing pending operations")
                    await self.processPendingOperations()
                }
            }
        }

        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Retry Queue Management

    /// Queue an operation for retry when it fails due to network issues
    func queueForRetry(description: String, operation: @escaping @Sendable () async throws -> Void) {
        let pendingOp = PendingOperation(description: description, operation: operation)
        pendingOperations.append(pendingOp)
        pendingOperationsCount = pendingOperations.count
        debugLog("📋 Queued operation for retry: \(description) (total pending: \(pendingOperations.count))")
    }

    /// Process all pending operations when network is available
    func processPendingOperations() async {
        guard !isProcessingQueue else {
            debugLog("📋 Already processing queue, skipping")
            return
        }
        guard networkQuality.shouldEnableAutoSync else {
            debugLog("📋 Network quality too poor for retry, skipping")
            return
        }
        guard !pendingOperations.isEmpty else {
            return
        }

        isProcessingQueue = true
        debugLog("📋 Processing \(pendingOperations.count) pending operations...")

        var completedIndices: [Int] = []
        var failedPermanently: [Int] = []

        for (index, var operation) in pendingOperations.enumerated() {
            do {
                try await operation.operation()
                completedIndices.append(index)
                debugLog("✅ Retry succeeded: \(operation.description)")
            } catch {
                operation.retryCount += 1
                pendingOperations[index] = operation

                if !operation.canRetry {
                    failedPermanently.append(index)
                    debugLog("❌ Retry failed permanently: \(operation.description)")
                } else {
                    debugLog("⚠️ Retry failed, will try again later: \(operation.description) (attempt \(operation.retryCount)/\(operation.maxRetries))")
                }
            }
        }

        // Remove completed and permanently failed operations
        let indicesToRemove = Set(completedIndices + failedPermanently)
        pendingOperations = pendingOperations.enumerated()
            .filter { !indicesToRemove.contains($0.offset) }
            .map { $0.element }

        pendingOperationsCount = pendingOperations.count
        isProcessingQueue = false

        debugLog("📋 Queue processing complete. Remaining: \(pendingOperations.count)")
    }

    /// Clear all pending operations (use with caution)
    func clearPendingOperations() {
        pendingOperations.removeAll()
        pendingOperationsCount = 0
        debugLog("📋 Cleared all pending operations")
    }

    // MARK: - Timeout Wrapper

    /// Wraps CloudKit operations with timeout to prevent hanging on poor network
    private func withTimeout<T>(
        _ timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CloudKitError.timeout
            }

            if let result = try await group.next() {
                group.cancelAll()
                return result
            }

            throw CloudKitError.timeout
        }
    }

    /// Check if we should sync based on network quality and workout state
    private func shouldPerformSync(allowDuringWorkout: Bool = false) -> Bool {
        guard isCloudKitEnabled else { return false }

        // CRITICAL: Never auto-sync during active gym session (prevents lag)
        if isInActiveWorkout && !allowDuringWorkout {
            debugLog("🚫 SYNC BLOCKED: User is in active workout - sync deferred")
            return false
        }

        // Always allow manual sync, but warn about poor connection
        if !networkQuality.shouldEnableAutoSync {
            debugLog("⚠️ NETWORK QUALITY POOR - Sync may be slow or fail")
        }

        return true
    }

    /// Set workout session state - call this when entering/exiting workout views
    func setWorkoutSessionActive(_ active: Bool) {
        isInActiveWorkout = active
        if active {
            debugLog("🏋️ WORKOUT SESSION STARTED - Auto-sync disabled")
        } else {
            debugLog("✅ WORKOUT SESSION ENDED - Auto-sync re-enabled")
        }
    }

    // MARK: - CloudKit Status
    nonisolated func checkCloudKitStatus() async {
        // Use a class to safely track if continuation has been resumed (prevents race condition)
        final class ResumeState: @unchecked Sendable {
            private let lock = NSLock()
            private var _hasResumed = false

            func tryResume() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                if _hasResumed { return false }
                _hasResumed = true
                return true
            }
        }

        let state = ResumeState()
        let statusTimeout: TimeInterval = 10.0  // 10 second timeout for account status check

        await withCheckedContinuation { continuation in
            // Set up timeout
            let timeoutTask = DispatchWorkItem {
                if state.tryResume() {
                    Task { @MainActor in
                        debugLog("🔥 CLOUDKIT STATUS CHECK: TIMED OUT - Using cached state")
                    }
                    continuation.resume()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + statusTimeout, execute: timeoutTask)

            container.accountStatus { status, error in
                timeoutTask.cancel()

                if state.tryResume() {
                    Task { @MainActor in
                        switch status {
                        case .available:
                            // CloudKit is available, check if user had it enabled before
                            let hasExistingPreference = self.userDefaults.object(forKey: self.cloudKitEnabledKey) != nil
                            let userPreference = self.userDefaults.bool(forKey: self.cloudKitEnabledKey)

                            if hasExistingPreference {
                                // User has a saved preference, respect it
                                self.isCloudKitEnabled = userPreference
                                debugLog("🔥 CLOUDKIT STATUS CHECK: AVAILABLE, EXISTING USER PREFERENCE: \(userPreference)")
                            } else {
                                // First time or fresh install - enable CloudKit by default when available
                                self.isCloudKitEnabled = true
                                self.userDefaults.set(true, forKey: self.cloudKitEnabledKey)
                                debugLog("🔥 CLOUDKIT STATUS CHECK: AVAILABLE, NO EXISTING PREFERENCE - ENABLING BY DEFAULT")
                            }
                            self.syncError = nil
                        case .noAccount:
                            self.isCloudKitEnabled = false
                            self.syncError = "iCloud account not available. Please sign in to iCloud in Settings."
                            self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                            debugLog("🔥 CLOUDKIT STATUS CHECK: NO ACCOUNT")
                        case .restricted:
                            self.isCloudKitEnabled = false
                            self.syncError = "iCloud is restricted on this device."
                            self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                            debugLog("🔥 CLOUDKIT STATUS CHECK: RESTRICTED")
                        case .couldNotDetermine:
                            self.isCloudKitEnabled = false
                            self.syncError = "Could not determine iCloud status."
                            self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                            debugLog("🔥 CLOUDKIT STATUS CHECK: COULD NOT DETERMINE")
                        case .temporarilyUnavailable:
                            self.isCloudKitEnabled = false
                            self.syncError = "iCloud is temporarily unavailable."
                            self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                            debugLog("🔥 CLOUDKIT STATUS CHECK: TEMPORARILY UNAVAILABLE")
                        @unknown default:
                            self.isCloudKitEnabled = false
                            self.syncError = "Unknown iCloud status."
                            self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                            debugLog("🔥 CLOUDKIT STATUS CHECK: UNKNOWN")
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    // MARK: - CloudKit State Management
    func setCloudKitEnabled(_ enabled: Bool) {
        isCloudKitEnabled = enabled
        userDefaults.set(enabled, forKey: cloudKitEnabledKey)
        debugLog("🔥 CLOUDKIT STATE SET TO: \(enabled)")
    }

    /// Updates the last sync date - call after any successful CloudKit save operation
    func updateLastSyncDate() {
        let now = Date()
        userDefaults.set(now, forKey: lastSyncKey)
        lastSyncDate = now
        debugLog("🔥 CLOUDKIT: Updated last sync date to \(now)")
    }

    func isCloudKitAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, error in
                continuation.resume(returning: status == .available)
            }
        }
    }

    // MARK: - Split Sync
    func saveSplit(_ split: Split) async throws {
        guard shouldPerformSync() else {
            throw CloudKitError.notAvailable
        }

        // CRITICAL: Save days FIRST before creating references to them
        // CloudKit requires referenced records to exist before creating references
        debugLog("🔄 SAVESPLIT: Saving \(split.days?.count ?? 0) days for split '\(split.name)'")

        // OPTIMIZATION: Save days in parallel instead of sequentially
        let days = split.days ?? []
        try await withThrowingTaskGroup(of: Void.self) { group in
            for day in days {
                group.addTask {
                    do {
                        try await self.saveDay(day, splitId: split.id)
                        debugLog("✅ SAVESPLIT: Saved day '\(day.name)'")
                    } catch is CloudKitError {
                        // Network timeout - queue for later retry
                        debugLog("⚠️ SAVESPLIT: Day '\(day.name)' queued for retry")
                        throw CloudKitError.timeout
                    }
                }
            }

            // Wait for all days to complete
            try await group.waitForAll()
        }

        // Now save the split record with references to the saved days
        let recordID = CKRecord.ID(recordName: split.id.uuidString)

        // Try to fetch existing record first (with timeout)
        let record: CKRecord
        do {
            record = try await withTimeout(operationTimeout) {
                try await self.privateDatabase.record(for: recordID)
            }
            debugLog("🔄 SAVESPLIT: Updating existing split record '\(split.name)'")
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "Split", recordID: recordID)
            debugLog("🆕 SAVESPLIT: Creating new split record '\(split.name)'")
        }

        // Update record fields
        record["name"] = split.name
        record["isActive"] = split.isActive ? 1 : 0
        record["startDate"] = split.startDate

        // Create references to the days we just saved
        let dayReferences = (split.days ?? []).map { day in
            CKRecord.Reference(recordID: CKRecord.ID(recordName: day.id.uuidString), action: .deleteSelf)
        }
        record["days"] = dayReferences

        do {
            _ = try await withTimeout(operationTimeout) {
                try await self.privateDatabase.save(record)
            }
            debugLog("✅ SAVESPLIT: Split record '\(split.name)' saved successfully")
            // Update last sync date after successful save
            await MainActor.run {
                updateLastSyncDate()
            }
        } catch {
            debugLog("❌ SAVESPLIT: Failed to save split record '\(split.name)': \(error.localizedDescription)")
            throw error
        }
    }

    func saveDay(_ day: Day, splitId: UUID) async throws {
        guard shouldPerformSync() else {
            throw CloudKitError.notAvailable
        }

        // CRITICAL: Save exercises FIRST before creating references to them
        debugLog("🔄 SAVEDAY: Saving \(day.exercises?.count ?? 0) exercises for day '\(day.name)'")

        // OPTIMIZATION: Save exercises in parallel instead of sequentially
        let exercises = day.exercises ?? []
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exercise in exercises {
                group.addTask {
                    try await self.saveExercise(exercise, dayId: day.id)
                    debugLog("✅ SAVEDAY: Saved exercise '\(exercise.name)'")
                }
            }

            try await group.waitForAll()
        }

        // Now save the day record with references
        let recordID = CKRecord.ID(recordName: day.id.uuidString)

        // Try to fetch existing record first (with timeout)
        let record: CKRecord
        do {
            record = try await withTimeout(operationTimeout) {
                try await self.privateDatabase.record(for: recordID)
            }
            debugLog("🔄 SAVEDAY: Updating existing day record '\(day.name)'")
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "Day", recordID: recordID)
            debugLog("🆕 SAVEDAY: Creating new day record '\(day.name)'")
        }

        record["name"] = day.name
        record["dayOfSplit"] = day.dayOfSplit
        record["date"] = day.date
        record["splitId"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: splitId.uuidString), action: .deleteSelf)

        // Create references to the exercises we just saved
        let exerciseReferences = (day.exercises ?? []).map { exercise in
            CKRecord.Reference(recordID: CKRecord.ID(recordName: exercise.id.uuidString), action: .deleteSelf)
        }
        record["exercises"] = exerciseReferences

        do {
            _ = try await withTimeout(operationTimeout) {
                try await self.privateDatabase.save(record)
            }
            debugLog("✅ SAVEDAY: Day record '\(day.name)' saved successfully")
        } catch {
            debugLog("❌ SAVEDAY: Failed to save day record '\(day.name)': \(error.localizedDescription)")
            throw error
        }
    }

    func saveExercise(_ exercise: Exercise, dayId: UUID) async throws {
        guard shouldPerformSync() else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: exercise.id.uuidString)

        // Try to fetch existing record first (with timeout)
        let record: CKRecord
        do {
            record = try await withTimeout(operationTimeout) {
                try await self.privateDatabase.record(for: recordID)
            }
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "Exercise", recordID: recordID)
        }
        record["name"] = exercise.name
        record["repGoal"] = exercise.repGoal
        record["muscleGroup"] = exercise.muscleGroup
        record["createdAt"] = exercise.createdAt
        record["completedAt"] = exercise.completedAt
        record["exerciseOrder"] = exercise.exerciseOrder
        record["done"] = exercise.done ? 1 : 0
        record["dayId"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: dayId.uuidString), action: .deleteSelf)

        // Save sets as data
        if let setsData = try? JSONEncoder().encode(exercise.sets) {
            record["setsData"] = setsData as CKRecordValue
        }

        _ = try await withTimeout(operationTimeout) {
            try await self.privateDatabase.save(record)
        }
    }

    // MARK: - DayStorage Sync
    func saveDayStorage(_ dayStorage: DayStorage) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: dayStorage.id.uuidString)

        // Use timeout to prevent hanging on poor network
        try await withTimeout(operationTimeout) {
            // Try to fetch existing record first
            let record: CKRecord
            do {
                record = try await self.privateDatabase.record(for: recordID)
            } catch {
                // Record doesn't exist, create new one
                record = CKRecord(recordType: "DayStorage", recordID: recordID)
            }
            record["date"] = dayStorage.date
            record["dayId"] = dayStorage.dayId.uuidString
            record["dayName"] = dayStorage.dayName
            record["dayOfSplit"] = dayStorage.dayOfSplit

            try await self.privateDatabase.save(record)
        }

        // Update last sync date after successful save
        await MainActor.run {
            updateLastSyncDate()
        }
    }

    // MARK: - WeightPoint Sync
    func saveWeightPoint(_ weightPoint: WeightPoint) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: weightPoint.cloudKitID)

        // Use timeout to prevent hanging on poor network
        try await withTimeout(operationTimeout) {
            // Try to fetch existing record first
            let record: CKRecord
            do {
                record = try await self.privateDatabase.record(for: recordID)
            } catch {
                // Record doesn't exist, create new one
                record = CKRecord(recordType: "WeightPoint", recordID: recordID)
            }
            record["weight"] = weightPoint.weight
            record["date"] = weightPoint.date

            try await self.privateDatabase.save(record)
        }

        // Update last sync date after successful save
        await MainActor.run {
            updateLastSyncDate()
        }
    }


    // MARK: - Fetch Data
    func fetchAllSplits() async throws -> [Split] {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        debugLog("🔍 FETCHING SPLITS FROM CLOUDKIT...")

        do {
            // Use the simpler records(matching:) API which works without queryable indexes
            let query = CKQuery(recordType: "Split", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDatabase.records(matching: query)

            var fetchedRecords: [CKRecord] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                    debugLog("🔍 Fetched split record: \(record["name"] as? String ?? "unknown")")
                case .failure(let error):
                    debugLog("❌ Error fetching individual record: \(error.localizedDescription)")
                }
            }

            debugLog("🔍 QUERY RESULT: \(fetchedRecords.count) split records found")

            var splits: [Split] = []
            for record in fetchedRecords {
                if let split = await splitFromRecord(record) {
                    splits.append(split)
                    debugLog("🔍 CONVERTED SPLIT: \(split.name), isActive: \(split.isActive)")
                }
            }

            debugLog("🔍 FINAL SPLIT COUNT: \(splits.count)")
            return splits
        } catch let error as CKError {
            debugLog("❌ CLOUDKIT ERROR FETCHING SPLITS: \(error.localizedDescription)")
            debugLog("❌ ERROR CODE: \(error.code.rawValue)")
            debugLog("❌ ERROR DETAILS: \(error)")

            // Return empty array instead of throwing if there are no records or query issues
            if error.code == .unknownItem || error.code == .invalidArguments {
                debugLog("⚠️ NO SPLITS FOUND IN CLOUDKIT OR QUERY ISSUE - RETURNING EMPTY ARRAY")
                return []
            }
            throw error
        }
    }

    private func splitFromRecord(_ record: CKRecord) async -> Split? {
        guard let name = record["name"] as? String,
              let startDate = record["startDate"] as? Date else {
            return nil
        }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let isActive = (record["isActive"] as? Int ?? 0) == 1

        // Fetch days
        var days: [Day] = []
        if let dayReferences = record["days"] as? [CKRecord.Reference] {
            for reference in dayReferences {
                if let day = try? await fetchDay(recordID: reference.recordID) {
                    days.append(day)
                }
            }
        }

        return Split(id: id, name: name, days: days, isActive: isActive, startDate: startDate)
    }

    private func fetchDay(recordID: CKRecord.ID) async throws -> Day {
        // Use timeout to prevent hanging on poor network
        let record = try await withTimeout(operationTimeout) {
            try await self.privateDatabase.record(for: recordID)
        }

        guard let name = record["name"] as? String,
              let dayOfSplit = record["dayOfSplit"] as? Int,
              let date = record["date"] as? String else {
            throw CloudKitError.invalidData
        }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()

        // Fetch exercises (each with its own timeout)
        var exercises: [Exercise] = []
        if let exerciseReferences = record["exercises"] as? [CKRecord.Reference] {
            for reference in exerciseReferences {
                if let exercise = try? await fetchExercise(recordID: reference.recordID) {
                    exercises.append(exercise)
                }
            }
        }

        return Day(id: id, name: name, dayOfSplit: dayOfSplit, exercises: exercises, date: date)
    }

    private func fetchExercise(recordID: CKRecord.ID) async throws -> Exercise {
        // Use timeout to prevent hanging on poor network
        let record = try await withTimeout(operationTimeout) {
            try await self.privateDatabase.record(for: recordID)
        }

        guard let name = record["name"] as? String,
              let repGoal = record["repGoal"] as? String,
              let muscleGroup = record["muscleGroup"] as? String,
              let exerciseOrder = record["exerciseOrder"] as? Int else {
            throw CloudKitError.invalidData
        }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let createdAt = record["createdAt"] as? Date ?? Date()
        let completedAt = record["completedAt"] as? Date
        let done = (record["done"] as? Int ?? 0) == 1

        // Decode sets
        var sets: [Exercise.Set] = []
        if let setsData = record["setsData"] as? Data {
            sets = (try? JSONDecoder().decode([Exercise.Set].self, from: setsData)) ?? []
        }

        return Exercise(
            id: id,
            name: name,
            sets: sets,
            repGoal: repGoal,
            muscleGroup: muscleGroup,
            createdAt: createdAt,
            completedAt: completedAt,
            exerciseOrder: exerciseOrder,
            done: done
        )
    }

    func fetchAllDayStorage() async throws -> [DayStorage] {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        do {
            let query = CKQuery(recordType: "DayStorage", predicate: NSPredicate(value: true))
            let records = try await privateDatabase.records(matching: query).matchResults.compactMap { try? $0.1.get() }

            var dayStorages: [DayStorage] = []
            for record in records {
                if let date = record["date"] as? String,
                   let dayIdString = record["dayId"] as? String,
                   let dayName = record["dayName"] as? String,
                   let dayOfSplit = record["dayOfSplit"] as? Int,
                   let dayId = UUID(uuidString: dayIdString) {
                    let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
                    dayStorages.append(DayStorage(id: id, dayId: dayId, dayName: dayName, dayOfSplit: dayOfSplit, date: date))
                }
            }

            return dayStorages
        } catch let error as CKError {
            if error.code == .unknownItem || error.code == .invalidArguments {
                return []
            }
            throw error
        }
    }

    func fetchAllWeightPoints() async throws -> [WeightPoint] {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        do {
            let query = CKQuery(recordType: "WeightPoint", predicate: NSPredicate(value: true))
            let records = try await privateDatabase.records(matching: query).matchResults.compactMap { try? $0.1.get() }

            var weightPoints: [WeightPoint] = []
            for record in records {
                if let weight = record["weight"] as? Double,
                   let date = record["date"] as? Date {
                    weightPoints.append(WeightPoint(date: date, weight: weight))
                }
            }

            return weightPoints
        } catch let error as CKError {
            if error.code == .unknownItem || error.code == .invalidArguments {
                return []
            }
            throw error
        }
    }


    // MARK: - Delete Operations
    func deleteSplit(_ splitId: UUID) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: splitId.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteDay(_ dayId: UUID) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: dayId.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteExercise(_ exerciseId: UUID) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: exerciseId.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Full Sync
    @MainActor
    func performFullSync(context: ModelContext, config: Config) async {
        guard shouldPerformSync() else {
            debugLog("❌ PERFORMFULLSYNC: CloudKit not enabled or network unavailable")
            return
        }

        // Check network quality and warn user
        if networkQuality == .poor {
            debugLog("⚠️ PERFORMFULLSYNC: Network quality is POOR - sync may be slow")
            self.syncError = "Network quality is poor. Sync may take longer than usual."
        }

        debugLog("🔄 PERFORMFULLSYNC: Starting full CloudKit sync")

        self.isSyncing = true

        // Run sync in background task - network operations are inherently async
        Task(priority: .utility) {
            do {
                // Sync Splits
                let descriptor = FetchDescriptor<Split>()
                let localSplits = try context.fetch(descriptor)
                debugLog("🔄 PERFORMFULLSYNC: Found \(localSplits.count) local splits to sync")

                // OPTIMIZATION: Sync splits in parallel with concurrency limit
                var successCount = 0
                var timeoutCount = 0

                for split in localSplits {
                    debugLog("🔄 PERFORMFULLSYNC: Uploading split '\(split.name)' to CloudKit...")
                    do {
                        try await self.saveSplit(split)
                        debugLog("✅ PERFORMFULLSYNC: Split '\(split.name)' uploaded successfully")
                        successCount += 1
                    } catch let error as CloudKitError where error == .timeout {
                        debugLog("⏱️ PERFORMFULLSYNC: Split '\(split.name)' timed out - queuing for retry")
                        timeoutCount += 1

                        // Log the rate limit - can't queue retry since Split is not Sendable
                        // The next full sync will retry this split
                        debugLog("⏳ PERFORMFULLSYNC: Rate limited saving split '\(split.name)', will retry on next sync")
                    } catch {
                        debugLog("❌ PERFORMFULLSYNC: Failed to upload split '\(split.name)': \(error.localizedDescription)")
                        // Continue with other splits even if one fails
                    }
                }

                // Sync DayStorage
                let dayStorageDescriptor = FetchDescriptor<DayStorage>()
                let localDayStorages = try context.fetch(dayStorageDescriptor)
                for dayStorage in localDayStorages {
                    try? await self.saveDayStorage(dayStorage)
                }

                // Sync WeightPoints
                let weightPointDescriptor = FetchDescriptor<WeightPoint>()
                let localWeightPoints = try context.fetch(weightPointDescriptor)
                for weightPoint in localWeightPoints {
                    try? await self.saveWeightPoint(weightPoint)
                }

                // Sync Progress Photos (with full images)
                let progressPhotoDescriptor = FetchDescriptor<ProgressPhoto>()
                let localProgressPhotos = try context.fetch(progressPhotoDescriptor)
                debugLog("🔄 PERFORMFULLSYNC: Found \(localProgressPhotos.count) progress photos to sync")

                for photo in localProgressPhotos {
                    // Load full image from Photos library if available
                    if let assetID = photo.photoAssetID {
                        if let fullImage = await PhotoManager.shared.loadImage(from: assetID) {
                            do {
                                try await self.saveProgressPhoto(photo, fullImage: fullImage)
                                debugLog("✅ PERFORMFULLSYNC: Progress photo synced")
                            } catch {
                                debugLog("❌ PERFORMFULLSYNC: Failed to sync progress photo - \(error)")
                            }
                        } else {
                            debugLog("⚠️ PERFORMFULLSYNC: Could not load image from Photos library for photo \(photo.id?.uuidString ?? "unknown")")
                        }
                    } else {
                        debugLog("⚠️ PERFORMFULLSYNC: Photo \(photo.id?.uuidString ?? "unknown") has no asset ID, skipping")
                    }
                }

                // Update last sync date
                await MainActor.run {
                    let now = Date()
                    self.userDefaults.set(now, forKey: self.lastSyncKey)
                    self.lastSyncDate = now
                    self.isSyncing = false

                    if timeoutCount > 0 {
                        self.syncError = "\(successCount) items synced, \(timeoutCount) timed out (will retry later)"
                    } else {
                        self.syncError = nil
                    }
                    debugLog("✅ PERFORMFULLSYNC: Sync complete - \(successCount) successful, \(timeoutCount) timed out")
                }
            } catch {
                await MainActor.run {
                    debugLog("❌ PERFORMFULLSYNC ERROR: \(error.localizedDescription)")
                    self.syncError = error.localizedDescription
                    self.isSyncing = false
                }
            }
        }
    }

    @MainActor
    func fetchAndMergeData(context: ModelContext, config: Config) async {
        guard isCloudKitEnabled else {
            debugLog("🔥 CLOUDKIT NOT ENABLED - SKIPPING FETCH")
            return
        }

        debugLog("🔥 STARTING FETCHANDMERGEDATA")
        self.isSyncing = true
        self.syncError = nil

        do {
            // Fetch from CloudKit (happens on background thread)
            let cloudSplits = try await fetchAllSplits()
            let cloudDayStorages = try await fetchAllDayStorage()
            let cloudWeightPoints = try await fetchAllWeightPoints()

            debugLog("🔥 FETCHED FROM CLOUDKIT: \(cloudSplits.count) splits, \(cloudDayStorages.count) day storages, \(cloudWeightPoints.count) weight points")

            // Merge with local data (must happen on main thread with ModelContext)
            let localSplitDescriptor = FetchDescriptor<Split>()
            let localSplits = try context.fetch(localSplitDescriptor)

            for cloudSplit in cloudSplits {
                if let localSplit = localSplits.first(where: { $0.id == cloudSplit.id }) {
                    // Conflict resolution: use "last write wins" based on startDate timestamp
                    // (startDate is updated when split is modified)
                    if cloudSplit.startDate > localSplit.startDate {
                        // Cloud is newer - update local with cloud data
                        localSplit.name = cloudSplit.name
                        localSplit.isActive = cloudSplit.isActive
                        localSplit.startDate = cloudSplit.startDate
                        // Note: days are handled separately via their own sync
                        debugLog("🔄 MERGED SPLIT (cloud newer): \(cloudSplit.name)")
                    } else {
                        debugLog("⏭️ SKIPPED SPLIT (local newer): \(localSplit.name)")
                    }
                } else {
                    // New split from cloud - insert it
                    context.insert(cloudSplit)
                    debugLog("🔥 INSERTED SPLIT: \(cloudSplit.name), isActive: \(cloudSplit.isActive)")
                }
            }

            // CRITICAL: If no split is active after CloudKit sync, activate the first one
            // This ensures splits appear immediately on TodayWorkoutView
            let updatedLocalSplits = try context.fetch(FetchDescriptor<Split>())
            let hasActiveSplit = updatedLocalSplits.contains(where: { $0.isActive })

            if !hasActiveSplit, let firstSplit = updatedLocalSplits.first {
                debugLog("🔥 NO ACTIVE SPLIT FOUND - Activating first split: \(firstSplit.name)")
                firstSplit.isActive = true
            }

            let localDayStorageDescriptor = FetchDescriptor<DayStorage>()
            let localDayStorages = try context.fetch(localDayStorageDescriptor)

            for cloudDayStorage in cloudDayStorages {
                if !localDayStorages.contains(where: { $0.id == cloudDayStorage.id }) {
                    context.insert(cloudDayStorage)
                }
            }

            let localWeightPointDescriptor = FetchDescriptor<WeightPoint>()
            let localWeightPoints = try context.fetch(localWeightPointDescriptor)

            for cloudWeightPoint in cloudWeightPoints {
                if !localWeightPoints.contains(where: { $0.id == cloudWeightPoint.id }) {
                    context.insert(cloudWeightPoint)
                }
            }

            // Fetch and restore Progress Photos from CloudKit
            let cloudProgressPhotos = try await fetchProgressPhotos()
            debugLog("🔥 FETCHED FROM CLOUDKIT: \(cloudProgressPhotos.count) progress photos")

            let localProgressPhotoDescriptor = FetchDescriptor<ProgressPhoto>()
            let localProgressPhotos = try context.fetch(localProgressPhotoDescriptor)

            // Get user profile to link photos
            let userProfileDescriptor = FetchDescriptor<UserProfile>()
            let userProfile = try context.fetch(userProfileDescriptor).first

            for (cloudPhoto, imageData) in cloudProgressPhotos {
                // Skip if photo already exists locally
                if localProgressPhotos.contains(where: { $0.id == cloudPhoto.id }) {
                    debugLog("📸 CLOUDKIT: Photo \(cloudPhoto.id?.uuidString ?? "unknown") already exists locally, skipping")
                    continue
                }

                // Convert Data to UIImage
                guard let image = UIImage(data: imageData) else {
                    debugLog("❌ CLOUDKIT: Failed to create UIImage from data for photo \(cloudPhoto.id?.uuidString ?? "unknown")")
                    continue
                }

                // Save to Photos library and get asset ID
                if let assetID = await PhotoManager.shared.saveToPhotosLibrary(image: image) {
                    // Update photo with asset ID and link to user profile
                    cloudPhoto.photoAssetID = assetID
                    cloudPhoto.userProfile = userProfile

                    // Insert into context
                    context.insert(cloudPhoto)

                    // Add to user profile's photos array
                    if let profile = userProfile {
                        if profile.progressPhotos == nil {
                            profile.progressPhotos = []
                        }
                        profile.progressPhotos?.append(cloudPhoto)
                    }

                    debugLog("✅ CLOUDKIT: Restored progress photo \(cloudPhoto.id?.uuidString ?? "unknown") to Photos library")
                } else {
                    debugLog("❌ CLOUDKIT: Failed to save photo \(cloudPhoto.id?.uuidString ?? "unknown") to Photos library")
                }
            }

            // Save context
            try context.save()
            debugLog("🔥 CONTEXT SAVED SUCCESSFULLY")

            // Update last sync date
            let now = Date()
            userDefaults.set(now, forKey: lastSyncKey)
            self.lastSyncDate = now
            self.isSyncing = false
        } catch {
            debugLog("❌ FETCHANDMERGEDATA ERROR: \(error)")
            self.syncError = error.localizedDescription
            self.isSyncing = false
        }
    }

    // MARK: - UserProfile CloudKit Methods

    func saveUserProfile(_ profile: UserProfile) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        do {
            // Use fixed record ID for user profile so there's only one per user
            let recordID = CKRecord.ID(recordName: "user_profile", zoneID: .default)

            let record: CKRecord
            do {
                // Try to fetch existing record to update it
                let existingRecord = try await privateDatabase.record(for: recordID)
                record = existingRecord
                debugLog("🔄 USER PROFILE: Updating existing CloudKit record")
            } catch {
                // Record doesn't exist, create new one
                record = CKRecord(recordType: "UserProfile", recordID: recordID)
                debugLog("🆕 USER PROFILE: Creating new CloudKit record")
            }

            // Update record with current profile data
            record["username"] = profile.username as CKRecordValue
            record["email"] = profile.email as CKRecordValue
            record["height"] = profile.height as CKRecordValue
            record["weight"] = profile.weight as CKRecordValue
            record["age"] = profile.age as CKRecordValue
            record["bmi"] = profile.bmi as CKRecordValue
            record["isHealthEnabled"] = (profile.isHealthEnabled ? 1 : 0) as CKRecordValue
            record["weightUnit"] = profile.weightUnit as CKRecordValue
            record["roundSetWeights"] = (profile.roundSetWeights ? 1 : 0) as CKRecordValue
            record["updatedAt"] = profile.updatedAt as CKRecordValue
            record["modifiedAt"] = Date() as CKRecordValue // For CloudKit query sorting

            if let cloudKitID = profile.profileImageCloudKitID {
                record["profileImageCloudKitID"] = cloudKitID as CKRecordValue
            }

            _ = try await privateDatabase.save(record)
            debugLog("✅ USER PROFILE: Saved to CloudKit with ID: \(record.recordID.recordName)")

            // Update last sync date after successful save
            await MainActor.run {
                updateLastSyncDate()
            }

        } catch {
            debugLog("❌ USER PROFILE: Failed to save to CloudKit - \(error)")
            throw CloudKitError.syncFailed(error.localizedDescription)
        }
    }

    func fetchUserProfile() async throws -> [String: Any]? {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        // Use direct record fetch with fixed ID instead of query to avoid field queryability issues
        let recordID = CKRecord.ID(recordName: "user_profile", zoneID: .default)

        do {
            let record = try await privateDatabase.record(for: recordID)
            debugLog("✅ USER PROFILE: Found existing CloudKit profile")
            return UserProfile.fromCKRecord(record)
        } catch {
            // Record doesn't exist or other error
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                debugLog("🔍 USER PROFILE: No CloudKit profile found")
                return nil
            } else {
                debugLog("❌ USER PROFILE: Failed to fetch from CloudKit - \(error)")
                throw CloudKitError.syncFailed(error.localizedDescription)
            }
        }
    }

    func saveProfileImage(_ image: UIImage) async throws -> String {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw CloudKitError.invalidData
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("profile_image.jpg")
        try imageData.write(to: tempURL)

        let asset = CKAsset(fileURL: tempURL)

        // Use fixed record ID for profile image so there's only one per user
        let recordID = CKRecord.ID(recordName: "user_profile_image", zoneID: .default)
        let record: CKRecord

        do {
            // Try to fetch existing record first
            let existingRecord = try await privateDatabase.record(for: recordID)
            record = existingRecord
            debugLog("🔄 PROFILE IMAGE: Updating existing CloudKit record")
        } catch {
            // Create new record if it doesn't exist
            record = CKRecord(recordType: "ProfileImage", recordID: recordID)
            debugLog("🆕 PROFILE IMAGE: Creating new CloudKit record")
        }

        record["image"] = asset

        do {
            _ = try await privateDatabase.save(record)
            debugLog("✅ PROFILE IMAGE: Saved to CloudKit")

            // Update last sync date after successful save
            await MainActor.run {
                updateLastSyncDate()
            }

            return "cloudkit_profile_image"
        } catch {
            debugLog("❌ PROFILE IMAGE: Failed to save to CloudKit - \(error)")
            throw CloudKitError.syncFailed(error.localizedDescription)
        }
    }

    func fetchProfileImage() async throws -> UIImage? {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        // Use the same fixed record ID as saveProfileImage
        let recordID = CKRecord.ID(recordName: "user_profile_image", zoneID: .default)

        do {
            let record = try await privateDatabase.record(for: recordID)

            if let asset = record["image"] as? CKAsset,
               let fileURL = asset.fileURL,
               let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                debugLog("✅ PROFILE IMAGE: Fetched from CloudKit")
                return image
            }

            debugLog("🔍 PROFILE IMAGE: Record found but no valid image data")
            return nil
        } catch {
            debugLog("🔍 PROFILE IMAGE: No CloudKit profile image found")
            return nil
        }
    }

    // MARK: - ProgressPhoto CloudKit Methods

    /// Save progress photo to CloudKit with full image
    func saveProgressPhoto(_ photo: ProgressPhoto, fullImage: UIImage) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        guard let photoID = photo.id else {
            throw CloudKitError.invalidData
        }

        debugLog("📸 CLOUDKIT: Saving progress photo \(photoID)")

        // Compress image for CloudKit (max 10MB, CloudKit limit is 25MB but we'll be conservative)
        guard let imageData = fullImage.jpegData(compressionQuality: 0.85) else {
            throw CloudKitError.invalidData
        }

        // Write to temporary file for CKAsset
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress_photo_\(photoID.uuidString).jpg")
        try imageData.write(to: tempURL)

        let asset = CKAsset(fileURL: tempURL)
        let recordID = CKRecord.ID(recordName: photoID.uuidString)

        let record: CKRecord
        do {
            // Try to fetch existing record
            record = try await privateDatabase.record(for: recordID)
            debugLog("🔄 PROGRESS PHOTO: Updating existing CloudKit record")
        } catch {
            // Create new record
            record = CKRecord(recordType: "ProgressPhoto", recordID: recordID)
            debugLog("🆕 PROGRESS PHOTO: Creating new CloudKit record")
        }

        // Store full image as asset
        record["imageAsset"] = asset

        // Store metadata
        if let date = photo.date {
            record["date"] = date as CKRecordValue
        }
        if let weight = photo.weight {
            record["weight"] = weight as CKRecordValue
        }
        if let notes = photo.notes {
            record["notes"] = notes as CKRecordValue
        }
        if let photoType = photo.photoType {
            record["photoType"] = photoType.rawValue as CKRecordValue
        }
        if let createdAt = photo.createdAt {
            record["createdAt"] = createdAt as CKRecordValue
        }
        if let thumbnailData = photo.thumbnailData {
            record["thumbnailData"] = thumbnailData as CKRecordValue
        }

        do {
            _ = try await withTimeout(30.0) { // 30 second timeout for image upload
                try await self.privateDatabase.save(record)
            }
            debugLog("✅ PROGRESS PHOTO: Saved to CloudKit")

            // Update last sync date after successful save
            await MainActor.run {
                updateLastSyncDate()
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            // Clean up temp file even on error
            try? FileManager.default.removeItem(at: tempURL)
            debugLog("❌ PROGRESS PHOTO: Failed to save - \(error)")
            throw CloudKitError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetch all progress photos from CloudKit
    func fetchProgressPhotos() async throws -> [(photo: ProgressPhoto, imageData: Data)] {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        debugLog("📸 CLOUDKIT: Fetching progress photos...")

        do {
            let query = CKQuery(recordType: "ProgressPhoto", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDatabase.records(matching: query)

            var results: [(photo: ProgressPhoto, imageData: Data)] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let photoData = try? await progressPhotoFromRecord(record) {
                        results.append(photoData)
                        debugLog("✅ PROGRESS PHOTO: Fetched photo from CloudKit")
                    }
                case .failure(let error):
                    debugLog("❌ PROGRESS PHOTO: Error fetching record - \(error)")
                }
            }

            debugLog("📸 CLOUDKIT: Fetched \(results.count) progress photos")
            return results
        } catch let error as CKError {
            if error.code == .unknownItem || error.code == .invalidArguments {
                debugLog("📸 CLOUDKIT: No progress photos found")
                return []
            }
            throw error
        }
    }

    /// Convert CloudKit record to ProgressPhoto with image data
    private func progressPhotoFromRecord(_ record: CKRecord) async throws -> (photo: ProgressPhoto, imageData: Data)? {
        guard let asset = record["imageAsset"] as? CKAsset,
              let fileURL = asset.fileURL,
              let imageData = try? Data(contentsOf: fileURL) else {
            debugLog("❌ PROGRESS PHOTO: No valid image asset in record")
            return nil
        }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let date = record["date"] as? Date
        let weight = record["weight"] as? Double
        let notes = record["notes"] as? String
        let photoTypeString = record["photoType"] as? String
        let photoType = photoTypeString.flatMap { PhotoType(rawValue: $0) }
        let createdAt = record["createdAt"] as? Date
        let thumbnailData = record["thumbnailData"] as? Data

        let photo = ProgressPhoto(
            id: id,
            date: date ?? Date(),
            photoAssetID: nil, // Will be set when saved to Photos library
            thumbnailData: thumbnailData,
            weight: weight,
            notes: notes,
            photoType: photoType ?? .front,
            createdAt: createdAt ?? Date(),
            userProfile: nil // Will be linked when inserted
        )

        return (photo, imageData)
    }

    /// Delete progress photo from CloudKit
    func deleteProgressPhoto(_ photoID: UUID) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: photoID.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
        debugLog("🗑️ PROGRESS PHOTO: Deleted from CloudKit")
    }

    /// Delete user profile from CloudKit
    func deleteUserProfile() async throws {
        let recordID = CKRecord.ID(recordName: "user_profile")
        try await privateDatabase.deleteRecord(withID: recordID)
        debugLog("🗑️ USER PROFILE: Deleted from CloudKit")
    }

    /// Delete profile image from CloudKit
    func deleteProfileImage() async throws {
        let recordID = CKRecord.ID(recordName: "user_profile_image")
        try await privateDatabase.deleteRecord(withID: recordID)
        debugLog("🗑️ PROFILE IMAGE: Deleted from CloudKit")
    }

    // MARK: - Public Split Sharing

    /// Share a split publicly and get shareable link
    /// Stores split in CloudKit public database and returns clean URL
    /// Returns: URL like https://shadowlift.app/splits/{id}
    func shareSplit(_ split: Split) async throws -> URL {
        debugLog("🔗 SHARE SPLIT: Starting public share for '\(split.name)'")

        // Use the public database for sharing
        let publicDatabase = container.publicCloudDatabase
        let shareID = split.id.uuidString
        let recordID = CKRecord.ID(recordName: "shared_\(shareID)")

        // Create or update the public record
        let record: CKRecord
        do {
            record = try await publicDatabase.record(for: recordID)
            debugLog("🔄 SHARE SPLIT: Updating existing public record")
        } catch {
            record = CKRecord(recordType: "SharedSplit", recordID: recordID)
            debugLog("🆕 SHARE SPLIT: Creating new public record")
        }

        // Encode split to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let splitData = try? encoder.encode(split) else {
            throw CloudKitError.invalidData
        }

        // Store split data and metadata
        record["splitData"] = splitData as CKRecordValue
        record["splitName"] = split.name as CKRecordValue
        record["splitDays"] = (split.days?.count ?? 0) as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["version"] = 1 as CKRecordValue

        // Calculate total exercises for metadata
        let totalExercises = split.days?.reduce(0) { total, day in
            total + (day.exercises?.count ?? 0)
        } ?? 0
        record["totalExercises"] = totalExercises as CKRecordValue

        debugLog("🔗 SHARE SPLIT: Split data size: \(splitData.count) bytes")

        do {
            _ = try await withTimeout(15.0) {
                try await publicDatabase.save(record)
            }
            debugLog("✅ SHARE SPLIT: Saved to public database")

            // Create clean shareable URL with just the split ID
            let shareURL = URL(string: "https://shadowlift.app/splits/\(shareID)")!
            debugLog("🔗 SHARE SPLIT: Generated shareable link: \(shareURL.absoluteString)")

            return shareURL

        } catch {
            debugLog("❌ SHARE SPLIT: Failed to save - \(error)")
            throw CloudKitError.syncFailed(error.localizedDescription)
        }
    }

    /// Fetch a shared split by ID from public database
    func fetchSharedSplit(shareID: String) async throws -> Split {
        debugLog("📥 FETCH SHARED SPLIT: Fetching split with ID \(shareID)")

        let publicDatabase = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "shared_\(shareID)")

        do {
            let record = try await withTimeout(10.0) {
                try await publicDatabase.record(for: recordID)
            }

            guard let splitData = record["splitData"] as? Data else {
                throw CloudKitError.invalidData
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let split = try decoder.decode(Split.self, from: splitData)

            debugLog("✅ FETCH SHARED SPLIT: Successfully fetched '\(split.name)'")
            return split

        } catch {
            debugLog("❌ FETCH SHARED SPLIT: Failed - \(error)")
            throw CloudKitError.syncFailed(error.localizedDescription)
        }
    }

    /// Get metadata for a shared split (for preview without full download)
    func fetchSharedSplitMetadata(shareID: String) async throws -> (name: String, days: Int, exercises: Int) {
        debugLog("📋 FETCH SHARED SPLIT METADATA: Fetching metadata for \(shareID)")

        let publicDatabase = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "shared_\(shareID)")

        do {
            let record = try await withTimeout(10.0) {
                try await publicDatabase.record(for: recordID)
            }

            let name = record["splitName"] as? String ?? "Unknown Split"
            let days = record["splitDays"] as? Int ?? 0
            let exercises = record["totalExercises"] as? Int ?? 0

            debugLog("✅ FETCH SHARED SPLIT METADATA: \(name) - \(days) days, \(exercises) exercises")
            return (name, days, exercises)

        } catch {
            debugLog("❌ FETCH SHARED SPLIT METADATA: Failed - \(error)")
            throw CloudKitError.syncFailed(error.localizedDescription)
        }
    }
}

enum CloudKitError: LocalizedError, Equatable {
    case notAvailable
    case invalidData
    case syncFailed(String)
    case timeout
    case poorNetworkQuality

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .invalidData:
            return "Invalid data format received from iCloud."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .timeout:
            return "Operation timed out. Please check your network connection."
        case .poorNetworkQuality:
            return "Network quality is poor. Sync will retry later."
        }
    }
}
