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

    enum SubscriptionPlan {
        case monthly
        case yearly

        var price: String {
            switch self {
            case .monthly: return "2.99€"
            case .yearly: return "29.99€"
            }
        }

        var period: String {
            switch self {
            case .monthly: return "month"
            case .yearly: return "year"
            }
        }

        var savings: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "Save 17%"
            }
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
            .sheet(isPresented: $showTermsOfService) {
                LegalDocumentView(documentName: "terms-of-service", title: "Terms of Service")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                LegalDocumentView(documentName: "privacy-policy", title: "Privacy Policy")
            }
            .task {
                await storeManager.loadProducts()
                // Auto-select yearly if available (better value)
                if let yearlyProduct = storeManager.yearlyProduct {
                    selectedProduct = yearlyProduct
                } else if let monthlyProduct = storeManager.monthlyProduct {
                    selectedProduct = monthlyProduct
                }
            }
            .onChange(of: storeManager.isPremium) { _, isPremium in
                if isPremium {
                    dismiss()
                }
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
                        Text("You're Pro!")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Enjoy all features unlocked")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

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
                        .background(Color.black.opacity(0.2))
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
                        PremiumFeatureRow(icon: "apple.intelligence", title: "AI Workout Summary")
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
                                description: "Weekly insights & recommendations \n(iPhones with Apple Inteligence only)"
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

                        // Pricing Plans - REAL STOREKIT PRODUCTS
                        VStack(spacing: 12) {
                            Text("Choose Your Plan")
                                .font(.headline)
                                .padding(.top, 20)

                            if storeManager.products.isEmpty {
                                ProgressView("Loading subscription options...")
                                    .padding()
                            } else {
                                ForEach(storeManager.products) { product in
                                    PlanCardReal(
                                        product: product,
                                        isSelected: selectedProduct?.id == product.id,
                                        action: {
                                            selectedProduct = product
                                        }
                                    )
                                }
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
                        .disabled(storeManager.purchaseInProgress || selectedProduct == nil)
                        .opacity((storeManager.purchaseInProgress || selectedProduct == nil) ? 0.6 : 1.0)
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
                                        }
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .disabled(storeManager.purchaseInProgress)
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
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(appearanceManager.accentColor.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .foregroundStyle(appearanceManager.accentColor.color)
            }

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(appearanceManager.accentColor.color)
                .font(.title3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(appearanceManager.accentColor.color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Plan Card Component (Legacy - kept for fallback)
struct PlanCard: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    let plan: PremiumSubscriptionView.SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.period.capitalized)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let savings = plan.savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }

                    Text("\(plan.price)/\(plan.period)")
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
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? appearanceManager.accentColor.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plan Card Real (StoreKit Product)
struct PlanCardReal: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
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
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? appearanceManager.accentColor.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PremiumSubscriptionView()
}
