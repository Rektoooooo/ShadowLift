//
//  WeightPoint.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 26.03.2025.
//
import Foundation
import SwiftData

@Model
class WeightPoint {
    var date: Date = Date()
    var weight: Double = 0.0

    // Computed property for CloudKit ID
    var cloudKitID: String {
        return "\(date.timeIntervalSince1970)-\(weight)"
    }

    init(date: Date, weight: Double) {
        self.date = date
        self.weight = weight
    }
}
