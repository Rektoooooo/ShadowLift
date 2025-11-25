//
//  SplitDetailView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 27.02.2025.
//

import SwiftUI

struct SplitDetailView: View {
    @State var split: Split
    @State var days: [Day] = []
    @State var shareSplit: Bool = false
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var scheme
    @State private var shareURL: URL?
    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            List {
                /// Show all days in a split and display them in a list
                ForEach(days.sorted(by: { $0.dayOfSplit < $1.dayOfSplit })) { day in
                    NavigationLink(destination: ShowSplitDayView(viewModel: viewModel, day: day)) {
                        Text("Day \(day.dayOfSplit) - \(day.name)")
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listRowBackground(Color.black.opacity(0.1))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let url = viewModel.exportSplit(split) {
                            viewModel.editPlan = false
                            shareURL = url
                            presentShareSheet(url: url)
                        }
                    } label: {
                        Label("", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .task {
                days = split.days ?? []
            }
            .navigationTitle(split.name)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listRowBackground(Color.clear)
        }
    }
    
    func presentShareSheet(url: URL) {
        DispatchQueue.main.async {
            // Ensure the file exists before sharing
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("File does not exist at path: \(url.path)")
                return
            }

            // Ensure the file is readable by setting explicit permissions
            do {
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            } catch {
                print("Failed to set file permissions: \(error)")
                return
            }

            // Verify file is readable
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("File is not readable at path: \(url.path)")
                return
            }

            // Ensure the UIActivityViewController isn't already presented
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if rootVC.presentedViewController != nil {
                    rootVC.dismiss(animated: false) {
                        self.presentActivityController(url: url, rootVC: rootVC)
                    }
                } else {
                    self.presentActivityController(url: url, rootVC: rootVC)
                }
            }
        }
    }

    private func presentActivityController(url: URL, rootVC: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = rootVC.view
        rootVC.present(activityVC, animated: true, completion: nil)
    }
}
