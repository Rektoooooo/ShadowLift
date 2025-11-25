//
//  WorkoutSkeletonView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 25.11.2024.
//

import SwiftUI

struct WorkoutSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
                // Skeleton for day title (e.g., "Lower 2")
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 180, height: 44)
                    Spacer()
                }
                .padding(.leading)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Skeleton for exercise list
                List {
                    // First muscle group section
                    Section {
                        ForEach(0..<2, id: \.self) { index in
                            skeletonExerciseRow
                        }
                    } header: {
                        skeletonSectionHeader
                    }

                    // Second muscle group section
                    Section {
                        skeletonExerciseRow
                    } header: {
                        skeletonSectionHeader
                    }

                    // Third muscle group section
                    Section {
                        skeletonExerciseRow
                    } header: {
                        skeletonSectionHeader
                    }

                    // Fourth muscle group section
                    Section {
                        skeletonExerciseRow
                    } header: {
                        skeletonSectionHeader
                    }

                    // Workout done button skeleton
                    Section {
                        HStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 140, height: 20)
                            Spacer()
                        }
                        .listRowBackground(Color.black.opacity(0.1))
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listStyle(.insetGrouped)
        }
        .redacted(reason: .placeholder)
    }

    // Skeleton for section header (muscle group name)
    private var skeletonSectionHeader: some View {
        HStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 100, height: 18)
            Spacer()
        }
    }

    // Skeleton for exercise row (number + name + chevron)
    private var skeletonExerciseRow: some View {
        HStack(spacing: 12) {
            // Exercise number
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 15, height: 20)

            // Exercise name
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 140, height: 20)

            Spacer()

            // Chevron placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 8, height: 14)
        }
        .listRowBackground(Color.black.opacity(0.1))
    }
}

#Preview {
    ZStack {
        FloatingClouds(theme: CloudsTheme.graphite(.dark))
            .ignoresSafeArea()

        WorkoutSkeletonView()
    }
}
