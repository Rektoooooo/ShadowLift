//
//  LegalDocumentView.swift
//  ShadowLift
//
//  Created by Claude Code on 13.11.2024.
//

import SwiftUI

struct LegalDocumentView: View {
    let documentName: String
    let title: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var content: String = ""
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MarkdownText(markdown: content)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDocument()
        }
    }

    private func loadDocument() {
        // Try multiple paths
        var url: URL?

        // Try with subdirectory first
        url = Bundle.main.url(forResource: documentName, withExtension: "md", subdirectory: "Resources/Legal")

        // If not found, try without subdirectory
        if url == nil {
            url = Bundle.main.url(forResource: documentName, withExtension: "md")
        }

        // If not found, try with path
        if url == nil {
            if let path = Bundle.main.path(forResource: "Resources/Legal/\(documentName)", ofType: "md") {
                url = URL(fileURLWithPath: path)
            }
        }

        guard let finalUrl = url,
              let text = try? String(contentsOf: finalUrl, encoding: .utf8) else {
            content = "Document not found. Please contact support at support@gymly.app\n\nLooking for: \(documentName).md"
            isLoading = false
            return
        }
        content = text
        isLoading = false
    }
}

#Preview {
    LegalDocumentView(documentName: "privacy-policy", title: "Privacy Policy")
}
