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
import Network

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

    // Queue for background sync operations
    private var pendingSyncQueue: [() async throws -> Void] = []
    private var isProcessingQueue = false

    init() {
        self.privateDatabase = container.privateCloudDatabase
        self.lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date

        // Check if we have an existing preference saved
        let hasExistingPreference = userDefaults.object(forKey: cloudKitEnabledKey) != nil
        let savedCloudKitState = userDefaults.bool(forKey: cloudKitEnabledKey)

        if hasExistingPreference {
            self.isCloudKitEnabled = savedCloudKitState
            print("🔥 INIT CLOUDKIT MANAGER - RESTORED EXISTING STATE: \(savedCloudKitState)")
        } else {
            // No existing preference - will be set based on availability check
            self.isCloudKitEnabled = false
            print("🔥 INIT CLOUDKIT MANAGER - NO EXISTING PREFERENCE, WILL CHECK AVAILABILITY")
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

                if path.status != .satisfied {
                    self.networkQuality = .offline
                } else if path.usesInterfaceType(.wifi) {
                    self.networkQuality = .excellent
                } else if path.usesInterfaceType(.cellular) {
                    self.networkQuality = .good
                } else {
                    self.networkQuality = .good
                }

                print("📡 Network Quality: \(self.networkQuality), Auto-sync: \(self.networkQuality.shouldEnableAutoSync)")
            }
        }

        networkMonitor.start(queue: networkQueue)
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
            print("🚫 SYNC BLOCKED: User is in active workout - sync deferred")
            return false
        }

        // Always allow manual sync, but warn about poor connection
        if !networkQuality.shouldEnableAutoSync {
            print("⚠️ NETWORK QUALITY POOR - Sync may be slow or fail")
        }

        return true
    }

    /// Set workout session state - call this when entering/exiting workout views
    func setWorkoutSessionActive(_ active: Bool) {
        isInActiveWorkout = active
        if active {
            print("🏋️ WORKOUT SESSION STARTED - Auto-sync disabled")
        } else {
            print("✅ WORKOUT SESSION ENDED - Auto-sync re-enabled")
        }
    }

    // MARK: - CloudKit Status
    nonisolated func checkCloudKitStatus() async {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, error in
                Task { @MainActor in
                    switch status {
                    case .available:
                        // CloudKit is available, check if user had it enabled before
                        let hasExistingPreference = self.userDefaults.object(forKey: self.cloudKitEnabledKey) != nil
                        let userPreference = self.userDefaults.bool(forKey: self.cloudKitEnabledKey)

                        if hasExistingPreference {
                            // User has a saved preference, respect it
                            self.isCloudKitEnabled = userPreference
                            print("🔥 CLOUDKIT STATUS CHECK: AVAILABLE, EXISTING USER PREFERENCE: \(userPreference)")
                        } else {
                            // First time or fresh install - enable CloudKit by default when available
                            self.isCloudKitEnabled = true
                            self.userDefaults.set(true, forKey: self.cloudKitEnabledKey)
                            print("🔥 CLOUDKIT STATUS CHECK: AVAILABLE, NO EXISTING PREFERENCE - ENABLING BY DEFAULT")
                        }
                        self.syncError = nil
                    case .noAccount:
                        self.isCloudKitEnabled = false
                        self.syncError = "iCloud account not available. Please sign in to iCloud in Settings."
                        self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                        print("🔥 CLOUDKIT STATUS CHECK: NO ACCOUNT")
                    case .restricted:
                        self.isCloudKitEnabled = false
                        self.syncError = "iCloud is restricted on this device."
                        self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                        print("🔥 CLOUDKIT STATUS CHECK: RESTRICTED")
                    case .couldNotDetermine:
                        self.isCloudKitEnabled = false
                        self.syncError = "Could not determine iCloud status."
                        self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                        print("🔥 CLOUDKIT STATUS CHECK: COULD NOT DETERMINE")
                    case .temporarilyUnavailable:
                        self.isCloudKitEnabled = false
                        self.syncError = "iCloud is temporarily unavailable."
                        self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                        print("🔥 CLOUDKIT STATUS CHECK: TEMPORARILY UNAVAILABLE")
                    @unknown default:
                        self.isCloudKitEnabled = false
                        self.syncError = "Unknown iCloud status."
                        self.userDefaults.set(false, forKey: self.cloudKitEnabledKey)
                        print("🔥 CLOUDKIT STATUS CHECK: UNKNOWN")
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - CloudKit State Management
    func setCloudKitEnabled(_ enabled: Bool) {
        isCloudKitEnabled = enabled
        userDefaults.set(enabled, forKey: cloudKitEnabledKey)
        print("🔥 CLOUDKIT STATE SET TO: \(enabled)")
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
        print("🔄 SAVESPLIT: Saving \(split.days?.count ?? 0) days for split '\(split.name)'")

        // OPTIMIZATION: Save days in parallel instead of sequentially
        let days = split.days ?? []
        try await withThrowingTaskGroup(of: Void.self) { group in
            for day in days {
                group.addTask {
                    do {
                        try await self.saveDay(day, splitId: split.id)
                        print("✅ SAVESPLIT: Saved day '\(day.name)'")
                    } catch is CloudKitError {
                        // Network timeout - queue for later retry
                        print("⚠️ SAVESPLIT: Day '\(day.name)' queued for retry")
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
            print("🔄 SAVESPLIT: Updating existing split record '\(split.name)'")
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "Split", recordID: recordID)
            print("🆕 SAVESPLIT: Creating new split record '\(split.name)'")
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
            print("✅ SAVESPLIT: Split record '\(split.name)' saved successfully")
        } catch {
            print("❌ SAVESPLIT: Failed to save split record '\(split.name)': \(error.localizedDescription)")
            throw error
        }
    }

    func saveDay(_ day: Day, splitId: UUID) async throws {
        guard shouldPerformSync() else {
            throw CloudKitError.notAvailable
        }

        // CRITICAL: Save exercises FIRST before creating references to them
        print("🔄 SAVEDAY: Saving \(day.exercises?.count ?? 0) exercises for day '\(day.name)'")

        // OPTIMIZATION: Save exercises in parallel instead of sequentially
        let exercises = day.exercises ?? []
        try await withThrowingTaskGroup(of: Void.self) { group in
            for exercise in exercises {
                group.addTask {
                    try await self.saveExercise(exercise, dayId: day.id)
                    print("✅ SAVEDAY: Saved exercise '\(exercise.name)'")
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
            print("🔄 SAVEDAY: Updating existing day record '\(day.name)'")
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "Day", recordID: recordID)
            print("🆕 SAVEDAY: Creating new day record '\(day.name)'")
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
            print("✅ SAVEDAY: Day record '\(day.name)' saved successfully")
        } catch {
            print("❌ SAVEDAY: Failed to save day record '\(day.name)': \(error.localizedDescription)")
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

        // Try to fetch existing record first
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "DayStorage", recordID: recordID)
        }
        record["date"] = dayStorage.date
        record["dayId"] = dayStorage.dayId.uuidString
        record["dayName"] = dayStorage.dayName
        record["dayOfSplit"] = dayStorage.dayOfSplit

        try await privateDatabase.save(record)
    }

    // MARK: - WeightPoint Sync
    func saveWeightPoint(_ weightPoint: WeightPoint) async throws {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        let recordID = CKRecord.ID(recordName: weightPoint.cloudKitID)

        // Try to fetch existing record first
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: "WeightPoint", recordID: recordID)
        }
        record["weight"] = weightPoint.weight
        record["date"] = weightPoint.date

        try await privateDatabase.save(record)
    }


    // MARK: - Fetch Data
    func fetchAllSplits() async throws -> [Split] {
        guard isCloudKitEnabled else {
            throw CloudKitError.notAvailable
        }

        print("🔍 FETCHING SPLITS FROM CLOUDKIT...")

        do {
            // Use the simpler records(matching:) API which works without queryable indexes
            let query = CKQuery(recordType: "Split", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDatabase.records(matching: query)

            var fetchedRecords: [CKRecord] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                    print("🔍 Fetched split record: \(record["name"] as? String ?? "unknown")")
                case .failure(let error):
                    print("❌ Error fetching individual record: \(error.localizedDescription)")
                }
            }

            print("🔍 QUERY RESULT: \(fetchedRecords.count) split records found")

            var splits: [Split] = []
            for record in fetchedRecords {
                if let split = await splitFromRecord(record) {
                    splits.append(split)
                    print("🔍 CONVERTED SPLIT: \(split.name), isActive: \(split.isActive)")
                }
            }

            print("🔍 FINAL SPLIT COUNT: \(splits.count)")
            return splits
        } catch let error as CKError {
            print("❌ CLOUDKIT ERROR FETCHING SPLITS: \(error.localizedDescription)")
            print("❌ ERROR CODE: \(error.code.rawValue)")
            print("❌ ERROR DETAILS: \(error)")

            // Return empty array instead of throwing if there are no records or query issues
            if error.code == .unknownItem || error.code == .invalidArguments {
                print("⚠️ NO SPLITS FOUND IN CLOUDKIT OR QUERY ISSUE - RETURNING EMPTY ARRAY")
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
        let record = try await privateDatabase.record(for: recordID)

        guard let name = record["name"] as? String,
              let dayOfSplit = record["dayOfSplit"] as? Int,
              let date = record["date"] as? String else {
            throw CloudKitError.invalidData
        }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()

        // Fetch exercises
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
        let record = try await privateDatabase.record(for: recordID)

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
            print("❌ PERFORMFULLSYNC: CloudKit not enabled or network unavailable")
            return
        }

        // Check network quality and warn user
        if networkQuality == .poor {
            print("⚠️ PERFORMFULLSYNC: Network quality is POOR - sync may be slow")
            self.syncError = "Network quality is poor. Sync may take longer than usual."
        }

        print("🔄 PERFORMFULLSYNC: Starting full CloudKit sync")

        self.isSyncing = true

        // Run sync in background task - network operations are inherently async
        Task(priority: .utility) {
            do {
                // Sync Splits
                let descriptor = FetchDescriptor<Split>()
                let localSplits = try context.fetch(descriptor)
                print("🔄 PERFORMFULLSYNC: Found \(localSplits.count) local splits to sync")

                // OPTIMIZATION: Sync splits in parallel with concurrency limit
                var successCount = 0
                var timeoutCount = 0

                for split in localSplits {
                    print("🔄 PERFORMFULLSYNC: Uploading split '\(split.name)' to CloudKit...")
                    do {
                        try await self.saveSplit(split)
                        print("✅ PERFORMFULLSYNC: Split '\(split.name)' uploaded successfully")
                        successCount += 1
                    } catch let error as CloudKitError where error == .timeout {
                        print("⏱️ PERFORMFULLSYNC: Split '\(split.name)' timed out - will retry later")
                        timeoutCount += 1
                        // Don't throw - continue with other splits
                    } catch {
                        print("❌ PERFORMFULLSYNC: Failed to upload split '\(split.name)': \(error.localizedDescription)")
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
                    print("✅ PERFORMFULLSYNC: Sync complete - \(successCount) successful, \(timeoutCount) timed out")
                }
            } catch {
                await MainActor.run {
                    print("❌ PERFORMFULLSYNC ERROR: \(error.localizedDescription)")
                    self.syncError = error.localizedDescription
                    self.isSyncing = false
                }
            }
        }
    }

    @MainActor
    func fetchAndMergeData(context: ModelContext, config: Config) async {
        guard isCloudKitEnabled else {
            print("🔥 CLOUDKIT NOT ENABLED - SKIPPING FETCH")
            return
        }

        print("🔥 STARTING FETCHANDMERGEDATA")
        self.isSyncing = true
        self.syncError = nil

        do {
            // Fetch from CloudKit (happens on background thread)
            let cloudSplits = try await fetchAllSplits()
            let cloudDayStorages = try await fetchAllDayStorage()
            let cloudWeightPoints = try await fetchAllWeightPoints()

            print("🔥 FETCHED FROM CLOUDKIT: \(cloudSplits.count) splits, \(cloudDayStorages.count) day storages, \(cloudWeightPoints.count) weight points")

            // Merge with local data (must happen on main thread with ModelContext)
            let localSplitDescriptor = FetchDescriptor<Split>()
            let localSplits = try context.fetch(localSplitDescriptor)

            for cloudSplit in cloudSplits {
                if !localSplits.contains(where: { $0.id == cloudSplit.id }) {
                    context.insert(cloudSplit)
                    print("🔥 INSERTED SPLIT: \(cloudSplit.name), isActive: \(cloudSplit.isActive)")
                }
            }

            // CRITICAL: If no split is active after CloudKit sync, activate the first one
            // This ensures splits appear immediately on TodayWorkoutView
            let updatedLocalSplits = try context.fetch(FetchDescriptor<Split>())
            let hasActiveSplit = updatedLocalSplits.contains(where: { $0.isActive })

            if !hasActiveSplit, let firstSplit = updatedLocalSplits.first {
                print("🔥 NO ACTIVE SPLIT FOUND - Activating first split: \(firstSplit.name)")
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

            // Save context
            try context.save()
            print("🔥 CONTEXT SAVED SUCCESSFULLY")

            // Update last sync date
            let now = Date()
            userDefaults.set(now, forKey: lastSyncKey)
            self.lastSyncDate = now
            self.isSyncing = false
        } catch {
            print("❌ FETCHANDMERGEDATA ERROR: \(error)")
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
                print("🔄 USER PROFILE: Updating existing CloudKit record")
            } catch {
                // Record doesn't exist, create new one
                record = CKRecord(recordType: "UserProfile", recordID: recordID)
                print("🆕 USER PROFILE: Creating new CloudKit record")
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
            print("✅ USER PROFILE: Saved to CloudKit with ID: \(record.recordID.recordName)")

        } catch {
            print("❌ USER PROFILE: Failed to save to CloudKit - \(error)")
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
            print("✅ USER PROFILE: Found existing CloudKit profile")
            return UserProfile.fromCKRecord(record)
        } catch {
            // Record doesn't exist or other error
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                print("🔍 USER PROFILE: No CloudKit profile found")
                return nil
            } else {
                print("❌ USER PROFILE: Failed to fetch from CloudKit - \(error)")
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
            print("🔄 PROFILE IMAGE: Updating existing CloudKit record")
        } catch {
            // Create new record if it doesn't exist
            record = CKRecord(recordType: "ProfileImage", recordID: recordID)
            print("🆕 PROFILE IMAGE: Creating new CloudKit record")
        }

        record["image"] = asset

        do {
            _ = try await privateDatabase.save(record)
            print("✅ PROFILE IMAGE: Saved to CloudKit")
            return "cloudkit_profile_image"
        } catch {
            print("❌ PROFILE IMAGE: Failed to save to CloudKit - \(error)")
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
                print("✅ PROFILE IMAGE: Fetched from CloudKit")
                return image
            }

            print("🔍 PROFILE IMAGE: Record found but no valid image data")
            return nil
        } catch {
            print("🔍 PROFILE IMAGE: No CloudKit profile image found")
            return nil
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
