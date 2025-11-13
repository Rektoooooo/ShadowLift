//
//  SetTypeCell.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 06.03.2025.
//

import SwiftUI

struct SetTypeCell: View {
    @Binding var failure: Bool
    @Binding var warmup: Bool
    @Binding var restPause: Bool
    @Binding var dropSet: Bool
    var setNumber: Int
    var exercise: Exercise
    
    var body: some View {
        Menu {
            ToggleButton(label: "Failure", isOn: $failure)
            ToggleButton(label: "Warm Up", isOn: $warmup)
            ToggleButton(label: "Rest Pause", isOn: $restPause)
            ToggleButton(label: "Drop Set", isOn: $dropSet)
        } label: {
            HStack {
                Text("Set Type:")
                Spacer()
                Text(selectedSetTypes().isEmpty ? "None" : selectedSetTypes().joined(separator: ", "))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
    
    /// Returns a list of selected set types
    private func selectedSetTypes() -> [String] {
        var types = [String]()
        if failure { types.append("Failure") }
        if warmup { types.append("Warm Up") }
        if restPause { types.append("Rest Pause") }
        if dropSet { types.append("Drop Set") }
        return types
    }
    
    /// Reusable button for toggling set types
    private func ToggleButton(label: String, isOn: Binding<Bool>) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
        }) {
            HStack {
                Text(label)
                Spacer()
                if isOn.wrappedValue { Image(systemName: "checkmark") }
            }
        }
    }
}

