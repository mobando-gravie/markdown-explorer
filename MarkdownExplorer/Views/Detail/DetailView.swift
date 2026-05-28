import SwiftUI

struct DetailView: View {
    @Environment(WorkspaceStore.self) private var store

    var body: some View {
        ZStack(alignment: .top) {
            content

            if let message = store.errorMessage {
                ErrorBanner(message: message) {
                    store.errorMessage = nil
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if let selected = store.selectedURL, let text = store.documentText {
            MarkdownDocumentView(source: text, fileName: selected.lastPathComponent)
        } else {
            EmptyStateView()
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.orange.opacity(0.5), lineWidth: 1)
        )
    }
}
