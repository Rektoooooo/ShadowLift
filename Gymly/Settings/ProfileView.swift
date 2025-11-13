//
//  ProfileView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 19.10.2025.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @StateObject var healthKitManager = HealthKitManager()
    @Environment(\.modelContext) var context: ModelContext
    @Environment(\.colorScheme) private var scheme

    @State private var bmiColor: Color = .green
    @State private var bmiStatus: String = ""
    @State private var editUser: Bool = false
    @State private var showBmiDetail: Bool = false
    @State private var showWeightDetail: Bool = false
    @State private var showStreakDetail: Bool = false
    @State private var profileImage: UIImage?
    @State private var weightUpdatedTrigger = false
    @State private var showCalendar: Bool = false
    @State private var showPremiumSheet: Bool = false

    @State var graphSorting: [String] = ["Today","Week ⭐","Month ⭐","All Time ⭐"]
    @State var graphSortingSelected: String = "Today"

    private var selectedTimeRange: ContentViewGraph.TimeRange {
        switch graphSortingSelected {
        case "Today": return .day
        case "Week ⭐": return .week
        case "Month ⭐": return .month
        case "All Time ⭐": return .all
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
                    // Profile Header - Tappable to edit
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

                    // Body Stats Cards
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
                                    showStreakDetail = true
                                }) {
                                    SettingUserInfoCell(
                                        value: String(format: "%d", userProfileManager.currentProfile?.currentStreak ?? 0),
                                        metric: "Days",
                                        headerColor: .orange,
                                        additionalInfo: "Streak 🔥",
                                        icon: "flame.fill"
                                    )
                                }
                                .foregroundStyle(Color.white)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                                Button(action: {
                                    if config.isPremium {
                                        showBmiDetail = true
                                    } else {
                                        showPremiumSheet = true
                                    }
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        SettingUserInfoCell(
                                            value: String(format: "%.1f", userProfileManager.currentProfile?.bmi ?? 0.0),
                                            metric: "BMI",
                                            headerColor: bmiColor,
                                            additionalInfo: bmiStatus,
                                            icon: "dumbbell.fill"
                                        )

                                        if !config.isPremium {
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                                .padding(8)
                                        }
                                    }
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

                    // Progress Section - Graph
                    Section(header: HStack {
                        Text("Progress")
                    }) {
                        VStack(spacing: 8) {
                            Picker(selection: $graphSortingSelected, label: Text("")) {
                                ForEach(graphSorting, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 350)

                            ZStack {
                                ContentViewGraph(range: selectedTimeRange)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    .id(selectedTimeRange)
                                RadarLabels()
                            }
                            .frame(width: 300, height: 300)
                            .animation(.easeInOut(duration: 0.3), value: selectedTimeRange)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)

                    // AI Insights Section
                    Section("AI Insights") {
                        if #available(iOS 18.1, *) {
                            NavigationLink(destination: AISummaryView()) {
                                HStack {
                                    Image(systemName: "apple.intelligence")
                                    Text("Week AI Summary")
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                            }
                            .frame(width: 300)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Fitness Section
                    Section("Fitness") {
                        NavigationLink(destination: FitnessProfileDetailView(config: config)) {
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                Text("Your Fitness Profile")
                            }
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(Color.white)
                    }
                }
                .onAppear {
                    profileImage = userProfileManager.currentProfile?.profileImage

                    let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                    let (color, status) = getBmiStyle(bmi: bmi)
                    bmiColor = color
                    bmiStatus = status
                }
                .onChange(of: config.isHealtKitEnabled) { _, newValue in
                    DispatchQueue.main.async {
                        let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                        let (color, status) = getBmiStyle(bmi: bmi)
                        bmiColor = color
                        bmiStatus = status
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
                    }
                }) {
                    EditUserView(viewModel: viewModel)
                }
                .sheet(isPresented: $showBmiDetail) {
                    let bmiValue = userProfileManager.currentProfile?.bmi ?? 0.0
                    let (color, status) = getBmiStyle(bmi: bmiValue)
                    BmiDetailView(viewModel: viewModel, bmi: bmiValue, bmiColor: color, bmiText: status)
                }
                .sheet(isPresented: $showWeightDetail, onDismiss: {
                    DispatchQueue.main.async {
                        let bmi = userProfileManager.currentProfile?.bmi ?? 0.0
                        let (color, status) = getBmiStyle(bmi: bmi)
                        bmiColor = color
                        bmiStatus = status
                        weightUpdatedTrigger.toggle()
                    }
                }) {
                    WeightDetailView(viewModel: viewModel)
                }
                .sheet(isPresented: $showStreakDetail) {
                    StreakDetailView(viewModel: viewModel)
                }
                .sheet(isPresented: $showCalendar) {
                    CalendarView(viewModel: viewModel)
                }
                .sheet(isPresented: $showPremiumSheet) {
                    PremiumSubscriptionView()
                }
            }
        }
    }

    /// Load profile image from UserProfile
    private func loadProfileImage() async {
        await MainActor.run {
            profileImage = userProfileManager.currentProfile?.profileImage
        }
    }
}
