//
//  ProgressPhotosLockedView.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import SwiftUI

struct ProgressPhotosLockedView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State private var showPremiumView = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Progress Photos")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
            }
            .padding()
            .background(Color.black.opacity(0.05))

            // Locked Content
            VStack(spacing: 24) {
                Spacer()

                // Lock Icon
                ZStack {
                    Circle()
                        .fill(appearanceManager.accentColor.color.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(appearanceManager.accentColor.color)
                }

                // Title
                Text("Progress Photos")
                    .font(.title2)
                    .bold()

                // Description
                Text("Track your transformation with progress photos. Compare before & after, see your journey, and stay motivated.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureCheckmark(text: "Unlimited progress photos")
                    FeatureCheckmark(text: "Side-by-side comparisons")
                    FeatureCheckmark(text: "Pose guides for consistency")
                    FeatureCheckmark(text: "Auto-link with weight data")
                    FeatureCheckmark(text: "iCloud sync across devices")
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)

                // Upgrade Button
                Button(action: {
                    showPremiumView = true
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Pro")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(appearanceManager.accentColor.color)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.top, 24)

                Spacer()
            }
            .padding(.vertical, 40)
        }
        .background(Color.clear)
        .sheet(isPresented: $showPremiumView) {
            PremiumSubscriptionView()
        }
    }
}

struct FeatureCheckmark: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

#Preview {
    ProgressPhotosLockedView()
        .environmentObject(AppearanceManager())
}
