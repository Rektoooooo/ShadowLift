//
//  ContactSupportView.swift
//  ShadowLift
//
//  Created by Claude Code on 13.11.2024.
//

import SwiftUI
import MessageUI

struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State private var showMailComposer = false
    @State private var showMailAlert = false
    @State private var selectedSupportType: SupportType = .general

    enum SupportType: String, CaseIterable {
        case general = "General Support"
        case bug = "Report a Bug"
        case feature = "Feature Request"
        case billing = "Billing Question"

        var email: String {
            switch self {
            case .general:
                return "support@shadowlift.app"
            case .bug:
                return "support@shadowlift.app"
            case .feature:
                return "hello@shadowlift.app"
            case .billing:
                return "support@shadowlift.app"
            }
        }

        var subject: String {
            switch self {
            case .general:
                return "Shadowlift Support Request"
            case .bug:
                return "Bug Report: [Brief Description]"
            case .feature:
                return "Feature Request: [Your Idea]"
            case .billing:
                return "Billing Question"
            }
        }

        var icon: String {
            switch self {
            case .general:
                return "questionmark.circle.fill"
            case .bug:
                return "ladybug.fill"
            case .feature:
                return "lightbulb.fill"
            case .billing:
                return "creditcard.fill"
            }
        }

        var color: Color {
            switch self {
            case .general:
                return .blue
            case .bug:
                return .red
            case .feature:
                return .yellow
            case .billing:
                return .green
            }
        }
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.accent(scheme, accentColor: appearanceManager.accentColor))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(appearanceManager.accentColor.color)

                        Text("Contact Support")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("We're here to help!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                        // Support Type Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What can we help you with?")
                                .font(.headline)
                                .padding(.horizontal, 24)

                            ForEach(SupportType.allCases, id: \.self) { type in
                                Button(action: {
                                    selectedSupportType = type
                                    openEmailComposer()
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(type.color)
                                            .frame(width: 40)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(type.rawValue)
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text(type.email)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)

                        Divider()
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)

                        // Quick Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Before You Contact Us")
                                .font(.headline)
                                .padding(.horizontal, 24)

                            VStack(alignment: .leading, spacing: 12) {
                                SupportInfoRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Check the FAQ for quick answers",
                                    color: .green
                                )

                                SupportInfoRow(
                                    icon: "arrow.clockwise.circle.fill",
                                    text: "Try restarting the app first",
                                    color: .blue
                                )

                                SupportInfoRow(
                                    icon: "arrow.down.circle.fill",
                                    text: "Make sure you're on the latest version",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal, 24)
                        }

                        // Response Time
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.secondary)
                                Text("Response Time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Within 24 hours on weekdays")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Email Not Available", isPresented: $showMailAlert) {
                Button("Copy Email", action: {
                    UIPasteboard.general.string = selectedSupportType.email
                })
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please send an email to \(selectedSupportType.email) from your mail app. The email address has been copied to your clipboard.")
            }
        }

    private func openEmailComposer() {
        // Get device info for support email
        let deviceModel = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        let body = """


        ---
        Device Information (Please don't remove):
        Device: \(deviceModel)
        iOS Version: \(osVersion)
        App Version: \(appVersion) (Build \(buildNumber))
        """

        let urlString = "mailto:\(selectedSupportType.email)?subject=\(selectedSupportType.subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback if mail app not available
            UIPasteboard.general.string = selectedSupportType.email
            showMailAlert = true
        }
    }
}

// MARK: - Support Info Row Component
struct SupportInfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

#Preview {
    ContactSupportView()
        .environmentObject(AppearanceManager())
}
