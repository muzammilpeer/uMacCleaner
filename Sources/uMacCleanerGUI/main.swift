import CleanerCore
import SwiftUI

enum ResultSort: String, CaseIterable {
    case largest = "Largest first"
    case smallest = "Smallest first"
    case name = "Name"
    case category = "Category"
}

enum AppPage {
    case results, storage, docker, intelligence
}

@MainActor @Observable final class CleanerModel {
    var items: [CleanerItem] = []
    var selected = Set<String>()
    var scanning = false
    var message: String?
    var showingConfirmation = false
    var chosenFolder: URL?
    var searchText = ""
    var categoryFilter: CleanerCategory?
    var sort: ResultSort = .largest
    var showingStorageTrace = false
    var storageTrace: [StorageTrace] = []
    var page: AppPage = .results
    var dockerOutput = "Run a scan to see Docker's images, containers, volumes, and build cache."
    var dockerAvailable = false
    var showingDockerConfirmation = false
    private let cleaner = Cleaner()

    var selectedItems: [CleanerItem] { items.filter { selected.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var visibleItems: [CleanerItem] {
        let filtered = items.filter { item in
            (categoryFilter == nil || item.category == categoryFilter) &&
            (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText) || item.path.localizedCaseInsensitiveContains(searchText))
        }
        switch sort {
        case .largest: return filtered.sorted { $0.bytes > $1.bytes }
        case .smallest: return filtered.sorted { $0.bytes < $1.bytes }
        case .name: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .category: return filtered.sorted {
            if $0.category == $1.category { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.category.rawValue < $1.category.rawValue
        }
        }
    }

    func selectVisible() { selected.formUnion(visibleItems.map(\.id)) }
    func deselectVisible() { selected.subtract(visibleItems.map(\.id)) }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        chosenFolder = url
        showingStorageTrace = false
        page = .results
        categoryFilter = nil
        scan()
    }

    func useMacLocations() {
        chosenFolder = nil
        showingStorageTrace = false
        page = .results
        categoryFilter = nil
        scan()
    }

    func traceSystemData() {
        chosenFolder = nil
        selected = []
        showingStorageTrace = true
        page = .storage
        scanning = true
        message = nil
        Task.detached { [cleaner] in
            let result = cleaner.traceStorage()
            await MainActor.run {
                self.storageTrace = result
                self.scanning = false
            }
        }
    }

    func scanDocker() {
        page = .docker
        scanning = true
        Task.detached {
            let result = DockerDiagnostics.diskUsage()
            await MainActor.run {
                self.dockerOutput = result.output
                self.dockerAvailable = result.available
                self.scanning = false
            }
        }
    }

    func pruneDockerBuildCache() {
        scanning = true
        Task.detached {
            let result = DockerDiagnostics.pruneBuildCache()
            let refreshed = DockerDiagnostics.diskUsage()
            await MainActor.run {
                self.dockerOutput = result.output + "\n\nCurrent Docker usage:\n" + refreshed.output
                self.dockerAvailable = refreshed.available
                self.scanning = false
            }
        }
    }

    func reviewTrace(_ trace: StorageTrace) {
        guard trace.canReviewForCleanup else { return }
        showingStorageTrace = false
        page = .results
        categoryFilter = switch trace.name {
        case "User caches": .caches
        case "User logs": .logs
        default: .developer
        }
        scan()
    }

    func scan() {
        scanning = true
        message = nil
        let folder = chosenFolder
        Task.detached { [cleaner] in
            let result = folder.map { cleaner.scanExternal(folder: $0) } ?? cleaner.scan()
            await MainActor.run {
                self.items = result
                self.selected = []
                self.scanning = false
            }
        }
    }

    func clean() {
        let targets = selectedItems
        let folder = chosenFolder
        scanning = true
        Task.detached { [cleaner] in
            let result = cleaner.clean(targets, externalRoot: folder)
            let refreshed = folder.map { cleaner.scanExternal(folder: $0) } ?? cleaner.scan()
            await MainActor.run {
                self.items = refreshed
                self.selected = []
                self.scanning = false
                self.message = "Moved \(result.moved.count) items to Trash." +
                    (result.failures.isEmpty ? "" : " \(result.failures.count) could not be moved.")
            }
        }
    }
}

@main struct uMacCleanerGUIApp: App {
    @State private var model = CleanerModel()

    var body: some Scene {
        WindowGroup("uMacCleaner") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("uMacCleaner").font(.largeTitle.bold())
                        Text(model.page == .docker ? "Docker disk usage and build cache" :
                             model.page == .intelligence ? "Apple Intelligence settings and storage" :
                             model.chosenFolder?.path ?? "User caches, logs, and Xcode build data")
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button("Mac Locations") { model.useMacLocations() }.disabled(model.scanning)
                    Button("Choose Folder…") { model.chooseFolder() }.disabled(model.scanning)
                    Button("Trace System Data") { model.traceSystemData() }.disabled(model.scanning)
                    Button("Docker") { model.scanDocker() }.disabled(model.scanning)
                    Button("Apple Intelligence") { model.page = .intelligence }.disabled(model.scanning)
                    Button("Scan") {
                        if model.page == .storage { model.traceSystemData() }
                        else if model.page == .docker { model.scanDocker() }
                        else { model.scan() }
                    }.disabled(model.scanning || model.page == .intelligence)
                }
                if model.scanning { ProgressView() }
                if model.chosenFolder != nil {
                    Text("Chosen folder contents are your data. Review each item before moving it to Trash.")
                        .foregroundStyle(.orange)
                }
                if model.page == .docker {
                    Text("Docker reports its own disk usage. Build cache can be removed through Docker; volumes and the disk image are left alone.")
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(model.dockerOutput)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    Button("Prune Docker Build Cache…") { model.showingDockerConfirmation = true }
                        .disabled(!model.dockerAvailable || model.scanning)
                } else if model.page == .intelligence {
                    Text("Apple Intelligence").font(.title2.bold())
                    Text("macOS 27 can store downloaded Apple Intelligence models on this Mac. Apple does not provide a supported file-level cleanup API or a reliable public size breakdown for these models.")
                    Text("To turn off Apple Intelligence features, open System Settings and review Siri and the individual feature settings. macOS manages the downloaded assets; this app does not remove protected model files or change private system settings.")
                        .foregroundStyle(.secondary)
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
                    }
                    Spacer()
                } else if model.page == .storage {
                    Text("Likely System Data contributors. Sizes may overlap and will not match the macOS Storage total exactly.")
                        .foregroundStyle(.secondary)
                    List(model.storageTrace) { trace in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(trace.name).font(.headline)
                                Text(trace.path).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: trace.bytes, countStyle: .file))
                                .monospacedDigit()
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: trace.path)])
                            }
                            if trace.canReviewForCleanup {
                                Button("Review Cleanup") { model.reviewTrace(trace) }
                            }
                        }
                    }
                    Text("App support, backups, archives, and simulator data need review in their owning apps or Finder. macOS manages protected system files and local snapshots.")
                        .foregroundStyle(.secondary)
                } else {
                HStack {
                    TextField("Filter by name or path", text: $model.searchText)
                        .textFieldStyle(.roundedBorder)
                    Picker("Category", selection: $model.categoryFilter) {
                        Text("All categories").tag(CleanerCategory?.none)
                        ForEach(CleanerCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }.frame(width: 190)
                    Picker("Sort", selection: $model.sort) {
                        ForEach(ResultSort.allCases, id: \.self) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }.frame(width: 170)
                }
                HStack {
                    Button("Select Visible") { model.selectVisible() }.disabled(model.visibleItems.isEmpty || model.scanning)
                    Button("Deselect Visible") { model.deselectVisible() }.disabled(model.visibleItems.isEmpty || model.scanning)
                    Spacer()
                    Text("\(model.visibleItems.count) shown of \(model.items.count)")
                        .foregroundStyle(.secondary)
                }
                List {
                    ForEach(model.visibleItems) { item in
                                Toggle(isOn: Binding(
                                    get: { model.selected.contains(item.id) },
                                    set: { if $0 { model.selected.insert(item.id) } else { model.selected.remove(item.id) } }
                                )) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                            Text(item.category.rawValue).font(.caption).foregroundStyle(.secondary)
                                            Text(item.path).font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(1).truncationMode(.middle)
                                        }
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))
                                            .monospacedDigit().foregroundStyle(.secondary)
                                    }
                                }
                    }
                }
                HStack {
                    Text("\(model.items.count) items found")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: model.selectedBytes, countStyle: .file) + " selected")
                    Button("Move Selected to Trash") { model.showingConfirmation = true }
                        .disabled(model.selected.isEmpty || model.scanning)
                }
                }
                if let message = model.message { Text(message).foregroundStyle(.secondary) }
            }
            .padding(20)
            .frame(minWidth: 760, minHeight: 520)
            .onAppear { model.scan() }
            .confirmationDialog("Move \(model.selected.count) selected items to Trash?", isPresented: $model.showingConfirmation) {
                Button("Move to Trash", role: .destructive) { model.clean() }
            } message: {
                Text("Close apps using these files first. You can restore items from Trash.")
            }
            .confirmationDialog("Remove unused Docker build cache?", isPresented: $model.showingDockerConfirmation) {
                Button("Prune Build Cache", role: .destructive) { model.pruneDockerBuildCache() }
            } message: {
                Text("Docker will remove its build cache. Future builds may need to download or rebuild data. This action cannot be undone through Trash.")
            }
        }
    }
}
