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
    @State private var splitDay: String = ""
    @State private var name: String = ""
    
    /// Environment objects for dismissing the view and accessing app context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.colorScheme) var scheme

    var body: some View {
        NavigationView {
            Form {
                /// Section for naming the workout split
                Section("Name your split") {
                    TextField("Push, Pull, Legs", text: $name)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                /// Section for selecting split duration
                Section("How many days is your split ?") {
                    TextField("7", text: $splitLength)
                        .keyboardType(.numbersAndPunctuation)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
                /// Section for selecting the starting day in the split
                Section("What is your current day in the split") {
                    TextField("1", text: $splitDay)
                        .keyboardType(.numbersAndPunctuation)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.black.opacity(0.1))
            }
            .toolbar {
                /// Toolbar button to save changes
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.createNewSplit(name: name, numberOfDays: Int(splitLength)!, startDate: Date(), context: context)
                        config.dayInSplit = Int(splitDay)!
                        dismiss()
                    } label: {
                        Text("Start")
                            .foregroundStyle(appearanceManager.accentColor.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .bold()
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Create Split")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
        }
    }
}
