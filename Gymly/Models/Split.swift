//
//  Split.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 27.02.2025.
//

import Foundation
import SwiftData

@Model
class Split: ObservableObject, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var days: [Day]?
    var isActive: Bool = false
    var startDate: Date = Date()

    init(id: UUID = UUID(), name: String, days: [Day] = [], isActive: Bool = false, startDate: Date) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.startDate = startDate

        // Set up relationships after initialization
        for day in days {
            day.split = self
        }
    }

    // MARK: - Codable Compliance
    enum CodingKeys: String, CodingKey {
        case id, name, days, isActive, startDate
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isActive = try container.decode(Bool.self, forKey: .isActive)
        self.startDate = try container.decode(Date.self, forKey: .startDate)

        // Handle days relationship separately
        let decodedDays = try container.decode([Day].self, forKey: .days)
        for day in decodedDays {
            day.split = self
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(days, forKey: .days)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(startDate, forKey: .startDate)
    }
}
