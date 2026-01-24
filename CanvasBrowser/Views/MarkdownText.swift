import SwiftUI

/// A view that renders markdown text with basic formatting support
struct MarkdownText: View {
    let text: String
    let fontSize: CGFloat

    init(_ text: String, fontSize: CGFloat = 14) {
        self.text = text
        self.fontSize = fontSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    enum MarkdownBlock {
        case paragraph(AttributedString)
        case heading(level: Int, text: String)
        case codeBlock(language: String?, code: String)
        case bulletList(items: [AttributedString])
        case numberedList(items: [AttributedString])
        case blockquote(text: String)
        case divider
    }

    // MARK: - Parsing

    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Heading
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 6), text: text))
                i += 1
                continue
            }

            // Code block
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                i += 1 // Skip closing ```
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Divider
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
                    quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.blockquote(text: quoteLines.joined(separator: " ")))
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [AttributedString] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") || listLine.hasPrefix("+ ") {
                        let itemText = String(listLine.dropFirst(2))
                        items.append(parseInlineMarkdown(itemText))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            // Numbered list
            if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                var items: [AttributedString] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if let _ = listLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        let itemText = listLine.replacingOccurrences(of: #"^\d+\.\s"#, with: "", options: .regularExpression)
                        items.append(parseInlineMarkdown(itemText))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(items: items))
                continue
            }

            // Regular paragraph
            var paragraphLines: [String] = []
            while i < lines.count {
                let pLine = lines[i].trimmingCharacters(in: .whitespaces)
                if pLine.isEmpty || pLine.hasPrefix("#") || pLine.hasPrefix("```") ||
                   pLine.hasPrefix("- ") || pLine.hasPrefix("* ") || pLine.hasPrefix(">") ||
                   pLine == "---" || pLine == "***" {
                    break
                }
                paragraphLines.append(lines[i])
                i += 1
            }
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(parseInlineMarkdown(paragraphLines.joined(separator: " "))))
            }
        }

        return blocks
    }

    // MARK: - Inline Markdown Parsing

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Bold: **text** or __text__
        result = applyPattern(to: result, pattern: #"\*\*(.+?)\*\*"#) { match in
            var attr = AttributedString(match)
            attr.font = .system(size: fontSize, weight: .bold)
            return attr
        }
        result = applyPattern(to: result, pattern: #"__(.+?)__"#) { match in
            var attr = AttributedString(match)
            attr.font = .system(size: fontSize, weight: .bold)
            return attr
        }

        // Italic: *text* or _text_
        result = applyPattern(to: result, pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#) { match in
            var attr = AttributedString(match)
            attr.font = .system(size: fontSize).italic()
            return attr
        }

        // Inline code: `code`
        result = applyPattern(to: result, pattern: #"`([^`]+)`"#) { match in
            var attr = AttributedString(match)
            attr.font = .system(size: fontSize - 1, design: .monospaced)
            attr.backgroundColor = Color(NSColor.controlBackgroundColor)
            return attr
        }

        // Links: [text](url)
        result = applyPattern(to: result, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) { match in
            var attr = AttributedString(match)
            attr.foregroundColor = .blue
            attr.underlineStyle = .single
            return attr
        }

        return result
    }

    private func applyPattern(to text: AttributedString, pattern: String, transform: (String) -> AttributedString) -> AttributedString {
        var result = text
        let string = String(text.characters)

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }

        let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))

        // Process matches in reverse to preserve indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: string) else { continue }
            let fullMatch = String(string[range])

            // Extract the content (first capture group)
            if match.numberOfRanges > 1,
               let contentRange = Range(match.range(at: 1), in: string) {
                let content = String(string[contentRange])
                let transformed = transform(content)

                // Replace in attributed string
                if let attrRange = result.range(of: fullMatch) {
                    result.replaceSubrange(attrRange, with: transformed)
                }
            }
        }

        return result
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(size: fontSize))
                .textSelection(.enabled)

        case .heading(let level, let text):
            Text(text)
                .font(.system(size: headingSize(level), weight: .bold))
                .padding(.top, level == 1 ? 8 : 4)

        case .codeBlock(_, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: fontSize))
                        Text(item)
                            .font(.system(size: fontSize))
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.system(size: fontSize))
                            .frame(width: 20, alignment: .trailing)
                        Text(item)
                            .font(.system(size: fontSize))
                    }
                }
            }

        case .blockquote(let text):
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                Text(text)
                    .font(.system(size: fontSize).italic())
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
            }

        case .divider:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return fontSize + 10
        case 2: return fontSize + 6
        case 3: return fontSize + 4
        case 4: return fontSize + 2
        default: return fontSize
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MarkdownText("""
            # Heading 1
            ## Heading 2

            This is a paragraph with **bold** and *italic* text.

            Here's some `inline code` in a sentence.

            ```swift
            func hello() {
                print("Hello, World!")
            }
            ```

            - Bullet item 1
            - Bullet item 2
            - Bullet item 3

            1. Numbered item
            2. Another item
            3. Third item

            > This is a blockquote

            ---

            [Link text](https://example.com)
            """)
            .padding()
        }
        .frame(width: 400, height: 600)
    }
}
#endif
