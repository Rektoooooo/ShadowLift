//
//  EditExerciseView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 02.09.2025.
//

import SwiftUI

struct EditExerciseView: View {
    /// Environment and observed objects
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State var exercise: Exercise
    @State private var name: String = ""
    @State private var repetitions: String = ""
    @State private var order: String = ""
    @State private var muscleGroup: String = ""
    @State private var muscleGroups: [String] = []
    @Environment(\.colorScheme) var scheme

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                VStack {
            Form {
                Section("Edit name") {
                    TextField("Name", text: $name)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                Section("Edit repetitions") {
                    TextField("Repetitions", text: $repetitions)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                Section("Edit order") {
                    TextField("Order", text: $order)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                Section("Edit muslce group") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                Section("") {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty { exercise.name = trimmedName }
                        exercise.repGoal = repetitions
                        exercise.muscleGroup = muscleGroup
                        exercise.exerciseOrder = Int(order) ?? 0
                        try? context.save()
                        dismiss()
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                .foregroundStyle(appearanceManager.accentColor.color)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            .navigationTitle("Edit \(exercise.name)")
                }
            }
        }
        .onAppear {
            self.name = exercise.name
            self.repetitions = exercise.repGoal
            self.muscleGroups = viewModel.muscleGroupNames
            self.muscleGroup = exercise.muscleGroup
            self.order = String(exercise.exerciseOrder)
        }
    }
}
