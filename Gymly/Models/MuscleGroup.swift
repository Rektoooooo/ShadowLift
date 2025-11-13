//
//  MuscleGroup.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 19.09.2024.
//

import Foundation
import SwiftUI

class MuscleGroup: ObservableObject, Identifiable {
    let id: UUID
    let name: String
    @Published var exercises: [Exercise]

    init(id: UUID = UUID(), name: String, exercises: [Exercise]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

extension MuscleGroup: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension MuscleGroup: Equatable {
    static func == (lhs: MuscleGroup, rhs: MuscleGroup) -> Bool {
        return lhs.name == rhs.name
    }
}

