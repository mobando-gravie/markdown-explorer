import AppKit
import MarkdownUI
import SwiftUI

struct HighlightedCodeBlock: View {
    let configuration: CodeBlockConfiguration

    @State private var isHovering = false
    @State private var didCopy = false

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
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.95))
                    }
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
        .overlay(alignment: .topTrailing) { copyButton }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var copyButton: some View {
        if isHovering {
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(configuration.content, forType: .string)
                didCopy = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    didCopy = false
                }
            } label: {
                Label(didCopy ? "Copied" : "Copy",
                      systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.borderless)
            .padding(8)
            .transition(.opacity)
        }
    }
}
