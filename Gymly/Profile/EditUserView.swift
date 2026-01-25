//
//  EditUserView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 29.01.2025.
//

import SwiftUI
import PhotosUI
import Foundation

@MainActor
struct EditUserView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @State private var profileImage: UIImage?
    @StateObject var healthKitManager = HealthKitManager()
    @Environment(\.colorScheme) private var scheme
    @State private var showCropEditor = false
    @State private var selectedImageForCrop: UIImage?
    @State private var isImagePressed = false
    @State private var isLoadingImage = false

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Profile Image Section - Tappable with Camera Badge
                        profileImagePicker
                        .onChange(of: avatarItem) {
                            Task {
                                if let newItem = avatarItem,
                                   let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    debugLog("📸 EDITUSER: Loaded image: \(uiImage.size)")
                                    await MainActor.run {
                                        selectedImageForCrop = uiImage
                                        showCropEditor = true
                                        debugLog("📸 EDITUSER: Presenting crop editor")
                                    }
                                }
                            }
                        }

                        Text("Tap to change photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Username Input Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Username")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(appearanceManager.accentColor.color.opacity(0.15))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(appearanceManager.accentColor.color)
                                }

                                TextField("Enter username", text: Binding(
                                    get: { userProfileManager.currentProfile?.username ?? "User" },
                                    set: { userProfileManager.updateUsername($0) }
                                ))
                                .font(.body)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            }
                            .padding(16)
                            .background(Color.listRowBackground(for: scheme))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 24)

                        // Save Button - Hero CTA
                        Button(action: {
                            Task {
                                debugLog("🔥 SAVE CHANGES PRESSED")
                                debugLog("🔥 CURRENT USERNAME: \(userProfileManager.currentProfile?.username ?? "none")")
                                debugLog("🔥 HAS AVATAR IMAGE: \(avatarImage != nil)")

                                if let image = avatarImage {
                                    debugLog("🔥 SAVING PROFILE IMAGE TO USERPROFILE")
                                    userProfileManager.updateProfileImage(image)
                                }

                                debugLog("✅ Profile changes saved to SwiftData + CloudKit")

                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Save Changes")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        appearanceManager.accentColor.color,
                                        appearanceManager.accentColor.color.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: appearanceManager.accentColor.color.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 50)
                    }
                }
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(Color.adaptiveText(for: scheme))
                    }
                }
                .onAppear {
                    Task {
                        await loadProfileImage()
                    }
                }
            }
        }
        .sheet(isPresented: $showCropEditor) {
            if let image = selectedImageForCrop {
                ProfileImageCropView(
                    image: image,
                    onComplete: { croppedImage in
                        avatarImage = croppedImage
                        showCropEditor = false
                        selectedImageForCrop = nil
                    },
                    onCancel: {
                        showCropEditor = false
                        selectedImageForCrop = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    /// Load profile image from UserProfile
    private func loadProfileImage() async {
        await MainActor.run {
            isLoadingImage = true
        }
        await MainActor.run {
            profileImage = userProfileManager.currentProfile?.profileImage
            isLoadingImage = false
        }
    }

    // MARK: - Profile Image Picker View
    /// Extracted to avoid @Sendable closure issues with @MainActor properties
    @ViewBuilder
    private var profileImagePicker: some View {
        let accentColor = appearanceManager.accentColor.color
        let currentAvatarImage = avatarImage
        let currentProfileImage = profileImage
        let pressed = isImagePressed
        let loading = isLoadingImage

        PhotosPicker(selection: $avatarItem, matching: .images) {
            ZStack {
                // Profile image with ring
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 130, height: 130)

                    // Profile image or loading indicator
                    if loading {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    } else if let avatarImage = currentAvatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        ProfileImageCell(profileImage: currentProfileImage, frameSize: 120)
                    }
                }
                .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 6)

                // Camera badge
                ZStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 36, height: 36)

                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 36, height: 36)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .offset(x: 45, y: 45)
            }
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isImagePressed {
                        isImagePressed = true
                    }
                }
                .onEnded { _ in
                    isImagePressed = false
                }
        )
    }
}
