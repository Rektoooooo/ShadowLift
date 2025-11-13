//
//  MarkdownText.swift
//  ShadowLift
//
//  Created by Claude Code on 13.11.2024.
//

import SwiftUI

struct MarkdownText: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(), id: \.id) { element in
                element.view
            }
        }
    }

    private func parseMarkdown() -> [MarkdownElement] {
        let lines = markdown.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        var listItems: [String] = []
        var currentListStartNumber: Int? = nil

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines but add spacing
            if trimmedLine.isEmpty {
                if !listItems.isEmpty {
                    elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
                    listItems = []
                    currentListStartNumber = nil
                }
                elements.append(MarkdownElement.spacer)
                continue
            }

            // Headers
            if trimmedLine.hasPrefix("### ") {
                if !listItems.isEmpty {
                    elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
                    listItems = []
                    currentListStartNumber = nil
                }
                let text = String(trimmedLine.dropFirst(4))
                elements.append(MarkdownElement.heading3(text))
            } else if trimmedLine.hasPrefix("## ") {
                if !listItems.isEmpty {
                    elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
                    listItems = []
                    currentListStartNumber = nil
                }
                let text = String(trimmedLine.dropFirst(3))
                elements.append(MarkdownElement.heading2(text))
            } else if trimmedLine.hasPrefix("# ") {
                if !listItems.isEmpty {
                    elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
                    listItems = []
                    currentListStartNumber = nil
                }
                let text = String(trimmedLine.dropFirst(2))
                elements.append(MarkdownElement.heading1(text))
            }
            // Horizontal rule
            else if trimmedLine == "---" || trimmedLine == "***" {
                if !listItems.isEmpty {
                    elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
                    listItems = []
                    currentListStartNumber = nil
                }
                elements.append(MarkdownElement.divider)
            }
            // Unordered list
            else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
                let text = String(trimmedLine.dropFirst(2))
                listItems.append(text)
            }
            // Ordered list
            else if trimmedLine.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil {
                if currentListStartNumber == nil {
                    let numberStr = String(trimmedLine.prefix(while: { $0.isNumber }))
                    currentListStartNumber = Int(numberStr) ?? 1
                }
                if let dotIndex = trimmedLine.firstIndex(of: ".") {
                    let startIndex = trimmedLine.index(after: dotIndex)
                    let text = String(trimmedLine[startIndex...]).trimmingCharacters(in: .whitespaces)
                    listItems.append(text)
                }
            }
            // Regular paragraph
            else {
                if !listItems.isEmpty {
                    elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
                    listItems = []
                    currentListStartNumber = nil
                }
                elements.append(MarkdownElement.paragraph(trimmedLine))
            }
        }

        // Add remaining list items
        if !listItems.isEmpty {
            elements.append(MarkdownElement.list(items: listItems, ordered: currentListStartNumber != nil, startNumber: currentListStartNumber ?? 1))
        }

        return elements
    }
}

enum MarkdownElement: Identifiable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case paragraph(String)
    case list(items: [String], ordered: Bool, startNumber: Int)
    case divider
    case spacer

    var id: String {
        switch self {
        case .heading1(let text): return "h1-\(text)-\(UUID().uuidString)"
        case .heading2(let text): return "h2-\(text)-\(UUID().uuidString)"
        case .heading3(let text): return "h3-\(text)-\(UUID().uuidString)"
        case .paragraph(let text): return "p-\(text.prefix(50))-\(UUID().uuidString)"
        case .list(let items, let ordered, _): return "list-\(items.count)-\(ordered)-\(UUID().uuidString)"
        case .divider: return "divider-\(UUID().uuidString)"
        case .spacer: return "spacer-\(UUID().uuidString)"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .heading1(let text):
            Text(text)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 8)
                .padding(.bottom, 4)

        case .heading2(let text):
            Text(text)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 12)
                .padding(.bottom, 4)

        case .heading3(let text):
            Text(text)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 8)
                .padding(.bottom, 2)

        case .paragraph(let text):
            MarkdownTextView(text: text)
                .font(.body)
                .padding(.vertical, 2)

        case .list(let items, let ordered, let startNumber):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        if ordered {
                            Text("\(startNumber + index).")
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else {
                            Text("•")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        MarkdownTextView(text: item)
                            .font(.body)
                    }
                }
            }
            .padding(.leading, 8)

        case .divider:
            Divider()
                .padding(.vertical, 8)

        case .spacer:
            Spacer()
                .frame(height: 4)
        }
    }
}

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        Text(attributedString)
    }

    private var attributedString: AttributedString {
        var result = AttributedString(text)

        // Process bold text **text**
        var searchText = String(result.characters)
        while let range = searchText.range(of: "\\*\\*([^*]+)\\*\\*", options: .regularExpression) {
            let matchText = String(searchText[range])
            let content = String(matchText.dropFirst(2).dropLast(2))

            if let attrRange = result.range(of: matchText) {
                var replacement = AttributedString(content)
                replacement.font = Font.body.bold()
                result.replaceSubrange(attrRange, with: replacement)
            }
            searchText = String(result.characters)
        }

        // Process italic text *text* (but not **)
        searchText = String(result.characters)
        while let range = searchText.range(of: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", options: .regularExpression) {
            let matchText = String(searchText[range])
            let content = String(matchText.dropFirst().dropLast())

            if let attrRange = result.range(of: matchText) {
                var replacement = AttributedString(content)
                replacement.font = Font.body.italic()
                result.replaceSubrange(attrRange, with: replacement)
            }
            searchText = String(result.characters)
        }

        // Process inline code `code`
        searchText = String(result.characters)
        while let range = searchText.range(of: "`([^`]+)`", options: .regularExpression) {
            let matchText = String(searchText[range])
            let content = String(matchText.dropFirst().dropLast())

            if let attrRange = result.range(of: matchText) {
                var replacement = AttributedString(content)
                replacement.font = Font.body.monospaced()
                replacement.backgroundColor = Color.secondary.opacity(0.2)
                result.replaceSubrange(attrRange, with: replacement)
            }
            searchText = String(result.characters)
        }

        return result
    }
}
