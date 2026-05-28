import Foundation

protocol BookmarkRepository {
    func save(_ url: URL) throws
    func restore() throws -> URL?
    func clear()
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
}
