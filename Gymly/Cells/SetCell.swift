//
//  SetCellView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 07.03.2025.
//


import SwiftUI

struct SetCell: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    var index: Int
    var set: Exercise.Set
    var config: Config
    var exercise: Exercise
    var setForCalendar: Bool
    var onSetTap: ((Exercise.Set) -> Void)? = nil
    @State private var showEditSheet = false

    // Computed properties to break down complex expressions
    private var weightUnit: String {
        userProfileManager.currentProfile?.weightUnit ?? "Kg"
    }

    private var weightConversionFactor: Double {
        weightUnit == "Kg" ? 1.0 : 2.20462
    }

    var body: some View {
        Section("Set \(index + 1)") {
            Button {
                if setForCalendar == false {
                    print("📱 Tapping set \(index + 1) (ID: \(set.id))")
                    if let onSetTap = onSetTap {
                        // Use callback for external sheet management
                        print("📱 Using callback for set tap")
                        onSetTap(set)
                    } else {
                        // Use internal sheet management
                        print("📱 Using internal sheet - showEditSheet: \(showEditSheet)")
                        showEditSheet = true
                        print("📱 Set showEditSheet to: \(showEditSheet)")
                    }
                }
            } label: {
                HStack {
                    /// Display set details (weight, reps, notes)
                    HStack {
                        if set.bodyWeight {
                            Text("BW  +")
                                .foregroundStyle(appearanceManager.accentColor.color)
                                .bold()
                        }
                        Text("\(Int(round(Double(set.weight) * weightConversionFactor)))")
                            .foregroundStyle(appearanceManager.accentColor.color)
                            .bold()
                        Text("\(weightUnit)")
                            .foregroundStyle(appearanceManager.accentColor.color)
                            .opacity(0.6)
                            .offset(x: -5)
                    }
                    HStack {
                        Text("\(set.reps)")
                            .foregroundStyle(Color.green)
                            .bold()
                        Text("Reps")
                            .foregroundStyle(Color.green)
                            .opacity(0.6)
                            .offset(x: -5)
                    }
                    HStack {
                        if set.failure {
                            Text("F")
                                .foregroundStyle(Color.red)
                                .offset(x: -5)
                        }
                        if set.warmUp {
                            Text("W")
                                .foregroundStyle(Color.orange)
                                .offset(x: -5)
                        }
                        if set.restPause {
                            Text("RP")
                                .foregroundStyle(Color.green)
                                .offset(x: -5)
                        }
                        if set.dropSet {
                            Text("DS")
                                .foregroundStyle(Color.blue)
                                .offset(x: -5)
                        }
                    }
                    Spacer()
                    Text("\(set.time)")
                        .foregroundStyle(Color.white)
                        .opacity(set.time.isEmpty ? 0 : 0.3)
                }
            }

            if !set.note.isEmpty {
                Text(set.note)
                    .foregroundStyle(Color.white)
                    .opacity(0.5)
            }
        }
        .sheet(isPresented: onSetTap == nil ? $showEditSheet : .constant(false)) {
            if onSetTap == nil {
                EditExerciseSetView(
                    targetSet: set,
                    exercise: exercise,
                    unit: .constant(weightUnit)
                )
                .onAppear {
                    print("📱 EditExerciseSetView appeared for set \(index + 1)")
                }
                .onDisappear {
                    print("📱 EditExerciseSetView disappeared for set \(index + 1)")
                }
            }
        }
        .onChange(of: showEditSheet) { oldValue, newValue in
            if onSetTap == nil {
                print("📱 showEditSheet changed to: \(newValue) for set \(index + 1)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listRowBackground(Color.black.opacity(0.1))
    }
}
