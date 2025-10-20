//
//  SetEditorView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 20.09.2024.
//

import SwiftUI

struct EditExerciseSetView: View {
    
    /// Environment and observed objects
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var userProfileManager: UserProfileManager

    /// The specific set being edited
    @State var targetSet: Exercise.Set
    @State var exercise: Exercise

    /// Local state for editing
    @State private var weight: Double
    @State private var reps: Int
    @State private var note: String
    @State private var failure: Bool
    @State private var warmup: Bool
    @State private var restPause: Bool
    @State private var dropSet: Bool
    @State private var bodyWeight: Bool

    /// Unit binding from config
    @Binding var unit: String

    /// Initialize the view with the target set data
    init(targetSet: Exercise.Set, exercise: Exercise, unit: Binding<String>) {
        self._targetSet = State(initialValue: targetSet)
        self._exercise = State(initialValue: exercise)
        self._unit = unit

        // Initialize local state with target set data
        self._weight = State(initialValue: targetSet.weight)
        self._reps = State(initialValue: targetSet.reps)
        self._note = State(initialValue: targetSet.note)
        self._failure = State(initialValue: targetSet.failure)
        self._warmup = State(initialValue: targetSet.warmUp)
        self._restPause = State(initialValue: targetSet.restPause)
        self._dropSet = State(initialValue: targetSet.dropSet)
        self._bodyWeight = State(initialValue: targetSet.bodyWeight)
    }

    /// Returns a list of selected set types
    var selectedSetTypes: [String] {
        var selected = [String]()
        if failure { selected.append("Failure") }
        if warmup{ selected.append("Warm Up") }
        if restPause { selected.append("Rest Pause") }
        if dropSet { selected.append("Drop Set") }
        return selected
    }
    @State private var isDropdownOpen = false

    /// Formats displayed weight based on the unit
    var displayedWeight: String {
        let weightInLbs = weight * 2.20462
        return userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" ? "\(Int(round(weight))) kg" : "\(Int(round(weightInLbs))) lbs"
    }


    /// Calculate the display number for this set
    private var setDisplayNumber: Int {
        if let index = (exercise.sets ?? []).firstIndex(where: { $0.id == targetSet.id }) {
            return index + 1
        }
        return 1
    }

    /// Get the actual 0-based index for this set
    private var setIndex: Int {
        if let index = (exercise.sets ?? []).firstIndex(where: { $0.id == targetSet.id }) {
            return index
        }
        return 0
    }

    
    var body: some View {
        NavigationView {
            Form {
                /// Section for setting a note
                Section("Set note") {
                    SetNoteCell(
                        note: $note,
                        setNumber: setDisplayNumber,
                        exercise: exercise
                    )
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                /// Section for selecting set type
                Section(header: Text("Set Type")) {
                    SetTypeCell(
                        failure: $failure,
                        warmup: $warmup,
                        restPause: $restPause,
                        dropSet: $dropSet,
                        setNumber: setIndex,
                        exercise: exercise
                    )
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                /// Section for adjusting weight
                Section("Weight (\(unit))") {
                    SetWeightCell(
                        bodyWeight: $bodyWeight,
                        displayedWeight: displayedWeight,
                        setNumber: setDisplayNumber,
                        exercise: exercise,
                        increaseWeight: increaseWeight,
                        decreaseWeight: decreaseWeight,
                        saveWeight: saveWeight
                    )
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                /// Section for adjusting repetitions
                Section("Repetitions") {
                    HStack {
                        SetRepetitionsCell(
                            reps: $reps,
                            saveReps: saveReps
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
            }
            .scrollDisabled(true)
            .toolbar {
                /// Toolbar button to save changes
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAllChanges()
                    } label: {
                        Text("Done")
                            .foregroundStyle(appearanceManager.accentColor.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .bold()
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Record set")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
        }
    }
    
    /// Get current time for set
    func getCurrentTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "H:mm"
        let currentTime = dateFormatter.string(from: Date())
        return currentTime.lowercased()
    }
    
    /// Increase the weight
    func increaseWeight(by value: Int) {
        if userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" {
            weight += Double(value)
        } else {
            weight += Double(value) / 2.20462 // Convert lbs to kg before adding
        }
    }

    /// Decrease the weight
    func decreaseWeight(by value: Int) {
        if userProfileManager.currentProfile?.weightUnit ?? "Kg" == "Kg" {
            weight -= Double(value)
        } else {
            weight -= Double(value) / 2.20462 // Convert lbs to kg before subtracting
        }
    }

    /// Save all changes to the target set
    private func saveAllChanges() {
        debugPrint("💾 Saving changes to set ID: \(targetSet.id)")

        // Validate that the target set still exists in the exercise
        guard let setIndex = (exercise.sets ?? []).firstIndex(where: { $0.id == targetSet.id }) else {
            debugPrint("❌ Error: Target set no longer exists in exercise")
            dismiss()
            return
        }

        // Validate input data
        guard weight >= 0, reps >= 0 else {
            debugPrint("❌ Error: Invalid weight (\(weight)) or reps (\(reps))")
            return
        }

        debugPrint("✅ Set validation passed - found at index \(setIndex)")

        // Update the target set directly
        targetSet.weight = weight
        targetSet.reps = reps
        targetSet.failure = failure
        targetSet.warmUp = warmup
        targetSet.restPause = restPause
        targetSet.dropSet = dropSet
        targetSet.time = getCurrentTime()
        targetSet.note = note
        targetSet.bodyWeight = bodyWeight

        do {
            try context.save()
            debugPrint("✅ Successfully saved set changes - Weight: \(weight), Reps: \(reps)")
        } catch {
            debugPrint("❌ Error saving set changes: \(error)")
        }

        dismiss()
    }

    /// Save weight to context (for incremental updates)
    private func saveWeight() {
        // Validate that the target set still exists
        guard (exercise.sets ?? []).contains(where: { $0.id == targetSet.id }) else {
            debugPrint("❌ Error: Cannot save weight - target set no longer exists")
            return
        }

        guard weight >= 0 else {
            debugPrint("❌ Error: Invalid weight value: \(weight)")
            return
        }

        targetSet.weight = weight
        do {
            try context.save()
            debugPrint("💾 Weight saved: \(weight) kg")
        } catch {
            debugPrint("❌ Error saving weight: \(error)")
        }
    }

    /// Save reps to context (for incremental updates)
    private func saveReps() {
        // Validate that the target set still exists
        guard (exercise.sets ?? []).contains(where: { $0.id == targetSet.id }) else {
            debugPrint("❌ Error: Cannot save reps - target set no longer exists")
            return
        }

        guard reps >= 0 else {
            debugPrint("❌ Error: Invalid reps value: \(reps)")
            return
        }

        targetSet.reps = reps
        do {
            try context.save()
            debugPrint("💾 Reps saved: \(reps)")
        } catch {
            debugPrint("❌ Error saving reps: \(error)")
        }
    }
}
