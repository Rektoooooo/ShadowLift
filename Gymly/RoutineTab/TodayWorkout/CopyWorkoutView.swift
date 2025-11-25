//
//  CopyWorkout.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 12.09.2024.
//

import SwiftUI
import SwiftData

struct CopyWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WorkoutViewModel
    @State var day:Day
    @State var availableDays: [Day] = []
    @State var selected: Day = Day(name: "", dayOfSplit: 0, date: "")
    
    // TODO: Make copying exercises possible
    var body: some View {
        NavigationView {
            List {
                Picker("Chose workout", selection: $selected) {
                    ForEach(availableDays.sorted(by: {$0.dayOfSplit < $1.dayOfSplit}), id: \.self) {  day in
                        Text(day.name)
                    }
                    .pickerStyle(.inline)
                }
                Button("Copy \(selected.name)") {
                    dismiss()
                    viewModel.copyWorkout(from: selected, to: day)
                }
            }
            .offset(y: -30)
            .onAppear {
                    availableDays = viewModel.getActiveSplitDays()
                    selected = availableDays.first ?? Day(name: "", dayOfSplit: 0, date: "")
            }
            .navigationTitle("Copy workout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

