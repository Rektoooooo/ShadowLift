//
//  FitnessProfile.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 17.10.2025.
//

import Foundation

struct FitnessProfile: Codable, Equatable {
    var goal: FitnessGoal
    var equipment: EquipmentType
    var experience: ExperienceLevel
    var daysPerWeek: Int
}

enum FitnessGoal: String, Codable, CaseIterable {
    case gainMuscle = "gain_muscle"
    case loseWeight = "lose_weight"
    case recomp = "recomp"
    case stayFit = "stay_fit"
    case increaseStrength = "increase_strength"

    var displayName: String {
        switch self {
        case .gainMuscle: return "Gain Muscle"
        case .loseWeight: return "Lose Weight"
        case .recomp: return "Lose Weight & Gain Muscle"
        case .stayFit: return "Stay Fit"
        case .increaseStrength: return "Increase Strength"
        }
    }

    var description: String {
        switch self {
        case .gainMuscle:
            return "Focus on building muscle mass and size through progressive overload"
        case .loseWeight:
            return "Burn calories and shed excess body fat while maintaining muscle"
        case .recomp:
            return "Build muscle while losing fat for a lean, defined physique"
        case .stayFit:
            return "Maintain current fitness levels and overall health"
        case .increaseStrength:
            return "Develop maximum strength and power in compound lifts"
        }
    }

    var icon: String {
        switch self {
        case .gainMuscle: return "figure.strengthtraining.traditional"
        case .loseWeight: return "flame.fill"
        case .recomp: return "arrow.triangle.2.circlepath"
        case .stayFit: return "heart.fill"
        case .increaseStrength: return "bolt.fill"
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable {
    case fullGym = "full_gym"
    case bigHomeGym = "big_home_gym"
    case smallHomeGym = "small_home_gym"
    case bodyweightOnly = "bodyweight_only"

    var displayName: String {
        switch self {
        case .fullGym: return "Full Gym Access"
        case .bigHomeGym: return "Big Home Gym"
        case .smallHomeGym: return "Small Home Gym"
        case .bodyweightOnly: return "Bodyweight Only"
        }
    }

    var description: String {
        switch self {
        case .fullGym:
            return "Access to all machines, barbells, dumbbells, and equipment"
        case .bigHomeGym:
            return "Power rack, barbell, dumbbells, bench, and various equipment"
        case .smallHomeGym:
            return "Basic equipment like dumbbells, resistance bands, pull-up bar"
        case .bodyweightOnly:
            return "No equipment needed - just your body weight and gravity"
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "building.columns.fill"
        case .bigHomeGym: return "house.fill"
        case .smallHomeGym: return "house"
        case .bodyweightOnly: return "figure.run"
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var displayName: String {
        switch self {
        case .beginner: return "Beginner (0-1 years)"
        case .intermediate: return "Intermediate (1-3 years)"
        case .advanced: return "Advanced (3+ years)"
        }
    }

    var description: String {
        switch self {
        case .beginner:
            return "New to training or less than 1 year of consistent experience"
        case .intermediate:
            return "1-3 years of consistent training with solid form and technique"
        case .advanced:
            return "3+ years of dedicated training with advanced programming knowledge"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        }
    }
}
