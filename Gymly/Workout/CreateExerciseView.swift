//
//  CreateExerciseView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 13.05.2024.
//

import SwiftUI
import SwiftData

struct CreateExerciseView: View {
    
    /// Environment objects for managing state and dismissal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearanceManager: AppearanceManager
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.colorScheme) var scheme
    @State var day: Day
    
    var body: some View {
        NavigationView {
                List {
                    /// Section for entering exercise details
                    Section("Exercise parameters") {
                        LazyVStack {
                            TextField("Name : Bench Press", text: $viewModel.name)
                        }
                        LazyVStack {
                            TextField("Sets : 3", text: $viewModel.sets)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        LazyVStack {
                            TextField("Repetitions : 8-10", text: $viewModel.reps)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        Picker("Muscle Group", selection: $viewModel.muscleGroup) {
                            ForEach(viewModel.muscleGroupNames, id: \.self) { muscleGroup in
                                Text(muscleGroup)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                    
                    /// Section for saving the exercise
                }
                .toolbar {
                    /// Toolbar button to save changes
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                                debugPrint(day.name)
                                Task {
                                    await viewModel.createExercise(to: day)
                                }
                                dismiss()
                        } label: {
                            Text("Create")
                                .foregroundStyle(appearanceManager.accentColor.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .bold()
                                .cornerRadius(10)
                        }
                    }
                }
                .navigationTitle("Create exercise")
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.clear)
            }
        }
}
