//
//  SetupSplitView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 17.10.2024.
//


import SwiftUI

struct SetupSplitView: View {
    
    /// User input state variables
    @State private var splitLength: String = ""
    @State private var name: String = ""
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""

    /// Environment objects for dismissing the view and accessing app context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.colorScheme) var scheme

    private var isValid: Bool {
        !name.isEmpty && Int(splitLength) != nil && (Int(splitLength) ?? 0) > 0 && (Int(splitLength) ?? 0) <= 14
    }

    var body: some View {
        NavigationView {
            Form {
                /// Section for naming the workout split
                Section {
                    TextField("Push, Pull, Legs", text: $name)
                } header: {
                    Text("Name your split")
                } footer: {
                    if !name.isEmpty {
                        Text("✓ Name looks good")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))

                /// Section for selecting split duration
                Section {
                    TextField("7", text: $splitLength)
                        .keyboardType(.numberPad)
                } header: {
                    Text("How many days is your split?")
                } footer: {
                    if let days = Int(splitLength), days > 0, days <= 14 {
                        Text("✓ \(days) day split")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if !splitLength.isEmpty {
                        Text("Please enter a number between 1 and 14")
                            .foregroundColor(.red)
                            .font(.caption)
                    } else {
                        Text("Most common: 3-7 days")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
            }
            .toolbar {
                /// Toolbar button to save changes
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createSplit()
                    } label: {
                        Text("Create")
                            .foregroundStyle(isValid ? appearanceManager.accentColor.color : Color.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isValid ? appearanceManager.accentColor.color.opacity(0.2) : Color.clear)
                            .bold()
                            .cornerRadius(10)
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Create Split")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
            .alert("Invalid Input", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationErrorMessage)
            }
        }
    }

    // MARK: - Helper Functions

    private func createSplit() {
        // Validate inputs
        guard !name.isEmpty else {
            validationErrorMessage = "Please enter a name for your split."
            showValidationError = true
            return
        }

        guard let days = Int(splitLength), days > 0, days <= 14 else {
            validationErrorMessage = "Please enter a valid number of days (1-14)."
            showValidationError = true
            return
        }

        // Create the split
        viewModel.createNewSplit(name: name, numberOfDays: days, startDate: Date(), context: context)

        // Start on day 1 by default
        config.dayInSplit = 1

        dismiss()
    }
}
