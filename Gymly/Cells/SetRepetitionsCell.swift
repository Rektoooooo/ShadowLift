//
//  RepetitionCell.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 06.03.2025.
//

import SwiftUI

struct SetRepetitionsCell: View {
    @Binding var reps: Int
    var saveReps: () -> Void

    var body: some View {
        HStack {
            Button {
                reps -= 1
                saveReps()
            } label: {
                HStack {
                    Image(systemName: "minus")
                    Label("", systemImage: "1.square")
                }
            }
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            Button {
                reps -= 5
                saveReps()
            } label: {
                Label("", systemImage: "5.square")
                    .padding(.leading, -15)
            }
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Text("\(reps)")
                .font(.title2)

            Spacer()

            Button {
                reps += 5
                saveReps()
            } label: {
                Label("", systemImage: "5.square")
                    .padding(.trailing, -15)
            }
            .font(.title2)
            .buttonStyle(PlainButtonStyle())

            Button {
                reps += 1
                saveReps()
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
    }
}

