//
//  CrashReportsView.swift
//  ShadowLift
//
//  Created by Claude Code on 04.12.2025.
//

import SwiftUI
import MessageUI

struct CrashReportsView: View {
    @ObservedObject var crashReporter = CrashReporter.shared
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var showMailComposer = false
    @State private var showCantSendMailAlert = false
    @State private var showClearConfirmation = false

    var body: some View {
        ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()

                if crashReporter.pendingCrashReports.isEmpty {
                    // Empty State
                    emptyStateView
                } else {
                    // Reports List
                    reportsListView
                }
        }
        .navigationTitle("Crash Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !crashReporter.pendingCrashReports.isEmpty {
                        Menu {
                            Button(action: {
                                sendReports()
                            }) {
                                Label("Send to Developer", systemImage: "paperplane")
                            }

                            Button(role: .destructive, action: {
                                showClearConfirmation = true
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(
                    subject: "ShadowLift Crash Reports",
                    body: crashReporter.exportReports(),
                    recipient: "sebastian.kucera@icloud.com"
                )
            }
            .alert("Cannot Send Email", isPresented: $showCantSendMailAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please configure a mail account on your device to send crash reports.")
            }
            .alert("Clear All Reports?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    crashReporter.clearReports()
                }
            } message: {
                Text("This will permanently delete all crash reports. This action cannot be undone.")
            }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("No Crashes Detected")
                .font(.title2)
                .bold()

            Text("Your app is running smoothly. Crash reports will appear here if any issues occur.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.top, 100)
    }

    // MARK: - Reports List

    private var reportsListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info Banner
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(appearanceManager.accentColor.color)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Help Improve ShadowLift")
                            .font(.headline)

                        Text("Send these reports to help identify and fix issues. No personal workout data is included.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)

                // Reports
                ForEach(crashReporter.pendingCrashReports) { report in
                    CrashReportCard(report: report)
                        .padding(.horizontal)
                }

                // Send Button
                Button(action: {
                    sendReports()
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send All Reports to Developer")
                    }
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(appearanceManager.accentColor.color)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Text("Reports are sent via email and will be cleared after sending.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
    }


    // MARK: - Actions

    private func sendReports() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showCantSendMailAlert = true
        }
    }
}

// MARK: - Report Card

struct CrashReportCard: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    let report: CrashReport

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: report.isFatal ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(report.isFatal ? .red : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(report.isFatal ? "Crash" : "Error")
                        .font(.headline)

                    Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            // Reason
            Text(report.reason)
                .font(.subheadline)
                .lineLimit(isExpanded ? nil : 2)

            // Expanded Details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "App Version", value: "\(report.systemInfo.appVersion) (\(report.systemInfo.buildNumber))")
                    DetailRow(label: "Device", value: report.systemInfo.deviceModel)
                    DetailRow(label: "iOS Version", value: report.systemInfo.osVersion)
                    DetailRow(label: "Free Memory", value: "\(report.systemInfo.freeMemoryMB) MB")
                    DetailRow(label: "Free Disk", value: String(format: "%.2f GB", report.systemInfo.diskSpaceGB))

                    if !report.context.isEmpty {
                        Text("Additional Context:")
                            .font(.caption)
                            .bold()
                            .padding(.top, 4)

                        ForEach(Array(report.context.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            DetailRow(label: key, value: value)
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

// MARK: - Mail Composer

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipient: String

    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if result == .sent {
                // Clear reports after successful send
                Task { @MainActor in
                    CrashReporter.shared.clearReports()
                }
            }
            parent.dismiss()
        }
    }
}

#Preview {
    CrashReportsView()
        .environmentObject(AppearanceManager.shared)
}
