//
//  SplitTemplate.swift
//  ShadowLift
//
//  Created by Claude Code on 26.10.2025.
//

import Foundation

/// Template for pre-built workout splits
struct SplitTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let targetUser: String  // "Beginner", "Intermediate", "Advanced"
    let frequency: String   // "3 days/week", "4 days/week", etc.
    let goal: String        // "Strength", "Hypertrophy", "Power", etc.
    let days: [SplitTemplateDay]
    let isPremium: Bool

    init(id: UUID = UUID(), name: String, description: String, targetUser: String, frequency: String, goal: String, days: [SplitTemplateDay], isPremium: Bool = true) {
        self.id = id
        self.name = name
        self.description = description
        self.targetUser = targetUser
        self.frequency = frequency
        self.goal = goal
        self.days = days
        self.isPremium = isPremium
    }
}

/// Template day structure
struct SplitTemplateDay: Identifiable, Codable {
    let id: UUID
    let name: String
    let dayNumber: Int
    let exercises: [SplitTemplateExercise]

    init(id: UUID = UUID(), name: String, dayNumber: Int, exercises: [SplitTemplateExercise]) {
        self.id = id
        self.name = name
        self.dayNumber = dayNumber
        self.exercises = exercises
    }
}

/// Template exercise structure
struct SplitTemplateExercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let muscleGroup: String
    let sets: Int
    let reps: String  // Can be range like "8-12" or fixed like "5"
    let exerciseOrder: Int
    let notes: String?

    init(id: UUID = UUID(), name: String, muscleGroup: String, sets: Int, reps: String, exerciseOrder: Int, notes: String? = nil) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.reps = reps
        self.exerciseOrder = exerciseOrder
        self.notes = notes
    }
}

// MARK: - Pre-built Templates

extension SplitTemplate {

    static let allTemplates: [SplitTemplate] = [
        .pplTemplate,
        .upperLowerTemplate,
        .arnoldSplitTemplate,
        .fullBodyTemplate,
        .phatTemplate
    ]

    // 1. PPL (Push/Pull/Legs) - Hypertrophy Focus
    static let pplTemplate = SplitTemplate(
        name: "PPL (Push/Pull/Legs)",
        description: "Classic hypertrophy split. Train each muscle group twice per week with optimal recovery.",
        targetUser: "Intermediate/Advanced",
        frequency: "6 days/week",
        goal: "Hypertrophy",
        days: [
            // Push Day
            SplitTemplateDay(name: "Push", dayNumber: 1, exercises: [
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: "8-10", exerciseOrder: 1),
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 4, reps: "8-10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 3, reps: "10-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 3, reps: "12-15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Tricep Rope Pushdowns", muscleGroup: "Triceps", sets: 3, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Overhead Tricep Extension", muscleGroup: "Triceps", sets: 3, reps: "10-12", exerciseOrder: 6)
            ]),
            // Pull Day
            SplitTemplateDay(name: "Pull", dayNumber: 2, exercises: [
                SplitTemplateExercise(name: "Deadlift", muscleGroup: "Back", sets: 4, reps: "6-8", exerciseOrder: 1),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 4, reps: "8-10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Pull-ups", muscleGroup: "Back", sets: 3, reps: "8-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Face Pulls", muscleGroup: "Shoulders", sets: 3, reps: "12-15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Barbell Curl", muscleGroup: "Biceps", sets: 3, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Hammer Curl", muscleGroup: "Biceps", sets: 3, reps: "10-12", exerciseOrder: 6)
            ]),
            // Legs Day
            SplitTemplateDay(name: "Legs", dayNumber: 3, exercises: [
                SplitTemplateExercise(name: "Squat", muscleGroup: "Legs", sets: 4, reps: "8-10", exerciseOrder: 1),
                SplitTemplateExercise(name: "Romanian Deadlift", muscleGroup: "Legs", sets: 4, reps: "8-10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: "10-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 3, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Calf Raises", muscleGroup: "Legs", sets: 4, reps: "12-15", exerciseOrder: 5)
            ]),
            // Repeat days 4-6 (same as 1-3)
            SplitTemplateDay(name: "Push", dayNumber: 4, exercises: [
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: "8-10", exerciseOrder: 1),
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 4, reps: "8-10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 3, reps: "10-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 3, reps: "12-15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Tricep Rope Pushdowns", muscleGroup: "Triceps", sets: 3, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Overhead Tricep Extension", muscleGroup: "Triceps", sets: 3, reps: "10-12", exerciseOrder: 6)
            ]),
            SplitTemplateDay(name: "Pull", dayNumber: 5, exercises: [
                SplitTemplateExercise(name: "Deadlift", muscleGroup: "Back", sets: 4, reps: "6-8", exerciseOrder: 1),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 4, reps: "8-10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Pull-ups", muscleGroup: "Back", sets: 3, reps: "8-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Face Pulls", muscleGroup: "Shoulders", sets: 3, reps: "12-15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Barbell Curl", muscleGroup: "Biceps", sets: 3, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Hammer Curl", muscleGroup: "Biceps", sets: 3, reps: "10-12", exerciseOrder: 6)
            ]),
            SplitTemplateDay(name: "Legs", dayNumber: 6, exercises: [
                SplitTemplateExercise(name: "Squat", muscleGroup: "Legs", sets: 4, reps: "8-10", exerciseOrder: 1),
                SplitTemplateExercise(name: "Romanian Deadlift", muscleGroup: "Legs", sets: 4, reps: "8-10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: "10-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 3, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Calf Raises", muscleGroup: "Legs", sets: 4, reps: "12-15", exerciseOrder: 5)
            ])
        ]
    )

    // 2. Upper/Lower - Strength & Power
    static let upperLowerTemplate = SplitTemplate(
        name: "Upper/Lower Split",
        description: "Perfect balance of strength and hypertrophy. Combines power and volume training.",
        targetUser: "Beginner/Intermediate",
        frequency: "4 days/week",
        goal: "Strength & Size",
        days: [
            // Upper Power
            SplitTemplateDay(name: "Upper Power", dayNumber: 1, exercises: [
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 5, reps: "5", exerciseOrder: 1, notes: "Heavy weight"),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 5, reps: "5", exerciseOrder: 2, notes: "Heavy weight"),
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: "8", exerciseOrder: 3),
                SplitTemplateExercise(name: "Pull-ups", muscleGroup: "Back", sets: 3, reps: "8", exerciseOrder: 4)
            ]),
            // Lower Power
            SplitTemplateDay(name: "Lower Power", dayNumber: 2, exercises: [
                SplitTemplateExercise(name: "Squat", muscleGroup: "Legs", sets: 5, reps: "5", exerciseOrder: 1, notes: "Heavy weight"),
                SplitTemplateExercise(name: "Deadlift", muscleGroup: "Legs", sets: 3, reps: "5", exerciseOrder: 2, notes: "Heavy weight"),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 3, reps: "10", exerciseOrder: 4)
            ]),
            // Upper Hypertrophy
            SplitTemplateDay(name: "Upper Hypertrophy", dayNumber: 3, exercises: [
                SplitTemplateExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 4, reps: "10", exerciseOrder: 1),
                SplitTemplateExercise(name: "Cable Row", muscleGroup: "Back", sets: 4, reps: "12", exerciseOrder: 2),
                SplitTemplateExercise(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", sets: 3, reps: "12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Tricep Extensions", muscleGroup: "Triceps", sets: 3, reps: "12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Bicep Curls", muscleGroup: "Biceps", sets: 3, reps: "12", exerciseOrder: 5)
            ]),
            // Lower Hypertrophy
            SplitTemplateDay(name: "Lower Hypertrophy", dayNumber: 4, exercises: [
                SplitTemplateExercise(name: "Front Squat", muscleGroup: "Legs", sets: 4, reps: "8", exerciseOrder: 1),
                SplitTemplateExercise(name: "Romanian Deadlift", muscleGroup: "Legs", sets: 4, reps: "10", exerciseOrder: 2),
                SplitTemplateExercise(name: "Bulgarian Split Squat", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Extensions", muscleGroup: "Legs", sets: 3, reps: "15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Calf Raises", muscleGroup: "Legs", sets: 4, reps: "15", exerciseOrder: 5)
            ])
        ]
    )

    // 3. Arnold Split
    static let arnoldSplitTemplate = SplitTemplate(
        name: "Arnold Split",
        description: "Classic golden era bodybuilding split. High volume antagonistic training for maximum growth.",
        targetUser: "Advanced",
        frequency: "6 days/week",
        goal: "Aesthetics & Mass",
        days: [
            // Chest & Back
            SplitTemplateDay(name: "Chest & Back", dayNumber: 1, exercises: [
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: "8-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 4, reps: "8-12", exerciseOrder: 2),
                SplitTemplateExercise(name: "Incline Press", muscleGroup: "Chest", sets: 4, reps: "10-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Pull-ups", muscleGroup: "Back", sets: 4, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Dumbbell Flyes", muscleGroup: "Chest", sets: 3, reps: "12-15", exerciseOrder: 5),
                SplitTemplateExercise(name: "Cable Row", muscleGroup: "Back", sets: 3, reps: "12-15", exerciseOrder: 6),
                SplitTemplateExercise(name: "Pullovers", muscleGroup: "Back", sets: 3, reps: "12-15", exerciseOrder: 7)
            ]),
            // Shoulders & Arms
            SplitTemplateDay(name: "Shoulders & Arms", dayNumber: 2, exercises: [
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 4, reps: "10-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 4, reps: "12-15", exerciseOrder: 2),
                SplitTemplateExercise(name: "Rear Delt Flyes", muscleGroup: "Shoulders", sets: 3, reps: "12-15", exerciseOrder: 3),
                SplitTemplateExercise(name: "Barbell Curl", muscleGroup: "Biceps", sets: 4, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Tricep Dips", muscleGroup: "Triceps", sets: 4, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Hammer Curl", muscleGroup: "Biceps", sets: 3, reps: "12-15", exerciseOrder: 6),
                SplitTemplateExercise(name: "Overhead Tricep Extension", muscleGroup: "Triceps", sets: 3, reps: "12-15", exerciseOrder: 7)
            ]),
            // Legs
            SplitTemplateDay(name: "Legs", dayNumber: 3, exercises: [
                SplitTemplateExercise(name: "Squat", muscleGroup: "Legs", sets: 5, reps: "8-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 4, reps: "12-15", exerciseOrder: 2),
                SplitTemplateExercise(name: "Leg Extensions", muscleGroup: "Legs", sets: 4, reps: "15-20", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 4, reps: "12-15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Stiff-Leg Deadlift", muscleGroup: "Legs", sets: 4, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Walking Lunges", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 6),
                SplitTemplateExercise(name: "Calf Raises", muscleGroup: "Legs", sets: 5, reps: "15-20", exerciseOrder: 7)
            ]),
            // Repeat days 4-6
            SplitTemplateDay(name: "Chest & Back", dayNumber: 4, exercises: [
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 4, reps: "8-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 4, reps: "8-12", exerciseOrder: 2),
                SplitTemplateExercise(name: "Incline Press", muscleGroup: "Chest", sets: 4, reps: "10-12", exerciseOrder: 3),
                SplitTemplateExercise(name: "Pull-ups", muscleGroup: "Back", sets: 4, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Dumbbell Flyes", muscleGroup: "Chest", sets: 3, reps: "12-15", exerciseOrder: 5),
                SplitTemplateExercise(name: "Cable Row", muscleGroup: "Back", sets: 3, reps: "12-15", exerciseOrder: 6),
                SplitTemplateExercise(name: "Pullovers", muscleGroup: "Back", sets: 3, reps: "12-15", exerciseOrder: 7)
            ]),
            SplitTemplateDay(name: "Shoulders & Arms", dayNumber: 5, exercises: [
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 4, reps: "10-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 4, reps: "12-15", exerciseOrder: 2),
                SplitTemplateExercise(name: "Rear Delt Flyes", muscleGroup: "Shoulders", sets: 3, reps: "12-15", exerciseOrder: 3),
                SplitTemplateExercise(name: "Barbell Curl", muscleGroup: "Biceps", sets: 4, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Tricep Dips", muscleGroup: "Triceps", sets: 4, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Hammer Curl", muscleGroup: "Biceps", sets: 3, reps: "12-15", exerciseOrder: 6),
                SplitTemplateExercise(name: "Overhead Tricep Extension", muscleGroup: "Triceps", sets: 3, reps: "12-15", exerciseOrder: 7)
            ]),
            SplitTemplateDay(name: "Legs", dayNumber: 6, exercises: [
                SplitTemplateExercise(name: "Squat", muscleGroup: "Legs", sets: 5, reps: "8-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 4, reps: "12-15", exerciseOrder: 2),
                SplitTemplateExercise(name: "Leg Extensions", muscleGroup: "Legs", sets: 4, reps: "15-20", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 4, reps: "12-15", exerciseOrder: 4),
                SplitTemplateExercise(name: "Stiff-Leg Deadlift", muscleGroup: "Legs", sets: 4, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Walking Lunges", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 6),
                SplitTemplateExercise(name: "Calf Raises", muscleGroup: "Legs", sets: 5, reps: "15-20", exerciseOrder: 7)
            ])
        ]
    )

    // 4. Full Body
    static let fullBodyTemplate = SplitTemplate(
        name: "Full Body 3x/Week",
        description: "Hit every muscle group three times per week. Perfect for beginners or busy schedules.",
        targetUser: "Beginner/Intermediate",
        frequency: "3 days/week",
        goal: "Strength & Conditioning",
        days: [
            // Day 1
            SplitTemplateDay(name: "Full Body A", dayNumber: 1, exercises: [
                SplitTemplateExercise(name: "Back Squat", muscleGroup: "Legs", sets: 5, reps: "5", exerciseOrder: 1),
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 5, reps: "5", exerciseOrder: 2),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 3, reps: "8", exerciseOrder: 3),
                SplitTemplateExercise(name: "Romanian Deadlift", muscleGroup: "Legs", sets: 3, reps: "10", exerciseOrder: 4),
                SplitTemplateExercise(name: "Plank", muscleGroup: "Core", sets: 3, reps: "60s", exerciseOrder: 5)
            ]),
            // Day 2
            SplitTemplateDay(name: "Full Body B", dayNumber: 2, exercises: [
                SplitTemplateExercise(name: "Front Squat", muscleGroup: "Legs", sets: 4, reps: "8", exerciseOrder: 1),
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 5, reps: "5", exerciseOrder: 2),
                SplitTemplateExercise(name: "Pull-ups", muscleGroup: "Back", sets: 3, reps: "8", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Bicep Curls", muscleGroup: "Biceps", sets: 3, reps: "10", exerciseOrder: 5)
            ]),
            // Day 3
            SplitTemplateDay(name: "Full Body C", dayNumber: 3, exercises: [
                SplitTemplateExercise(name: "Deadlift", muscleGroup: "Back", sets: 5, reps: "5", exerciseOrder: 1),
                SplitTemplateExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 4, reps: "8", exerciseOrder: 2),
                SplitTemplateExercise(name: "Lat Pulldown", muscleGroup: "Back", sets: 3, reps: "10", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Face Pulls", muscleGroup: "Shoulders", sets: 3, reps: "15", exerciseOrder: 5)
            ])
        ]
    )

    // 5. PHAT (Power Hypertrophy Adaptive Training)
    static let phatTemplate = SplitTemplate(
        name: "PHAT",
        description: "Dr. Layne Norton's proven system. Combines powerlifting strength with bodybuilding size.",
        targetUser: "Advanced",
        frequency: "5 days/week",
        goal: "Strength & Hypertrophy",
        days: [
            // Day 1: Upper Power
            SplitTemplateDay(name: "Upper Power", dayNumber: 1, exercises: [
                SplitTemplateExercise(name: "Bench Press", muscleGroup: "Chest", sets: 5, reps: "3-5", exerciseOrder: 1, notes: "Heavy"),
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 5, reps: "3-5", exerciseOrder: 2, notes: "Heavy"),
                SplitTemplateExercise(name: "Overhead Press", muscleGroup: "Shoulders", sets: 3, reps: "5", exerciseOrder: 3),
                SplitTemplateExercise(name: "Weighted Pull-ups", muscleGroup: "Back", sets: 3, reps: "5", exerciseOrder: 4),
                SplitTemplateExercise(name: "Close-Grip Bench", muscleGroup: "Triceps", sets: 3, reps: "6", exerciseOrder: 5)
            ]),
            // Day 2: Lower Power
            SplitTemplateDay(name: "Lower Power", dayNumber: 2, exercises: [
                SplitTemplateExercise(name: "Squat", muscleGroup: "Legs", sets: 5, reps: "3-5", exerciseOrder: 1, notes: "Heavy"),
                SplitTemplateExercise(name: "Deadlift", muscleGroup: "Legs", sets: 3, reps: "3-5", exerciseOrder: 2, notes: "Heavy"),
                SplitTemplateExercise(name: "Leg Press", muscleGroup: "Legs", sets: 3, reps: "8", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 3, reps: "8", exerciseOrder: 4),
                SplitTemplateExercise(name: "Calf Raises", muscleGroup: "Legs", sets: 4, reps: "10", exerciseOrder: 5)
            ]),
            // Day 3: Rest
            // Day 4: Back & Shoulders Hypertrophy
            SplitTemplateDay(name: "Back & Shoulders", dayNumber: 3, exercises: [
                SplitTemplateExercise(name: "Barbell Row", muscleGroup: "Back", sets: 4, reps: "8-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Lat Pulldown", muscleGroup: "Back", sets: 4, reps: "10-12", exerciseOrder: 2),
                SplitTemplateExercise(name: "Cable Row", muscleGroup: "Back", sets: 3, reps: "12-15", exerciseOrder: 3),
                SplitTemplateExercise(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", sets: 4, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Lateral Raises", muscleGroup: "Shoulders", sets: 4, reps: "12-15", exerciseOrder: 5),
                SplitTemplateExercise(name: "Rear Delt Flyes", muscleGroup: "Shoulders", sets: 3, reps: "15", exerciseOrder: 6)
            ]),
            // Day 5: Chest & Arms Hypertrophy
            SplitTemplateDay(name: "Chest & Arms", dayNumber: 4, exercises: [
                SplitTemplateExercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", sets: 4, reps: "10-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Flat Dumbbell Press", muscleGroup: "Chest", sets: 4, reps: "10-12", exerciseOrder: 2),
                SplitTemplateExercise(name: "Cable Flyes", muscleGroup: "Chest", sets: 3, reps: "12-15", exerciseOrder: 3),
                SplitTemplateExercise(name: "Barbell Curl", muscleGroup: "Biceps", sets: 4, reps: "10-12", exerciseOrder: 4),
                SplitTemplateExercise(name: "Tricep Rope Pushdown", muscleGroup: "Triceps", sets: 4, reps: "10-12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Hammer Curl", muscleGroup: "Biceps", sets: 3, reps: "12-15", exerciseOrder: 6),
                SplitTemplateExercise(name: "Overhead Tricep Extension", muscleGroup: "Triceps", sets: 3, reps: "12-15", exerciseOrder: 7)
            ]),
            // Day 6: Legs Hypertrophy
            SplitTemplateDay(name: "Legs Hypertrophy", dayNumber: 5, exercises: [
                SplitTemplateExercise(name: "Front Squat", muscleGroup: "Legs", sets: 4, reps: "10-12", exerciseOrder: 1),
                SplitTemplateExercise(name: "Romanian Deadlift", muscleGroup: "Legs", sets: 4, reps: "10-12", exerciseOrder: 2),
                SplitTemplateExercise(name: "Leg Extensions", muscleGroup: "Legs", sets: 4, reps: "15-20", exerciseOrder: 3),
                SplitTemplateExercise(name: "Leg Curl", muscleGroup: "Legs", sets: 4, reps: "15-20", exerciseOrder: 4),
                SplitTemplateExercise(name: "Walking Lunges", muscleGroup: "Legs", sets: 3, reps: "12", exerciseOrder: 5),
                SplitTemplateExercise(name: "Seated Calf Raises", muscleGroup: "Legs", sets: 5, reps: "15-20", exerciseOrder: 6)
            ])
        ]
    )
}
