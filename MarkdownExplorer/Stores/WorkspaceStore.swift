import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceStore {
    private(set) var rootURL: URL?
    private(set) var rootChildren: [FileNode] = []
    private(set) var expanded: Set<URL> = []
    private(set) var childrenCache: [URL: [FileNode]] = [:]

    var selectedURL: URL?
    private(set) var documentText: String?

    var errorMessage: String?

    private(set) var recents: [URL] = []
    private(set) var sidebarMode: SidebarMode = .wip
    private(set) var wipFolders: [WIPFolder] = []
    private(set) var lastBootstrapAt: Date?
    private(set) var isScanning: Bool = false
    private(set) var projectStates: [URL: ProjectState] = [:]

    var isQuickOpenPresented: Bool = false

    var allMarkdownURLs: [URL] {
        projectStates.values
            .flatMap(\.folders)
            .flatMap { $0.files.map(\.node.url) }
    }

    private let fileSystem: FileSystemRepository
    private let bookmarks: BookmarkRepository

    private var wipTimer: Timer?
    private static let tickInterval: TimeInterval = 60
    private static let hotWindow: TimeInterval = 30 * 60
    private static let coldRescanInterval: TimeInterval = 30 * 60
    private static let bootstrapInterval: TimeInterval = 60 * 60
    private static let maxFilesPerRow: Int = 10

    init(fileSystem: FileSystemRepository, bookmarks: BookmarkRepository) {
        self.fileSystem = fileSystem
        self.bookmarks = bookmarks
        self.recents = bookmarks.restoreRecents()
    }

    func openFromRecents(_ url: URL) async {
        _ = url.startAccessingSecurityScopedResource()
        await applyRoot(url, persist: true)
    }

    func restorePersistedRoot() async {
        do {
            guard let url = try bookmarks.restore() else { return }
            await applyRoot(url, persist: false)
        } catch {
            errorMessage = "Could not restore last folder: \(error.localizedDescription)"
            bookmarks.clear()
        }
    }

    func chooseFolder() async {
        guard let url = await fileSystem.presentOpenPanel() else { return }
        _ = url.startAccessingSecurityScopedResource()
        await applyRoot(url, persist: true)
    }

    func toggleExpanded(_ url: URL) {
        if expanded.contains(url) {
            expanded.remove(url)
        } else {
            expanded.insert(url)
            if childrenCache[url] == nil {
                loadChildren(of: url)
            }
        }
    }

    func selectFile(at url: URL) {
        select(makeNode(for: url))
    }

    func navigateToLink(_ url: URL, from currentDoc: URL?) -> Bool {
        guard let root = rootURL else { return false }

        let resolved: URL
        if url.scheme == nil || url.scheme == "file" {
            let base = currentDoc?.deletingLastPathComponent() ?? root
            let raw = url.relativePath.isEmpty ? url.path : url.relativePath
            resolved = URL(fileURLWithPath: raw, relativeTo: base).standardizedFileURL
        } else {
            return false
        }

        let ext = resolved.pathExtension.lowercased()
        guard FileNode.markdownExtensions.contains(ext) else { return false }
        guard FileManager.default.fileExists(atPath: resolved.path) else { return false }

        let rootPath = root.standardizedFileURL.path
        guard resolved.path.hasPrefix(rootPath) else { return false }

        selectFile(at: resolved)
        return true
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func select(_ node: FileNode) {
        if node.isDirectory {
            toggleExpanded(node.url)
            return
        }
        selectedURL = node.url
        guard node.isMarkdown else {
            documentText = nil
            return
        }
        do {
            documentText = try fileSystem.read(node.url)
        } catch {
            documentText = nil
            errorMessage = "Could not read \(node.name): \(error.localizedDescription)"
        }
    }

    func children(of url: URL) -> [FileNode] {
        childrenCache[url] ?? []
    }

    func isExpanded(_ url: URL) -> Bool {
        expanded.contains(url)
    }

    func refresh() {
        guard let root = rootURL else { return }
        childrenCache.removeAll(keepingCapacity: true)
        loadRootChildren(root)
        for url in expanded {
            loadChildren(of: url)
        }
        if sidebarMode == .wip {
            Task { await bootstrap() }
        }
    }

    // MARK: - Projects (in-progress) mode

    func setMode(_ mode: SidebarMode) {
        guard mode != sidebarMode else { return }
        sidebarMode = mode
        if mode == .wip {
            activateWIPMode()
        } else {
            stopWIPTimer()
        }
    }

    private func activateWIPMode() {
        stopWIPTimer()
        if rootURL != nil, projectStates.isEmpty || lastBootstrapAt == nil {
            Task { await bootstrap() }
        }
        wipTimer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.tick()
            }
        }
    }

    func bootstrap() async {
        guard let root = rootURL else { return }
        isScanning = true
        defer { isScanning = false }

        let now = Date()
        let entries: [MarkdownEntry]
        do {
            entries = try fileSystem.enumerateMarkdown(root)
        } catch {
            errorMessage = "Bootstrap scan failed: \(error.localizedDescription)"
            return
        }

        projectStates = bootstrapBuildState(entries: entries, workspaceRoot: root, scannedAt: now)
        lastBootstrapAt = now
        rebuildWIPFolders()
    }

    func tick() async {
        guard let root = rootURL else { return }
        let now = Date()

        if let last = lastBootstrapAt, now.timeIntervalSince(last) > Self.bootstrapInterval {
            await bootstrap()
            return
        }

        for (projectURL, var state) in projectStates {
            let isHot = state.lastKnownMaxMtime > now.addingTimeInterval(-Self.hotWindow)
            let isColdAndDue = !isHot && state.lastScannedAt < now.addingTimeInterval(-Self.coldRescanInterval)
            guard isHot || isColdAndDue else { continue }

            let entries: [MarkdownEntry]
            do {
                entries = try fileSystem.enumerateMarkdown(projectURL)
            } catch {
                continue
            }

            if entries.isEmpty {
                projectStates.removeValue(forKey: projectURL)
                continue
            }

            state.folders = buildFolders(entries: entries, projectURL: projectURL)
            state.lastKnownMaxMtime = entries.map(\.modified).max() ?? state.lastKnownMaxMtime
            state.lastScannedAt = now
            projectStates[projectURL] = state
        }

        rebuildWIPFolders()
        _ = root
    }

    // MARK: - private

    private func applyRoot(_ url: URL, persist: Bool) async {
        stopWIPTimer()
        sidebarMode = .wip
        projectStates.removeAll()
        wipFolders = []
        lastBootstrapAt = nil
        isScanning = false
        rootURL = url
        selectedURL = nil
        documentText = nil
        expanded.removeAll()
        childrenCache.removeAll()
        loadRootChildren(url)

        if persist {
            do {
                try bookmarks.save(url)
                try bookmarks.saveRecent(url)
                recents = bookmarks.restoreRecents()
            } catch {
                errorMessage = "Could not remember this folder: \(error.localizedDescription)"
            }
        }

        activateWIPMode()
    }

    private func loadRootChildren(_ root: URL) {
        do {
            rootChildren = try fileSystem.list(root)
        } catch {
            rootChildren = []
            errorMessage = "Could not list folder: \(error.localizedDescription)"
        }
    }

    private func loadChildren(of url: URL) {
        do {
            childrenCache[url] = try fileSystem.list(url)
        } catch {
            childrenCache[url] = []
            errorMessage = "Could not list \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func stopWIPTimer() {
        wipTimer?.invalidate()
        wipTimer = nil
    }

    private func bootstrapBuildState(
        entries: [MarkdownEntry],
        workspaceRoot: URL,
        scannedAt: Date
    ) -> [URL: ProjectState] {
        var projectCache: [URL: URL] = [:]
        var grouped: [URL: [MarkdownEntry]] = [:]
        for entry in entries {
            let parentDir = entry.url.deletingLastPathComponent()
            let projectURL = findProjectRoot(
                for: parentDir,
                workspaceRoot: workspaceRoot,
                cache: &projectCache
            )
            grouped[projectURL, default: []].append(entry)
        }

        var states: [URL: ProjectState] = [:]
        for (projectURL, projectEntries) in grouped {
            let folders = buildFolders(entries: projectEntries, projectURL: projectURL)
            states[projectURL] = ProjectState(
                url: projectURL,
                lastKnownMaxMtime: projectEntries.map(\.modified).max() ?? .distantPast,
                lastScannedAt: scannedAt,
                folders: folders
            )
        }
        return states
    }

    private func buildFolders(entries: [MarkdownEntry], projectURL: URL) -> [WIPFolder] {
        let groups = Dictionary(grouping: entries) { $0.url.deletingLastPathComponent() }
        let projectStandardized = projectURL.standardizedFileURL
        return groups.map { (parentDir, parentEntries) -> WIPFolder in
            let parentPath = parentDir.standardizedFileURL == projectStandardized
                ? ""
                : parentDir.lastPathComponent
            let allFiles = parentEntries
                .map { WIPFile(node: makeNode(for: $0.url), modified: $0.modified) }
                .sorted { $0.modified > $1.modified }
            let capped = Array(allFiles.prefix(Self.maxFilesPerRow))
            return WIPFolder(
                url: parentDir,
                projectURL: projectURL,
                projectName: projectURL.lastPathComponent,
                parentPath: parentPath,
                files: capped,
                mostRecentMtime: capped.first?.modified ?? .distantPast
            )
        }
        .sorted { $0.mostRecentMtime > $1.mostRecentMtime }
    }

    private func rebuildWIPFolders() {
        wipFolders = projectStates.values
            .flatMap(\.folders)
            .sorted { $0.mostRecentMtime > $1.mostRecentMtime }
    }

    private func findProjectRoot(for dir: URL, workspaceRoot: URL, cache: inout [URL: URL]) -> URL {
        let stop = workspaceRoot.standardizedFileURL
        var current = dir.standardizedFileURL
        var path: [URL] = []
        var resolved: URL?

        while resolved == nil {
            if let cached = cache[current] {
                resolved = cached
                break
            }
            if fileSystem.isProjectRoot(current) {
                resolved = current
                break
            }
            if current == stop {
                resolved = stop
                break
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent == current {
                resolved = stop
                break
            }
            path.append(current)
            current = parent
        }

        let answer = resolved ?? stop
        for url in path { cache[url] = answer }
        cache[current] = answer
        return answer
    }

    private func makeNode(for url: URL) -> FileNode {
        let keys: [URLResourceKey] = [.isDirectoryKey, .localizedNameKey]
        if let values = try? url.resourceValues(forKeys: Set(keys)) {
            return FileNode.from(url: url, resourceValues: values)
        }
        let ext = url.pathExtension.lowercased()
        return FileNode(
            url: url,
            name: url.lastPathComponent,
            isDirectory: false,
            isMarkdown: FileNode.markdownExtensions.contains(ext)
        )
    }
}
