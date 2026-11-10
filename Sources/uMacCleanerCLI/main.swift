import CleanerCore
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
func usage() {
    print("""
    uMacCleaner-CLI scan [--json] [--category caches|logs|developer]
    uMacCleaner-CLI trace
    uMacCleaner-CLI docker
    uMacCleaner-CLI docker-prune-build --yes
    uMacCleaner-CLI clean --yes [--category caches|logs|developer]

    Clean moves the scanned items to Trash. Close apps before cleaning their caches.
    """)
}

guard let command = args.first, ["scan", "clean", "trace", "docker", "docker-prune-build"].contains(command) else {
    usage()
    exit(args.isEmpty ? 0 : 2)
}
if command == "docker" || command == "docker-prune-build" {
    guard (command == "docker" && args.count == 1) ||
          (command == "docker-prune-build" && args == ["docker-prune-build", "--yes"]) else {
        usage(); exit(2)
    }
    let result = command == "docker" ? DockerDiagnostics.diskUsage() : DockerDiagnostics.pruneBuildCache()
    print(result.output)
    exit(result.available ? 0 : 1)
}
if command == "trace" {
    guard args.count == 1 else { usage(); exit(2) }
    for entry in Cleaner().traceStorage() {
        let size = ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file)
        print("\(size)\t\(entry.name)\t\(entry.path)")
    }
    exit(0)
}
let categoryNames: [String: CleanerCategory] = ["caches": .caches, "logs": .logs, "developer": .developer]
var categories = Set(CleanerCategory.allCases)
if let index = args.firstIndex(of: "--category") {
    guard index + 1 < args.count, let category = categoryNames[args[index + 1]] else {
        fputs("Invalid category\n", stderr)
        exit(2)
    }
    categories = [category]
}
let allowed = Set([command, "--json", "--yes", "--category"] + categoryNames.keys)
guard args.allSatisfy(allowed.contains), !(command == "clean" && !args.contains("--yes")) else {
    usage()
    exit(2)
}
let cleaner = Cleaner()
let items = cleaner.scan(categories: categories)
if command == "scan" {
    if args.contains("--json") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(items), let json = String(data: data, encoding: .utf8) { print(json) }
    } else {
        for item in items {
            print("\(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))\t\(item.category.rawValue)\t\(item.path)")
        }
        print("\(items.count) items · \(ByteCountFormatter.string(fromByteCount: items.reduce(0) { $0 + $1.bytes }, countStyle: .file))")
    }
} else {
    let result = cleaner.clean(items)
    print("Moved \(result.moved.count) items to Trash.")
    for failure in result.failures { fputs("\(failure)\n", stderr) }
    if !result.failures.isEmpty { exit(1) }
}
