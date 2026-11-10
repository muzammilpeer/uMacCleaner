import Foundation

public struct DockerDiagnostics: Sendable {
    public let output: String
    public let available: Bool

    public static func diskUsage() -> DockerDiagnostics {
        let result = run(["system", "df"])
        return DockerDiagnostics(output: result.output, available: result.available)
    }

    /// Removes Docker build cache only. This does not touch volumes or the Docker disk image.
    public static func pruneBuildCache() -> DockerDiagnostics {
        let result = run(["builder", "prune", "--force"])
        return DockerDiagnostics(output: result.output, available: result.available)
    }

    private static func run(_ arguments: [String]) -> DockerDiagnostics {
        let candidates = ["/opt/homebrew/bin/docker", "/usr/local/bin/docker", "/Applications/Docker.app/Contents/Resources/bin/docker", "/usr/bin/docker"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return DockerDiagnostics(output: "Docker CLI was not found. Install or start Docker Desktop, then scan again.", available: false)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return DockerDiagnostics(output: output.isEmpty ? "Docker returned no data." : output,
                                     available: process.terminationStatus == 0)
        } catch {
            return DockerDiagnostics(output: error.localizedDescription, available: false)
        }
    }
}
