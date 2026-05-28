import SwiftUI

struct EmptyStateView: View {
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(headline)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(subline)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headline: String {
        store.rootURL == nil ? "Open a folder to get started" : "Select a Markdown file"
    }

    private var subline: String {
        store.rootURL == nil
            ? "Use the sidebar or press ⌘O."
            : "Click any .md file in the sidebar to preview it here."
    }
}
