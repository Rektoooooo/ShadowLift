//
//  WeightSelectorCell.swift
//  Gymly
//
//  Created by Sebastián Kučera on 06.03.2025.
//

import SwiftUI

struct SetWeightCell: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Binding var bodyWeight: Bool
    var displayedWeight: String
    var setNumber: Int
    var exercise: Exercise
    var increaseWeight: (Int) -> Void
    var decreaseWeight: (Int) -> Void
    var saveWeight: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button {
                    decreaseWeight(1)
                    saveWeight()
                } label: {
                    HStack {
                        Image(systemName: "minus")
                        Label("", systemImage: "1.square")
                    }
                }
                .font(.title2)
                .buttonStyle(PlainButtonStyle())

                Button {
                    decreaseWeight(5)
                    saveWeight()
                } label: {
                    Label("", systemImage: "5.square")
                        .padding(.leading, -15)
                }
                .font(.title2)
                .buttonStyle(PlainButtonStyle())

                Spacer()
                Text("\(displayedWeight)") // Ensuring formatted display
                    .font(.title2)
                Spacer()

                Button {
                    increaseWeight(5)
                    saveWeight()
                } label: {
                    Label("", systemImage: "5.square")
                        .padding(.trailing, -15)
                }
                .font(.title2)
                .buttonStyle(PlainButtonStyle())

                Button {
                    increaseWeight(1)
                    saveWeight()
                } label: {
                    HStack {
                        Label("", systemImage: "1.square")
                        Image(systemName: "plus")
                            .padding(.leading, -20)
                    }
                }
                .font(.title2)
                .buttonStyle(PlainButtonStyle())
            }
            HStack {
                Toggle("Body Weight", isOn: $bodyWeight)
                    .toggleStyle(CheckToggleStyle())
                    .onChange(of: bodyWeight) { _, newValue in
                        guard let sets = exercise.sets, setNumber < sets.count else { return }
                        exercise.sets?[setNumber].bodyWeight = newValue
                        do {
                            try context.save()
                        } catch {
                            debugPrint(error)
                        }
                    }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
    /// Toggles set type and saves changes
    struct CheckToggleStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                Label {
                    configuration.label
                } icon: {
                    Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(configuration.isOn ? AppearanceManager.shared.accentColor.color : .secondary)
                        .accessibility(label: Text(configuration.isOn ? "Checked" : "Unchecked"))
                        .imageScale(.large)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

