//
//  AISummaryCache.swift
//  ShadowLift
//
//  Created by Claude Code on 23.10.2025.
//

import Foundation

/// Simple cached summary data structure
struct CachedSummaryData: Codable {
    var headline: String?
    var overview: String?
    var keyStats: [CachedKeyStat]?
    var trends: [CachedTrend]?
    var prs: [CachedPR]?
    var issues: [CachedIssue]?
    var recommendations: [CachedRecommendation]?
}

struct CachedKeyStat: Codable {
    var name: String?
    var value: String?
    var delta: String?
}

struct CachedTrend: Codable {
    var label: String?
    var direction: String?
    var evidence: String?
}

struct CachedPR: Codable {
    var exercise: String?
    var type: String?
    var value: String?
}

struct CachedIssue: Codable {
    var category: String?
    var detail: String?
    var severity: String?
}

struct CachedRecommendation: Codable {
    var title: String?
    var rationale: String?
    var action: String?
}

/// Manages persistent caching of AI-generated workout summaries
/// Uses UserDefaults for lightweight, fast storage of the most recent summary
class AISummaryCache {
    static let shared = AISummaryCache()

    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cachedAISummary"
    private let timestampKey = "cachedAISummaryTimestamp"

    private init() {}

    /// Save a generated summary to cache (runs on background thread for performance)
    @available(iOS 26, *)
    nonisolated func saveSummary(_ summary: WorkoutSummary.PartiallyGenerated) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }

            do {
                // Convert PartiallyGenerated to simple Codable struct
                let cached = CachedSummaryData(
                    headline: summary.headline,
                    overview: summary.overview,
                    keyStats: summary.keyStats?.map { CachedKeyStat(name: $0.name, value: $0.value, delta: $0.delta) },
                    trends: summary.trends?.map { CachedTrend(label: $0.label, direction: $0.direction, evidence: $0.evidence) },
                    prs: summary.prs?.map { CachedPR(exercise: $0.exercise, type: $0.type, value: $0.value) },
                    issues: summary.issues?.map { CachedIssue(category: $0.category, detail: $0.detail, severity: $0.severity) },
                    recommendations: summary.recommendations?.map { CachedRecommendation(title: $0.title, rationale: $0.rationale, action: $0.action) }
                )

                let encoder = JSONEncoder()
                let data = try encoder.encode(cached)

                self.userDefaults.set(data, forKey: self.cacheKey)
                self.userDefaults.set(Date(), forKey: self.timestampKey)

                #if DEBUG
                debugPrint("💾 AI SUMMARY CACHE: Saved summary to cache")
                #endif
            } catch {
                #if DEBUG
                debugPrint("❌ AI SUMMARY CACHE: Failed to save summary - \(error)")
                #endif
            }
        }
    }

    /// Load the cached summary data if available
    nonisolated func loadCachedData() -> CachedSummaryData? {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            #if DEBUG
            debugPrint("📭 AI SUMMARY CACHE: No cached summary found")
            #endif
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let cached = try decoder.decode(CachedSummaryData.self, from: data)

            #if DEBUG
            if let timestamp = getCacheTimestamp() {
                let age = Date().timeIntervalSince(timestamp)
                let days = Int(age / 86400)
                debugPrint("✅ AI SUMMARY CACHE: Loaded cached summary (generated \(days) days ago)")
            } else {
                debugPrint("✅ AI SUMMARY CACHE: Loaded cached summary")
            }
            #endif

            return cached
        } catch {
            #if DEBUG
            debugPrint("❌ AI SUMMARY CACHE: Failed to decode cached summary - \(error)")
            #endif
            // Clear corrupted cache
            clearCache()
            return nil
        }
    }

    /// Clear the cached summary
    nonisolated func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: timestampKey)
        #if DEBUG
        debugPrint("🗑️ AI SUMMARY CACHE: Cleared cache")
        #endif
    }

    /// Get the timestamp when the summary was generated
    nonisolated func getCacheTimestamp() -> Date? {
        return userDefaults.object(forKey: timestampKey) as? Date
    }

    /// Check if a cached summary exists
    nonisolated func hasCachedSummary() -> Bool {
        return userDefaults.data(forKey: cacheKey) != nil
    }

    /// Get a human-readable age string for the cached summary
    nonisolated func getCacheAgeString() -> String? {
        guard let timestamp = getCacheTimestamp() else {
            return nil
        }

        let age = Date().timeIntervalSince(timestamp)
        let days = Int(age / 86400)
        let hours = Int(age / 3600)
        let minutes = Int(age / 60)

        if days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}
