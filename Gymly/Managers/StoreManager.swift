//
//  StoreManager.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 28.11.2025.
//

import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var subscriptionStatus: SubscriptionStatus?
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published var errorMessage: String?

    // MARK: - Product IDs (will match App Store Connect when ready)
    // Pro tier (without AI features) - €3/month
    private let proMonthlyProductID = "com.icservis.shadowlift.pro.monthly"
    private let proYearlyProductID = "com.icservis.shadowlift.pro.yearly"

    // Pro + AI tier (with AI features) - €5/month
    private let proAIMonthlyProductID = "com.icservis.shadowlift.proai.monthly"
    private let proAIYearlyProductID = "com.icservis.shadowlift.proai.yearly"

    // Track which tier user has
    @Published private(set) var hasAIAccess: Bool = false

    // MARK: - Subscription Status
    enum SubscriptionStatus {
        case trial(expiresAt: Date)
        case active(expiresAt: Date)
        case expired
        case gracePeriod(expiresAt: Date)
        case cancelled(expiresAt: Date) // Cancelled but still has time left

        var isActive: Bool {
            switch self {
            case .trial, .active, .gracePeriod, .cancelled:
                return true
            case .expired:
                return false
            }
        }

        var displayText: String {
            switch self {
            case .trial(let date):
                return "Free Trial (expires \(formatDate(date)))"
            case .active(let date):
                return "Active (renews \(formatDate(date)))"
            case .expired:
                return "Expired"
            case .gracePeriod(let date):
                return "Payment Issue (expires \(formatDate(date)))"
            case .cancelled(let date):
                return "Cancelled (access until \(formatDate(date)))"
            }
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Transaction Listener
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Initialization
    init() {
        debugLog("🛒 StoreManager: Initializing...")

        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        guard !isLoadingProducts else {
            debugLog("⚠️ StoreManager: Already loading products, skipping...")
            return
        }

        isLoadingProducts = true
        errorMessage = nil
        debugLog("🛒 StoreManager: Loading products...")

        do {
            let productIDs = [proMonthlyProductID, proYearlyProductID, proAIMonthlyProductID, proAIYearlyProductID]
            products = try await Product.products(for: productIDs)

            if products.isEmpty {
                debugLog("⚠️ StoreManager: No products returned from App Store")
                errorMessage = "No subscription products available. Please try again later."
            } else {
                debugLog("✅ StoreManager: Loaded \(products.count) products")
                for product in products {
                    debugLog("   - \(product.displayName): \(product.displayPrice)")
                }
            }
        } catch {
            debugLog("❌ StoreManager: Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options. Please check your connection."
        }

        isLoadingProducts = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        guard !purchaseInProgress else {
            debugLog("⚠️ StoreManager: Purchase already in progress")
            return
        }

        debugLog("🛒 StoreManager: Starting purchase for \(product.displayName)...")
        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                debugLog("✅ StoreManager: Purchase successful, verifying...")

                // Verify transaction
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Finish transaction
                await transaction.finish()

                // Sync with RevenueCat for analytics
                await RevenueCatManager.shared.syncPurchase()

                debugLog("✅ StoreManager: Purchase complete for \(product.id)")

            case .userCancelled:
                debugLog("⚠️ StoreManager: User cancelled purchase")

            case .pending:
                debugLog("⚠️ StoreManager: Purchase pending (Ask to Buy)")
                errorMessage = "Purchase pending approval"

            @unknown default:
                debugLog("❌ StoreManager: Unknown purchase result")
                errorMessage = "Unknown purchase result"
            }
        } catch StoreError.failedVerification {
            errorMessage = "Purchase verification failed. Please try again."
            debugLog("❌ StoreManager: Failed verification")
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            debugLog("❌ StoreManager: Purchase error: \(error)")
        }

        purchaseInProgress = false
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        debugLog("🛒 StoreManager: Restoring purchases...")
        purchaseInProgress = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()

            // Sync with RevenueCat
            await RevenueCatManager.shared.syncPurchase()

            if isPremium {
                debugLog("✅ StoreManager: Purchases restored successfully")
            } else {
                debugLog("⚠️ StoreManager: No purchases to restore")
                errorMessage = "No active subscriptions found"
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            debugLog("❌ StoreManager: Restore failed: \(error)")
        }

        purchaseInProgress = false
    }

    // MARK: - Update Subscription Status
    func updateSubscriptionStatus() async {
        debugLog("🛒 StoreManager: Updating subscription status...")

        // Check for active subscriptions
        var activeSubscription: Product.SubscriptionInfo.Status?
        var highestPriorityProduct: Product?

        for product in products {
            guard let subscription = product.subscription else { continue }

            let statuses = try? await subscription.status

            // Find the highest priority active status
            if let status = statuses?.first(where: { $0.state == .subscribed || $0.state == .inGracePeriod }) {
                activeSubscription = status
                highestPriorityProduct = product
                break
            }
        }

        if let status = activeSubscription, let product = highestPriorityProduct {
            debugLog("✅ StoreManager: Found active subscription: \(product.displayName)")

            // Check if this is an AI tier subscription
            let isAITier = product.id == proAIMonthlyProductID || product.id == proAIYearlyProductID
            hasAIAccess = isAITier
            debugLog("   AI Access: \(isAITier)")

            // Verify the transaction
            guard let transaction = try? checkVerified(status.transaction) else {
                debugLog("❌ StoreManager: Transaction verification failed")
                isPremium = false
                subscriptionStatus = .expired
                return
            }

            let expirationDate = transaction.expirationDate ?? Date()

            // Get renewal info (verified)
            guard let renewalInfo = try? checkVerified(status.renewalInfo) else {
                debugLog("❌ StoreManager: Renewal info verification failed")
                isPremium = false
                subscriptionStatus = .expired
                return
            }

            // Determine subscription status
            switch status.state {
            case .subscribed:
                if renewalInfo.willAutoRenew {
                    // Check if in trial period - use offer instead of deprecated offerType
                    if transaction.offer?.type == .introductory {
                        subscriptionStatus = .trial(expiresAt: expirationDate)
                        debugLog("   Status: Free Trial (expires \(expirationDate))")
                    } else {
                        subscriptionStatus = .active(expiresAt: expirationDate)
                        debugLog("   Status: Active (renews \(expirationDate))")
                    }
                } else {
                    subscriptionStatus = .cancelled(expiresAt: expirationDate)
                    debugLog("   Status: Cancelled (access until \(expirationDate))")
                }
                isPremium = true

            case .inGracePeriod:
                subscriptionStatus = .gracePeriod(expiresAt: expirationDate)
                isPremium = true
                debugLog("   Status: Grace Period (expires \(expirationDate))")

            case .revoked:
                subscriptionStatus = .expired
                isPremium = false
                debugLog("   Status: Revoked")

            case .expired:
                subscriptionStatus = .expired
                isPremium = false
                debugLog("   Status: Expired")

            case .inBillingRetryPeriod:
                // Keep premium active during billing retry
                subscriptionStatus = .gracePeriod(expiresAt: expirationDate)
                isPremium = true
                debugLog("   Status: Billing Retry Period")

            default:
                // Handle any future subscription states
                subscriptionStatus = .expired
                isPremium = false
                debugLog("   Status: Unknown (treating as expired)")
            }
        } else {
            // No active subscription
            isPremium = false
            hasAIAccess = false
            subscriptionStatus = .expired
            debugLog("⚠️ StoreManager: No active subscription found")
        }

        debugLog("🛒 StoreManager: isPremium = \(isPremium), hasAIAccess = \(hasAIAccess)")
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }

            debugLog("🛒 StoreManager: Started listening for transaction updates...")

            for await result in Transaction.updates {
                do {
                    // checkVerified is not actor-isolated, so we can call it directly
                    let transaction = try await self.checkVerifiedAsync(result)

                    debugLog("🛒 StoreManager: Received transaction update for \(transaction.productID)")

                    // Update subscription status on main thread
                    _ = await MainActor.run {
                        Task { @MainActor in
                            await self.updateSubscriptionStatus()
                        }
                    }

                    await transaction.finish()
                } catch {
                    debugLog("❌ StoreManager: Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Async Transaction Verification (for background task)
    private func checkVerifiedAsync<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            debugLog("❌ StoreManager: Transaction unverified")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            debugLog("❌ StoreManager: Transaction unverified")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Debug: Toggle Premium (for testing only)
    #if DEBUG
    func debugTogglePremium() {
        isPremium.toggle()
        debugLog("🧪 DEBUG: Premium toggled to \(isPremium)")
    }

    func debugSetPremium(_ value: Bool) {
        isPremium = value
        debugLog("🧪 DEBUG: Premium set to \(isPremium)")
    }

    func debugToggleAIAccess() {
        hasAIAccess.toggle()
        debugLog("🧪 DEBUG: AI Access toggled to \(hasAIAccess)")
    }
    #endif

    // MARK: - Helper: Get Product by ID
    func getProduct(for productID: String) -> Product? {
        return products.first(where: { $0.id == productID })
    }

    // MARK: - Pro Tier Products (without AI)
    var proMonthlyProduct: Product? {
        return getProduct(for: proMonthlyProductID)
    }

    var proYearlyProduct: Product? {
        return getProduct(for: proYearlyProductID)
    }

    // MARK: - Pro + AI Tier Products
    var proAIMonthlyProduct: Product? {
        return getProduct(for: proAIMonthlyProductID)
    }

    var proAIYearlyProduct: Product? {
        return getProduct(for: proAIYearlyProductID)
    }

    // MARK: - Check Device AI Capability
    static var deviceSupportsAI: Bool {
        if #available(iOS 26, *) {
            // FoundationModels requires iPhone 15 Pro or newer (A17 Pro chip)
            // Check using model identifier
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            let identifier = machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }

            // iPhone 15 Pro (iPhone16,1), iPhone 15 Pro Max (iPhone16,2), iPhone 16 series
            let aiCapableDevices = ["iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4"]
            return aiCapableDevices.contains(identifier) || identifier.contains("iPhone17") || identifier.contains("iPhone18")
        }
        return false
    }
}

// MARK: - Store Errors
enum StoreError: Error {
    case failedVerification
    case purchaseFailed
    case unknown

    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
