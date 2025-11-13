//
//  AboutGymlyView.swift
//  ShadowLift
//
//  Created by Claude Code on 13.11.2024.
//

import SwiftUI

struct AboutGymlyView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State private var content: String = ""
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.accent(scheme, accentColor: appearanceManager.accentColor))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // App Logo and Version
                            VStack(spacing: 12) {
                                Image("LogoGymlyBlack")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(20)
                                    .shadow(radius: 5)

                                Text("ShadowLift")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)

                                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                    Text("Version \(version) (Build \(build))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                            .padding(.bottom, 10)

                            Divider()
                                .padding(.horizontal)

                            // Content
                            MarkdownText(markdown: content)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("About ShadowLift")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDocument()
        }
    }

    private func loadDocument() {
        // Try multiple paths
        var url: URL?

        // Try with subdirectory first
        url = Bundle.main.url(forResource: "about", withExtension: "md", subdirectory: "Resources/Legal")

        // If not found, try without subdirectory
        if url == nil {
            url = Bundle.main.url(forResource: "about", withExtension: "md")
        }

        // If not found, try with path
        if url == nil {
            if let path = Bundle.main.path(forResource: "Resources/Legal/about", ofType: "md") {
                url = URL(fileURLWithPath: path)
            }
        }

        guard let finalUrl = url,
              let text = try? String(contentsOf: finalUrl, encoding: .utf8) else {
            content = """
            # About ShadowLift

            **Built for lifters, by lifters.**

            ShadowLift is a modern fitness tracking app designed for strength training enthusiasts.

            ## Our Mission

            We believe that tracking your workouts shouldn't be complicated, frustrating, or time-consuming. That's why we created a fitness app that's fast, intuitive, and designed specifically for strength training.

            ## Contact

            **Support**: support@shadowlift.app
            **General**: hello@shadowlift.app

            © 2024 ShadowLift. All rights reserved.
            """
            isLoading = false
            return
        }
        content = text
        isLoading = false
    }
}

#Preview {
    AboutGymlyView()
        .environmentObject(AppearanceManager())
}
