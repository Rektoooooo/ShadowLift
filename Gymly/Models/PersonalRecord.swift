//
//  PersonalRecord.swift
//  ShadowLift
//
//  Created by Claude Code on 03.11.2025.
//

import Foundation
import SwiftData

@Model
class ExercisePR: ObservableObject {
    var id: UUID = UUID()  // Removed @Attribute(.unique) for CloudKit compatibility

    // Exercise identification (optional for CloudKit)
    var exerciseName: String = ""      // Normalized exercise name
    var muscleGroup: String = ""       // For filtering/analytics

    // Best Weight PR
    var bestWeight: Double?            // Heaviest single rep weight (kg)
    var bestWeightReps: Int?           // Reps achieved at best weight
    var bestWeightDate: Date?          // When achieved
    var bestWeightWorkoutID: UUID?     // Reference to DayStorage

    // Calculated 1RM PR
    var best1RM: Double?               // Calculated from weight × reps formulas
    var best1RMDate: Date?             // When achieved
    var best1RMSourceWeight: Double?   // The weight used for calculation
    var best1RMSourceReps: Int?        // The reps used for calculation

    // Volume PR (single workout)
    var bestVolume: Double?            // Total weight × reps for single workout
    var bestVolumeDate: Date?          // When achieved
    var bestVolumeSets: Int?           // Number of sets in that workout
    var bestVolumeWorkoutID: UUID?     // Reference to DayStorage

    // Best 5RM PR (strength endurance)
    var best5RM: Double?               // Best weight for 5+ reps
    var best5RMReps: Int?              // Exact reps achieved
    var best5RMDate: Date?             // When achieved

    // Best 10RM PR (hypertrophy)
    var best10RM: Double?              // Best weight for 10+ reps
    var best10RMReps: Int?             // Exact reps achieved
    var best10RMDate: Date?            // When achieved

    // Metadata
    var lastUpdated: Date = Date()     // Cache invalidation
    var totalWorkouts: Int = 0         // How many times this exercise performed
    var lastPerformed: Date?           // Most recent workout with this exercise

    init(exerciseName: String, muscleGroup: String) {
        self.exerciseName = exerciseName.normalizedExerciseName
        self.muscleGroup = muscleGroup
    }

    // MARK: - Helper Methods

    /// Check if we have any PRs recorded
    var hasPRs: Bool {
        return bestWeight != nil || best1RM != nil || bestVolume != nil || best5RM != nil || best10RM != nil
    }

    /// Get the most impressive PR for display (prioritize weight, then 1RM, then volume)
    var displayPR: (value: Double, reps: Int, type: String)? {
        if let weight = bestWeight, let reps = bestWeightReps {
            return (weight, reps, "Weight")
        } else if let rm1 = best1RM, let reps = best1RMSourceReps {
            return (rm1, reps, "1RM")
        } else if let volume = bestVolume, let sets = bestVolumeSets {
            return (volume, sets, "Volume")
        }
        return nil
    }

    /// Update PRs from a set
    func updatePRsIfNeeded(from set: Exercise.Set, workoutDate: Date, workoutID: UUID, userWeight: Double?) {
        // Calculate effective weight (for bodyweight exercises)
        let effectiveWeight = set.bodyWeight ? (userWeight ?? 0) + set.weight : set.weight

        // Update best weight
        if bestWeight == nil || effectiveWeight > bestWeight! {
            bestWeight = effectiveWeight
            bestWeightReps = set.reps
            bestWeightDate = workoutDate
            bestWeightWorkoutID = workoutID
        }

        // Update 1RM
        let calculated1RM = calculate1RM(weight: effectiveWeight, reps: set.reps)
        if best1RM == nil || calculated1RM > best1RM! {
            best1RM = calculated1RM
            best1RMDate = workoutDate
            best1RMSourceWeight = effectiveWeight
            best1RMSourceReps = set.reps
        }

        // Update best 5RM (only if 5+ reps)
        if set.reps >= 5 {
            if best5RM == nil || effectiveWeight > best5RM! {
                best5RM = effectiveWeight
                best5RMReps = set.reps
                best5RMDate = workoutDate
            }
        }

        // Update best 10RM (only if 10+ reps)
        if set.reps >= 10 {
            if best10RM == nil || effectiveWeight > best10RM! {
                best10RM = effectiveWeight
                best10RMReps = set.reps
                best10RMDate = workoutDate
            }
        }

        lastUpdated = Date()
    }

    /// Update volume PR for a workout
    func updateVolumePR(totalVolume: Double, sets: Int, workoutDate: Date, workoutID: UUID) {
        if bestVolume == nil || totalVolume > bestVolume! {
            bestVolume = totalVolume
            bestVolumeSets = sets
            bestVolumeDate = workoutDate
            bestVolumeWorkoutID = workoutID
        }
        lastUpdated = Date()
    }

    /// Calculate 1RM from weight and reps using Epley and Brzycki formulas
    private func calculate1RM(weight: Double, reps: Int) -> Double {
        // For 1 rep, just return the weight
        if reps == 1 { return weight }

        // Don't estimate beyond 12 reps (formulas become inaccurate)
        if reps > 12 { return weight }

        // Epley formula: 1RM = weight × (1 + reps/30)
        let epley = weight * (1 + Double(reps) / 30.0)

        // Brzycki formula: 1RM = weight × (36 / (37 - reps))
        let brzycki = weight * (36.0 / (37.0 - Double(reps)))

        // Average both for better accuracy
        return (epley + brzycki) / 2.0
    }

    // MARK: - CloudKit Sync Support

    /// Convert to CloudKit-compatible dictionary
    func toCloudKitDict() -> [String: Any] {
        var dict: [String: Any] = [
            "exerciseName": exerciseName,
            "muscleGroup": muscleGroup,
            "lastUpdated": lastUpdated,
            "totalWorkouts": totalWorkouts
        ]

        // Add optional fields
        if let bestWeight = bestWeight { dict["bestWeight"] = bestWeight }
        if let bestWeightReps = bestWeightReps { dict["bestWeightReps"] = bestWeightReps }
        if let bestWeightDate = bestWeightDate { dict["bestWeightDate"] = bestWeightDate }

        if let best1RM = best1RM { dict["best1RM"] = best1RM }
        if let best1RMDate = best1RMDate { dict["best1RMDate"] = best1RMDate }
        if let best1RMSourceWeight = best1RMSourceWeight { dict["best1RMSourceWeight"] = best1RMSourceWeight }
        if let best1RMSourceReps = best1RMSourceReps { dict["best1RMSourceReps"] = best1RMSourceReps }

        if let bestVolume = bestVolume { dict["bestVolume"] = bestVolume }
        if let bestVolumeDate = bestVolumeDate { dict["bestVolumeDate"] = bestVolumeDate }
        if let bestVolumeSets = bestVolumeSets { dict["bestVolumeSets"] = bestVolumeSets }

        if let best5RM = best5RM { dict["best5RM"] = best5RM }
        if let best5RMReps = best5RMReps { dict["best5RMReps"] = best5RMReps }
        if let best5RMDate = best5RMDate { dict["best5RMDate"] = best5RMDate }

        if let best10RM = best10RM { dict["best10RM"] = best10RM }
        if let best10RMReps = best10RMReps { dict["best10RMReps"] = best10RMReps }
        if let best10RMDate = best10RMDate { dict["best10RMDate"] = best10RMDate }

        if let lastPerformed = lastPerformed { dict["lastPerformed"] = lastPerformed }

        return dict
    }

    /// Update from CloudKit dictionary
    func updateFromCloudKit(_ dict: [String: Any]) {
        // Only update if CloudKit data is newer
        if let cloudUpdated = dict["lastUpdated"] as? Date,
           cloudUpdated <= lastUpdated {
            return
        }

        // Update all fields, keeping the better PR values
        if let weight = dict["bestWeight"] as? Double,
           (bestWeight == nil || weight > bestWeight!) {
            bestWeight = weight
            bestWeightReps = dict["bestWeightReps"] as? Int
            bestWeightDate = dict["bestWeightDate"] as? Date
        }

        if let rm1 = dict["best1RM"] as? Double,
           (best1RM == nil || rm1 > best1RM!) {
            best1RM = rm1
            best1RMDate = dict["best1RMDate"] as? Date
            best1RMSourceWeight = dict["best1RMSourceWeight"] as? Double
            best1RMSourceReps = dict["best1RMSourceReps"] as? Int
        }

        if let volume = dict["bestVolume"] as? Double,
           (bestVolume == nil || volume > bestVolume!) {
            bestVolume = volume
            bestVolumeDate = dict["bestVolumeDate"] as? Date
            bestVolumeSets = dict["bestVolumeSets"] as? Int
        }

        if let rm5 = dict["best5RM"] as? Double,
           (best5RM == nil || rm5 > best5RM!) {
            best5RM = rm5
            best5RMReps = dict["best5RMReps"] as? Int
            best5RMDate = dict["best5RMDate"] as? Date
        }

        if let rm10 = dict["best10RM"] as? Double,
           (best10RM == nil || rm10 > best10RM!) {
            best10RM = rm10
            best10RMReps = dict["best10RMReps"] as? Int
            best10RMDate = dict["best10RMDate"] as? Date
        }

        if let total = dict["totalWorkouts"] as? Int {
            totalWorkouts = max(totalWorkouts, total)
        }

        if let lastPerf = dict["lastPerformed"] as? Date {
            lastPerformed = lastPerf
        }

        lastUpdated = dict["lastUpdated"] as? Date ?? Date()
    }
}

// MARK: - String Extension for Exercise Name Normalization

extension String {
    /// Normalize exercise name for consistent matching
    var normalizedExerciseName: String {
        return self
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "  ", with: " ")  // Remove double spaces
            .replacingOccurrences(of: "barbell ", with: "")  // Normalize "Barbell Bench Press" -> "bench press"
            .replacingOccurrences(of: "dumbbell ", with: "")
    }
}
