//
//  ContentViewGraph.swift
//  Gymly
//
//  Created by Sebastián Kučera on 24.09.2024.
//

import SwiftUI
import SwiftData

struct ContentViewGraph: View {
    @EnvironmentObject var config: Config
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appearanceManager: AppearanceManager
    var range: TimeRange
    @State private var chartValues: [Double] = []
    @State private var chartMax: Double = 1.0
    @State private var isCalculating = false

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case all = "All"
        var id: String { rawValue }
    }

    // Define muscle groups in the same order as your radar chart
    private let muscleGroups = ["chest", "back", "biceps", "triceps", "shoulders", "quads", "hamstrings", "calves", "glutes", "abs"]

    // Cache to avoid recalculating same data
    @State private var cachedData: [TimeRange: (values: [Double], max: Double)] = [:]

    private var cal: Calendar { Calendar.current }
    private func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
    private func startOfWeek(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? startOfDay(d) }
    private func startOfMonth(_ d: Date) -> Date { cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? startOfDay(d) }

    private func calculateMuscleGroupData() {
        // Check cache first - avoid recalculation
        if let cached = cachedData[range] {
            chartValues = cached.values
            chartMax = cached.max
            return
        }

        // Prevent concurrent calculations
        guard !isCalculating else { return }
        isCalculating = true
        defer { isCalculating = false }

        // Determine the date range to filter - backward looking periods
        let now = Date()
        let fromDate: Date?

        switch range {
        case .day:
            fromDate = startOfDay(now)
        case .week:
            fromDate = cal.date(byAdding: .day, value: -7, to: now)
        case .month:
            fromDate = cal.date(byAdding: .day, value: -30, to: now)
        case .all:
            fromDate = nil
        }

        do {
            // OPTIMIZATION 1: Use predicates to filter at database level (not in-memory)
            // Fetch only completed exercises
            let completedDescriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate<Exercise> { exercise in
                    exercise.done == true && exercise.completedAt != nil
                }
            )

            let completedExercises = try modelContext.fetch(completedDescriptor)

            // OPTIMIZATION 2: Filter by date range in Swift (needed for proper date comparison)
            let filteredExercises: [Exercise]
            if let fromDate = fromDate {
                filteredExercises = completedExercises.filter { exercise in
                    guard let completedAt = exercise.completedAt else { return false }
                    return completedAt >= fromDate
                }
            } else {
                filteredExercises = completedExercises
            }

            #if DEBUG
            print("[Graph] \(range.rawValue): Found \(filteredExercises.count) exercises (from \(completedExercises.count) total completed)")
            #endif

            // OPTIMIZATION 3: Aggregate muscle group counts efficiently
            var muscleGroupCounts = Array(repeating: 0.0, count: muscleGroups.count)

            for exercise in filteredExercises {
                let muscleGroup = exercise.muscleGroup.lowercased()
                if let index = muscleGroups.firstIndex(of: muscleGroup) {
                    muscleGroupCounts[index] += Double(exercise.sets?.count ?? 0)
                }
            }

            // If no data found, show empty chart
            if muscleGroupCounts.allSatisfy({ $0 == 0 }) {
                chartValues = Array(repeating: 0.0, count: muscleGroups.count)
                chartMax = 1.0
                // Cache empty result
                cachedData[range] = (chartValues, chartMax)
                return
            }

            // Use raw values without artificial minimum scaling
            let maxValue = muscleGroupCounts.max() ?? 1.0
            let safeMax = max(maxValue, 1.0)

            // Use actual values - show true ratios
            chartValues = muscleGroupCounts
            chartMax = safeMax

            // OPTIMIZATION 3: Cache the result
            cachedData[range] = (chartValues, chartMax)

        } catch {
            // Fallback to config values or minimal chart
            chartValues = config.graphDataValues.isEmpty ? Array(repeating: 1.0, count: muscleGroups.count) : config.graphDataValues
            chartMax = max(chartValues.max() ?? 1.0, 1.0)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RadarBackground(levels: 3)
                    .stroke(Color.gray, lineWidth: 1)
                    .opacity(0.5)

                // Only show red radar chart if there's actual data
                if chartValues.contains(where: { $0 > 0 }) {
                    RadarChart(values: chartValues, maxValue: chartMax)
                        .fill(appearanceManager.accentColor.color.opacity(0.4))
                        .overlay(
                            RadarChart(values: chartValues, maxValue: chartMax)
                                .stroke(appearanceManager.accentColor.color, lineWidth: 2)
                        )
                }
            }
            .padding(.top, 6)
            .frame(width: 250, height: 250)
            .padding()
        }
        .onAppear {
            calculateMuscleGroupData()
        }
        .onChange(of: range) { _, _ in
            calculateMuscleGroupData()
        }
        .onChange(of: config.graphDataValues) { _, _ in
            // Clear cache when graph data is updated (e.g., after completing workout)
            cachedData.removeAll()
            calculateMuscleGroupData()
        }
    }
}
