//
//  PremiumSubscriptionView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 20.10.2025.
//

import SwiftUI
import StoreKit

struct PremiumSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var config: Config
    @EnvironmentObject var storeManager: StoreManager
    @State private var selectedProduct: Product?
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showError = false
    @State private var showRestoreSuccess = false
    @State private var selectedTier: SubscriptionTier = .pro
    @State private var selectedPeriod: SubscriptionPeriod = .yearly

    enum SubscriptionTier {
        case pro      // €3/month - without AI
        case proAI    // €5/month - with AI features
    }

    enum SubscriptionPeriod {
        case monthly
        case yearly
    }

    // Check if device supports AI features
    private var deviceSupportsAI: Bool {
        StoreManager.deviceSupportsAI
    }

    // Get products for selected tier
    private var productsForSelectedTier: [Product] {
        switch selectedTier {
        case .pro:
            return [storeManager.proMonthlyProduct, storeManager.proYearlyProduct].compactMap { $0 }
        case .proAI:
            return [storeManager.proAIMonthlyProduct, storeManager.proAIYearlyProduct].compactMap { $0 }
        }
    }

    // Get the selected product based on tier and period
    private var currentSelectedProduct: Product? {
        switch (selectedTier, selectedPeriod) {
        case (.pro, .monthly):
            return storeManager.proMonthlyProduct
        case (.pro, .yearly):
            return storeManager.proYearlyProduct
        case (.proAI, .monthly):
            return storeManager.proAIMonthlyProduct
        case (.proAI, .yearly):
            return storeManager.proAIYearlyProduct
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.premium(scheme))
                    .ignoresSafeArea()

                if config.isPremium {
                    premiumUserView
                } else {
                    upgradeView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storeManager.errorMessage ?? "An unknown error occurred")
            }
            .alert("Restore Successful", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your premium subscription has been restored successfully!")
            }
            .sheet(isPresented: $showTermsOfService) {
                LegalDocumentView(documentName: "terms-of-service", title: "Terms of Service")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                LegalDocumentView(documentName: "privacy-policy", title: "Privacy Policy")
            }
            .task {
                await storeManager.loadProducts()
                // Set default tier based on device capability
                // If device doesn't support AI, default to Pro tier
                if !deviceSupportsAI {
                    selectedTier = .pro
                }
                // Auto-select the product based on tier and period
                selectedProduct = currentSelectedProduct
            }
            .onChange(of: storeManager.isPremium) { _, isPremium in
                if isPremium {
                    dismiss()
                }
            }
            .onChange(of: storeManager.errorMessage) { _, newError in
                if newError != nil {
                    showError = true
                }
            }
            .onChange(of: selectedTier) { _, _ in
                selectedProduct = currentSelectedProduct
            }
            .onChange(of: selectedPeriod) { _, _ in
                selectedProduct = currentSelectedProduct
            }
        }
    }

    // MARK: - Premium User View
    private var premiumUserView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Success Header
                VStack(spacing: 20) {
                    Image(.shadowPremium)
                        .resizable()
                        .frame(width: 300, height: 300)

                    VStack(spacing: 8) {
                        Text(storeManager.hasAIAccess ? "You're Pro+AI!" : "You're Pro!")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(storeManager.hasAIAccess ? "All features including AI unlocked" : "Enjoy all premium features")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Tier badge
                        HStack(spacing: 8) {
                            Text(storeManager.hasAIAccess ? "Pro + AI" : "Pro")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(storeManager.hasAIAccess ? Color.purple : appearanceManager.accentColor.color)
                                .cornerRadius(20)
                        }
                        .padding(.top, 4)

                        // Subscription status
                        if let status = storeManager.subscriptionStatus {
                            Text(status.displayText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.top, 40)

                // Subscription Management
                VStack(spacing: 16) {
                    Text("Subscription Management")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        // Current Plan Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .foregroundColor(appearanceManager.accentColor.color)
                                Text("Current Plan")
                                    .font(.headline)
                                Spacer()
                            }

                            if storeManager.subscriptionStatus != nil,
                               let product = storeManager.products.first {
                                Text(product.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(product.displayPrice + "/" + (product.subscription?.subscriptionPeriod.unit == .month ? "month" : "year"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("ShadowLift Pro")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Active subscription")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.listRowBackground(for: scheme))
                        .cornerRadius(12)

                        // Manage Subscription Button
                        Button(action: {
                            // Open iOS Settings to manage subscription
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.white)
                                Text("Manage Subscription")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        // Info text
                        Text("Change plan, cancel, or manage your subscription in the App Store")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)

                // Features List with Checkmarks
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Pro Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        PremiumFeatureRow(icon: "trophy.fill", title: "Automatic PR Tracking")
                        PremiumFeatureRow(icon: "camera.fill", title: "Progress Photo Timeline")
                        PremiumFeatureRow(
                            icon: "apple.intelligence",
                            title: "AI Workout Summary",
                            requiresAI: true,
                            hasAIAccess: storeManager.hasAIAccess,
                            deviceSupportsAI: deviceSupportsAI
                        )
                        PremiumFeatureRow(
                            icon: "wand.and.stars",
                            title: "AI Personalized Split",
                            requiresAI: true,
                            hasAIAccess: storeManager.hasAIAccess,
                            deviceSupportsAI: deviceSupportsAI
                        )
                        PremiumFeatureRow(icon: "book.fill", title: "Workout Templates")
                        PremiumFeatureRow(icon: "flame.fill", title: "Advanced Streak Analytics")
                        PremiumFeatureRow(icon: "figure.arms.open", title: "BMI Tracking & Analysis")
                        PremiumFeatureRow(icon: "calendar", title: "Unlimited History")
                        PremiumFeatureRow(icon: "paintbrush.fill", title: "Custom App Appearance")
                        PremiumFeatureRow(icon: "chart.bar.fill", title: "Advanced Graph Statistics")
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Upgrade View
    private var upgradeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(.shadowPremium)
                        .resizable()
                        .frame(width: 300, height: 300)

                    Text("ShadowLift Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Unlock your full potential")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)

                        // Features List
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "trophy.fill",
                                title: "Automatic PR Tracking",
                                description: "Never miss a personal record"
                            )

                            FeatureRow(
                                icon: "camera.fill",
                                title: "Progress Photo Timeline",
                                description: "Track your visual transformation"
                            )

                            FeatureRow(
                                icon: "apple.intelligence",
                                title: "AI Workout Summary",
                                description: "Weekly insights & recommendations",
                                requiresAI: true,
                                deviceSupportsAI: deviceSupportsAI
                            )

                            FeatureRow(
                                icon: "wand.and.stars",
                                title: "AI Personalized Split",
                                description: "Generate custom workout plans with AI",
                                requiresAI: true,
                                deviceSupportsAI: deviceSupportsAI
                            )

                            FeatureRow(
                                icon: "book.fill",
                                title: "Workout Templates",
                                description: "Pre-built programs for your goals"
                            )

                            FeatureRow(
                                icon: "flame.fill",
                                title: "Advanced Streak Analytics",
                                description: "Motivation & predictions"
                            )

                            FeatureRow(
                                icon: "figure.arms.open",
                                title: "BMI Tracking & Analysis",
                                description: "Monitor your body composition"
                            )

                            FeatureRow(
                                icon: "calendar",
                                title: "Unlimited History",
                                description: "Lifetime workout access"
                            )

                            FeatureRow(
                                icon: "paintbrush.fill",
                                title: "Custom App Appearance",
                                description: "Choose your theme & colors"
                            )

                            FeatureRow(
                                icon: "chart.bar.fill",
                                title: "Advanced Graph Statistics",
                                description: "Week, month & all-time filtering"
                            )
                        }
                        .padding(.horizontal, 24)

                        // Tier Selection with Segmented Picker
                        VStack(spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.headline)
                                .padding(.top, 20)

                            if deviceSupportsAI {
                                // Segmented picker for Pro | Pro AI
                                Picker("Plan", selection: $selectedTier) {
                                    Text("Pro").tag(SubscriptionTier.pro)
                                    Text("Pro + AI").tag(SubscriptionTier.proAI)
                                }
                                .pickerStyle(.segmented)

                                // Tier description
                                Text(selectedTier == .pro ? "All premium features" : "Premium + AI-powered features")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                // Device doesn't support AI - show info
                                Text("ShadowLift Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                    Text("Pro + AI requires iPhone 15 Pro or newer")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Pricing Cards
                        VStack(spacing: 12) {
                            if storeManager.isLoadingProducts {
                                // Loading state
                                ProgressView("Loading prices...")
                                    .padding()
                            } else if storeManager.products.isEmpty {
                                // Error/empty state with retry
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)

                                    Text(storeManager.errorMessage ?? "Unable to load subscription options")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)

                                    Button("Try Again") {
                                        Task {
                                            await storeManager.loadProducts()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding()
                            } else {
                                // Monthly option
                                SubscriptionOptionCard(
                                    title: "Monthly",
                                    product: selectedTier == .pro ? storeManager.proMonthlyProduct : storeManager.proAIMonthlyProduct,
                                    isSelected: selectedPeriod == .monthly,
                                    action: { selectedPeriod = .monthly }
                                )

                                // Yearly option
                                SubscriptionOptionCard(
                                    title: "Yearly",
                                    product: selectedTier == .pro ? storeManager.proYearlyProduct : storeManager.proAIYearlyProduct,
                                    isSelected: selectedPeriod == .yearly,
                                    badge: "Save 17%",
                                    action: { selectedPeriod = .yearly }
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        // CTA Button - REAL PURCHASE
                        Button(action: {
                            guard let product = selectedProduct else { return }
                            Task {
                                await storeManager.purchase(product)
                                if storeManager.errorMessage != nil {
                                    showError = true
                                }
                            }
                        }) {
                            VStack(spacing: 8) {
                                if storeManager.purchaseInProgress {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Text("Start 7-Day Free Trial")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    if let product = selectedProduct {
                                        let period = product.subscription?.subscriptionPeriod.unit == .month ? "month" : "year"
                                        Text("Then \(product.displayPrice)/\(period)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(appearanceManager.accentColor.color)
                            .cornerRadius(12)
                        }
                        .disabled(storeManager.purchaseInProgress || selectedProduct == nil || storeManager.products.isEmpty)
                        .opacity((storeManager.purchaseInProgress || selectedProduct == nil || storeManager.products.isEmpty) ? 0.6 : 1.0)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Fine Print
                        VStack(spacing: 8) {
                            Text("Cancel anytime. No commitment.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                Button("Terms of Service") {
                                    showTermsOfService = true
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                                Button("Privacy Policy") {
                                    showPrivacyPolicy = true
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                                Button("Restore Purchase") {
                                    Task {
                                        await storeManager.restorePurchases()
                                        if storeManager.errorMessage != nil {
                                            showError = true
                                        } else if storeManager.isPremium {
                                            showRestoreSuccess = true
                                        }
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .disabled(storeManager.purchaseInProgress)
                                .accessibilityLabel("Restore Purchase")
                                .accessibilityHint("Double tap to restore your previous subscription purchase")
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    


// MARK: - Premium Feature Row (Simple checkmark row for premium users)
struct PremiumFeatureRow: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var scheme
    let icon: String
    let title: String
    var requiresAI: Bool = false
    var hasAIAccess: Bool = true
    var deviceSupportsAI: Bool = true

    private var isAvailable: Bool {
        if requiresAI {
            return hasAIAccess && deviceSupportsAI
        }
        return true
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((isAvailable ? appearanceManager.accentColor.color : Color.gray).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .foregroundStyle(isAvailable ? appearanceManager.accentColor.color : Color.gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(isAvailable ? .primary : .secondary)

                    if requiresAI && !hasAIAccess {
                        Text("Pro+AI")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                }

                if requiresAI && !deviceSupportsAI {
                    Text("Requires iPhone 15 Pro or newer")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if requiresAI && !hasAIAccess {
                    Text("Upgrade to Pro+AI to unlock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(appearanceManager.accentColor.color)
                    .font(.title3)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.gray)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.listRowBackground(for: scheme))
        .cornerRadius(12)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    let icon: String
    let title: String
    let description: String
    var requiresAI: Bool = false
    var deviceSupportsAI: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(requiresAI && !deviceSupportsAI ? .gray : appearanceManager.accentColor.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(requiresAI && !deviceSupportsAI ? .secondary : .primary)

                    if requiresAI {
                        Text("Pro+AI")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(deviceSupportsAI ? Color.purple : Color.gray)
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if requiresAI && !deviceSupportsAI {
                    Text("Requires iPhone 15 Pro or newer")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Plan Card Real (StoreKit Product)
struct PlanCardReal: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var scheme
    let product: Product
    let isSelected: Bool
    let action: () -> Void

    private var isYearly: Bool {
        product.subscription?.subscriptionPeriod.unit == .year
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if isYearly {
                            Text("Save 17%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }

                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(appearanceManager.accentColor.color)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.listRowBackground(for: scheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? appearanceManager.accentColor.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tier Card Component
struct TierCard: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var scheme
    let title: String
    let price: String
    let description: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(6)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(price)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.listRowBackground(for: scheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? appearanceManager.accentColor.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Period Card Component
struct PeriodCard: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var scheme
    let period: PremiumSubscriptionView.SubscriptionPeriod
    let product: Product?
    let isSelected: Bool
    var savings: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack {
                    Text(period == .monthly ? "Monthly" : "Yearly")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let savings = savings {
                        Text(savings)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let product = product {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    if period == .yearly {
                        Text("per year")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.listRowBackground(for: scheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? appearanceManager.accentColor.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Option Card (New cleaner design)
struct SubscriptionOptionCard: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var scheme
    let title: String
    let product: Product?
    let isSelected: Bool
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // Left side - Title and badge
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                    }

                    if let product = product {
                        if title == "Yearly", let monthly = calculateMonthlyPrice(from: product) {
                            Text("\(monthly)/month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Right side - Price
                if let product = product {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? appearanceManager.accentColor.color : .gray.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.listRowBackground(for: scheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? appearanceManager.accentColor.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func calculateMonthlyPrice(from product: Product) -> String? {
        guard product.subscription?.subscriptionPeriod.unit == .year else { return nil }
        let yearlyPrice = product.price
        let monthlyPrice = yearlyPrice / 12
        return monthlyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))
    }
}

#Preview {
    PremiumSubscriptionView()
}
