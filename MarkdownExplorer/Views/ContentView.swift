import SwiftUI

struct ContentView: View {
    @Environment(WorkspaceStore.self) private var store
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 500)
        } detail: {
            DetailView()
        }
        .navigationTitle(store.rootURL?.lastPathComponent ?? "Markdown Explorer")
        .toolbar {
            if columnVisibility != .detailOnly {
                ToolbarItem(placement: .navigation) {
                    modePicker
                }
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    Task { await store.chooseFolder() }
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open Folder (⌘O)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.rootURL == nil)
                .help("Refresh file tree")
            }
        }
    }

    private var modePicker: some View {
        Picker("", selection: Binding(
            get: { store.sidebarMode },
            set: { store.setMode($0) }
        )) {
            ForEach(SidebarMode.allCases, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 180)
        .disabled(store.rootURL == nil)
        .help("Switch sidebar view")
    }
}
