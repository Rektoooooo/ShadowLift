//
//  PremiumSubscriptionView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 20.10.2025.
//

import SwiftUI

struct PremiumSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State private var selectedPlan: SubscriptionPlan = .monthly

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

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.yellow)

                            Text("Gymly Pro")
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
                                icon: "brain.head.profile",
                                title: "Smart Progression Coach",
                                description: "AI suggests optimal weight increases"
                            )

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
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Extended Analytics",
                                description: "Week, month, and all-time graphs"
                            )

                            FeatureRow(
                                icon: "apple.intelligence",
                                title: "AI Workout Summary",
                                description: "Weekly insights & recommendations"
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
                                icon: "square.and.arrow.up",
                                title: "Export Your Data",
                                description: "CSV/PDF reports anytime"
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
                        }
                        .padding(.horizontal, 24)

                        // Pricing Plans
                        VStack(spacing: 12) {
                            Text("Choose Your Plan")
                                .font(.headline)
                                .padding(.top, 20)

                            // Monthly Plan
                            PlanCard(
                                plan: .monthly,
                                isSelected: selectedPlan == .monthly
                            ) {
                                selectedPlan = .monthly
                            }

                            // Yearly Plan
                            PlanCard(
                                plan: .yearly,
                                isSelected: selectedPlan == .yearly
                            ) {
                                selectedPlan = .yearly
                            }
                        }
                        .padding(.horizontal, 24)

                        // CTA Button
                        Button(action: {
                            // TODO: Implement subscription purchase
                            print("Starting subscription: \(selectedPlan)")
                        }) {
                            VStack(spacing: 8) {
                                Text("Start 7-Day Free Trial")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Then \(selectedPlan.price)/\(selectedPlan.period)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(appearanceManager.accentColor.color)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Fine Print
                        VStack(spacing: 8) {
                            Text("Cancel anytime. No commitment.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                Button("Terms of Service") {
                                    // TODO: Open terms
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                                Button("Privacy Policy") {
                                    // TODO: Open privacy
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                                Button("Restore Purchase") {
                                    // TODO: Restore purchase
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
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

// MARK: - Plan Card Component
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

#Preview {
    PremiumSubscriptionView()
}
