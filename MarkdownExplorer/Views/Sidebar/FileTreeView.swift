import SwiftUI

struct FileTreeView: View {
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.rootChildren) { node in
                    FileNodeRow(node: node, depth: 0)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
