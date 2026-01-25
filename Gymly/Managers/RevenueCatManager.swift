//
//  RevenueCatManager.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 25.01.2025.
//

import Foundation
import RevenueCat

/// RevenueCat integration for analytics and subscription tracking
/// Works alongside existing StoreKit 2 implementation
@MainActor
class RevenueCatManager: ObservableObject {

    // MARK: - Singleton
    static let shared = RevenueCatManager()

    // MARK: - Published Properties
    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?

    // MARK: - Configuration
    // Use test key for development, production key for App Store
    #if DEBUG
    private static let apiKey = "test_HNRAFFFIWVsMVuezooTCBTNlNgx"
    #else
    private static let apiKey = "appl_yJyjKFfTWMAIpCqvbBKxdVkSydp"
    #endif

    // Entitlement identifiers (create these in RevenueCat dashboard)
    static let proEntitlementID = "pro"
    static let proAIEntitlementID = "pro_ai"

    // MARK: - Initialization
    private init() {}

    /// Configure RevenueCat - call once at app launch
    func configure() {
        guard !isConfigured else {
            debugLog("💰 RevenueCat: Already configured")
            return
        }

        debugLog("💰 RevenueCat: Configuring...")

        // Enable debug logs in development
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        // Configure RevenueCat
        Purchases.configure(withAPIKey: Self.apiKey)

        // Enable automatic collection of Apple Search Ads attribution
        Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()

        isConfigured = true
        debugLog("💰 RevenueCat: Configured successfully")

        // Fetch initial customer info
        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
    }

    // MARK: - Customer Info

    /// Refresh customer info from RevenueCat
    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
            debugLog("💰 RevenueCat: Customer info refreshed")
            debugLog("   Active entitlements: \(customerInfo?.entitlements.active.keys.joined(separator: ", ") ?? "none")")
        } catch {
            debugLog("❌ RevenueCat: Failed to get customer info: \(error)")
        }
    }

    /// Check if user has pro entitlement
    var hasPro: Bool {
        customerInfo?.entitlements[Self.proEntitlementID]?.isActive == true ||
        customerInfo?.entitlements[Self.proAIEntitlementID]?.isActive == true
    }

    /// Check if user has pro + AI entitlement
    var hasProAI: Bool {
        customerInfo?.entitlements[Self.proAIEntitlementID]?.isActive == true
    }

    // MARK: - Offerings

    /// Fetch available offerings (products)
    func fetchOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
            debugLog("💰 RevenueCat: Offerings fetched")
            if let current = offerings?.current {
                debugLog("   Current offering: \(current.identifier)")
                debugLog("   Packages: \(current.availablePackages.map { $0.identifier }.joined(separator: ", "))")
            }
        } catch {
            debugLog("❌ RevenueCat: Failed to fetch offerings: \(error)")
        }
    }

    // MARK: - Purchase Tracking

    /// Track a purchase made through StoreKit
    /// Call this after a successful StoreKit purchase to sync with RevenueCat
    func syncPurchase() async {
        debugLog("💰 RevenueCat: Syncing purchases...")
        do {
            customerInfo = try await Purchases.shared.syncPurchases()
            debugLog("💰 RevenueCat: Purchases synced successfully")
        } catch {
            debugLog("❌ RevenueCat: Failed to sync purchases: \(error)")
        }
    }

    /// Restore purchases
    func restorePurchases() async throws {
        debugLog("💰 RevenueCat: Restoring purchases...")
        customerInfo = try await Purchases.shared.restorePurchases()
        debugLog("💰 RevenueCat: Purchases restored")
    }

    // MARK: - User Identification

    /// Login user with their Apple ID or custom ID
    func login(userID: String) async {
        debugLog("💰 RevenueCat: Logging in user: \(userID)")
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userID)
            self.customerInfo = customerInfo
            debugLog("💰 RevenueCat: User logged in successfully")
        } catch {
            debugLog("❌ RevenueCat: Failed to login: \(error)")
        }
    }

    /// Logout current user
    func logout() async {
        debugLog("💰 RevenueCat: Logging out user...")
        do {
            customerInfo = try await Purchases.shared.logOut()
            debugLog("💰 RevenueCat: User logged out")
        } catch {
            debugLog("❌ RevenueCat: Failed to logout: \(error)")
        }
    }

    // MARK: - Attribution

    /// Set user attributes for analytics
    func setUserAttributes(email: String? = nil, displayName: String? = nil) {
        if let email = email {
            Purchases.shared.attribution.setEmail(email)
        }
        if let displayName = displayName {
            Purchases.shared.attribution.setDisplayName(displayName)
        }
        debugLog("💰 RevenueCat: User attributes updated")
    }

    /// Set campaign/ad attribution
    func setAdAttribution(source: String, campaign: String? = nil, adGroup: String? = nil, creative: String? = nil) {
        Purchases.shared.attribution.setMediaSource(source)
        if let campaign = campaign {
            Purchases.shared.attribution.setCampaign(campaign)
        }
        if let adGroup = adGroup {
            Purchases.shared.attribution.setAdGroup(adGroup)
        }
        if let creative = creative {
            Purchases.shared.attribution.setCreative(creative)
        }
        debugLog("💰 RevenueCat: Ad attribution set - source: \(source)")
    }

    // MARK: - Analytics Helpers

    /// Get subscription info for analytics
    var subscriptionInfo: (productID: String?, expirationDate: Date?, isTrialPeriod: Bool) {
        guard let entitlement = customerInfo?.entitlements.active.values.first else {
            return (nil, nil, false)
        }
        return (
            entitlement.productIdentifier,
            entitlement.expirationDate,
            entitlement.periodType == .trial
        )
    }
}
