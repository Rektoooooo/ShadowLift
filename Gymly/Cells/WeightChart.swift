//
//  WeightChart.swift
//  Gymly
//
//  Created by Sebastián Kučera on 26.03.2025.
//

import SwiftUI
import Charts
import SwiftData

struct WeightChart: View {
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Query(sort: \WeightPoint.date, order: .forward) var weightPoints: [WeightPoint]

    private var weightConversionFactor: Double {
        let isKg = userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg"
        return isKg ? 1.0 : 2.20462
    }

    var body: some View {
        Chart {
            ForEach(weightPoints) { weightPoint in
                LineMark(
                    x: .value("Date", weightPoint.date),
                    y: .value("Weight", weightPoint.weight * weightConversionFactor)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(appearanceManager.accentColor.color)
                .symbol {
                    Circle()
                        .fill(appearanceManager.accentColor.color)
                        .frame(width: 10, height: 10)
                }

                PointMark(
                    x: .value("Date", weightPoint.date),
                    y: .value("Weight", weightPoint.weight * weightConversionFactor)
                )
                .annotation(position: .top) {
                    Text(String(format: "%.1f", weightPoint.weight * weightConversionFactor))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .chartYScale(domain: {
            let currentWeight = (userProfileManager.currentProfile?.weight ?? 0.0) * weightConversionFactor
            return (currentWeight - 10)...(currentWeight + 10)
        }())
        .preferredColorScheme(.dark)
        .frame(width: 300, height: 150)
    }
}

