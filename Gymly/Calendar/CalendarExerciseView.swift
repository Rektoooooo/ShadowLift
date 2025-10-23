//
//  CalendarExerciseView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 01.10.2024.
//

import SwiftUI
import SwiftData

struct CalendarExerciseView: View {

    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var userProfileManager: UserProfileManager

    @State var exercise: Exercise
    @State private var isOn = false
    @State var showSheet = false
    @State var weight: Double = 0.0
    @State var reps: Int = 0
    @State var failure: Bool = false
    @State var warmUp: Bool = false
    @State var restPause: Bool = false
    @State var dropSet: Bool = false
    @State var bodyWeight: Bool = false
    @State var setNumber: Int = 0
    @State var note: String = ""

    /// Converts weight to correct unit (Kg/Lbs)
    var convertedWeight: Double {
        if userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" {
            return weight
        } else {
            return weight * 2.20462
        }
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            VStack {
            HStack {
                Text("\(exercise.sets?.count ?? 0) Sets")
                    .foregroundStyle(appearanceManager.accentColor.color)
                    .padding()
                    .bold()
                Spacer()
                Text("\(exercise.repGoal) Reps")
                    .foregroundStyle(appearanceManager.accentColor.color)
                    .padding()
                    .bold()
            }
            Form {
                /// List of exercise sets
                ForEach(Array((exercise.sets ?? []).sorted(by: { $0.createdAt < $1.createdAt }).enumerated()), id: \.element.id) { index, set in
                    SetCell(
                        viewModel: viewModel,
                        index: index,
                        set: set,
                        config: config,
                        exercise: exercise,
                        setForCalendar: true
                    )
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("\(exercise.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Empty func so i can reuse the SetCell
    func loadSetData(set: Exercise.Set, shouldOpenSheet: Bool = false) {}
    
    func refreshExercise() {
        Task {
            exercise = await viewModel.fetchExercise(id: exercise.id)
        }
    }
}

