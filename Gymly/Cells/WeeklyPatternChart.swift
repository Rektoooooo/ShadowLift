//
//  WeeklyPatternChart.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 03.11.2025.
//

import SwiftUI
import SwiftData
import Charts

struct WeeklyPatternChart: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.modelContext) var context

    @Query var allWorkouts: [DayStorage]

    private var weeklyPattern: [WeekdayPattern] {
        calculateWeeklyPattern()
    }

    private var mostActiveDay: String {
        weeklyPattern.max(by: { $0.percentage < $1.percentage })?.dayName ?? "Monday"
    }

    private var leastActiveDay: String {
        weeklyPattern.min(by: { $0.percentage < $1.percentage })?.dayName ?? "Sunday"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart
            Chart(weeklyPattern) { pattern in
                BarMark(
                    x: .value("Day", pattern.dayAbbreviation),
                    y: .value("Workouts", pattern.percentage)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            appearanceManager.accentColor.color,
                            appearanceManager.accentColor.color.opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    if let percentage = value.as(Int.self) {
                        AxisValueLabel {
                            Text("\(percentage)%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(.secondary.opacity(0.2))
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    if let day = value.as(String.self) {
                        AxisValueLabel {
                            Text(day)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 150)

            // Insights
            if !weeklyPattern.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Most active: \(mostActiveDay)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Least active: \(leastActiveDay)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func calculateWeeklyPattern() -> [WeekdayPattern] {
        let calendar = Calendar.current
        var weekdayCounts: [Int: Int] = [:] // weekday (1-7) -> count
        var weekdayTotals: [Int: Int] = [:] // weekday (1-7) -> total possible

        // Get date range (last 90 days or all workouts if less)
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        // Count workouts per weekday
        for workout in allWorkouts {
            if let date = parseDate(workout.date) {
                if date >= startDate && date <= endDate {
                    let weekday = calendar.component(.weekday, from: date)
                    weekdayCounts[weekday, default: 0] += 1
                }
            }
        }

        // Calculate total possible days for each weekday in the range
        var currentDate = startDate
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            weekdayTotals[weekday, default: 0] += 1
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Create pattern array (Monday = 1, Sunday = 7 in ISO calendar)
        let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let weekdayFullNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        return (0..<7).map { index in
            // Convert to calendar weekday (Sunday = 1, Monday = 2, etc.)
            let calendarWeekday = (index + 2) % 7 + 1 // Map Mon-Sun (0-6) to calendar weekday (2-1)
            let actualWeekday = calendarWeekday == 1 ? 1 : calendarWeekday // Handle Sunday

            let count = weekdayCounts[actualWeekday] ?? 0
            let total = weekdayTotals[actualWeekday] ?? 1
            let percentage = total > 0 ? Double(count) / Double(total) * 100 : 0

            return WeekdayPattern(
                dayAbbreviation: weekdayNames[index],
                dayName: weekdayFullNames[index],
                workoutCount: count,
                totalDays: total,
                percentage: percentage
            )
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

struct WeekdayPattern: Identifiable {
    let id = UUID()
    let dayAbbreviation: String
    let dayName: String
    let workoutCount: Int
    let totalDays: Int
    let percentage: Double
}

#Preview {
    WeeklyPatternChart(viewModel: WorkoutViewModel(config: Config(), context: ModelContext(try! ModelContainer(for: Split.self))))
        .environmentObject(AppearanceManager())
        .frame(height: 220)
        .padding()
}
