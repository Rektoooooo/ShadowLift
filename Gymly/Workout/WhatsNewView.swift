//
//  WhatsNewView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 25.03.2025.
//

import SwiftUI

struct WhatsNewView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section("New features") {
                    Label("Calculate your bmi with the bmi view", systemImage: "arrow.clockwise")
                }
                Section("Fixes") {
                    Label("Fixed some smaller bugs", systemImage: "hammer.fill")
                }
                Section("") {
                    Button("Got it!") {
                        WhatsNewManager.markAsSeen()
                        isPresented = false
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("What's new in build \(WhatsNewManager.currentBuild)")
        }
    }
}

#Preview {
    @Previewable @State var show = true
    return WhatsNewView(isPresented: $show)
}
