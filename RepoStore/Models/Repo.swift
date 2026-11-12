import Foundation

/// 一个软件源
struct Repo: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var url: String
    var name: String = ""
    var identifier: String = ""
    var subtitle: String = ""
    var iconURL: String?
    var tint: String?
    var requiresUnlock: Bool = false
    var unlockURL: String?
    var apps: [AppItem] = []
    var lastUpdated: Date = Date()
    var isUnlocked: Bool = false
    var unlockToken: String?
}

/// 源 JSON 的原始解码结构（宽松解析，兼容多种字段名）
struct RawRepo: Decodable {
    var name: String?
    var identifier: String?
    var subtitle: String?
    var description: String?
    var icon: String?
    var iconURL: String?
    var tint: String?
    var requiresUnlock: Bool?
    var locked: Bool?
    var unlockURL: String?
    var apps: [RawApp]?
    var packages: [RawApp]?
    var items: [RawApp]?
}

struct RawApp: Decodable {
    var name: String?
    var bundleIdentifier: String?
    var bundleid: String?
    var bundleID: String?
    var version: String?
    var size: Int?
    var icon: String?
    var iconURL: String?
    var downloadURL: String?
    var url: String?
    var description: String?
    var developer: String?
    var author: String?
    var category: String?

    func toItem() -> AppItem? {
        guard let n = name, !n.isEmpty else { return nil }
        let dl = downloadURL ?? url ?? ""
        guard !dl.isEmpty else { return nil }
        return AppItem(
            name: n,
            bundleIdentifier: bundleIdentifier ?? bundleid ?? bundleID ?? "unknown.\(n.hashValue)",
            version: version ?? "1.0",
            size: size ?? 0,
            iconURL: iconURL ?? icon,
            downloadURL: dl,
            description: description ?? "",
            developer: developer ?? author ?? "",
            category: category ?? ""
        )
    }
}
