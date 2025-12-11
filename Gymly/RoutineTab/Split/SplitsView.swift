//
//  SplitsView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 27.02.2025.
//

import SwiftUI
import SwiftData

struct SplitsView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var scheme

    @State var splits: [Split] = []
    @State var createSplit: Bool = false
    @State var showTemplates: Bool = false

    var body: some View {
        NavigationView {
            // TODO: Make switching between split possible
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                List {
                    // Browse Templates Button
                    Section {
                        Button(action: {
                            showTemplates = true
                        }) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(appearanceManager.accentColor.color)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Workout Templates")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("5 pro-designed splits")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.1))
                    }

                    Section("My Splits") {
                        if splits.isEmpty {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)

                                Text("No Workout Splits Yet")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.primary)

                                Text("Create your first split or browse templates to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                Button(action: {
                                    createSplit = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Create Split")
                                    }
                                    .bold()
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(appearanceManager.accentColor.color)
                                    .foregroundColor(.black)
                                    .cornerRadius(25)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .listRowBackground(Color.clear)
                        } else {
                            /// Show all splits
                            ForEach($splits.sorted(by: { $0.wrappedValue.isActive && !$1.wrappedValue.isActive })) { $split in
                            NavigationLink(destination: SplitDetailView(split: split, viewModel: viewModel)) {
                                HStack(spacing: 12) {
                                    // Active/Inactive Toggle
                                    Toggle("", isOn: $split.isActive)
                                        .toggleStyle(CheckToggleStyle())
                                        .onChange(of: split.isActive) {
                                            if split.isActive {
                                                viewModel.switchActiveSplit(split: split, context: context)
                                            }
                                        }

                                    // Split info
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Split name
                                        Text(split.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        // Split details (days and exercises count)
                                        HStack(spacing: 8) {
                                            // Days count
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.caption2)
                                                Text("\(split.days?.count ?? 0) days")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                            Text("•")
                                                .foregroundColor(.secondary)

                                            // Total exercises count
                                            HStack(spacing: 4) {
                                                Image(systemName: "dumbbell.fill")
                                                    .font(.caption2)
                                                Text("\(totalExercises(in: split)) exercises")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }

                                        // Active/Inactive status
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(split.isActive ? Color.green : Color.secondary.opacity(0.5))
                                                .frame(width: 6, height: 6)
                                            Text(split.isActive ? "Active" : "Inactive")
                                                .font(.caption2)
                                                .foregroundColor(split.isActive ? .green : .secondary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing) {
                                /// Swipe-to-delete action
                                Button(role: .destructive) {
                                    viewModel.deleteSplit(split: split)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .listRowBackground(Color.black.opacity(0.1))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listRowBackground(Color.clear)
                .padding(.vertical)
                .toolbar {
                    /// Button for adding splits
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            createSplit = true
                        } label: {
                            Label("", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("My Splits")
        }
        .task {
            splits = viewModel.getAllSplits()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.importSplit)) { notification in
            if let split = notification.object as? Split {
                debugLog("📩 Received imported split notification: \(split.name)")

                DispatchQueue.main.async {
                    viewModel.deactivateAllSplits()
                    splits = viewModel.getAllSplits() // Reload all splits from database
                }
            } else {
                splits = viewModel.getAllSplits()
            }
        }
        .sheet(isPresented: $createSplit, onDismiss: {
            splits = viewModel.getAllSplits()
        }) {
            SetupSplitView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTemplates, onDismiss: {
            splits = viewModel.getAllSplits()
        }) {
            SplitTemplatesView(viewModel: viewModel)
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

    // MARK: - Helper Functions

    private func totalExercises(in split: Split) -> Int {
        guard let days = split.days else { return 0 }
        return days.reduce(0) { total, day in
            total + (day.exercises?.count ?? 0)
        }
    }
}
