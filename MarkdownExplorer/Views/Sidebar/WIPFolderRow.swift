import SwiftUI

struct WIPFolderRow: View {
    @Environment(WorkspaceStore.self) private var store
    let folder: WIPFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            ForEach(folder.files) { file in
                fileRow(file)
            }
        }
        .padding(.horizontal, 6)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            breadcrumb
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(folder.mostRecentMtime, format: .relative(presentation: .numeric))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Reveal in Finder") {
                store.revealInFinder(folder.url)
            }
        }
    }

    @ViewBuilder
    private var breadcrumb: some View {
        if folder.parentPath.isEmpty {
            Text(folder.projectName)
        } else {
            HStack(spacing: 4) {
                Text(folder.projectName)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(folder.parentPath)
                    .foregroundStyle(.primary)
            }
        }
    }

    private func fileRow(_ file: WIPFile) -> some View {
        let isSelected = store.selectedURL == file.node.url
        return HStack(spacing: 4) {
            Color.clear.frame(width: 16)
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(file.node.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(file.modified, format: .relative(presentation: .numeric))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.20))
                : nil
        )
        .onTapGesture {
            store.select(file.node)
        }
        .contextMenu {
            Button("Reveal in Finder") {
                store.revealInFinder(file.node.url)
            }
        }
    }
}
