import Foundation

enum RepoError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decodeFailed(String)
    case locked
    case unlockFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "源地址无效"
        case .badStatus(let c): return "服务器返回 \(c)"
        case .decodeFailed(let m): return "解析失败：\(m)"
        case .locked: return "该源需要解锁码"
        case .unlockFailed(let m): return "解锁失败：\(m)"
        }
    }
}

actor RepoService {
    static let shared = RepoService()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }

    /// 拉取并解析源
    func fetch(_ repo: Repo) async throws -> Repo {
        guard let u = URL(string: repo.url), u.scheme != nil else {
            throw RepoError.invalidURL
        }
        var req = URLRequest(url: u)
        req.setValue("RepoStore/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        if let token = repo.unlockToken, !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "X-Unlock-Token")
        }

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw RepoError.locked
            }
            guard (200..<300).contains(http.statusCode) else {
                throw RepoError.badStatus(http.statusCode)
            }
        }

        do {
            let raw = try decoder.decode(RawRepo.self, from: data)
            var r = repo
            r.name = raw.name ?? (repo.name.isEmpty ? (u.host ?? "未命名源") : repo.name)
            r.identifier = raw.identifier ?? raw.name ?? ""
            r.subtitle = raw.subtitle ?? raw.description ?? ""
            r.iconURL = raw.iconURL ?? raw.icon ?? repo.iconURL
            r.tint = raw.tint ?? repo.tint
            r.requiresUnlock = raw.requiresUnlock ?? raw.locked ?? repo.requiresUnlock
            r.unlockURL = raw.unlockURL ?? repo.unlockURL

            let rawApps = raw.apps ?? raw.packages ?? raw.items ?? []
            r.apps = rawApps.compactMap { $0.toItem() }
            r.lastUpdated = Date()
            return r
        } catch {
            throw RepoError.decodeFailed(error.localizedDescription)
        }
    }

    /// 下载 IPA / 文件
    func download(_ item: AppItem,
                  progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard let u = URL(string: item.downloadURL) else { throw RepoError.invalidURL }
        var req = URLRequest(url: u)
        req.setValue("RepoStore/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (bytes, resp) = try await session.bytes(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RepoError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let total = max(Int(http.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0, item.size)
        let extRaw = (u.path as NSString).pathExtension
        let ext = extRaw.isEmpty ? "ipa" : extRaw
        let safeName = item.name.replacingOccurrences(of: "/", with: "_")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoStore", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(safeName)_\(item.version).\(ext)")

        FileManager.default.createFile(atPath: dest.path, contents: nil)
        let handle = try FileHandle(forWritingTo: dest)
        defer { try? handle.close() }

        var received = 0
        var buf = Data()
        buf.reserveCapacity(1 << 18)

        for try await b in bytes {
            buf.append(b)
            if buf.count >= (1 << 18) {
                try handle.write(contentsOf: buf)
                received += buf.count
                buf.removeAll(keepingCapacity: true)
                if total > 0 {
                    let p = Double(received) / Double(total)
                    progress(min(max(p, 0), 1))
                }
            }
        }
        if !buf.isEmpty {
            try handle.write(contentsOf: buf)
            received += buf.count
        }
        progress(1)
        return dest
    }
}
