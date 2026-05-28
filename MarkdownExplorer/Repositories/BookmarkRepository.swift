import Foundation

protocol BookmarkRepository {
    func save(_ url: URL) throws
    func restore() throws -> URL?
    func clear()
    func saveRecent(_ url: URL) throws
    func restoreRecents() -> [URL]
}

struct DefaultBookmarkRepository: BookmarkRepository {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "lastRootBookmark") {
        self.defaults = defaults
        self.key = key
    }

    func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    func restore() throws -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try? save(url)
        }

        guard url.startAccessingSecurityScopedResource() else {
            clear()
            return nil
        }
        return url
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    func saveRecent(_ url: URL) throws {
        let entry = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var blobs = defaults.array(forKey: recentsKey) as? [Data] ?? []
        let newPath = url.standardizedFileURL.path
        blobs = blobs.filter { existing in
            guard let path = Self.path(of: existing) else { return true }
            return path != newPath
        }
        blobs.insert(entry, at: 0)
        if blobs.count > Self.recentsMax { blobs = Array(blobs.prefix(Self.recentsMax)) }
        defaults.set(blobs, forKey: recentsKey)
    }

    func restoreRecents() -> [URL] {
        guard let blobs = defaults.array(forKey: recentsKey) as? [Data] else { return [] }
        var resolved: [URL] = []
        var keep: [Data] = []
        for data in blobs {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            resolved.append(url)
            keep.append(data)
        }
        if keep.count != blobs.count {
            defaults.set(keep, forKey: recentsKey)
        }
        return resolved
    }

    private var recentsKey: String { "recentBookmarks" }
    private static let recentsMax = 5

    private static func path(of bookmark: Data) -> String? {
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return url?.standardizedFileURL.path
    }
}
