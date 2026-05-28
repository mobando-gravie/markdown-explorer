import SwiftUI

struct MarkdownDocumentView: View {
    @Environment(WorkspaceStore.self) private var store
    @AppStorage("preferDarkMode") private var preferDarkMode: Bool = false
    let source: String
    let fileName: String
    let fileURL: URL

    var body: some View {
        VStack(spacing: 0) {
            DocumentHeader(fileName: fileName, source: source)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            Divider()
            DocumentWebView(
                source: source,
                baseURL: fileURL.deletingLastPathComponent(),
                isDarkMode: preferDarkMode,
                onNavigate: { url in store.navigateToLink(url, from: fileURL) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
