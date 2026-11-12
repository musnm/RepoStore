import Foundation

/// 源里的一个应用
struct AppItem: Identifiable, Codable, Hashable {
    var id: String { bundleIdentifier + "@" + version }
    var name: String
    var bundleIdentifier: String
    var version: String
    var size: Int
    var iconURL: String?
    var downloadURL: String
    var description: String
    var developer: String
    var category: String

    var sizeText: String {
        guard size > 0 else { return "" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(size))
    }
}

/// 下载状态
enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case finished(URL)
    case failed(String)
}
