//
//  UserProfile.swift
//  ShadowLift
//
//  Created by SwiftData Migration on 18.09.2025.
//

import Foundation
import SwiftData
import UIKit
import CloudKit

@Model
class UserProfile {
    var id: UUID = UUID()
    var username: String = "User"
    var email: String = "user@example.com"

    // Profile Image - stored locally in SwiftData for instant display
    var profileImageData: Data?
    var profileImageCloudKitID: String? // For CloudKit sync tracking

    // Physical Stats
    var height: Double = 0.0  // in cm
    var weight: Double = 0.0  // in kg
    var age: Int = 0
    var bmi: Double = 0.0

    var isHealthEnabled: Bool = false

    // Streak Tracking
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var restDaysPerWeek: Int = 2  // Default: 2 rest days per week
    var lastWorkoutDate: Date?
    var streakPaused: Bool = false

    // User Preferences (can be argued if these belong to app settings instead)
    var weightUnit: String = "Kg"  // "Kg" or "Lbs"
    var roundSetWeights: Bool = false

    // CloudKit sync metadata
    var lastSyncedAt: Date?
    var needsSync: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationships
    @Relationship(deleteRule: .cascade) var progressPhotos: [ProgressPhoto]?

    // Computed Properties
    var profileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }

    init(
        username: String = "User",
        email: String = "user@example.com",
        height: Double = 0.0,
        weight: Double = 0.0,
        age: Int = 0,
        isHealthEnabled: Bool = false,
        weightUnit: String = "Kg",
        roundSetWeights: Bool = false
    ) {
        self.username = username
        self.email = email
        self.height = height
        self.weight = weight
        self.age = age
        self.isHealthEnabled = isHealthEnabled
        self.weightUnit = weightUnit
        self.roundSetWeights = roundSetWeights
        // Don't calculate BMI in init - will be calculated when height/weight are updated
    }

    // MARK: - Helper Methods

    /// Update BMI based on current height and weight
    func updateBMI() {
        if height > 0 && weight > 0 {
            let heightInMeters = height / 100.0
            bmi = weight / (heightInMeters * heightInMeters)
            print("🧮 BMI CALC: height=\(height)cm, weight=\(weight)kg, heightInMeters=\(heightInMeters)m, BMI=\(bmi)")
        } else {
            bmi = 0.0
            print("🧮 BMI CALC: Invalid data - height=\(height)cm, weight=\(weight)kg, BMI set to 0")
        }
        markAsUpdated()
    }

    /// Set profile image from UIImage
    func setProfileImage(_ image: UIImage?) {
        if let image = image {
            profileImageData = image.jpegData(compressionQuality: 0.8)
        } else {
            profileImageData = nil
        }
        markAsUpdated()
    }

    /// Mark as needing sync and update timestamp
    func markAsUpdated() {
        updatedAt = Date()
        needsSync = true
    }

    /// Mark as synced
    func markAsSynced() {
        lastSyncedAt = Date()
        needsSync = false
    }
}

// MARK: - CloudKit Conversion
extension UserProfile {
    /// Convert to CKRecord for CloudKit storage
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: "user_profile", zoneID: .default)
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)

        record["username"] = username as CKRecordValue
        record["email"] = email as CKRecordValue
        record["height"] = height as CKRecordValue
        record["weight"] = weight as CKRecordValue
        record["age"] = age as CKRecordValue
        record["bmi"] = bmi as CKRecordValue
        record["isHealthEnabled"] = (isHealthEnabled ? 1 : 0) as CKRecordValue
        record["currentStreak"] = currentStreak as CKRecordValue
        record["longestStreak"] = longestStreak as CKRecordValue
        record["restDaysPerWeek"] = restDaysPerWeek as CKRecordValue
        record["streakPaused"] = (streakPaused ? 1 : 0) as CKRecordValue
        if let lastWorkoutDate = lastWorkoutDate {
            record["lastWorkoutDate"] = lastWorkoutDate as CKRecordValue
        }
        record["weightUnit"] = weightUnit as CKRecordValue
        record["roundSetWeights"] = (roundSetWeights ? 1 : 0) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        if let cloudKitID = profileImageCloudKitID {
            record["profileImageCloudKitID"] = cloudKitID as CKRecordValue
        }

        return record
    }

    /// Convert from CKRecord to dictionary
    static func fromCKRecord(_ record: CKRecord) -> [String: Any] {
        var dict: [String: Any] = [:]

        if let username = record["username"] as? String {
            dict["username"] = username
        }
        if let email = record["email"] as? String {
            dict["email"] = email
        }
        if let height = record["height"] as? Double {
            dict["height"] = height
        }
        if let weight = record["weight"] as? Double {
            dict["weight"] = weight
        }
        if let age = record["age"] as? Int {
            dict["age"] = age
        }
        if let bmi = record["bmi"] as? Double {
            dict["bmi"] = bmi
        }
        if let isHealthEnabled = record["isHealthEnabled"] as? Int {
            dict["isHealthEnabled"] = isHealthEnabled
        }
        if let currentStreak = record["currentStreak"] as? Int {
            dict["currentStreak"] = currentStreak
        }
        if let longestStreak = record["longestStreak"] as? Int {
            dict["longestStreak"] = longestStreak
        }
        if let restDaysPerWeek = record["restDaysPerWeek"] as? Int {
            dict["restDaysPerWeek"] = restDaysPerWeek
        }
        if let streakPaused = record["streakPaused"] as? Int {
            dict["streakPaused"] = streakPaused
        }
        if let lastWorkoutDate = record["lastWorkoutDate"] as? Date {
            dict["lastWorkoutDate"] = lastWorkoutDate
        }
        if let weightUnit = record["weightUnit"] as? String {
            dict["weightUnit"] = weightUnit
        }
        if let roundSetWeights = record["roundSetWeights"] as? Int {
            dict["roundSetWeights"] = roundSetWeights
        }
        if let cloudKitID = record["profileImageCloudKitID"] as? String {
            dict["profileImageCloudKitID"] = cloudKitID
        }
        if let updatedAt = record["updatedAt"] as? Date {
            dict["updatedAt"] = updatedAt
        }

        return dict
    }

    /// Update from CloudKit dictionary
    func updateFromCloudKit(_ dict: [String: Any]) {
        if let username = dict["username"] as? String {
            self.username = username
        }
        if let email = dict["email"] as? String {
            self.email = email
        }
        if let height = dict["height"] as? Double {
            self.height = height
        }
        if let weight = dict["weight"] as? Double {
            self.weight = weight
        }
        if let age = dict["age"] as? Int {
            self.age = age
        }
        if let bmi = dict["bmi"] as? Double {
            self.bmi = bmi
        }
        if let isHealthEnabled = dict["isHealthEnabled"] as? Int {
            self.isHealthEnabled = isHealthEnabled == 1
        }
        if let currentStreak = dict["currentStreak"] as? Int {
            self.currentStreak = currentStreak
        }
        if let longestStreak = dict["longestStreak"] as? Int {
            self.longestStreak = longestStreak
        }
        if let restDaysPerWeek = dict["restDaysPerWeek"] as? Int {
            self.restDaysPerWeek = restDaysPerWeek
        }
        if let streakPaused = dict["streakPaused"] as? Int {
            self.streakPaused = streakPaused == 1
        }
        if let lastWorkoutDate = dict["lastWorkoutDate"] as? Date {
            self.lastWorkoutDate = lastWorkoutDate
        }
        if let weightUnit = dict["weightUnit"] as? String {
            self.weightUnit = weightUnit
        }
        if let roundSetWeights = dict["roundSetWeights"] as? Int {
            self.roundSetWeights = roundSetWeights == 1
        }
        if let cloudKitID = dict["profileImageCloudKitID"] as? String {
            self.profileImageCloudKitID = cloudKitID
        }
        if let updatedAt = dict["updatedAt"] as? Date {
            self.updatedAt = updatedAt
        }

        markAsSynced()
    }
}
