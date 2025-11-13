//
//  Set.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 27.02.2025.
//

import Foundation
import SwiftData

@Model
class Set {
    @Attribute(.unique) var id: UUID
    var weight: Int
    var reps: Int
    var failure: Bool
    var warmUp: Bool
    var restPause: Bool
    var dropSet: Bool
    var time: String
    var note: String
    var createdAt: Date
    var bodyWeight: Bool

    @Relationship(deleteRule: .cascade, inverse: \Exercise.sets) var exercise: Exercise? // ✅ Each Set belongs to an Exercise

    init(id: UUID = UUID(), weight: Int, reps: Int, failure: Bool, warmUp: Bool, restPause: Bool, dropSet: Bool, time: String, note: String, createdAt: Date, bodyWeight: Bool, exercise: Exercise? = nil) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.failure = failure
        self.warmUp = warmUp
        self.restPause = restPause
        self.dropSet = dropSet
        self.time = time
        self.note = note
        self.createdAt = createdAt
        self.bodyWeight = bodyWeight
        self.exercise = exercise
    }
}
