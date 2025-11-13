//
//  CloudKitSyncStatus.swift
//  ShadowLift
//
//  Created by CloudKit Integration on 18.09.2025.
//

import SwiftUI
import CloudKit

struct CloudKitSyncStatus: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @EnvironmentObject var config: Config

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "icloud")
                    .foregroundColor(statusColor)
                Text("iCloud Sync")
                    .font(.headline)
                Spacer()
                if cloudKitManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)

            if let lastSync = cloudKitManager.lastSyncDate {
                Text("Last synced: \(lastSync, formatter: DateFormatter.shortDateTime)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = cloudKitManager.syncError {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .task {
            await cloudKitManager.checkCloudKitStatus()
        }
    }

    private var statusColor: Color {
        if cloudKitManager.isSyncing {
            return .blue
        } else if cloudKitManager.syncError != nil {
            return .red
        } else if cloudKitManager.isCloudKitEnabled && config.isCloudKitEnabled {
            return .green
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if cloudKitManager.isSyncing {
            return "Syncing..."
        } else if cloudKitManager.syncError != nil {
            return "Sync unavailable"
        } else if cloudKitManager.isCloudKitEnabled && config.isCloudKitEnabled {
            return "Sync enabled"
        } else if !cloudKitManager.isCloudKitEnabled {
            return "iCloud unavailable"
        } else {
            return "Sync disabled"
        }
    }
}