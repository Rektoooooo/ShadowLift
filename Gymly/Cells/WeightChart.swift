//
//  WeightChart.swift
//  ShadowLift
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

    // Time range selection
    @State private var selectedTimeRange: TimeRange = .month

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
        case all = "All"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .all: return nil
            }
        }
    }

    private var weightConversionFactor: Double {
        let isKg = userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg"
        return isKg ? 1.0 : 2.20462
    }

    // Filter weight points based on selected time range
    private var filteredWeightPoints: [WeightPoint] {
        guard let daysBack = selectedTimeRange.days else {
            return weightPoints // Show all data
        }

        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
            return weightPoints
        }

        return weightPoints.filter { $0.date >= cutoffDate }
    }

    // Dynamic Y-axis range based on filtered data
    private var yAxisRange: ClosedRange<Double> {
        guard !filteredWeightPoints.isEmpty else {
            let currentWeight = (userProfileManager.currentProfile?.weight ?? 0.0) * weightConversionFactor
            return (currentWeight - 5)...(currentWeight + 5)
        }

        let weights = filteredWeightPoints.map { $0.weight * weightConversionFactor }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 100

        // Add 5% padding to top and bottom for better visualization
        let padding = (maxWeight - minWeight) * 0.1
        let paddingValue = max(padding, 2) // Minimum 2 units padding

        return (minWeight - paddingValue)...(maxWeight + paddingValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Time range selector
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Enhanced chart
            if filteredWeightPoints.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No weight data for this period")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(filteredWeightPoints) { weightPoint in
                        // Area fill with gradient
                        AreaMark(
                            x: .value("Date", weightPoint.date),
                            yStart: .value("Min", yAxisRange.lowerBound),
                            yEnd: .value("Weight", weightPoint.weight * weightConversionFactor)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    appearanceManager.accentColor.color.opacity(0.3),
                                    appearanceManager.accentColor.color.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        // Line mark
                        LineMark(
                            x: .value("Date", weightPoint.date),
                            y: .value("Weight", weightPoint.weight * weightConversionFactor)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(appearanceManager.accentColor.color)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        // Point markers
                        PointMark(
                            x: .value("Date", weightPoint.date),
                            y: .value("Weight", weightPoint.weight * weightConversionFactor)
                        )
                        .foregroundStyle(appearanceManager.accentColor.color)
                        .symbol {
                            Circle()
                                .fill(appearanceManager.accentColor.color)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatAxisDate(date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.secondary.opacity(0.2))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let weight = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.1f", weight))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(.secondary.opacity(0.1))
                        }
                    }
                }
                .preferredColorScheme(.dark)
                .frame(height: 250)
                .animation(.easeInOut(duration: 0.3), value: selectedTimeRange)
            }
        }
    }

    // Format date for X-axis based on time range
    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()

        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "EEE" // Mon, Tue, Wed
        case .month:
            formatter.dateFormat = "d MMM" // 1 Jan, 2 Jan
        case .quarter:
            formatter.dateFormat = "d MMM" // 1 Jan, 15 Jan
        case .all:
            formatter.dateFormat = "MMM yy" // Jan 25, Feb 25
        }

        return formatter.string(from: date)
    }
}

