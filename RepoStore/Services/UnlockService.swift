import Foundation
import UIKit

/// 解锁码校验
enum UnlockService {

    struct Result {
        var ok: Bool
        var token: String?
        var message: String?
    }

    /// 本地内置卡密表 —— 改成你自己的
    static let localCodes: Set<String> = [
        "FKBFC00FFF7C33"
    ]

    static func verify(code: String, for repo: Repo) async -> Result {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return Result(ok: false, message: "请输入解锁码") }

        // 1. 有远程接口就走远程
        if let urlStr = repo.unlockURL, let u = URL(string: urlStr), !urlStr.isEmpty {
            var req = URLRequest(url: u)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("RepoStore/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
            let body: [String: String] = [
                "code": c,
                "repo": repo.url,
                "identifier": repo.identifier,
                "device": deviceModel(),
                "os": UIDevice.current.systemVersion
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 15

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let okFlag = (obj["ok"] as? Bool)
                        ?? (obj["success"] as? Bool)
                        ?? (obj["valid"] as? Bool)
                        ?? false
                    let token = (obj["token"] as? String) ?? (obj["key"] as? String)
                    let msg = (obj["message"] as? String) ?? (obj["error"] as? String)
                    return Result(ok: okFlag && (200..<300).contains(status),
                                  token: token,
                                  message: msg ?? (okFlag ? nil : "解锁码无效"))
                }
                if (200..<300).contains(status) {
                    return Result(ok: true, token: nil, message: nil)
                }
                return Result(ok: false, message: "校验失败(\(status))")
            } catch {
                if localCodes.contains(c) {
                    return Result(ok: true, token: c, message: nil)
                }
                return Result(ok: false, message: error.localizedDescription)
            }
        }

        // 2. 本地比对
        if localCodes.contains(c) {
            return Result(ok: true, token: c, message: nil)
        }
        return Result(ok: false, message: "解锁码无效")
    }

    static func deviceModel() -> String {
        var sys = utsname()
        uname(&sys)
        let m = withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return m
    }
}
