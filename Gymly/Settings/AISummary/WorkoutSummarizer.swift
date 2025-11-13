//
//  WorkoutSummarizer.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 22.09.2025.
//

import Foundation
import FoundationModels
import SwiftData
import SwiftUI

enum WorkoutSummaryError: LocalizedError {
    case noWorkoutData

    var errorDescription: String? {
        switch self {
        case .noWorkoutData:
            return "No completed workouts found in the selected time period. Complete some workouts and try again."
        }
    }
}

@available(iOS 26, *)
@MainActor
final class WorkoutSummarizer: ObservableObject {
    @Published private(set) var workoutSummary: WorkoutSummary.PartiallyGenerated?
    private var session: LanguageModelSession

    @Published var error: Error?
    @Published var isGenerating = false

    init() {
        self.session = LanguageModelSession(
            instructions: Instructions {
                "You are an expert fitness coach and performance analyst."

                "Your job is to analyze workout data and provide personalized insights."

                "Focus on:"
                "- Identifying patterns in performance"
                "- Recognizing personal records and achievements"
                "- Spotting potential issues with volume, consistency, muscle balance, or training frequency"
                "- Providing actionable recommendations for improvement"

                "Be concise but comprehensive."
                "Use motivating language while being realistic."
                "Always prioritize safety and proper progression."
            }
        )
    }

    /// Format number with thousands separator (comma)
    private func formatNumberWithCommas(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? String(format: "%.0f", number)
    }

    func generateWeeklySummary(
        thisWeek: [CompletedWorkout],
        lastWeek: [CompletedWorkout],
        fitnessProfile: FitnessProfile? = nil,
        userWeight: Double? = nil,
        weightUnit: String = "Kg"
    ) async throws {
        isGenerating = true
        defer { isGenerating = false }

        // Validate that there is meaningful workout data to analyze
        let hasThisWeekData = !thisWeek.isEmpty && thisWeek.contains { !$0.exercises.isEmpty }
        let hasLastWeekData = !lastWeek.isEmpty && lastWeek.contains { !$0.exercises.isEmpty }

        // If no workout data exists at all, throw an error
        guard hasThisWeekData || hasLastWeekData else {
            throw WorkoutSummaryError.noWorkoutData
        }

        // Calculate stats manually BEFORE generating the AI prompt
        let manualStats = ManualStats.calculate(thisWeek: thisWeek, lastWeek: lastWeek)

        let stream = session.streamResponse(
            generating: WorkoutSummary.self,
            includeSchemaInPrompt: false,
            options: GenerationOptions(sampling: .greedy)
        ) {
            "Analyze the following workout data and generate a comprehensive summary:"

            if hasThisWeekData {
                let workoutNames = thisWeek.map { $0.dayName }.joined(separator: ", ")
                "This week's workout split: \(workoutNames)"

                "THIS WEEK'S WORKOUTS:"
                for (index, workout) in thisWeek.enumerated() {
                "Workout \(index + 1): \(workout.dayName) - \(workout.duration) min"

                for exercise in workout.exercises {
                    let totalVolume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                    let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                    let totalReps = exercise.sets.reduce(0) { $0 + $1.reps }
                    let specialTechniques = exercise.sets.compactMap { set in
                        if set.failure { return "failure" }
                        if set.dropSet { return "drop" }
                        if set.restPause { return "rest-pause" }
                        return nil
                    }

                    "- \(exercise.name): \(exercise.sets.count) sets, \(totalReps) reps, max \(maxWeight)kg, volume \(String(format: "%.0f", totalVolume))kg"
                    if !specialTechniques.isEmpty {
                        "  (used: \(specialTechniques.joined(separator: ", ")))"
                    }
                }

                    if !workout.incompleteExercises.isEmpty {
                        "Skipped: \(workout.incompleteExercises.map { $0.name }.joined(separator: ", "))"
                    }
                }
            } else {
                "No completed workouts in the current week."
            }

            if hasLastWeekData {
                "LAST WEEK'S SUMMARY (for comparison):"
                "Total workouts: \(lastWeek.count)"
                "Total duration: \(lastWeek.reduce(0) { $0 + $1.duration }) minutes"

                // Calculate essential metrics for comparison
                let lastWeekVolume = lastWeek.flatMap { $0.exercises }.flatMap { $0.sets }.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                let lastWeekTotalSets = lastWeek.flatMap { $0.exercises }.reduce(0) { $0 + $1.sets.count }
                let lastWeekExercises = Set(lastWeek.flatMap { $0.exercises }.map { $0.name })
                let lastWeekSkipped = lastWeek.flatMap { $0.incompleteExercises }.map { $0.name }

                "Total volume: \(String(format: "%.0f", lastWeekVolume)) kg"
                "Total sets: \(lastWeekTotalSets)"
                "Unique exercises: \(lastWeekExercises.count)"
                if !lastWeekSkipped.isEmpty {
                    "Skipped exercises: \(lastWeekSkipped.joined(separator: ", "))"
                }
            } else {
                "No workout data available for comparison from the previous week."
            }

            // Add fitness profile context if available
            if let profile = fitnessProfile {
                ""
                "USER'S FITNESS PROFILE (tailor recommendations to match these goals):"
                "Primary Goal: \(profile.goal.displayName) - \(profile.goal.description)"
                "Equipment Access: \(profile.equipment.displayName) - \(profile.equipment.description)"
                "Experience Level: \(profile.experience.displayName) - \(profile.experience.description)"
                "Target Training Days: \(profile.daysPerWeek) days per week"
                ""
                "IMPORTANT: Tailor ALL recommendations and analysis to align with the user's stated goal of '\(profile.goal.displayName)'."
                "Consider their \(profile.experience.displayName) experience level when suggesting exercises and programming."
                "Account for their equipment access (\(profile.equipment.displayName)) in recommendations."
                if manualStats.totalSessions < profile.daysPerWeek {
                    "NOTE: User completed \(manualStats.totalSessions) sessions this week but their target is \(profile.daysPerWeek) sessions. Address this gap."
                } else if manualStats.totalSessions > profile.daysPerWeek {
                    "NOTE: User completed \(manualStats.totalSessions) sessions this week, exceeding their target of \(profile.daysPerWeek) sessions. Consider recovery needs."
                }
            }

            // Add user weight data if available
            if let weight = userWeight, weight > 0 {
                ""
                "USER'S BODY WEIGHT DATA:"
                "Current Weight: \(String(format: "%.1f", weight)) \(weightUnit)"

                // Goal-specific weight context
                if let profile = fitnessProfile {
                    switch profile.goal {
                    case .gainMuscle:
                        "Weight Goal Context: User aims to GAIN MUSCLE. Slight weight increase (0.25-0.5kg per week) is healthy and expected with proper training."
                        "In recommendations, emphasize that weight gain + strength gains = successful muscle building. Reassure user if weight is trending up."
                    case .loseWeight:
                        "Weight Goal Context: User aims to LOSE WEIGHT. Target is gradual weight loss (0.5-1kg per week) while preserving muscle mass."
                        "In recommendations, emphasize maintaining training intensity despite caloric deficit. Celebrate weight loss progress."
                    case .recomp:
                        "Weight Goal Context: User aims for BODY RECOMPOSITION (lose fat, gain muscle). Weight may stay STABLE or change slowly."
                        "In recommendations, emphasize that stable weight + strength gains = successful recomp. Focus on performance metrics, not scale."
                    case .stayFit:
                        "Weight Goal Context: User aims to MAINTAIN FITNESS. Weight should remain relatively stable."
                        "In recommendations, focus on consistency and performance rather than weight changes."
                    case .increaseStrength:
                        "Weight Goal Context: User aims to INCREASE STRENGTH. Weight may increase slightly due to muscle gain."
                        "In recommendations, emphasize strength metrics over weight. Some weight gain is acceptable if strength is improving."
                    }
                } else {
                    "Use this data to provide context-aware recommendations about nutrition and recovery."
                }
                ""
            }

            "IMPORTANT: Use these EXACT pre-calculated statistics in your keyStats section (ONLY these three):"
            "- Total Volume: \(formatNumberWithCommas(manualStats.totalVolume)) kg" + (manualStats.volumeDelta != nil ? " (delta: \(manualStats.volumeDelta!))" : "")
            "- Total Sessions: \(manualStats.totalSessions)" + (manualStats.sessionsDelta != nil ? " (delta: \(manualStats.sessionsDelta!))" : "")
            "- PRs Achieved: \(manualStats.prsAchieved)"
            "DO NOT add current/previous PR weights to keyStats - that belongs in the Personal Records section only."

            if !manualStats.prDetails.isEmpty {
                "PERSONAL RECORDS (PRs) - Use WEIGHT PRs only, NOT volume. List ONLY the highest weight achieved for each exercise (NO DUPLICATES):"
                for pr in manualStats.prDetails {
                    "- \(pr.exerciseName): \(String(format: "%.1f", pr.newWeight))kg (was: \(String(format: "%.1f", pr.previousWeight))kg)"
                }
            } else {
                "No PRs were achieved this week (no exercises exceeded previous max weight)"
            }

            "Generate a workout summary with:"
            "- A motivating headline capturing the week's key achievement"
            "- A 2-3 sentence overview in plain language. TONE GUIDELINES:"
            if manualStats.totalSessions <= 2 {
                "  * \(manualStats.totalSessions) sessions is CONCERNINGLY LOW. Be critical and honest. Mention risk of muscle loss and need for more consistency."
            } else if manualStats.totalSessions >= 6 {
                "  * \(manualStats.totalSessions) sessions is VERY HIGH. Be cautious about overtraining risk. Emphasize need for recovery."
            } else {
                "  * \(manualStats.totalSessions) sessions is good. Be positive but realistic about achievements."
            }
            "- Exercise-by-exercise breakdown"
            if hasThisWeekData && hasLastWeekData {
                "- 3-4 Short-term trends (comparing to previous weeks) covering volume, sessions, strength gains, etc."
                ""
                "  ⚠️ TREND DIRECTION RULES: Set the 'direction' field correctly:"
                "  - Use 'up' for improvements/increases (volume increased, strength gains, etc.) → will show green arrow pointing up-right"
                "  - Use 'down' for decreases/declines (volume decreased, fewer sessions, etc.) → will show red arrow pointing down-right"
                "  - Use 'flat' for consistency/no change (maintained same level) → will show gray arrow pointing right"
                ""
                "  ⚠️ CRITICAL RULE FOR TRENDS: NEVER show raw numbers like 'Volume: Week 1: 16204kg, Week 2: 11000kg' or 'Sessions: Week 1: 4, Week 2: 2'."
                "  ALWAYS provide ONLY analysis and interpretation in natural language."
                "  GOOD EXAMPLES:"
                "  - 'Volume decreased by 32% this week compared to last week, suggesting reduced training intensity'"
                "  - 'Training frequency dropped significantly from 4 to 2 sessions, which is concerning for consistency'"
                "  - 'Strength gains continued with notable improvements in compound movements'"
                "  BAD EXAMPLES (DO NOT DO THIS):"
                "  - 'Volume: Week 1: 16204kg, Week 2: 11000kg'"
                "  - 'Sessions: 4 last week, 2 this week'"
                "  - Any format showing raw week-by-week numbers"
                ""
                "  When discussing SESSIONS trend:"
                if manualStats.totalSessions <= 2 {
                    "  * Be NEGATIVE/CONCERNED about low session count (\(manualStats.totalSessions) sessions). This is problematic."
                } else if manualStats.totalSessions >= 6 {
                    "  * Be CAUTIOUS about high session count (\(manualStats.totalSessions) sessions). Warn about recovery needs."
                } else {
                    "  * Be POSITIVE about session count (\(manualStats.totalSessions) sessions). This is a good training frequency."
                }
            } else {
                "- Performance observations from available data"
            }
            "- Personal records achieved MUST be based on MAX WEIGHT per exercise (e.g. '100kg bench press'), NEVER use volume totals"
            "- 2-3 potential training issues (NOT form-related, focus on volume, consistency, muscle balance, recovery, etc). When discussing training frequency:"
            if manualStats.totalSessions <= 2 {
                "  * SHOULD include as concern: Low training frequency (\(manualStats.totalSessions) sessions). Mention that this may limit progress. This is TOO FEW sessions, NOT an overtraining risk."
            } else if manualStats.totalSessions >= 6 {
                "  * SHOULD include concern about: High training frequency (\(manualStats.totalSessions) sessions). Risk of overtraining and insufficient recovery."
            } else {
                "  * Training frequency is appropriate. Focus concerns on other areas like muscle balance, volume distribution, exercise variety, etc."
            }
            "- 2-3 specific, actionable recommendations for next week (covering training frequency, progressive overload, exercise selection, etc)."

            // Goal-specific recommendation guidance
            if let profile = fitnessProfile {
                "  * GOAL-ALIGNED RECOMMENDATIONS for '\(profile.goal.displayName)':"
                switch profile.goal {
                case .gainMuscle:
                    "    - Focus on progressive overload and sufficient volume for hypertrophy (8-12 reps, 3-5 sets)"
                    "    - Ensure adequate protein and caloric surplus"
                    "    - Emphasize compound movements and time under tension"
                case .loseWeight:
                    "    - Maintain strength training to preserve muscle while in caloric deficit"
                    "    - Consider circuit training or supersets to increase calorie burn"
                    "    - Emphasize consistency and sustainable training volume"
                case .recomp:
                    "    - Balance strength training with adequate protein intake"
                    "    - Progressive overload is crucial to build muscle while losing fat"
                    "    - Recommend slight caloric deficit with high protein"
                case .stayFit:
                    "    - Maintain current training volume and variety"
                    "    - Focus on exercise enjoyment and consistency"
                    "    - Suggest variations to keep workouts interesting"
                case .increaseStrength:
                    "    - Prioritize heavy compound lifts (3-6 reps, higher weight)"
                    "    - Emphasize proper rest between sets (3-5 minutes)"
                    "    - Progressive overload with focus on weight increases, not volume"
                }

                "  * EXPERIENCE-ADJUSTED GUIDANCE for \(profile.experience.displayName):"
                switch profile.experience {
                case .beginner:
                    "    - Focus on form and technique over weight"
                    "    - Recommend full-body workouts or upper/lower splits"
                    "    - Avoid overly complex programming or excessive volume"
                case .intermediate:
                    "    - Can handle moderate training volume and intensity"
                    "    - Suggest periodization and planned deloads"
                    "    - Appropriate for push/pull/legs or body part splits"
                case .advanced:
                    "    - Can utilize advanced techniques (drop sets, rest-pause, etc.)"
                    "    - May benefit from specialized programming and periodization"
                    "    - Focus on weak points and optimization"
                }
            }

            "  * When making frequency recommendations:"
            if manualStats.totalSessions <= 2 {
                "  * FIRST RECOMMENDATION MUST BE: User only completed \(manualStats.totalSessions) sessions. Recommend INCREASING training frequency to minimum 4 sessions per week."
                "  * DO NOT recommend rest or recovery - they need MORE training, not less."
                "  * Additional recommendations should focus on building consistency and habit formation."
            } else if manualStats.totalSessions >= 6 {
                "  * FIRST RECOMMENDATION SHOULD BE: User completed \(manualStats.totalSessions) sessions. Recommend ensuring adequate REST and RECOVERY."
                "  * Consider suggesting a deload week or reducing frequency to 4-5 sessions."
                "  * Additional recommendations can cover sleep quality, recovery strategies, and maintaining quality over quantity."
            } else {
                "  * Training frequency of \(manualStats.totalSessions) sessions is good. Focus recommendations on progressive overload, exercise variety, maintaining consistency, and other performance improvements."
            }

            if !hasThisWeekData {
                "IMPORTANT: Focus on motivating the user to get back to their workout routine since they haven't completed any workouts this week."
            }

            "Make it personal, specific, and actionable. Do not make up or hallucinate data that wasn't provided."
        }

        for try await partialResponse in stream {
            workoutSummary = partialResponse.content
        }

        // Save the completed summary to cache
        if let finalSummary = workoutSummary {
            AISummaryCache.shared.saveSummary(finalSummary)
        }
    }

    func prewarm() {
        session.prewarm()
    }

    func loadCachedSummary() {
        // Cache loading is now handled directly in the view
        // This method is kept for backward compatibility but does nothing
    }

    func clearSummary() {
        workoutSummary = nil
        AISummaryCache.shared.clearCache()
    }

    func cleanup() {
        // DON'T clear the summary - it's now cached and should persist
        // Only recreate the session to clear any cached data
        session = LanguageModelSession(
            instructions: Instructions {
                "You are an expert fitness coach and performance analyst."

                "Your job is to analyze workout data and provide personalized insights."

                "Focus on:"
                "- Identifying patterns in performance"
                "- Recognizing personal records and achievements"
                "- Spotting potential issues with volume, consistency, muscle balance, or training frequency"
                "- Providing actionable recommendations for improvement"

                "Be concise but comprehensive."
                "Use motivating language while being realistic."
                "Always prioritize safety and proper progression."
            }
        )
    }
}

struct CompletedWorkout {
    let date: Date
    let dayName: String
    let duration: Int
    let exercises: [CompletedExercise]
    let incompleteExercises: [IncompleteExercise]
}

struct CompletedExercise {
    let name: String
    let muscleGroup: String
    let sets: [CompletedSet]
}

struct CompletedSet {
    let weight: Double
    let reps: Int
    let failure: Bool
    let dropSet: Bool
    let restPause: Bool
}

// MARK: - Manual Stats Calculator
struct ManualStats {
    let totalVolume: Double
    let totalSessions: Int
    let prsAchieved: Int
    let volumeDelta: String?
    let sessionsDelta: String?
    let prDetails: [PRDetail]  // New: detailed PR information

    /// Calculate stats manually from workout data
    static func calculate(thisWeek: [CompletedWorkout], lastWeek: [CompletedWorkout]) -> ManualStats {
        // Calculate total volume for this week
        let thisWeekVolume = thisWeek
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        // Calculate total volume for last week
        let lastWeekVolume = lastWeek
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        // Calculate volume delta
        let volumeDelta: String?
        if lastWeekVolume > 0 {
            let percentChange = ((thisWeekVolume - lastWeekVolume) / lastWeekVolume) * 100
            volumeDelta = String(format: "%+.0f%%", percentChange)
        } else {
            volumeDelta = nil
        }

        // Calculate sessions
        let thisWeekSessions = thisWeek.count
        let lastWeekSessions = lastWeek.count

        // Calculate sessions delta
        let sessionsDelta: String?
        if lastWeekSessions > 0 {
            let difference = thisWeekSessions - lastWeekSessions
            sessionsDelta = difference >= 0 ? "+\(difference)" : "\(difference)"
        } else {
            sessionsDelta = nil
        }

        // Calculate PRs (compare max weights for each exercise)
        let prResult = calculatePRs(thisWeek: thisWeek, lastWeek: lastWeek)

        return ManualStats(
            totalVolume: thisWeekVolume,
            totalSessions: thisWeekSessions,
            prsAchieved: prResult.count,
            volumeDelta: volumeDelta,
            sessionsDelta: sessionsDelta,
            prDetails: prResult.details
        )
    }

    /// Calculate how many PRs were achieved based on max weight per exercise
    private static func calculatePRs(thisWeek: [CompletedWorkout], lastWeek: [CompletedWorkout]) -> (count: Int, details: [PRDetail]) {
        // Build a map of exercise -> max weight for last week
        var lastWeekMaxWeights: [String: Double] = [:]
        for workout in lastWeek {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                if let currentMax = lastWeekMaxWeights[exercise.name] {
                    lastWeekMaxWeights[exercise.name] = max(currentMax, maxWeight)
                } else {
                    lastWeekMaxWeights[exercise.name] = maxWeight
                }
            }
        }

        // Build a map of exercise -> max weight for THIS week (across all workouts)
        var thisWeekMaxWeights: [String: Double] = [:]
        for workout in thisWeek {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                if let currentMax = thisWeekMaxWeights[exercise.name] {
                    thisWeekMaxWeights[exercise.name] = max(currentMax, maxWeight)
                } else {
                    thisWeekMaxWeights[exercise.name] = maxWeight
                }
            }
        }

        // Count PRs by comparing max weights
        var prDetails: [PRDetail] = []
        for (exerciseName, thisWeekMax) in thisWeekMaxWeights {
            // If we have historical data and this week's max is higher, it's a PR
            if let lastWeekMax = lastWeekMaxWeights[exerciseName] {
                if thisWeekMax > lastWeekMax {
                    prDetails.append(PRDetail(
                        exerciseName: exerciseName,
                        newWeight: thisWeekMax,
                        previousWeight: lastWeekMax
                    ))
                }
            }
            // If no historical data but weight > 0, don't count as PR
            // (we need comparison data to confirm it's actually a record)
        }

        return (prDetails.count, prDetails)
    }
}

struct PRDetail {
    let exerciseName: String
    let newWeight: Double
    let previousWeight: Double
}
