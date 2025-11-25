//
//  ProgressPhotoCompareView.swift
//  ShadowLift
//
//  Created by Claude Code on 27.10.2025.
//

import SwiftUI
import SwiftData

struct ProgressPhotoCompareView: View {
    let photo1: ProgressPhoto // Before
    let photo2: ProgressPhoto // After

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appearanceManager: AppearanceManager

    @StateObject private var photoManager = PhotoManager.shared

    @State private var image1: UIImage?
    @State private var image2: UIImage?

    // Determine which is before/after based on date
    private var beforePhoto: ProgressPhoto {
        guard let date1 = photo1.date, let date2 = photo2.date else { return photo1 }
        return date1 < date2 ? photo1 : photo2
    }

    private var afterPhoto: ProgressPhoto {
        guard let date1 = photo1.date, let date2 = photo2.date else { return photo2 }
        return date1 < date2 ? photo2 : photo1
    }

    private var beforeImage: UIImage? {
        guard let date1 = photo1.date, let date2 = photo2.date else { return image1 }
        return date1 < date2 ? image1 : image2
    }

    private var afterImage: UIImage? {
        guard let date1 = photo1.date, let date2 = photo2.date else { return image2 }
        return date1 < date2 ? image2 : image1
    }

    private var daysDifference: Int {
        guard let beforeDate = beforePhoto.date, let afterDate = afterPhoto.date else { return 0 }
        return Calendar.current.dateComponents([.day], from: beforeDate, to: afterDate).day ?? 0
    }

    private var weightDifference: Double {
        let before = beforePhoto.weight ?? 0
        let after = afterPhoto.weight ?? 0
        return after - before
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Side-by-Side Photos
                    HStack(spacing: 12) {
                        // Before
                        VStack(spacing: 8) {
                            Text("Before")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .bold()

                            if let image = beforeImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 300)
                                    .overlay(ProgressView())
                                    .cornerRadius(12)
                            }

                            VStack(spacing: 4) {
                                if let date = beforePhoto.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .bold()
                                }

                                if let weight = beforePhoto.weight {
                                    Text(String(format: "%.1f kg", weight))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // After
                        VStack(spacing: 8) {
                            Text("After")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .bold()

                            if let image = afterImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 300)
                                    .overlay(ProgressView())
                                    .cornerRadius(12)
                            }

                            VStack(spacing: 4) {
                                if let date = afterPhoto.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .bold()
                                }

                                if let weight = afterPhoto.weight {
                                    Text(String(format: "%.1f kg", weight))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Stats
                    VStack(spacing: 16) {
                        Text("Progress Summary")
                            .font(.headline)

                        HStack(spacing: 20) {
                            // Days
                            StatCard(
                                icon: "calendar",
                                value: "\(daysDifference)",
                                label: "Days",
                                color: .blue
                            )

                            // Weight Change
                            if beforePhoto.weight != nil && afterPhoto.weight != nil {
                                StatCard(
                                    icon: weightDifference < 0 ? "arrow.down" : "arrow.up",
                                    value: String(format: "%.1f kg", abs(weightDifference)),
                                    label: weightDifference < 0 ? "Lost" : "Gained",
                                    color: weightDifference < 0 ? .green : .orange
                                )
                            }

                            // Type
                            StatCard(
                                icon: "figure.stand",
                                value: beforePhoto.photoType?.rawValue ?? "Front",
                                label: "View",
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Share Button
                    Button(action: shareComparison) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Progress")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(appearanceManager.accentColor.color)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Extract asset IDs on main actor
                let assetID1 = photo1.photoAssetID
                let assetID2 = photo2.photoAssetID

                async let img1 = loadImage(from: assetID1)
                async let img2 = loadImage(from: assetID2)

                image1 = await img1
                image2 = await img2
            }
        }
    }

    private func loadImage(from assetID: String?) async -> UIImage? {
        guard let assetID = assetID else { return nil }
        return await photoManager.loadImage(from: assetID)
    }

    private func shareComparison() {
        guard let before = beforeImage, let after = afterImage else { return }

        // Create side-by-side comparison image
        let comparisonImage = createComparisonImage(before: before, after: after)

        let activityViewController = UIActivityViewController(
            activityItems: [comparisonImage],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }

    private func createComparisonImage(before: UIImage, after: UIImage) -> UIImage {
        let width = before.size.width + after.size.width + 20
        let height = max(before.size.height, after.size.height)
        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)

        // Draw before image
        before.draw(in: CGRect(origin: .zero, size: before.size))

        // Draw after image
        after.draw(in: CGRect(origin: CGPoint(x: before.size.width + 20, y: 0), size: after.size))

        let comparisonImage = UIGraphicsGetImageFromCurrentImageContext() ?? before
        UIGraphicsEndImageContext()

        return comparisonImage
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .bold()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
