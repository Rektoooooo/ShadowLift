//
//  EditUserView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 29.01.2025.
//

import SwiftUI
import PhotosUI
import Foundation

struct EditUserView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss
    @State private var profileImage: UIImage?
    @StateObject var healthKitManager = HealthKitManager()
    @Environment(\.colorScheme) private var scheme
    @State private var showCropEditor = false
    @State private var selectedImageForCrop: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()
                List {
                Section("Profile image") {
                        HStack {
                            Spacer()
                            if avatarImage == nil {
                                ProfileImageCell(profileImage: profileImage, frameSize: 100)
                            } else {
                                if let avatarImage = avatarImage {
                                    Image(uiImage: avatarImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .padding()
                                        .shadow(color: Color.black.opacity(0.6), radius: 15, x: 0, y: 0)
                                }
                            }
                            Spacer()
                        }
                        PhotosPicker("Select avatar", selection: $avatarItem, matching: .images)
                            .onChange(of: avatarItem) {
                                Task {
                                    if let newItem = avatarItem,
                                       let data = try? await newItem.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        print("📸 EDITUSER: Loaded image: \(uiImage.size)")
                                        // Set image first, then present on main thread
                                        await MainActor.run {
                                            selectedImageForCrop = uiImage
                                            showCropEditor = true
                                            print("📸 EDITUSER: Presenting crop editor")
                                        }
                                    }
                                }
                            }
                    }
                    .listRowBackground(Color.black.opacity(0.1))
                    Section("User credencials") {
                        HStack {
                            Text("Username")
                                .foregroundStyle(.white.opacity(0.6))
                            TextField("Username", text: Binding(
                                get: { userProfileManager.currentProfile?.username ?? "User" },
                                set: { userProfileManager.updateUsername($0) }
                            ))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.1))
                    Section("Workout Preferences") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rest days per week")
                                    .foregroundStyle(.white)
                                Text("Days you can skip without breaking streak")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Text("\(userProfileManager.currentProfile?.restDaysPerWeek ?? 2)")
                                .foregroundStyle(.white)
                                .bold()
                                .font(.title3)
                            Stepper(
                                "",
                                value: Binding(
                                    get: { userProfileManager.currentProfile?.restDaysPerWeek ?? 2 },
                                    set: { userProfileManager.updateRestDays($0) }
                                ),
                                in: 0...7
                            )
                            .labelsHidden()
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.1))
                    Section("") {
                        Button("Save changes") {
                            Task {
                                do {
                                    print("🔥 SAVE CHANGES PRESSED")
                                    print("🔥 CURRENT USERNAME: \(userProfileManager.currentProfile?.username ?? "none")")
                                    print("🔥 HAS AVATAR IMAGE: \(avatarImage != nil)")

                                    // Save profile image using new UserProfile system
                                    if let image = avatarImage {
                                        print("🔥 SAVING PROFILE IMAGE TO USERPROFILE")
                                        userProfileManager.updateProfileImage(image)
                                    }

                                    print("✅ Profile changes saved to SwiftData + CloudKit")

                                    await MainActor.run {
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.1))
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Edit profile")
                .onAppear() {
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
            profileImage = userProfileManager.currentProfile?.profileImage
        }
    }
}
