//
//  ProgressPhoto.swift
//  Gymly
//
//  Created by Claude Code on 27.10.2025.
//

import Foundation
import SwiftData

/// Photo type for progress tracking
enum PhotoType: String, Codable {
    case front = "Front"
    case side = "Side"
    case back = "Back"
    case custom = "Custom"
}

/// Progress photo model for tracking visual transformation
@Model
class ProgressPhoto: Codable, Identifiable {
    var id: UUID?
    var date: Date?
    var photoAssetID: String? // Photos library identifier (local)
    var thumbnailData: Data? // Compressed thumbnail for CloudKit sync (50KB)
    var weight: Double? // Auto-linked weight at time of photo
    var notes: String? // User notes about this photo
    var photoType: PhotoType? // Type of photo (front/side/back)
    var createdAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \UserProfile.progressPhotos) var userProfile: UserProfile?

    init(id: UUID = UUID(), date: Date = Date(), photoAssetID: String? = nil, thumbnailData: Data? = nil, weight: Double? = nil, notes: String? = nil, photoType: PhotoType = .front, createdAt: Date = Date(), userProfile: UserProfile? = nil) {
        self.id = id
        self.date = date
        self.photoAssetID = photoAssetID
        self.thumbnailData = thumbnailData
        self.weight = weight
        self.notes = notes
        self.photoType = photoType
        self.createdAt = createdAt
        self.userProfile = userProfile
    }

    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, date, photoAssetID, thumbnailData, weight, notes, photoType, createdAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id)
        self.date = try container.decodeIfPresent(Date.self, forKey: .date)
        self.photoAssetID = try container.decodeIfPresent(String.self, forKey: .photoAssetID)
        self.thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.photoType = try container.decodeIfPresent(PhotoType.self, forKey: .photoType)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encodeIfPresent(photoAssetID, forKey: .photoAssetID)
        try container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(photoType, forKey: .photoType)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}
