//
//  EditExerciseView.swift
//  ShadowLift
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
    @State private var muscleGroup: String = ""
    @State private var muscleGroups: [String] = []
    @State private var showValidationError = false
    @Environment(\.colorScheme) var scheme

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !repetitions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                VStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)
                } header: {
                    Text("Exercise Name")
                } footer: {
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("✓ Name looks good")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if name.isEmpty {
                        Text("Required field")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Text("Name cannot be empty or just spaces")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))

                Section {
                    TextField("e.g., 8-12, 5x5, AMRAP", text: $repetitions)
                } header: {
                    Text("Rep Goal")
                } footer: {
                    if !repetitions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("✓ Rep goal set")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Text("Examples: 8-12, 5x5, 20, AMRAP")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))

                Section {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Muscle Group")
                } footer: {
                    Text("Used for organizing exercises in your workout")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))

                Section {
                    Button {
                        saveExercise()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                    .foregroundStyle(isValid ? appearanceManager.accentColor.color : Color.secondary)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
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
        }
    }

    // MARK: - Helper Functions

    private func saveExercise() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReps = repetitions.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedReps.isEmpty else {
            showValidationError = true
            return
        }

        // Update exercise properties
        exercise.name = trimmedName
        exercise.repGoal = trimmedReps
        exercise.muscleGroup = muscleGroup

        // Save to context
        do {
            try context.save()
            debugLog("✅ Exercise updated: \(exercise.name)")

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            dismiss()
        } catch {
            debugLog("❌ Failed to save exercise: \(error)")
            showValidationError = true
        }
    }
}
