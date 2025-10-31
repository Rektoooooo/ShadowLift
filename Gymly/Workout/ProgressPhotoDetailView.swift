//
//  ProgressPhotoDetailView.swift
//  Gymly
//
//  Created by Claude Code on 27.10.2025.
//

import SwiftUI
import SwiftData

struct ProgressPhotoDetailView: View {
    let photo: ProgressPhoto

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager

    @ObservedObject private var photoManager = PhotoManager.shared

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var showDeleteConfirmation = false
    @State private var showComparisonPicker = false

    init(photo: ProgressPhoto) {
        self.photo = photo

        print("📸 INIT: Creating ProgressPhotoDetailView for photo \(photo.id?.uuidString ?? "unknown")")
        print("📸 INIT: Has thumbnailData: \(photo.thumbnailData != nil)")
        print("📸 INIT: Thumbnail size: \(photo.thumbnailData?.count ?? 0) bytes")
        print("📸 INIT: Has photoAssetID: \(photo.photoAssetID != nil)")

        // CRITICAL: Load thumbnail SYNCHRONOUSLY in init before view appears
        // This ensures image is ready immediately, not waiting for .onAppear
        if let thumbnailData = photo.thumbnailData,
           let thumbnail = UIImage(data: thumbnailData) {
            _image = State(initialValue: thumbnail)
            print("✅ INIT: Loaded cached thumbnail successfully - size: \(thumbnail.size)")
        } else if photo.thumbnailData != nil {
            print("❌ INIT: Has thumbnailData but failed to create UIImage!")
        } else {
            print("⚠️ INIT: No thumbnailData for photo")
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Photo
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .padding()
                        } else if isLoading {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 400)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                        Text("Loading photo...")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                )
                                .cornerRadius(12)
                                .padding()
                        } else if loadError {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 400)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.badge.exclamationmark")
                                            .font(.system(size: 50))
                                            .foregroundColor(.red)
                                        Text("Photo not available")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("The photo may have been deleted from your Photos library")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 40)
                                    }
                                )
                                .cornerRadius(12)
                                .padding()
                        } else {
                            // Fallback: Show thumbnail if full image failed
                            if let thumbnailData = photo.thumbnailData,
                               let thumbnail = UIImage(data: thumbnailData) {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                                    .padding()
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            Text("Full resolution unavailable - showing thumbnail")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(8)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(8)
                                                .padding()
                                        }
                                    )
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 400)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            Image(systemName: "photo.badge.exclamationmark")
                                                .font(.system(size: 50))
                                                .foregroundColor(.secondary)
                                            Text("Photo not available")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                                    .cornerRadius(12)
                                    .padding()
                            }
                        }

                        // Metadata
                        VStack(spacing: 16) {
                            InfoRow(label: "Type", value: photo.photoType?.rawValue ?? "Front")
                            if let date = photo.date {
                                InfoRow(label: "Date", value: date.formatted(date: .long, time: .shortened))
                            }

                            if let weight = photo.weight {
                                InfoRow(label: "Weight", value: String(format: "%.1f kg", weight))
                            }

                            if let notes = photo.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text(notes)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                showComparisonPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.left.and.right")
                                    Text("Compare with Another Photo")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(appearanceManager.accentColor.color)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }

                            Button(action: {
                                sharePhoto()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Progress")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .task {
                await loadPhoto()
            }
        }
    }

    /// Load photo with proper error handling
    private func loadPhoto() async {
        print("📸 TASK: Starting loadPhoto() - current image state: \(image != nil ? "has image" : "no image")")

        // Load full resolution from Photos library
        guard let assetID = photo.photoAssetID else {
            await MainActor.run {
                isLoading = false
                loadError = true
                print("❌ TASK: No asset ID for photo")
            }
            return
        }

        print("📸 TASK: Loading full resolution for asset: \(assetID)")

        if let fullImage = await photoManager.loadImage(from: assetID) {
            await MainActor.run {
                image = fullImage
                isLoading = false
                loadError = false
                print("✅ TASK: Full resolution loaded successfully")
            }
        } else {
            await MainActor.run {
                isLoading = false
                // If we have a thumbnail, don't show error - just keep thumbnail
                if image == nil {
                    loadError = true
                    print("❌ TASK: Failed to load full resolution and no thumbnail available")
                } else {
                    print("⚠️ TASK: Failed to load full resolution but thumbnail is available")
                }
            }
        }
    }

    private func deletePhoto() {
        photoManager.deletePhoto(photo, context: context)
        dismiss()
    }

    private func sharePhoto() {
        guard let image = image else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Comparison Photo Picker

struct ComparisonPhotoPickerView: View {
    let currentPhoto: ProgressPhoto

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userProfileManager: UserProfileManager

    @ObservedObject private var photoManager = PhotoManager.shared
    @State private var selectedPhoto: ProgressPhoto?
    @State private var showComparison = false

    private var availablePhotos: [ProgressPhoto] {
        guard let profile = userProfileManager.currentProfile else { return [] }
        return photoManager.getAllPhotos(for: profile)
            .filter { $0.id != currentPhoto.id }
    }

    var body: some View {
        NavigationView {
            List(availablePhotos) { photo in
                Button(action: {
                    selectedPhoto = photo
                    showComparison = true
                }) {
                    HStack {
                        AsyncThumbnail(photo: photo)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            if let date = photo.date {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .bold()
                            }

                            Text(photo.photoType?.rawValue ?? "Front")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let weight = photo.weight {
                                Text(String(format: "%.1f kg", weight))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Choose Photo to Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showComparison) {
                if let selected = selectedPhoto {
                    ProgressPhotoCompareView(photo1: currentPhoto, photo2: selected)
                }
            }
        }
    }
}

// MARK: - Async Thumbnail

struct AsyncThumbnail: View {
    let photo: ProgressPhoto

    @State private var image: UIImage?
    @ObservedObject private var photoManager = PhotoManager.shared

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let thumbnailData = photo.thumbnailData,
                      let thumbnail = UIImage(data: thumbnailData) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            }
        }
        .task {
            // Load thumbnail immediately from cached data
            if let thumbnailData = photo.thumbnailData,
               let thumbnail = UIImage(data: thumbnailData) {
                image = thumbnail
            } else if let assetID = photo.photoAssetID {
                // Fallback to loading from Photos if no cached thumbnail
                image = await photoManager.loadImage(from: assetID)
            }
        }
    }
}