import SwiftUI

@main
struct MarkdownExplorerApp: App {
    @State private var store: WorkspaceStore

    init() {
        let fs = DefaultFileSystemRepository()
        let bookmarks = DefaultBookmarkRepository()
        _store = State(initialValue: WorkspaceStore(fileSystem: fs, bookmarks: bookmarks))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 700, minHeight: 500)
                .task {
                    await store.restorePersistedRoot()
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    Task { await store.chooseFolder() }
                }
                .keyboardShortcut("o", modifiers: [.command])

                Menu("Open Recent") {
                    if store.recents.isEmpty {
                        Text("No recent folders")
                    } else {
                        ForEach(store.recents, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                Task { await store.openFromRecents(url) }
                            }
                        }
                    }
                }

                Divider()

                Button("Quick Open…") {
                    store.isQuickOpenPresented = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(store.rootURL == nil)
            }
        }
    }
}
