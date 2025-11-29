//
//  PhotoManager.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import Foundation
import Photos
import UIKit
import SwiftData

/// Manager for handling progress photos
class PhotoManager: ObservableObject {

    static let shared = PhotoManager()

    private init() {}

    // MARK: - Permission Management

    /// Request photo library permission
    func requestPhotoPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Save Photos

    /// Save progress photo to Photos library and create ProgressPhoto record
    @MainActor
    func saveProgressPhoto(
        image: UIImage,
        type: PhotoType,
        notes: String,
        weight: Double?,
        userProfile: UserProfile?,
        context: ModelContext
    ) async -> ProgressPhoto? {
        // Request permission first
        let hasPermission = await requestPhotoPermission()
        guard hasPermission else {
            print("❌ Photo permission denied")
            return nil
        }

        // Save to Photos library
        guard let assetID = await saveToPhotosLibrary(image: image) else {
            print("❌ Failed to save to Photos library")
            return nil
        }

        // Create thumbnail
        let thumbnail = createThumbnail(from: image, maxSize: 200)
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.7)

        // Create ProgressPhoto record
        let progressPhoto = ProgressPhoto(
            date: Date(),
            photoAssetID: assetID,
            thumbnailData: thumbnailData,
            weight: weight,
            notes: notes,
            photoType: type,
            userProfile: userProfile
        )

        print("📸 Creating photo with ID: \(progressPhoto.id?.uuidString ?? "nil"), type: \(type.rawValue), userProfile: \(userProfile?.id.uuidString ?? "nil")")

        context.insert(progressPhoto)

        // Explicitly add to userProfile's progressPhotos array
        if let profile = userProfile {
            if profile.progressPhotos == nil {
                profile.progressPhotos = []
            }
            profile.progressPhotos?.append(progressPhoto)
            print("📸 Added photo to userProfile, total photos: \(profile.progressPhotos?.count ?? 0)")
        } else {
            print("⚠️ No userProfile provided for photo!")
        }

        do {
            try context.save()
            print("✅ Progress photo saved: \(type.rawValue)")

            // Sync to CloudKit if enabled
            Task {
                do {
                    try await CloudKitManager.shared.saveProgressPhoto(progressPhoto, fullImage: image)
                    print("✅ Progress photo synced to CloudKit")
                } catch {
                    print("⚠️ Failed to sync progress photo to CloudKit: \(error)")
                    // Don't fail the save if CloudKit sync fails
                }
            }

            return progressPhoto
        } catch {
            print("❌ Failed to save ProgressPhoto: \(error)")
            return nil
        }
    }

    /// Save image to Photos library and return asset identifier
    func saveToPhotosLibrary(image: UIImage) async -> String? {
        return await withCheckedContinuation { continuation in
            var assetID: String?

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                assetID = request.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                if success, let id = assetID {
                    print("✅ Saved to Photos library: \(id)")
                    continuation.resume(returning: id)
                } else {
                    print("❌ Failed to save to Photos: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Fetch Photos

    /// Load UIImage from Photos library using asset ID
    func loadImage(from assetID: String) async -> UIImage? {
        // Retry logic for freshly saved photos
        for attempt in 1...3 {
            let fetchOptions = PHFetchOptions()
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: fetchOptions)

            if let asset = result.firstObject {
                if let image = await loadImage(from: asset) {
                    return image
                }
            }

            // If first attempt fails, wait a bit for Photos library to process
            if attempt < 3 {
                print("⚠️ Asset not ready, retrying... (attempt \(attempt))")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }

        print("❌ Asset not found after 3 attempts: \(assetID)")
        return nil
    }

    /// Load UIImage from PHAsset
    private func loadImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize, // Full resolution
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("❌ Photo loading error: \(error)")
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// Get all progress photos for a user
    func getAllPhotos(for userProfile: UserProfile) -> [ProgressPhoto] {
        return userProfile.progressPhotos?.sorted(by: {
            guard let date1 = $0.date, let date2 = $1.date else { return false }
            return date1 > date2
        }) ?? []
    }

    /// Get photos within date range
    func getPhotos(for userProfile: UserProfile, from startDate: Date, to endDate: Date) -> [ProgressPhoto] {
        return getAllPhotos(for: userProfile).filter { photo in
            guard let photoDate = photo.date else { return false }
            return photoDate >= startDate && photoDate <= endDate
        }
    }

    /// Get photos grouped by month
    func getPhotosGroupedByMonth(for userProfile: UserProfile) -> [(String, [ProgressPhoto])] {
        let photos = getAllPhotos(for: userProfile)
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

    // MARK: - Delete Photos

    /// Delete progress photo from database (keeps in Photos library)
    func deletePhoto(_ photo: ProgressPhoto, context: ModelContext) {
        print("🗑️ Deleting photo with ID: \(photo.id?.uuidString ?? "nil"), type: \(photo.photoType?.rawValue ?? "nil"), userProfile: \(photo.userProfile?.id.uuidString ?? "nil")")

        let photoID = photo.id
        context.delete(photo)

        do {
            try context.save()
            print("✅ Progress photo deleted")

            // Delete from CloudKit if enabled
            if let photoID = photoID {
                Task {
                    do {
                        try await CloudKitManager.shared.deleteProgressPhoto(photoID)
                        print("✅ Progress photo deleted from CloudKit")
                    } catch {
                        print("⚠️ Failed to delete progress photo from CloudKit: \(error)")
                        // Don't fail the delete if CloudKit sync fails
                    }
                }
            }
        } catch {
            print("❌ Failed to delete photo: \(error)")
        }
    }

    // MARK: - Image Processing

    /// Create thumbnail from image
    func createThumbnail(from image: UIImage, maxSize: CGFloat) -> UIImage? {
        let size = image.size
        let ratio = size.width / size.height

        var newSize: CGSize
        if ratio > 1 {
            // Landscape
            newSize = CGSize(width: maxSize, height: maxSize / ratio)
        } else {
            // Portrait
            newSize = CGSize(width: maxSize * ratio, height: maxSize)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail
    }

    /// Compress image for CloudKit sync (max 500KB)
    func compressForSync(image: UIImage) -> Data? {
        var compression: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compression)

        // Reduce quality until under 500KB
        while let data = imageData, data.count > 500_000 && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }

        return imageData
    }

    // MARK: - Migration & Repair

    /// Migrate old photos that are missing thumbnails
    @MainActor
    func migrateMissingThumbnails(for userProfile: UserProfile, context: ModelContext) async {
        let photos = userProfile.progressPhotos ?? []
        var migratedCount = 0

        for photo in photos {
            // Skip if already has thumbnail
            if photo.thumbnailData != nil {
                continue
            }

            // Skip if no asset ID
            guard let assetID = photo.photoAssetID else {
                print("⚠️ Photo \(photo.id?.uuidString ?? "unknown") has no asset ID")
                continue
            }

            print("🔄 Migrating thumbnail for photo: \(photo.id?.uuidString ?? "unknown")")

            // Load full image from Photos library
            if let fullImage = await loadImage(from: assetID) {
                // Create and save thumbnail
                if let thumbnail = createThumbnail(from: fullImage, maxSize: 200),
                   let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                    photo.thumbnailData = thumbnailData
                    migratedCount += 1
                    print("✅ Thumbnail created for photo: \(photo.id?.uuidString ?? "unknown")")
                } else {
                    print("❌ Failed to create thumbnail for photo: \(photo.id?.uuidString ?? "unknown")")
                }
            } else {
                print("❌ Failed to load image from Photos library for: \(assetID)")
            }
        }

        if migratedCount > 0 {
            do {
                try context.save()
                print("✅ Migrated \(migratedCount) thumbnails")
            } catch {
                print("❌ Failed to save migrated thumbnails: \(error)")
            }
        } else {
            print("ℹ️ No thumbnails needed migration")
        }
    }
}
