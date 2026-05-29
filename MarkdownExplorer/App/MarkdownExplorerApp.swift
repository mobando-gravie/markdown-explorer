import AppKit
import SwiftUI

@main
struct MarkdownExplorerApp: App {
    @State private var store: WorkspaceStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let fs = DefaultFileSystemRepository()
        let bookmarks = DefaultBookmarkRepository()
        _store = State(initialValue: WorkspaceStore(fileSystem: fs, bookmarks: bookmarks))
        Self.seedAppearanceIfNeeded()
    }

    private static func seedAppearanceIfNeeded() {
        let key = "preferDarkMode"
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        let isDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        UserDefaults.standard.set(isDark, forKey: key)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 700, minHeight: 500)
                .task {
                    await store.restorePersistedRoot()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        store.handleAppDidBecomeActive()
                    case .inactive, .background:
                        store.handleAppDidResignActive()
                    @unknown default:
                        break
                    }
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

            CommandGroup(after: .textEditing) {
                Section {
                    Button("Find…") { Self.performFindAction(.showFindInterface) }
                        .keyboardShortcut("f", modifiers: .command)
                    Button("Find Next") { Self.performFindAction(.nextMatch) }
                        .keyboardShortcut("g", modifiers: .command)
                    Button("Find Previous") { Self.performFindAction(.previousMatch) }
                        .keyboardShortcut("g", modifiers: [.command, .shift])
                }
            }
        }
    }

    private static func performFindAction(_ action: NSTextFinder.Action) {
        guard let window = NSApp.keyWindow,
              let textView = firstTextView(in: window.contentView) else { return }
        window.makeFirstResponder(textView)
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.performTextFinderAction(sender)
    }

    private static func firstTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let tv = view as? NSTextView { return tv }
        for sub in view.subviews {
            if let tv = firstTextView(in: sub) { return tv }
        }
        return nil
    }
}
