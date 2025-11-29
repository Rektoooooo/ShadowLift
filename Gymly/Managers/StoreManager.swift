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
    @Published var errorMessage: String?

    // MARK: - Product IDs (will match App Store Connect when ready)
    private let monthlyProductID = "com.icservis.shadowlift.pro.monthly"
    private let yearlyProductID = "com.icservis.shadowlift.pro.yearly"

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
        print("🛒 StoreManager: Initializing...")

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
        print("🛒 StoreManager: Loading products...")

        do {
            let productIDs = [monthlyProductID, yearlyProductID]
            products = try await Product.products(for: productIDs)

            print("✅ StoreManager: Loaded \(products.count) products")
            for product in products {
                print("   - \(product.displayName): \(product.displayPrice)")
            }
        } catch {
            print("❌ StoreManager: Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        guard !purchaseInProgress else {
            print("⚠️ StoreManager: Purchase already in progress")
            return
        }

        print("🛒 StoreManager: Starting purchase for \(product.displayName)...")
        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                print("✅ StoreManager: Purchase successful, verifying...")

                // Verify transaction
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Finish transaction
                await transaction.finish()

                print("✅ StoreManager: Purchase complete for \(product.id)")

            case .userCancelled:
                print("⚠️ StoreManager: User cancelled purchase")

            case .pending:
                print("⚠️ StoreManager: Purchase pending (Ask to Buy)")
                errorMessage = "Purchase pending approval"

            @unknown default:
                print("❌ StoreManager: Unknown purchase result")
                errorMessage = "Unknown purchase result"
            }
        } catch StoreError.failedVerification {
            errorMessage = "Purchase verification failed. Please try again."
            print("❌ StoreManager: Failed verification")
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ StoreManager: Purchase error: \(error)")
        }

        purchaseInProgress = false
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        print("🛒 StoreManager: Restoring purchases...")
        purchaseInProgress = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()

            if isPremium {
                print("✅ StoreManager: Purchases restored successfully")
            } else {
                print("⚠️ StoreManager: No purchases to restore")
                errorMessage = "No active subscriptions found"
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ StoreManager: Restore failed: \(error)")
        }

        purchaseInProgress = false
    }

    // MARK: - Update Subscription Status
    func updateSubscriptionStatus() async {
        print("🛒 StoreManager: Updating subscription status...")

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
            print("✅ StoreManager: Found active subscription: \(product.displayName)")

            // Verify the transaction
            guard let transaction = try? checkVerified(status.transaction) else {
                print("❌ StoreManager: Transaction verification failed")
                isPremium = false
                subscriptionStatus = .expired
                return
            }

            let expirationDate = transaction.expirationDate ?? Date()

            // Get renewal info (verified)
            guard let renewalInfo = try? checkVerified(status.renewalInfo) else {
                print("❌ StoreManager: Renewal info verification failed")
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
                        print("   Status: Free Trial (expires \(expirationDate))")
                    } else {
                        subscriptionStatus = .active(expiresAt: expirationDate)
                        print("   Status: Active (renews \(expirationDate))")
                    }
                } else {
                    subscriptionStatus = .cancelled(expiresAt: expirationDate)
                    print("   Status: Cancelled (access until \(expirationDate))")
                }
                isPremium = true

            case .inGracePeriod:
                subscriptionStatus = .gracePeriod(expiresAt: expirationDate)
                isPremium = true
                print("   Status: Grace Period (expires \(expirationDate))")

            case .revoked:
                subscriptionStatus = .expired
                isPremium = false
                print("   Status: Revoked")

            case .expired:
                subscriptionStatus = .expired
                isPremium = false
                print("   Status: Expired")

            case .inBillingRetryPeriod:
                // Keep premium active during billing retry
                subscriptionStatus = .gracePeriod(expiresAt: expirationDate)
                isPremium = true
                print("   Status: Billing Retry Period")

            default:
                // Handle any future subscription states
                subscriptionStatus = .expired
                isPremium = false
                print("   Status: Unknown (treating as expired)")
            }
        } else {
            // No active subscription
            isPremium = false
            subscriptionStatus = .expired
            print("⚠️ StoreManager: No active subscription found")
        }

        print("🛒 StoreManager: isPremium = \(isPremium)")
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }

            print("🛒 StoreManager: Started listening for transaction updates...")

            for await result in Transaction.updates {
                do {
                    // checkVerified is not actor-isolated, so we can call it directly
                    let transaction = try await self.checkVerifiedAsync(result)

                    print("🛒 StoreManager: Received transaction update for \(transaction.productID)")

                    // Update subscription status on main thread
                    _ = await MainActor.run {
                        Task { @MainActor in
                            await self.updateSubscriptionStatus()
                        }
                    }

                    await transaction.finish()
                } catch {
                    print("❌ StoreManager: Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Async Transaction Verification (for background task)
    private func checkVerifiedAsync<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            print("❌ StoreManager: Transaction unverified")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            print("❌ StoreManager: Transaction unverified")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helper: Get Product by ID
    func getProduct(for productID: String) -> Product? {
        return products.first(where: { $0.id == productID })
    }

    // MARK: - Helper: Monthly Product
    var monthlyProduct: Product? {
        return getProduct(for: monthlyProductID)
    }

    // MARK: - Helper: Yearly Product
    var yearlyProduct: Product? {
        return getProduct(for: yearlyProductID)
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
