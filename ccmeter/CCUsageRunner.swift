import Foundation

enum CCUsageRunner {

    static let userOverrideKey = "ccusagePath"

    static let candidatePaths: [String] = [
        "/opt/homebrew/bin/ccusage",
        "/usr/local/bin/ccusage",
        "~/.bun/bin/ccusage",
        "~/.npm-global/bin/ccusage",
        "~/.volta/bin/ccusage",
        "~/.local/bin/ccusage",
        "/opt/local/bin/ccusage",
    ]

    private static var cachedURL: URL?

    static func resetCache() { cachedURL = nil }

    static func resolveBinary() -> URL? {
        if let cached = cachedURL, FileManager.default.isExecutableFile(atPath: cached.path) {
            return cached
        }

        if let override = UserDefaults.standard.string(forKey: userOverrideKey),
           !override.isEmpty,
           FileManager.default.isExecutableFile(atPath: override) {
            cachedURL = URL(fileURLWithPath: override)
            return cachedURL
        }

        let expanded = candidatePaths.map { ($0 as NSString).expandingTildeInPath }
        for path in expanded where FileManager.default.isExecutableFile(atPath: path) {
            cachedURL = URL(fileURLWithPath: path)
            return cachedURL
        }

        if let nvm = findNvmCcusage() {
            cachedURL = nvm
            return cachedURL
        }

        if let viaShell = discoverViaLoginShell() {
            cachedURL = viaShell
            return cachedURL
        }

        return nil
    }

    private static func findNvmCcusage() -> URL? {
        let root = ("~/.nvm/versions/node" as NSString).expandingTildeInPath
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: root) else {
            return nil
        }
        for v in versions.sorted().reversed() {
            let candidate = "\(root)/\(v)/bin/ccusage"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }

    private static func discoverViaLoginShell() -> URL? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "command -v ccusage"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do {
            try p.run()
        } catch {
            return nil
        }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    static func run(_ subcommand: String, extraArgs: [String] = []) async throws -> Data {
        guard let url = resolveBinary() else { throw CCUsageError.notFound }
        let p = Process()
        p.executableURL = url
        p.arguments = [subcommand, "--json"] + extraArgs

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        do {
            try p.run()
        } catch {
            throw CCUsageError.launchFailed(error.localizedDescription)
        }

        return try await withCheckedThrowingContinuation { cont in
            p.terminationHandler = { proc in
                let stdoutData = out.fileHandleForReading.readDataToEndOfFile()
                let stderrData = err.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    cont.resume(returning: stdoutData)
                } else {
                    let msg = String(data: stderrData, encoding: .utf8) ?? ""
                    cont.resume(throwing: CCUsageError.nonZeroExit(proc.terminationStatus, msg))
                }
            }
        }
    }

    static func decode<T: Decodable>(_ data: Data, as: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<non-utf8>"
            throw CCUsageError.decode("\(error.localizedDescription) — head: \(preview)")
        }
    }
}
