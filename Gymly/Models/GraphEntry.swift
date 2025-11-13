//
//  WeightPoint.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 26.03.2025.
//
import Foundation
import SwiftData

@Model
class GraphEntry {
    var date: Date
    var data: [Double]
    
    init(date: Date, data: [Double]) {
        self.date = date
        self.data = data
    }
}
