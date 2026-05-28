import SwiftUI

struct WIPFoldersView: View {
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if store.isScanning {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .padding(.horizontal, 8)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isScanning)
            .help("Rescan workspace")

            Spacer()

            if let scannedAt = store.lastBootstrapAt {
                Text("Updated \(scannedAt, format: .relative(presentation: .numeric))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var content: some View {
        if store.wipFolders.isEmpty {
            if store.lastBootstrapAt == nil {
                loadingState
            } else {
                emptyState
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(store.wipFolders) { folder in
                        WIPFolderRow(folder: folder)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Scanning workspace…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No markdown files in this folder yet")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
