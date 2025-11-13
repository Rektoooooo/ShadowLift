//
//  Config.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 21.08.2024.
//

import Foundation
import SwiftData
import SwiftUI


class Config:ObservableObject {

    // MARK: - App Configuration Properties (not user-specific)
    
    @Published var daysRecorded: [String] {
        didSet {
            UserDefaults.standard.set(daysRecorded, forKey: "daysRecorded")
        }
    }
    
    @Published var splitStarted: Bool {
        didSet {
            UserDefaults.standard.set(splitStarted, forKey: "splitStarted")
        }
    }
    
    @Published var dayInSplit: Int {
        didSet {
            UserDefaults.standard.set(dayInSplit, forKey: "dayInSplit")
        }
    }
    
    @Published var splitLength: Int {
        didSet {
            UserDefaults.standard.set(splitLength, forKey: "splitLength")
        }
    }
    
    @Published var lastUpdateDate: Date {
        didSet {
            UserDefaults.standard.set(lastUpdateDate, forKey: "lastUpdateDate")
        }
    }
    
    @Published var isUserLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isUserLoggedIn, forKey: "isUserLoggedIn")
        }
    }
    
    
    @Published var firstSplitEdit: Bool {
        didSet {
            UserDefaults.standard.set(firstSplitEdit, forKey: "firstSplitEdit")
        }
    }
    
    @Published var activeExercise: Int {
        didSet {
            UserDefaults.standard.set(activeExercise, forKey: "activeExercise")
        }
    }
    
    @Published var graphDataValues: [Double] {
        didSet {
            UserDefaults.standard.set(graphDataValues, forKey: "graphDataValues")
        }
    }
    
    @Published var graphMaxValue: Double {
        didSet {
            UserDefaults.standard.set(graphMaxValue, forKey: "graphMaxValue")
        }
    }

    // Note: graphUpdatedExerciseIDs removed - no longer needed
    // Graph now recalculates from database instead of accumulating

    @Published var totalWorkoutTimeMinutes: Int {
        didSet {
            UserDefaults.standard.set(totalWorkoutTimeMinutes, forKey: "totalWorkoutTimeMinutes")
        }
    }

    @Published var isCloudKitEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCloudKitEnabled, forKey: "isCloudKitEnabled")
        }
    }

    @Published var cloudKitSyncDate: Date? {
        didSet {
            UserDefaults.standard.set(cloudKitSyncDate, forKey: "cloudKitSyncDate")
        }
    }
    
    @Published var isHealtKitEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHealtKitEnabled, forKey: "isHealtKitEnabled")
        }
    }

    @Published var isPremium: Bool {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: "isPremium")
        }
    }

    // MARK: - Fitness Profile Properties

    @Published var hasCompletedFitnessProfile: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedFitnessProfile, forKey: "hasCompletedFitnessProfile")
        }
    }

    @Published var fitnessGoal: String {
        didSet {
            UserDefaults.standard.set(fitnessGoal, forKey: "fitnessGoal")
        }
    }

    @Published var equipmentAccess: String {
        didSet {
            UserDefaults.standard.set(equipmentAccess, forKey: "equipmentAccess")
        }
    }

    @Published var experienceLevel: String {
        didSet {
            UserDefaults.standard.set(experienceLevel, forKey: "experienceLevel")
        }
    }

    @Published var trainingDaysPerWeek: Int {
        didSet {
            UserDefaults.standard.set(trainingDaysPerWeek, forKey: "trainingDaysPerWeek")
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
        self.isPremium = UserDefaults.standard.object(forKey: "isPremium") as? Bool ?? true  // Default true for now (testing)

        // Fitness Profile initialization
        self.hasCompletedFitnessProfile = UserDefaults.standard.object(forKey: "hasCompletedFitnessProfile") as? Bool ?? false
        self.fitnessGoal = UserDefaults.standard.object(forKey: "fitnessGoal") as? String ?? ""
        self.equipmentAccess = UserDefaults.standard.object(forKey: "equipmentAccess") as? String ?? ""
        self.experienceLevel = UserDefaults.standard.object(forKey: "experienceLevel") as? String ?? ""
        self.trainingDaysPerWeek = UserDefaults.standard.object(forKey: "trainingDaysPerWeek") as? Int ?? 4

    }

}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
