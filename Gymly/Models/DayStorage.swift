//
//  DayStorage.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 29.08.2024.
//

import Foundation
import SwiftData

@Model
class DayStorage {
    var id: UUID = UUID()
    var dayId: UUID = UUID()
    var dayName: String = ""
    var dayOfSplit: Int = 0
    var date: String = ""

    init(id: UUID, day: Day, date: String) {
        self.id = id
        self.dayId = day.id
        self.dayName = day.name
        self.dayOfSplit = day.dayOfSplit
        self.date = date
    }

    init(id: UUID, dayId: UUID, dayName: String, dayOfSplit: Int, date: String) {
        self.id = id
        self.dayId = dayId
        self.dayName = dayName
        self.dayOfSplit = dayOfSplit
        self.date = date
    }
}
