//
//  ExerciseExtensions.swift
//  ShadowLift
//
//  Created by CloudKit Integration on 18.09.2025.
//

import Foundation

extension Exercise {
    /// Safe access to sets array
    var safeSets: [Exercise.Set] {
        return sets ?? []
    }

    /// Safe count of sets
    var setsCount: Int {
        return sets?.count ?? 0
    }
}