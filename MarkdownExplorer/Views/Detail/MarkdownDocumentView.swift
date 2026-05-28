import MarkdownUI
import SwiftUI

struct MarkdownDocumentView: View {
    let source: String
    let fileName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(fileName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Markdown(source)
                    .markdownTheme(.gitHub)
                    .markdownBlockStyle(\.codeBlock) { config in
                        if config.language?.lowercased() == "mermaid" {
                            MermaidWebView(source: config.content)
                                .padding(.vertical, 4)
                        } else {
                            DefaultCodeBlock(configuration: config)
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
    }
}

private struct DefaultCodeBlock: View {
    let configuration: CodeBlockConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language = configuration.language, !language.isEmpty {
                Text(language)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(Color.secondary.opacity(0.08))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(configuration.content)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
