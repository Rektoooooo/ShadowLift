//
//  PRHistoryView.swift
//  Gymly
//
//  Created by Claude Code on 26.11.2025.
//

import SwiftUI
import SwiftData

struct PRHistoryView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @StateObject private var prManager = PRManager.shared

    @State private var allPRs: [ExercisePR] = []
    @State private var filteredPRs: [ExercisePR] = []
    @State private var searchText: String = ""
    @State private var selectedMuscleGroup: String = "All"
    @State private var sortOption: SortOption = .byDate
    @State private var isLoading: Bool = true

    enum SortOption: String, CaseIterable {
        case byDate = "By Date"
        case byName = "By Name"
        case byWeight = "By Weight"
    }

    private let muscleGroups = ["All", "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves", "Abs"]

    // Recent PRs (last 30 days)
    private var recentPRs: [ExercisePR] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return allPRs.filter { pr in
            pr.lastUpdated >= thirtyDaysAgo
        }
    }

    // Total PR count
    private var totalPRCount: Int {
        var count = 0
        for pr in allPRs {
            if pr.bestWeight != nil { count += 1 }
            if pr.best1RM != nil { count += 1 }
            if pr.best5RM != nil { count += 1 }
            if pr.best10RM != nil { count += 1 }
            if pr.bestVolume != nil { count += 1 }
        }
        return count
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()

            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Personal Records...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
            } else if allPRs.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.yellow)

                    Text("No Personal Records Yet")
                        .font(.title2)
                        .bold()

                    Text("Complete workouts to start tracking\nyour strength gains!")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            } else {
                List {
                    // Header Stats
                    Section {
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(allPRs.count)")
                                        .font(.title)
                                        .bold()
                                    Text("Exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(totalPRCount)")
                                        .font(.title)
                                        .bold()
                                    Text("Total PRs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    // Recent Achievements (Last 30 Days)
                    if !recentPRs.isEmpty {
                        Section(header: Text("Recent Achievements (Last 30 Days)")) {
                            ForEach(recentPRs.prefix(5)) { pr in
                                NavigationLink(destination: ExercisePRDetailView(exercisePR: pr)) {
                                    RecentPRRow(pr: pr)
                                }
                                .listRowBackground(Color.yellow.opacity(0.05))
                            }
                        }
                    }

                    // Muscle Group Filter
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(muscleGroups, id: \.self) { group in
                                    Button {
                                        selectedMuscleGroup = group
                                        filterPRs()
                                    } label: {
                                        Text(group)
                                            .font(.caption)
                                            .bold()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedMuscleGroup == group ? appearanceManager.accentColor.color : Color.gray.opacity(0.2))
                                            .foregroundStyle(selectedMuscleGroup == group ? .black : .primary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // Sort Options
                    Section {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    // All Personal Records
                    Section(header: Text("All Personal Records (\(filteredPRs.count))")) {
                        ForEach(filteredPRs) { pr in
                            NavigationLink(destination: ExercisePRDetailView(exercisePR: pr)) {
                                PRExerciseCard(pr: pr)
                            }
                            .listRowBackground(Color.black.opacity(0.05))
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search exercises...")
                .onChange(of: searchText) { _, _ in
                    filterPRs()
                }
                .onChange(of: sortOption) { _, _ in
                    filterPRs()
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPRs()
        }
    }

    // MARK: - Helper Functions

    private func loadPRs() async {
        isLoading = true
        allPRs = await prManager.getAllPRs()
        filterPRs()
        isLoading = false

        #if DEBUG
        print("📊 PR HISTORY: Loaded \(allPRs.count) exercises with PRs")
        #endif
    }

    private func filterPRs() {
        var filtered = allPRs

        // Filter by muscle group
        if selectedMuscleGroup != "All" {
            filtered = filtered.filter { $0.muscleGroup.lowercased() == selectedMuscleGroup.lowercased() }
        }

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { pr in
                pr.exerciseName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOption {
        case .byDate:
            filtered.sort { $0.lastUpdated > $1.lastUpdated }
        case .byName:
            filtered.sort { $0.exerciseName < $1.exerciseName }
        case .byWeight:
            filtered.sort { ($0.bestWeight ?? 0) > ($1.bestWeight ?? 0) }
        }

        filteredPRs = filtered
    }
}

// MARK: - Recent PR Row

struct RecentPRRow: View {
    let pr: ExercisePR
    @EnvironmentObject var userProfileManager: UserProfileManager

    private var weightUnit: String {
        userProfileManager.currentProfile?.weightUnit ?? "Kg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise name with muscle group badge
            HStack {
                Text(pr.exerciseName.capitalized)
                    .font(.headline)
                    .bold()

                Spacer()

                Text(pr.muscleGroup)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            // Best PR display
            if let display = pr.displayPR {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.yellow)
                        .font(.caption)

                    let displayWeight = weightUnit == "Kg" ? display.value : display.value * 2.20462262

                    Text("\(String(format: "%.1f", displayWeight)) \(weightUnit) × \(display.reps) reps")
                        .font(.subheadline)
                        .bold()
                }
            }

            // Date
            if let date = pr.bestWeightDate {
                Text(date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - PR Exercise Card

struct PRExerciseCard: View {
    let pr: ExercisePR
    @EnvironmentObject var userProfileManager: UserProfileManager

    private var weightUnit: String {
        userProfileManager.currentProfile?.weightUnit ?? "Kg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name with muscle group badge
            HStack {
                Text(pr.exerciseName.capitalized)
                    .font(.headline)
                    .bold()

                Spacer()

                Text(pr.muscleGroup)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            // Weight PR
            if let weight = pr.bestWeight, let reps = pr.bestWeightReps {
                PRStatRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: "Weight PR",
                    value: "\(String(format: "%.1f", weightUnit == "Kg" ? weight : weight * 2.20462262)) \(weightUnit) × \(reps) reps"
                )
            }

            // 1RM PR
            if let oneRM = pr.best1RM {
                PRStatRow(
                    icon: "trophy.fill",
                    iconColor: .orange,
                    title: "1RM",
                    value: "\(String(format: "%.1f", weightUnit == "Kg" ? oneRM : oneRM * 2.20462262)) \(weightUnit)"
                )
            }

            // Volume PR
            if let volume = pr.bestVolume, let sets = pr.bestVolumeSets {
                PRStatRow(
                    icon: "flame.fill",
                    iconColor: .red,
                    title: "Volume PR",
                    value: "\(String(format: "%.0f", weightUnit == "Kg" ? volume : volume * 2.20462262)) \(weightUnit) in \(sets) sets"
                )
            }

            // Footer
            HStack {
                Text("\(pr.totalWorkouts) workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let date = pr.lastPerformed {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - PR Stat Row

struct PRStatRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.caption)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.caption)
                .bold()
        }
    }
}

#Preview {
    NavigationStack {
        PRHistoryView()
            .environmentObject(Config())
            .environmentObject(AppearanceManager.shared)
            .environmentObject(UserProfileManager.shared)
    }
}
