import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        Group {
            if store.rootURL == nil {
                emptyState
            } else {
                switch store.sidebarMode {
                case .tree: FileTreeView()
                case .wip:  WIPFoldersView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No folder open")
                .font(.headline)
            Text("Choose a folder to browse its Markdown files.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Folder…") {
                Task { await store.chooseFolder() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
