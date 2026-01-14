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
    @EnvironmentObject var storeManager: StoreManager
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

    @State var graphSortingSelected: String = "Today"

    // Graph filtering options - locked for free users
    private var graphSorting: [String] {
        if config.isPremium {
            return ["Today","Week","Month","All Time"]
        } else {
            return ["Today"]
        }
    }

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

                ScrollView {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 8)

                        // Profile Header - Elevated Design (Outside List for clean background)
                        Button(action: {
                            editUser = true
                        }) {
                            ZStack {
                                // Multi-tone gradient background
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        appearanceManager.accentColor.color,
                                        appearanceManager.accentColor.color.opacity(0.8),
                                        appearanceManager.accentColor.color.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                // Subtle pattern overlay
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear,
                                        Color.black.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                HStack(spacing: 16) {
                                    // Profile Image with ring
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                            .frame(width: 88, height: 88)

                                        ProfileImageCell(profileImage: profileImage, frameSize: 80)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(userProfileManager.currentProfile?.username ?? "User")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)

                                        // Quick stats row
                                        HStack(spacing: 4) {
                                            Image(systemName: "flame.fill")
                                                .font(.caption2)
                                            Text("\(userProfileManager.currentProfile?.currentStreak ?? 0) day streak")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundStyle(.white.opacity(0.9))

                                        // Edit hint
                                        HStack(spacing: 4) {
                                            Text("Tap to edit profile")
                                                .font(.caption2)
                                            Image(systemName: "pencil")
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.white.opacity(0.6))
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: appearanceManager.accentColor.color.opacity(0.4), radius: 16, x: 0, y: 8)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        // Body Stats Cards - Glassmorphism Design
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Stats")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
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
                                            additionalInfo: "Body Weight",
                                            icon: "scalemass.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        if config.isPremium {
                                            showStreakDetail = true
                                        } else {
                                            showPremiumSheet = true
                                        }
                                    }) {
                                        SettingUserInfoCell(
                                            value: String(format: "%d", userProfileManager.currentProfile?.currentStreak ?? 0),
                                            metric: "Days",
                                            headerColor: .orange,
                                            additionalInfo: "Current Streak",
                                            icon: "flame.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        if config.isPremium {
                                            showBmiDetail = true
                                        } else {
                                            showPremiumSheet = true
                                        }
                                    }) {
                                        SettingUserInfoCell(
                                            value: String(format: "%.1f", userProfileManager.currentProfile?.bmi ?? 0.0),
                                            metric: "BMI",
                                            headerColor: bmiColor,
                                            additionalInfo: bmiStatus,
                                            icon: "heart.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    SettingUserInfoCell(
                                        value: String(format: "%.0f", (userProfileManager.currentProfile?.height ?? 0.0)),
                                        metric: "cm",
                                        headerColor: .cyan,
                                        additionalInfo: "Height",
                                        icon: "ruler.fill"
                                    )

                                    SettingUserInfoCell(
                                        value: String(format: "%.0f", Double(userProfileManager.currentProfile?.age ?? 0)),
                                        metric: "years",
                                        headerColor: .purple,
                                        additionalInfo: "Age",
                                        icon: "birthday.cake.fill"
                                    )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                        .scrollClipDisabled(true)
                        .id(weightUpdatedTrigger)

                        // Progress Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progress")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)

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

                                // Premium banner for graph filters
                                if !config.isPremium {
                                    Button(action: {
                                        showPremiumSheet = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "lock.fill")
                                                .foregroundStyle(.yellow)
                                                .font(.caption)
                                            Text("Upgrade to unlock Week, Month & All Time views")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Image(systemName: "arrow.right")
                                                .foregroundStyle(.secondary)
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.secondaryBackground(for: scheme))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }

                        // Personal Records Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal Records")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)

                            NavigationLink(destination: Group {
                                if config.isPremium {
                                    PRHistoryView()
                                } else {
                                    PRHistoryLockedView()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(.yellow)
                                    Text("View All Records")
                                    Spacer()
                                    if !config.isPremium {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(.yellow)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.listRowBackground(for: scheme))
                                .cornerRadius(25)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }

                        // AI Insights Section
                        if #available(iOS 18.1, *) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("AI Insights")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 20)

                                NavigationLink(destination: AISummaryView()) {
                                    HStack {
                                        Image(systemName: "apple.intelligence")
                                            .foregroundStyle(.linearGradient(
                                                colors: [.purple, .blue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                        Text("Week AI Summary")
                                        Spacer()
                                        if !storeManager.hasAIAccess {
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color.listRowBackground(for: scheme))
                                    .cornerRadius(25)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }

                        // Fitness Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fitness")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)

                            NavigationLink(destination: FitnessProfileDetailView()) {
                                HStack {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundStyle(.green)
                                    Text("Your Fitness Profile")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.listRowBackground(for: scheme))
                                .cornerRadius(25)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 100)
                    }
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(Color.adaptiveText(for: scheme))
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

}
