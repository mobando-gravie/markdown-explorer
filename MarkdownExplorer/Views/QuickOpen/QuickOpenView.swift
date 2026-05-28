import SwiftUI

struct QuickOpenItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let parent: String
    let score: Int

    var id: URL { url }
}

struct QuickOpenView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var selection: URL?
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
        }
        .frame(width: 540, height: 360)
        .onAppear { queryFocused = true }
        .onChange(of: query) { _, _ in
            selection = filteredResults.first?.url
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search markdown files…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($queryFocused)
                .onSubmit { openSelection() }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    dismiss()
                    return .handled
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(filteredResults) { item in
                    QuickOpenRow(item: item, isSelected: item.url == selection)
                        .tag(item.url)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { open(item.url) }
                        .onTapGesture { selection = item.url }
                }
            }
            .listStyle(.plain)
            .onChange(of: selection) { _, new in
                if let new { withAnimation(.linear(duration: 0.08)) { proxy.scrollTo(new, anchor: .center) } }
            }
        }
    }

    private var allItems: [QuickOpenItem] {
        store.allMarkdownURLs.map { url in
            QuickOpenItem(
                url: url,
                name: url.lastPathComponent,
                parent: url.deletingLastPathComponent().lastPathComponent,
                score: 0
            )
        }
    }

    private var filteredResults: [QuickOpenItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return Array(allItems.prefix(50))
        }
        return allItems
            .compactMap { item -> QuickOpenItem? in
                guard let s = FuzzyMatch.score(query: trimmed, candidate: item.name) else { return nil }
                return QuickOpenItem(url: item.url, name: item.name, parent: item.parent, score: s)
            }
            .sorted { $0.score > $1.score }
            .prefix(50)
            .map { $0 }
    }

    private func moveSelection(by delta: Int) {
        let items = filteredResults
        guard !items.isEmpty else { return }
        if let sel = selection, let idx = items.firstIndex(where: { $0.url == sel }) {
            let next = max(0, min(items.count - 1, idx + delta))
            selection = items[next].url
        } else {
            selection = items.first?.url
        }
    }

    private func openSelection() {
        if let sel = selection { open(sel) }
        else if let first = filteredResults.first?.url { open(first) }
    }

    private func open(_ url: URL) {
        store.selectFile(at: url)
        dismiss()
    }
}

private struct QuickOpenRow: View {
    let item: QuickOpenItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .lineLimit(1)
                Text(item.parent)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
