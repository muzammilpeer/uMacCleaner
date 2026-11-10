import CleanerCore
import Foundation
import Testing

@Test func scansOnlyDirectChildrenAndSkipsSymlinks() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let caches = home.appendingPathComponent("Library/Caches")
    try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    let item = caches.appendingPathComponent("Sample")
    try FileManager.default.createDirectory(at: item, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 42).write(to: item.appendingPathComponent("data"))
    try FileManager.default.createSymbolicLink(at: caches.appendingPathComponent("Outside"), withDestinationURL: URL(fileURLWithPath: "/tmp"))
    let result = Cleaner(home: home).scan(categories: [.caches])
    #expect(result.count == 1)
    #expect(result.first?.name == "Sample")
    #expect(result.first?.bytes == 42)
}

@Test func rejectsForgedItemOutsideKnownRoot() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let file = home.appendingPathComponent("keep.txt")
    try Data("keep".utf8).write(to: file)
    let forged = CleanerItem(category: .caches, name: "keep.txt", path: file.path, bytes: 4)
    let result = Cleaner(home: home).clean([forged])
    #expect(result.moved.isEmpty)
    #expect(result.failures.count == 1)
    #expect(FileManager.default.fileExists(atPath: file.path))
}

@Test func externalScanRequiresMatchingRootForCleanup() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("data.bin")
    try Data(repeating: 1, count: 17).write(to: file)
    let cleaner = Cleaner()
    let items = cleaner.scanExternal(folder: folder)
    #expect(items.count == 1)
    #expect(items.first?.bytes == 17)
    let denied = cleaner.clean(items)
    #expect(denied.moved.isEmpty)
    #expect(FileManager.default.fileExists(atPath: file.path))
}
