import SwiftUI

struct FileNodeRow: View {
    @Environment(WorkspaceStore.self) private var store
    let node: FileNode
    let depth: Int

    private var isExpanded: Bool { store.isExpanded(node.url) }
    private var isSelected: Bool { store.selectedURL == node.url }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent

            if node.isDirectory && isExpanded {
                ForEach(store.children(of: node.url)) { child in
                    FileNodeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 4) {
            disclosureChevron
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(depth) * 14 + 6)
        .padding(.vertical, 3)
        .padding(.trailing, 6)
        .contentShape(Rectangle())
        .background(rowBackground)
        .onTapGesture {
            store.select(node)
        }
    }

    @ViewBuilder
    private var disclosureChevron: some View {
        if node.isDirectory {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12)
                .onTapGesture { store.toggleExpanded(node.url) }
        } else {
            Color.clear.frame(width: 12)
        }
    }

    private var iconName: String {
        if node.isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return node.isMarkdown ? "doc.text" : "doc"
    }

    private var iconColor: Color {
        node.isDirectory ? .accentColor : .secondary
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.20))
                .padding(.horizontal, 2)
        }
    }
}
