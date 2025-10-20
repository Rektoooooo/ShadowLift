//
//  AccountView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 13.05.2024.
//

import SwiftUI
import SwiftData
import Foundation

struct SettingsView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @StateObject var healthKitManager = HealthKitManager()
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.colorScheme) private var scheme
    @State private var height: Double?
    @State private var weight: Double?
    @State private var bmi: Double?
    @State var bmiStatus: String = ""
    @State var bmiColor: Color = .green
    @State private var age: Int?
    @State private var editUser: Bool = false
    @State private var showBmiDetail: Bool = false
    @State private var showWeightDetail: Bool = false
    @State private var profileImage: UIImage?
    @State var selectedUnit:String = ""
    @State private var weightUpdatedTrigger = false
    
    
    let units: [String] = ["Kg","Lbs"]
    
    @State var graphSorting: [String] = ["Today","Week","Month","All Time"]
    @State var graphSortingSelected: String = "Today"
    private var selectedTimeRange: ContentViewGraph.TimeRange {
        switch graphSortingSelected {
        case "Today": return .day
        case "Week": return .week
        case "Month": return .month
        case "All Time": return .all
        default: return .month
        }
    }
    
    /// Computed property for formatted workout hours
    private var formattedWorkoutHours: Int {
        return config.totalWorkoutTimeMinutes / 60
    }

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.accent(scheme, accentColor: appearanceManager.accentColor))
                    .ignoresSafeArea()
                List {
                    Button(action: {
                        editUser = true
                    }) {
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [appearanceManager.accentColor.color, appearanceManager.accentColor.color]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .cornerRadius(20)
                            HStack {
                                ProfileImageCell(profileImage: profileImage, frameSize: 80)
                                    .padding()

                                VStack(spacing: 8) {
                                    Text("\(userProfileManager.currentProfile?.username ?? "User")")
                                        .bold()
                                        .font(.body)
                                        .padding(.trailing)


                                    HStack(spacing: 15) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "flame")
                                            Text("\(userProfileManager.currentProfile?.currentStreak ?? 0)")
                                        }
                                        .font(.footnote)
                                        .bold()


                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                            Text("\(formattedWorkoutHours) h")
                                        }
                                        .font(.footnote)
                                        .bold()
                                        .padding(.trailing)

                                    }
                                }
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding(.trailing)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .frame(width: 340, height: 120)
                    .listRowSeparator(.hidden)
                    HStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                Button(action: {
                                    showWeightDetail = true
                                }) {
                                    SettingUserInfoCell(
                                        value: String(
                                            format: "%.1f",
                                            {
                                                let weight = userProfileManager.currentProfile?.weight ?? 0.0
                                                let unit = userProfileManager.currentProfile?.weightUnit ?? "Kg"
                                                let factor = unit == "Kg" ? 1.0 : 2.20462262
                                                return weight * factor
                                            }()),
                                        metric: userProfileManager.currentProfile?.weightUnit ?? "Kg",
                                        headerColor: appearanceManager.accentColor.color,
                                        additionalInfo: "Body weight",
                                        icon: "figure.mixed.cardio"
                                    )
                                }
                                .foregroundStyle(Color.white)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                Button(action: {
                                    showBmiDetail = true
                                }) {
                                    SettingUserInfoCell(
                                        value: String(format: "%.1f", userProfileManager.currentProfile?.bmi ?? 0.0),
                                        metric: "BMI",
                                        headerColor: bmiColor,
                                        additionalInfo: bmiStatus,
                                        icon: "dumbbell.fill"
                                    )
                                }
                                .foregroundStyle(Color.white)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                SettingUserInfoCell(
                                    value: String(format: "%.2f", (userProfileManager.currentProfile?.height ?? 0.0) / 100.0),
                                    metric: "m",
                                    headerColor: appearanceManager.accentColor.color,
                                    additionalInfo: "Height",
                                    icon: "figure.wave"
                                )
                                SettingUserInfoCell(
                                    value: String(format: "%.0f", Double(userProfileManager.currentProfile?.age ?? 0)),
                                    metric: "yo",
                                    headerColor: appearanceManager.accentColor.color,
                                    additionalInfo: "Age",
                                    icon: "person.text.rectangle"
                                )
                            }
                        }
                    }
                    .frame(width: 370)
                    .padding(.horizontal, 4)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(weightUpdatedTrigger)

                    // Fitness Profile Section
                    Section("Fitness Profile") {
                        NavigationLink(destination: FitnessProfileDetailView(config: config)) {
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                Text("View Fitness Profile")
                            }
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    Section("") {
                        NavigationLink(destination: AISummaryView()) {
                            Image(systemName: "apple.intelligence")
                            Text("Week AI Summary")
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))
                    Section("Preferences") {
                        HStack {
                            HStack {
                                Image(systemName: "scalemass")
                                Text("Unit")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Picker(selection: Binding(
                                get: { userProfileManager.currentProfile?.weightUnit ?? "Kg" },
                                set: { userProfileManager.updatePreferences(weightUnit: $0) }
                            ), label: Text("")) {
                                ForEach(units, id: \.self) { unit in
                                    Text(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, -30)
                            .onChange(of: userProfileManager.currentProfile?.weightUnit ?? "Kg") {
                                debugPrint("Selected unit: \(userProfileManager.currentProfile?.weightUnit ?? "Kg")")
                                userProfileManager.updatePreferences(roundSetWeights: true)
                                weightUpdatedTrigger.toggle()
                            }
                        }
                        .frame(width: 300)
                        NavigationLink(destination: ConnectionsView(viewModel: viewModel)) {
                            Image(systemName: "square.2.layers.3d.top.filled")
                            Text("App connections")
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))
                    Section(header: HStack {
                        Text("Graph")
                    }) {
                        VStack(spacing: 8) {
                            Picker(selection: $graphSortingSelected, label: Text("")) {
                                ForEach(graphSorting, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            ZStack {
                                ContentViewGraph(range: selectedTimeRange)
                                RadarLabels()
                            }
                            .frame(width: 300, height: 300)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("\(userProfileManager.currentProfile?.username ?? "User")'s profile")
                .onAppear {
                    profileImage = userProfileManager.currentProfile?.profileImage

                    // Don't fetch from HealthKit on appear to preserve manually saved data
                    // Just update UI with current profile data
                    let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                    let (color, status) = getBmiStyle(bmi: bmi)
                    bmiColor = color
                    bmiStatus = status

                    print("📱 SettingsView appeared - Current weight: \(userProfileManager.currentProfile?.weight ?? 0.0) kg")
                }
                .onChange(of: config.isHealtKitEnabled) { _, newValue in
                    // When HealthKit status changes, update BMI color immediately
                    DispatchQueue.main.async {
                        let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                        let (color, status) = getBmiStyle(bmi: bmi)
                        bmiColor = color
                        bmiStatus = status
                        print("🎨 SETTINGS: Updated BMI color due to HealthKit status change")
                    }
                }
                .sheet(isPresented: $editUser, onDismiss: {
                    Task {
                        await loadProfileImage()
                    }
                    healthKitManager.fetchWeight { weight in
                        DispatchQueue.main.async {
                            userProfileManager.updatePhysicalStats(weight: weight ?? 0.0)
                        }
                    }                }) {
                        EditUserView(viewModel: viewModel)
                    }
                    .sheet(isPresented: $showBmiDetail, onDismiss: {
                    }) {
                        let (color, status) = getBmiStyle(bmi: userProfileManager.currentProfile?.bmi ?? 0.0)
                        BmiDetailView(viewModel: viewModel, bmiColor: color, bmiText: status)
                    }
                    .sheet(isPresented: $showWeightDetail, onDismiss: {
                        // Just update the UI with the current profile weight (already saved in WeightDetailView)
                        DispatchQueue.main.async {
                            let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                            let (color, status) = getBmiStyle(bmi: bmi)
                            bmiColor = color
                            bmiStatus = status
                            weightUpdatedTrigger.toggle() // Trigger UI update
                        }
                    }) {
                            WeightDetailView(viewModel: viewModel)
                        }
                        .onAppear {
                            // Refresh HealthKit permissions when view appears
                            refreshHealthKitDataWithFullUpdate()
                            // Load profile image
                            Task {
                                await loadProfileImage()
                            }
                        }
            }
        }
    }

    /// Refresh HealthKit data
    private func refreshHealthKitData() {
        if UserDefaults.standard.bool(forKey: "healthKitEnabled") {
            healthKitManager.fetchWeight { weight in
                DispatchQueue.main.async {
                    let currentWeight = userProfileManager.currentProfile?.weight ?? 0.0
                    userProfileManager.updatePhysicalStats(weight: weight ?? currentWeight)
                }
            }
            healthKitManager.fetchHeight { height in
                DispatchQueue.main.async {
                    let currentHeight = userProfileManager.currentProfile?.height ?? 0.0
                    // Convert from meters to centimeters for UserProfile storage
                    let heightInCm = (height ?? (currentHeight / 100.0)) * 100.0
                    userProfileManager.updatePhysicalStats(height: heightInCm)
                }
            }
            healthKitManager.fetchAge { age in
                DispatchQueue.main.async {
                    let currentAge = userProfileManager.currentProfile?.age ?? 0
                    userProfileManager.updatePhysicalStats(age: age ?? currentAge)
                }
            }
            // Update BMI
            DispatchQueue.main.async {
                let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                if bmi > 0 {
                    let (color, status) = getBmiStyle(bmi: bmi)
                    bmiColor = color
                    bmiStatus = status
                }
            }
        }
    }

    /// Full HealthKit data refresh (fetches height and age, preserves manual weight)
    private func refreshHealthKitDataWithFullUpdate() {
        // Only fetch if HealthKit is enabled
        guard UserDefaults.standard.bool(forKey: "healthKitEnabled") else {
            // If HealthKit not enabled, just update UI with existing data
            DispatchQueue.main.async {
                let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                let (color, status) = getBmiStyle(bmi: bmi)
                bmiColor = color
                bmiStatus = status
                weightUpdatedTrigger.toggle()
            }
            return
        }

        // Fetch height from HealthKit
        healthKitManager.fetchHeight { height in
            DispatchQueue.main.async {
                if let height = height {
                    // HealthKit returns height in meters, UserProfile stores in centimeters
                    let heightInCm = height * 100.0
                    userProfileManager.updatePhysicalStats(height: heightInCm)
                    print("✅ SETTINGS: Fetched height from HealthKit: \(height) m (\(heightInCm) cm)")
                }
            }
        }

        // Fetch age from HealthKit
        healthKitManager.fetchAge { age in
            DispatchQueue.main.async {
                if let age = age {
                    userProfileManager.updatePhysicalStats(age: age)
                    print("✅ SETTINGS: Fetched age from HealthKit: \(age) years")
                }
            }
        }

        // Update BMI UI after fetching
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
            let (color, status) = getBmiStyle(bmi: bmi)
            bmiColor = color
            bmiStatus = status
            weightUpdatedTrigger.toggle()
        }
    }

    /// Load profile image from UserProfile
    private func loadProfileImage() async {
        await MainActor.run {
            profileImage = userProfileManager.currentProfile?.profileImage
        }
    }
}

func getBmiStyle(bmi: Double) -> (Color, String) {
    switch bmi {
    case ..<18.5:
        return (.orange, "Underweight")
    case 18.5...24.9:
        return (.green, "Normal weight")
    case 25...29.9:
        return (.orange, "Overweight")
    default:
        return (.red, "Obese")
    }
}


