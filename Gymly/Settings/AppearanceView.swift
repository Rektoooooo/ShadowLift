//
//  AppearanceView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 20.10.2025.
//

import SwiftUI

struct AppearanceView: View {
    @StateObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.colorScheme) private var scheme
    @State private var showColorChangeAnimation = false
    @State private var selectedColor: AccentColorOption
    @State private var showSaveButton = false

    init() {
        _selectedColor = State(initialValue: AppearanceManager.shared.accentColor)
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.accent(scheme, accentColor: selectedColor))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedColor)

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 50))
                            .foregroundColor(selectedColor.color)

                        Text("App Appearance")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Customize your Gymly experience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Live Preview Card
                    LivePreviewCard(accentColor: selectedColor)
                        .padding(.horizontal, 24)

                    // Accent Color Picker
                    VStack(spacing: 16) {
                        HStack {
                            Text("Accent Color")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        // Info note about app icon change
                        HStack(spacing: 8) {
                            Image(systemName: "app.badge")
                                .foregroundStyle(.secondary)
                            Text("Preview your color choice, then save to update the app icon (Works for light mode only)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)

                        // Color Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(AccentColorOption.allCases) { colorOption in
                                ColorPickerButton(
                                    colorOption: colorOption,
                                    isSelected: selectedColor == colorOption
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        selectedColor = colorOption
                                        showSaveButton = selectedColor != appearanceManager.accentColor
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Save Button (only shows when color is different)
                        if showSaveButton {
                            Button(action: {
                                appearanceManager.updateAccentColor(selectedColor)
                                withAnimation {
                                    showSaveButton = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedColor.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // Coming Soon Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Coming Soon")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 12) {
                            ComingSoonFeature(
                                icon: "moon.fill",
                                title: "Dark Mode Options",
                                description: "Choose from Light, Dark, or Auto"
                            )

                            ComingSoonFeature(
                                icon: "sparkles",
                                title: "Custom Themes",
                                description: "More theme options coming soon"
                            )
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Live Preview Card
struct LivePreviewCard: View {
    let accentColor: AccentColorOption

    var body: some View {
        VStack(spacing: 16) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Preview UI Elements
            VStack(spacing: 16) {
                // Button Preview
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Primary Button")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accentColor.color)
                            .cornerRadius(12)
                    }

                    Button(action: {}) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(accentColor.color)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                    }
                }

                // Progress Bar Preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Workout Progress")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("75%")
                            .font(.subheadline)
                            .foregroundColor(accentColor.color)
                            .fontWeight(.semibold)
                    }

                    ProgressView(value: 0.75)
                        .tint(accentColor.color)
                }

                // Badge Preview
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("7 day streak")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor.color.opacity(0.2))
                    .foregroundColor(accentColor.color)
                    .cornerRadius(8)

                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                        Text("New PR")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor.color.opacity(0.2))
                    .foregroundColor(accentColor.color)
                    .cornerRadius(8)

                    Spacer()
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
        }
    }
}

// MARK: - Color Picker Button
struct ColorPickerButton: View {
    let colorOption: AccentColorOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(colorOption.color)
                        .frame(width: 60, height: 60)

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 60, height: 60)

                        Image(systemName: "checkmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: isSelected ? colorOption.color.opacity(0.5) : .clear, radius: 10)

                Text(colorOption.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? colorOption.color : .secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Coming Soon Feature
struct ComingSoonFeature: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Soon")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .foregroundStyle(.secondary)
                .cornerRadius(6)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        AppearanceView()
    }
}
