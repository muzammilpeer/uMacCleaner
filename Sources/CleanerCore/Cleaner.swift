import Foundation

public enum CleanerCategory: String, CaseIterable, Codable, Sendable {
    case caches = "User Caches"
    case logs = "User Logs"
    case developer = "Xcode Derived Data"
    case external = "Chosen Folder"

    public var relativePath: String {
        switch self {
        case .caches: "Library/Caches"
        case .logs: "Library/Logs"
        case .developer: "Library/Developer/Xcode/DerivedData"
        case .external: ""
        }
    }
}

public struct CleanerItem: Identifiable, Codable, Sendable {
    public let id: String
    public let category: CleanerCategory
    public let name: String
    public let path: String
    public let bytes: Int64

    public init(category: CleanerCategory, name: String, path: String, bytes: Int64) {
        self.id = path
        self.category = category
        self.name = name
        self.path = path
        self.bytes = bytes
    }
}

public struct CleanResult: Sendable {
    public let moved: [CleanerItem]
    public let failures: [String]
}

public struct Cleaner: Sendable {
    public let home: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home.standardizedFileURL.resolvingSymlinksInPath()
    }

    public func scan(categories: Set<CleanerCategory> = Set(CleanerCategory.allCases)) -> [CleanerItem] {
        let fm = FileManager.default
        var items: [CleanerItem] = []
        for category in CleanerCategory.allCases where category != .external && categories.contains(category) {
            let root = home.appendingPathComponent(category.relativePath, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { continue }
            for entry in entries {
                guard isSafe(entry, within: root),
                      (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { continue }
                let size = directorySize(entry)
                guard size > 0 else { continue }
                items.append(CleanerItem(category: category, name: entry.lastPathComponent, path: entry.path, bytes: size))
            }
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    /// Lists the immediate contents of a user-chosen folder. No item is classified as junk.
    public func scanExternal(folder: URL) -> [CleanerItem] {
        let root = folder.standardizedFileURL.resolvingSymlinksInPath()
        guard root.isFileURL,
              let entries = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return [] }
        return entries.compactMap { entry in
            guard isSafe(entry, within: root),
                  (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { return nil }
            let size = directorySize(entry)
            guard size > 0 else { return nil }
            return CleanerItem(category: .external, name: entry.lastPathComponent, path: entry.path, bytes: size)
        }.sorted { $0.bytes > $1.bytes }
    }

    /// A best-effort breakdown of folders that may contribute to macOS System Data.
    /// These totals do not reproduce the Storage Settings classification.
    public func traceStorage() -> [StorageTrace] {
        let locations: [(String, String, Bool)] = [
            ("User caches", "Library/Caches", true),
            ("User logs", "Library/Logs", true),
            ("Application support", "Library/Application Support", false),
            ("App containers", "Library/Containers", false),
            ("Shared app containers", "Library/Group Containers", false),
            ("iPhone and iPad backups", "Library/Application Support/MobileSync/Backup", false),
            ("Xcode Derived Data", "Library/Developer/Xcode/DerivedData", true),
            ("Xcode archives", "Library/Developer/Xcode/Archives", false),
            ("Simulator devices", "Library/Developer/CoreSimulator/Devices", false)
        ]
        return locations.compactMap { name, path, canReviewForCleanup in
            let url = home.appendingPathComponent(path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return StorageTrace(name: name, path: url.path, bytes: directorySize(url), canReviewForCleanup: canReviewForCleanup)
        }.sorted { $0.bytes > $1.bytes }
    }

    public func clean(_ items: [CleanerItem], externalRoot: URL? = nil) -> CleanResult {
        let fm = FileManager.default
        var moved: [CleanerItem] = []
        var failures: [String] = []
        for item in items {
            let url = URL(fileURLWithPath: item.path)
            let root: URL
            if item.category == .external {
                guard let externalRoot else {
                    failures.append("No chosen folder for: \(item.path)")
                    continue
                }
                root = externalRoot.standardizedFileURL.resolvingSymlinksInPath()
            } else {
                root = home.appendingPathComponent(item.category.relativePath, isDirectory: true)
            }
            guard isSafe(url, within: root),
                  (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
                  fm.fileExists(atPath: url.path) else {
                failures.append("Skipped unsafe or missing item: \(item.path)")
                continue
            }
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                moved.append(item)
            } catch {
                failures.append("\(item.path): \(error.localizedDescription)")
            }
        }
        return CleanResult(moved: moved, failures: failures)
    }

    private func isSafe(_ url: URL, within root: URL) -> Bool {
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath().path
        return resolved.hasPrefix(resolvedRoot + "/") &&
            url.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path
    }

    private func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        if let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), values.isRegularFile == true {
            return Int64(values.fileSize ?? 0)
        }
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: [], errorHandler: { _, _ in true }) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else { continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if values.isRegularFile == true { total += Int64(values.fileSize ?? 0) }
        }
        return total
    }
}

public struct StorageTrace: Identifiable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let bytes: Int64
    public let canReviewForCleanup: Bool
}
