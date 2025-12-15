//
//  SplitDetailView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 27.02.2025.
//

import SwiftUI

struct SplitDetailView: View {
    @State var split: Split
    @State var days: [Day] = []
    @State var shareSplit: Bool = false
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var scheme
    @Environment(\.modelContext) var context
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State private var shareURL: URL?
    @State private var editingSplitName: Bool = false
    @State private var splitName: String = ""
    @State private var showAddDay: Bool = false
    @State private var newDayName: String = ""
    @State private var isReorderingDays: Bool = false
    @State private var editModeDays: EditMode = .inactive
    @State private var reorderingBufferDays: [Day] = []
    private func orderNumber(for day: Day) -> Int {
        if let idx = reorderingBufferDays.firstIndex(where: { $0.id == day.id }) {
            return idx + 1
        }
        return 0
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            List {
                /// Show all days in a split and display them in a list
                if isReorderingDays {
                    // Reorder mode: operate on buffer
                    ForEach(reorderingBufferDays, id: \.id) { day in
                        HStack {
                            Text("\(orderNumber(for: day))")
                                .foregroundStyle(appearanceManager.accentColor.color)
                                .bold()
                            Text(day.name)
                            Spacer()
                            Text("\(day.exercises?.count ?? 0) exercises")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .listRowBackground(Color.black.opacity(0.1))
                    }
                    .onMove { indices, newOffset in
                        reorderingBufferDays.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } else {
                    // Normal mode
                    ForEach(days.sorted(by: { $0.dayOfSplit < $1.dayOfSplit })) { day in
                    NavigationLink(destination: ShowSplitDayView(viewModel: viewModel, day: day, split: split)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day \(day.dayOfSplit) - \(day.name)")
                                .font(.headline)

                            HStack {
                                Text("\(day.exercises?.count ?? 0) exercises")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if day.isRestDay {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text("Rest Day")
                                        .font(.caption)
                                        .foregroundColor(appearanceManager.accentColor.color)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            duplicateDay(day)
                        } label: {
                            Label("Duplicate Day", systemImage: "doc.on.doc")
                        }

                        Button {
                            toggleRestDay(day)
                        } label: {
                            Label(
                                day.isRestDay ? "Mark as Workout Day" : "Mark as Rest Day",
                                systemImage: day.isRestDay ? "figure.run" : "moon.zzz.fill"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("Delete Day", systemImage: "trash")
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                    }
                }
            }
            .environment(\.editMode, $editModeDays)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isReorderingDays {
                        // Show Done button in reorder mode
                        Button {
                            // Commit: write buffer back to split.days and persist
                            split.days = reorderingBufferDays
                            // Update day numbers based on new order
                            for (idx, day) in reorderingBufferDays.enumerated() {
                                day.dayOfSplit = idx + 1
                            }
                            isReorderingDays = false
                            editModeDays = .inactive
                            do {
                                try context.save()
                                days = split.days ?? []
                                debugLog("✅ Days reordered and saved")
                            } catch {
                                debugLog("❌ Failed to save reordered days: \(error)")
                            }
                        } label: {
                            Text("Done")
                                .bold()
                        }
                    } else {
                        // Normal mode: Add Day + Menu

                        // Add Day button (primary action)
                        Button {
                            newDayName = ""
                            showAddDay = true
                        } label: {
                            Label("Add Day", systemImage: "plus.circle")
                        }

                        // More menu (secondary actions)
                        Menu {
                            Button {
                                splitName = split.name
                                editingSplitName = true
                            } label: {
                                Label("Edit Split Name", systemImage: "pencil")
                            }

                            Divider()

                            Button {
                                // Enter reorder mode
                                reorderingBufferDays = days.sorted(by: { $0.dayOfSplit < $1.dayOfSplit })
                                isReorderingDays = true
                                editModeDays = .active
                            } label: {
                                Label("Reorder Days", systemImage: "arrow.up.arrow.down")
                            }

                            Divider()

                            Button {
                                Task {
                                    do {
                                        let shareLink = try await CloudKitManager.shared.shareSplit(split)
                                        await MainActor.run {
                                            viewModel.editPlan = false
                                            shareURL = shareLink
                                            presentShareSheet(url: shareLink)
                                        }
                                    } catch {
                                        debugLog("❌ Failed to share split: \(error)")
                                        // Fallback to file export if CloudKit fails
                                        if let url = viewModel.exportSplit(split) {
                                            viewModel.editPlan = false
                                            shareURL = url
                                            presentShareSheet(url: url)
                                        }
                                    }
                                }
                            } label: {
                                Label("Share Split", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Edit Split Name", isPresented: $editingSplitName) {
                TextField("Split name", text: $splitName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    saveSplitName()
                }
            } message: {
                Text("Enter a new name for this split")
            }
            .alert("Add New Day", isPresented: $showAddDay) {
                TextField("Day name (e.g., Push, Pull, Legs)", text: $newDayName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    addNewDay()
                }
            } message: {
                Text("Enter a name for the new workout day")
            }
            .task {
                days = split.days ?? []
            }
            .navigationTitle(split.name)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
        }
    }
    
    func presentShareSheet(url: URL) {
        DispatchQueue.main.async {
            // Check if this is a web URL (https) or file URL (file)
            let isWebURL = url.scheme == "https" || url.scheme == "http"

            if !isWebURL {
                // For file URLs, ensure the file exists
                guard FileManager.default.fileExists(atPath: url.path) else {
                    debugLog("File does not exist at path: \(url.path)")
                    return
                }

                // Ensure the file is readable by setting explicit permissions
                do {
                    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
                } catch {
                    debugLog("Failed to set file permissions: \(error)")
                    return
                }

                // Verify file is readable
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    debugLog("File is not readable at path: \(url.path)")
                    return
                }
            }

            // Ensure the UIActivityViewController isn't already presented
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if rootVC.presentedViewController != nil {
                    rootVC.dismiss(animated: false) {
                        self.presentActivityController(url: url, rootVC: rootVC)
                    }
                } else {
                    self.presentActivityController(url: url, rootVC: rootVC)
                }
            }
        }
    }

    private func presentActivityController(url: URL, rootVC: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        rootVC.present(activityVC, animated: true, completion: nil)
    }

    // MARK: - Helper Functions

    private func saveSplitName() {
        let trimmedName = splitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        split.name = trimmedName
        do {
            try context.save()
            debugLog("✅ Split name updated: \(trimmedName)")
        } catch {
            debugLog("❌ Failed to save split name: \(error)")
        }
    }

    private func deleteDay(_ day: Day) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        split.days?.removeAll { $0.id == day.id }
        context.delete(day)

        do {
            try context.save()
            days = split.days ?? []
            debugLog("✅ Day deleted: \(day.name)")
        } catch {
            debugLog("❌ Failed to delete day: \(error)")
        }
    }

    private func duplicateDay(_ day: Day) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Create new day with incremented number
        let newDayNumber = (split.days?.map { $0.dayOfSplit }.max() ?? 0) + 1
        let newDay = Day(
            name: day.name + " (Copy)",
            dayOfSplit: newDayNumber,
            exercises: [],
            date: ""
        )
        newDay.isRestDay = day.isRestDay

        // Deep copy exercises
        if let exercises = day.exercises {
            newDay.exercises = exercises.map { exercise in
                exercise.copy()
            }
        }

        if split.days == nil {
            split.days = []
        }
        split.days?.append(newDay)
        context.insert(newDay)

        do {
            try context.save()
            days = split.days ?? []
            debugLog("✅ Day duplicated: \(day.name)")
        } catch {
            debugLog("❌ Failed to duplicate day: \(error)")
        }
    }

    private func toggleRestDay(_ day: Day) {
        day.isRestDay.toggle()
        do {
            try context.save()
            days = split.days ?? []
            debugLog("✅ Rest day toggled for: \(day.name)")
        } catch {
            debugLog("❌ Failed to toggle rest day: \(error)")
        }
    }

    private func addNewDay() {
        let trimmedName = newDayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Create new day with next day number
        let newDayNumber = (split.days?.map { $0.dayOfSplit }.max() ?? 0) + 1
        let newDay = Day(
            name: trimmedName,
            dayOfSplit: newDayNumber,
            exercises: [],
            date: ""
        )

        if split.days == nil {
            split.days = []
        }
        split.days?.append(newDay)
        context.insert(newDay)

        do {
            try context.save()
            days = split.days ?? []
            debugLog("✅ Day added: \(trimmedName) (Day \(newDayNumber))")
        } catch {
            debugLog("❌ Failed to add day: \(error)")
        }
    }
}
