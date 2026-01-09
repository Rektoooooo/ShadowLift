//
//  Config.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 21.08.2024.
//

import Foundation
import SwiftData
import SwiftUI


class Config: ObservableObject {

    // MARK: - Debounced UserDefaults Save System
    // This prevents hundreds of synchronous disk writes during workouts
    // by batching writes and debouncing them

    private var pendingWrites: [String: Any] = [:]
    private var saveTask: Task<Void, Never>?
    private let saveDebounceMs: UInt64 = 100  // 100ms debounce

    /// Queue a UserDefaults write - will be batched and debounced
    private func queueSave(_ key: String, _ value: Any?) {
        if let value = value {
            pendingWrites[key] = value
        } else {
            pendingWrites[key] = NSNull()  // Mark for removal
        }

        // Cancel any pending save and schedule a new one
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: (self?.saveDebounceMs ?? 100) * 1_000_000)
                guard !Task.isCancelled else { return }
                self?.flushPendingWrites()
            } catch {
                // Task was cancelled, which is expected
            }
        }
    }

    /// Flush all pending writes to UserDefaults
    private func flushPendingWrites() {
        guard !pendingWrites.isEmpty else { return }

        for (key, value) in pendingWrites {
            if value is NSNull {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        pendingWrites.removeAll()
    }

    /// Force immediate save of all pending writes (call before app termination)
    func saveImmediately() {
        saveTask?.cancel()
        flushPendingWrites()
    }

    // MARK: - App Configuration Properties (not user-specific)

    @Published var daysRecorded: [String] {
        didSet {
            queueSave("daysRecorded", daysRecorded)
        }
    }

    @Published var splitStarted: Bool {
        didSet {
            queueSave("splitStarted", splitStarted)
        }
    }

    @Published var dayInSplit: Int {
        didSet {
            queueSave("dayInSplit", dayInSplit)
        }
    }

    @Published var splitLength: Int {
        didSet {
            queueSave("splitLength", splitLength)
        }
    }

    @Published var lastUpdateDate: Date {
        didSet {
            queueSave("lastUpdateDate", lastUpdateDate)
        }
    }

    @Published var isUserLoggedIn: Bool {
        didSet {
            queueSave("isUserLoggedIn", isUserLoggedIn)
        }
    }


    @Published var firstSplitEdit: Bool {
        didSet {
            queueSave("firstSplitEdit", firstSplitEdit)
        }
    }

    @Published var activeExercise: Int {
        didSet {
            queueSave("activeExercise", activeExercise)
        }
    }

    @Published var graphDataValues: [Double] {
        didSet {
            queueSave("graphDataValues", graphDataValues)
        }
    }

    @Published var graphMaxValue: Double {
        didSet {
            queueSave("graphMaxValue", graphMaxValue)
        }
    }

    // Note: graphUpdatedExerciseIDs removed - no longer needed
    // Graph now recalculates from database instead of accumulating

    @Published var totalWorkoutTimeMinutes: Int {
        didSet {
            queueSave("totalWorkoutTimeMinutes", totalWorkoutTimeMinutes)
        }
    }

    @Published var isCloudKitEnabled: Bool {
        didSet {
            queueSave("isCloudKitEnabled", isCloudKitEnabled)
        }
    }

    @Published var cloudKitSyncDate: Date? {
        didSet {
            queueSave("cloudKitSyncDate", cloudKitSyncDate)
        }
    }

    @Published var isHealtKitEnabled: Bool {
        didSet {
            queueSave("isHealtKitEnabled", isHealtKitEnabled)
        }
    }

    @Published var isPremium: Bool {
        didSet {
            queueSave("isPremium", isPremium)
            debugLog("💎 Config: isPremium updated to \(isPremium)")
        }
    }

    // MARK: - StoreKit Integration

    /// Update premium status from StoreManager
    /// This should be called by StoreManager when subscription status changes
    func updatePremiumStatus(from storeManager: Bool) {
        if self.isPremium != storeManager {
            debugLog("💎 Config: Syncing premium status from StoreManager: \(storeManager)")
            self.isPremium = storeManager
        }
    }

    // MARK: - Notification Settings

    @Published var notificationsEnabled: Bool {
        didSet {
            queueSave("notificationsEnabled", notificationsEnabled)
        }
    }

    @Published var streakNotificationsEnabled: Bool {
        didSet {
            queueSave("streakNotificationsEnabled", streakNotificationsEnabled)
        }
    }

    @Published var workoutReminderEnabled: Bool {
        didSet {
            queueSave("workoutReminderEnabled", workoutReminderEnabled)
        }
    }

    @Published var workoutReminderTime: Date {
        didSet {
            queueSave("workoutReminderTime", workoutReminderTime)
        }
    }

    @Published var progressMilestonesEnabled: Bool {
        didSet {
            queueSave("progressMilestonesEnabled", progressMilestonesEnabled)
        }
    }

    @Published var inactivityRemindersEnabled: Bool {
        didSet {
            queueSave("inactivityRemindersEnabled", inactivityRemindersEnabled)
        }
    }

    // MARK: - Fitness Profile Properties

    @Published var hasCompletedFitnessProfile: Bool {
        didSet {
            queueSave("hasCompletedFitnessProfile", hasCompletedFitnessProfile)
        }
    }

    @Published var fitnessGoal: String {
        didSet {
            queueSave("fitnessGoal", fitnessGoal)
        }
    }

    @Published var equipmentAccess: String {
        didSet {
            queueSave("equipmentAccess", equipmentAccess)
        }
    }

    @Published var experienceLevel: String {
        didSet {
            queueSave("experienceLevel", experienceLevel)
        }
    }

    @Published var trainingDaysPerWeek: Int {
        didSet {
            queueSave("trainingDaysPerWeek", trainingDaysPerWeek)
        }
    }

    // MARK: - Tutorial State

    @Published var hasSeenTutorial: Bool {
        didSet {
            queueSave("hasSeenTutorial", hasSeenTutorial)
        }
    }

    // Helper computed property for type-safe access
    var fitnessProfile: FitnessProfile? {
        get {
            guard !fitnessGoal.isEmpty,
                  !equipmentAccess.isEmpty,
                  !experienceLevel.isEmpty,
                  let goal = FitnessGoal(rawValue: fitnessGoal),
                  let equipment = EquipmentType(rawValue: equipmentAccess),
                  let experience = ExperienceLevel(rawValue: experienceLevel) else {
                return nil
            }
            return FitnessProfile(
                goal: goal,
                equipment: equipment,
                experience: experience,
                daysPerWeek: trainingDaysPerWeek
            )
        }
        set {
            guard let profile = newValue else { return }
            fitnessGoal = profile.goal.rawValue
            equipmentAccess = profile.equipment.rawValue
            experienceLevel = profile.experience.rawValue
            trainingDaysPerWeek = profile.daysPerWeek
        }
    }

    init() {
        self.daysRecorded = UserDefaults.standard.object(forKey: "daysRecorded") as? [String] ?? []
        self.splitStarted = UserDefaults.standard.object(forKey: "splitStarted") as? Bool ?? false
        self.dayInSplit = UserDefaults.standard.object(forKey: "dayInSplit") as? Int ?? 1
        // Migration: Check old key first for backward compatibility
        if let oldValue = UserDefaults.standard.object(forKey: "splitLenght") as? Int {
            self.splitLength = oldValue
            UserDefaults.standard.removeObject(forKey: "splitLenght")
            UserDefaults.standard.set(oldValue, forKey: "splitLength")
        } else {
            self.splitLength = UserDefaults.standard.object(forKey: "splitLength") as? Int ?? 1
        }
        self.lastUpdateDate = UserDefaults.standard.object(forKey: "lastUpdateDate")  as? Date ?? Date()
        self.isUserLoggedIn = UserDefaults.standard.object(forKey: "isUserLoggedIn") as? Bool ?? false
        self.firstSplitEdit = UserDefaults.standard.object(forKey: "firstSplitEdit") as? Bool ?? true
        self.activeExercise = UserDefaults.standard.object(forKey: "activeExercise") as? Int ?? 1
        self.graphDataValues = UserDefaults.standard.object(forKey: "graphDataValues") as? [Double] ?? []
        self.graphMaxValue = UserDefaults.standard.object(forKey: "graphMaxValue") as? Double ?? 1.0
        // graphUpdatedExerciseIDs removed - no longer tracking exercise IDs
        self.totalWorkoutTimeMinutes = UserDefaults.standard.object(forKey: "totalWorkoutTimeMinutes") as? Int ?? 0
        self.isCloudKitEnabled = UserDefaults.standard.object(forKey: "isCloudKitEnabled") as? Bool ?? false
        self.cloudKitSyncDate = UserDefaults.standard.object(forKey: "cloudKitSyncDate") as? Date
        self.isHealtKitEnabled = UserDefaults.standard.object(forKey: "isHealtKitEnabled") as? Bool ?? false

        // Premium status - will be synced from StoreManager
        // Load from UserDefaults, will be updated by StoreManager after initialization
        let loadedPremium = UserDefaults.standard.object(forKey: "isPremium") as? Bool ?? false
        self.isPremium = loadedPremium
        debugLog("💎 Config: isPremium loaded from UserDefaults: \(loadedPremium)")

        // Notification Settings initialization
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? false
        self.streakNotificationsEnabled = UserDefaults.standard.object(forKey: "streakNotificationsEnabled") as? Bool ?? true
        self.workoutReminderEnabled = UserDefaults.standard.object(forKey: "workoutReminderEnabled") as? Bool ?? true
        // Default reminder time: 6 PM
        if let savedTime = UserDefaults.standard.object(forKey: "workoutReminderTime") as? Date {
            self.workoutReminderTime = savedTime
        } else {
            let calendar = Calendar.current
            let defaultTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            self.workoutReminderTime = defaultTime
        }
        self.progressMilestonesEnabled = UserDefaults.standard.object(forKey: "progressMilestonesEnabled") as? Bool ?? true
        self.inactivityRemindersEnabled = UserDefaults.standard.object(forKey: "inactivityRemindersEnabled") as? Bool ?? true

        // Fitness Profile initialization
        self.hasCompletedFitnessProfile = UserDefaults.standard.object(forKey: "hasCompletedFitnessProfile") as? Bool ?? false
        self.fitnessGoal = UserDefaults.standard.object(forKey: "fitnessGoal") as? String ?? ""
        self.equipmentAccess = UserDefaults.standard.object(forKey: "equipmentAccess") as? String ?? ""
        self.experienceLevel = UserDefaults.standard.object(forKey: "experienceLevel") as? String ?? ""
        self.trainingDaysPerWeek = UserDefaults.standard.object(forKey: "trainingDaysPerWeek") as? Int ?? 4

        // Tutorial state initialization
        self.hasSeenTutorial = UserDefaults.standard.object(forKey: "hasSeenTutorial") as? Bool ?? false

    }

    deinit {
        // Ensure any pending writes are saved before Config is deallocated
        saveTask?.cancel()
        flushPendingWrites()
    }

}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
