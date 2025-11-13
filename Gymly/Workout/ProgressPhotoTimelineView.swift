//
//  ProgressPhotoTimelineView.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import SwiftUI
import SwiftData

struct ProgressPhotoTimelineView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.modelContext) var context
    @Environment(\.colorScheme) var scheme

    @StateObject private var photoManager = PhotoManager.shared

    @Query(sort: \ProgressPhoto.date, order: .reverse) var allPhotos: [ProgressPhoto]

    @State private var showAddPhoto = false
    @State private var selectedPhoto: ProgressPhoto?

    private var groupedPhotos: [(String, [ProgressPhoto])] {
        guard let profile = userProfileManager.currentProfile else { return [] }
        // Filter photos for current user
        let userPhotos = allPhotos.filter { photo in
            photo.userProfile?.id == profile.id
        }
        return groupPhotos(userPhotos)
    }

    private func groupPhotos(_ photos: [ProgressPhoto]) -> [(String, [ProgressPhoto])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var grouped: [String: [ProgressPhoto]] = [:]
        var order: [String] = []

        for photo in photos {
            guard let photoDate = photo.date else { continue }
            let monthKey = formatter.string(from: photoDate)
            if grouped[monthKey] == nil {
                order.append(monthKey)
                grouped[monthKey] = []
            }
            grouped[monthKey]?.append(photo)
        }

        return order.map { ($0, grouped[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Progress Photos")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    showAddPhoto = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Photo")
                            .font(.subheadline)
                            .bold()
                    }
                    .foregroundColor(appearanceManager.accentColor.color)
                }
            }
            .padding()
            .background(Color.black.opacity(0.05))
            .onAppear {
                // Migrate missing thumbnails for old photos on first load
                if let profile = userProfileManager.currentProfile {
                    Task {
                        await photoManager.migrateMissingThumbnails(for: profile, context: context)
                    }
                }
            }

            if groupedPhotos.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No Progress Photos Yet")
                        .font(.title3)
                        .bold()

                    Text("Start tracking your transformation by adding your first progress photo!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button(action: {
                        showAddPhoto = true
                    }) {
                        Text("Take First Photo")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(appearanceManager.accentColor.color)
                            .cornerRadius(25)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Timeline
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                        ForEach(groupedPhotos, id: \.0) { month, photos in
                            VStack(alignment: .leading, spacing: 12) {
                                // Month Header
                                Text(month)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                // Photo Grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ], spacing: 8) {
                                    ForEach(photos) { photo in
                                        PhotoThumbnailCell(photo: photo, onTap: {
                                            print("📸 TIMELINE: Photo tapped - ID: \(photo.id?.uuidString ?? "unknown")")
                                            selectedPhoto = photo
                                            print("📸 TIMELINE: Set selectedPhoto=\(photo.id?.uuidString ?? "unknown")")
                                        })
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showAddPhoto) {
            AddProgressPhotoView()
        }
        .sheet(item: $selectedPhoto) { photo in
            ProgressPhotoDetailView(photo: photo)
                .onAppear {
                    print("✅ TIMELINE: Sheet appeared for photo: \(photo.id?.uuidString ?? "unknown")")
                }
        }
    }
}

// MARK: - Photo Thumbnail Cell

struct PhotoThumbnailCell: View {
    let photo: ProgressPhoto
    let onTap: () -> Void

    @State private var image: UIImage?
    @ObservedObject private var photoManager = PhotoManager.shared

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Image
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                    } else if let thumbnailData = photo.thumbnailData,
                              let thumbnail = UIImage(data: thumbnailData) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                ProgressView()
                            )
                    }

                    // Photo Type Badge
                    VStack {
                        HStack {
                            Spacer()
                            Text(photo.photoType?.rawValue ?? "Front")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(6)
                        }
                        Spacer()
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let date = photo.date {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }

                    if let weight = photo.weight {
                        Text(String(format: "%.1f kg", weight))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.black.opacity(0.05))
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            // For thumbnails, prefer cached thumbnail data for faster loading
            if let thumbnailData = photo.thumbnailData,
               let cachedThumbnail = UIImage(data: thumbnailData) {
                image = cachedThumbnail
            } else if let assetID = photo.photoAssetID {
                // Fallback to loading from Photos if no cached thumbnail
                image = await photoManager.loadImage(from: assetID)
            }
        }
    }
}
