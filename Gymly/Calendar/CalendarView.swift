//
//  CalendarView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 30.08.2024.
//

import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var currentMonth = Date()
    @EnvironmentObject var config: Config
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    let calendar = Calendar.current
    let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                GeometryReader { geometry in
                    ScrollView {
                        VStack {
                            HStack {
                                Button(action: {
                                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                                }) {
                                    Image(systemName: "chevron.left")
                                        .bold()
                                        .foregroundStyle(appearanceManager.accentColor.color)
                                }
                                Spacer()
                                Text(viewModel.monthAndYearString(from: currentMonth))
                                    .font(.title)
                                Spacer()
                                Button(action: {
                                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                                }) {
                                    Image(systemName: "chevron.right")
                                        .bold()
                                        .foregroundStyle(appearanceManager.accentColor.color)
                                }
                            }
                            .padding()

                        VStack {
                            HStack {
                                ForEach(daysOfWeek, id: \.self) { day in
                                    Spacer()
                                    Text(day)
                                        .frame(width: geometry.size.width * 0.085)
                                        .bold()
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                            .padding(5)
                            .background(appearanceManager.accentColor.color)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(appearanceManager.accentColor.color, lineWidth: 4)
                            )
                            .padding(.bottom, 10)

                            let daysInMonth = viewModel.getDaysInMonth(for: currentMonth)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                                ForEach(daysInMonth.indices, id: \.self) { index in
                                    let day = daysInMonth[index]

                                    if day.day != 0 {
                                        if viewModel.formattedDateString(from: day.date) == viewModel.formattedDateString(from: Date()) {
                                            NavigationLink("\(day.day)") {
                                                CalendarDayView(viewModel: viewModel, date: viewModel.formattedDateString(from: day.date))
                                            }
                                            .frame(width: geometry.size.width * 0.085, height: geometry.size.width * 0.085)
                                            .font(.system(size: 22))
                                            .foregroundColor(Color.white)
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 2)
                                            .background(appearanceManager.accentColor.color)
                                            .cornerRadius(25)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 25)
                                                    .stroke(appearanceManager.accentColor.color, lineWidth: 4)
                                            )
                                            .fontWeight(.bold)
                                            .padding(3)
                                        } else {
                                            ZStack {
                                                let dayDateString = viewModel.formattedDateString(from: day.date)

                                                NavigationLink("\(day.day)") {
                                                    CalendarDayView(viewModel: viewModel, date: dayDateString)
                                                }
                                                .frame(width: geometry.size.width * 0.085, height: geometry.size.width * 0.085)
                                                .font(.system(size: 22))
                                                .foregroundColor(Color.white)
                                                .padding(3)
                                                .onAppear {
                                                    // Only log for today's date to reduce noise
                                                    if Calendar.current.isDate(day.date, inSameDayAs: Date()) {
                                                        print("🔍 CALENDAR: Today's date is '\(dayDateString)'")
                                                        print("🔍 CALENDAR: daysRecorded contains: \(config.daysRecorded)")
                                                        print("🔍 CALENDAR: Contains today? \(config.daysRecorded.contains(dayDateString))")
                                                    }
                                                }

                                                if config.daysRecorded.contains(dayDateString) || viewModel.hasDayStorage(for: dayDateString) {
                                                    Circle()
                                                        .frame(width: 10, height: 10)
                                                        .foregroundColor(appearanceManager.accentColor.color)
                                                        .offset(x: 0, y: 20)
                                                }
                                            }
                                        }
                                    } else {
                                        /// Empty day so the calendar is alligned right
                                        Text("")
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 6)
                                    }
                                }
                            }
                            .padding(2)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .listRowBackground(Color.black.opacity(0.1))

                            // Progress Photos Timeline
                            if config.isPremium {
                                ProgressPhotoTimelineView()
                                    .frame(minHeight: 400)
                            } else {
                                ProgressPhotosLockedView()
                                    .frame(minHeight: 400)
                            }
                        }
                        .frame(maxWidth: geometry.size.width * 0.92)
                        }
                    }
                    .navigationTitle("Calendar")
                    .onAppear() {
                        currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? currentMonth
                        // Clean up any duplicate dates in the daysRecorded array
                        viewModel.cleanupDuplicateDates()
                    }
                }
            }
        }
    }
}

struct DayCalendar: Hashable {
    var id = UUID()
    let day: Int
    let date: Date
}

