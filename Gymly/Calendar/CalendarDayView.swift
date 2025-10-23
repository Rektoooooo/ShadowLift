//
//  CalendarDayView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 30.09.2024.
//


import SwiftUI
import Foundation
import SwiftData

struct CalendarDayView: View {
    /// Environment and observed objects
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.colorScheme) var scheme

    /// Bindings for exercise data
    @State var date: String
    @State var day: Day = Day(name: "", dayOfSplit: 0, exercises: [], date: "")
    @State var muscleGroups:[MuscleGroup] = []

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            if muscleGroups.isEmpty {
                /// If there is no recorded day display text
                VStack {
                    Spacer()
                    Text("Workout not recorded for the date")
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            /// Else display the day name and all the exercises
            VStack {
                HStack {
                    Text(day.name)
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                    Spacer()
                }
                List {
                    ForEach(muscleGroups) { group in
                        if !group.exercises.isEmpty {
                            Section(header: Text(group.name)) {
                                ForEach(group.exercises, id: \.id) { exercise in
                                    NavigationLink(destination: CalendarExerciseView(viewModel: WorkoutViewModel(config: config, context: context), exercise: exercise)) {
                                        Text(exercise.name)
                                    }
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .listRowBackground(Color.black.opacity(0.1))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.clear)
                .id(UUID())
                .navigationTitle("\(date)")
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    await refreshMuscleGroups()
                    debugPrint(date)
                }
            }
        }
    }
    
    func refreshMuscleGroups() async {
        debugPrint("🔍 CalendarDayView: Fetching data for date '\(date)'")
        day = await viewModel.fetchCalendarDay(date: date)
        debugPrint("📋 CalendarDayView: Day name: '\(day.name)', exercises count: \(day.exercises?.count ?? 0)")

        muscleGroups.removeAll() /// Clear array to trigger UI update
        muscleGroups = await viewModel.sortDataForCalendar(date: date) /// Reassign updated data
        debugPrint("💪 CalendarDayView: Found \(muscleGroups.count) muscle groups with exercises")
    }
}
