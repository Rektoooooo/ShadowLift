//
//  SetNoteCell.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 06.03.2025.
//

import SwiftUI

struct SetNoteCell: View {
    @Environment(\.modelContext) private var context
    @Binding var note: String
    var setNumber: Int
    var exercise: Exercise

    var body: some View {
        TextField("Set note", text: $note)
            .onSubmit {
                saveNote(note)
            }
    }

    private func saveNote(_ newValue: String) {
        guard let sets = exercise.sets, setNumber < sets.count else { return }
        exercise.sets?[setNumber].note = newValue
        do {
            try context.save()
        } catch {
            debugPrint(error)
        }
    }
}
