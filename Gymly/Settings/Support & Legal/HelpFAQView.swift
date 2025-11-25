//
//  HelpFAQView.swift
//  ShadowLift
//
//  Created by Claude Code on 13.11.2024.
//

import SwiftUI

struct HelpFAQView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var content: String = ""
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""

    var filteredContent: String {
        if searchText.isEmpty {
            return content
        }

        // Filter content by search text
        let lines = content.components(separatedBy: .newlines)
        var filteredLines: [String] = []
        var includeSection = false

        for line in lines {
            // Check if line is a section header
            if line.hasPrefix("##") || line.hasPrefix("###") {
                includeSection = line.lowercased().contains(searchText.lowercased())
                if includeSection {
                    filteredLines.append(line)
                }
            } else if includeSection || line.lowercased().contains(searchText.lowercased()) {
                filteredLines.append(line)
            }
        }

        return filteredLines.isEmpty ? "No results found for '\(searchText)'" : filteredLines.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search FAQ...", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                if isLoading {
                    Spacer()
                    ProgressView("Loading FAQ...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            MarkdownText(markdown: filteredContent)
                                .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle("Help & FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDocument()
        }
    }

    private func loadDocument() {
        // Try multiple paths
        var url: URL?

        // Try with subdirectory first
        url = Bundle.main.url(forResource: "faq", withExtension: "md", subdirectory: "Resources/Legal")

        // If not found, try without subdirectory
        if url == nil {
            url = Bundle.main.url(forResource: "faq", withExtension: "md")
        }

        // If not found, try with path
        if url == nil {
            if let path = Bundle.main.path(forResource: "Resources/Legal/faq", ofType: "md") {
                url = URL(fileURLWithPath: path)
            }
        }

        guard let finalUrl = url,
              let text = try? String(contentsOf: finalUrl, encoding: .utf8) else {
            content = """
            # Help & FAQ

            Unable to load FAQ content. Please contact support at support@gymly.app

            ## Common Questions

            For immediate assistance, please email:
            - **Support**: support@gymly.app
            - **General**: hello@gymly.app

            We typically respond within 24 hours on weekdays.
            """
            isLoading = false
            return
        }
        content = text
        isLoading = false
    }
}

#Preview {
    HelpFAQView()
}
