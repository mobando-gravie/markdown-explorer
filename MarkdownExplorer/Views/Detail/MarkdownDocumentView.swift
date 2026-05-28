import MarkdownUI
import SwiftUI

struct MarkdownDocumentView: View {
    @Environment(WorkspaceStore.self) private var store
    let source: String
    let fileName: String
    let fileURL: URL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DocumentHeader(fileName: fileName, source: source)

                Markdown(source)
                    .markdownTheme(.gitHub)
                    .markdownBlockStyle(\.codeBlock) { config in
                        if config.language?.lowercased() == "mermaid" {
                            MermaidWebView(source: config.content)
                                .padding(.vertical, 4)
                        } else {
                            HighlightedCodeBlock(configuration: config)
                        }
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.95))
                        BackgroundColor(Color.secondary.opacity(0.15))
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .environment(\.openURL, OpenURLAction { url in
            store.navigateToLink(url, from: fileURL) ? .handled : .systemAction
        })
    }
}

private struct DocumentHeader: View {
    let fileName: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fileName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(metrics)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var metrics: String {
        let wordCount = source
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.rangeOfCharacter(from: .letters) != nil }
            .count
        let minutes = max(1, Int((Double(wordCount) / 200.0).rounded(.up)))
        return "\(wordCount) words · \(minutes) min read"
    }
}

