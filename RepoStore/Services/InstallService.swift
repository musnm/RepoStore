import SwiftUI
import UIKit

/// 用 UIViewControllerRepresentable 包一层 UIActivityViewController，
/// 用于下载完成后弹出系统分享 / 打开方式面板。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 安装 / 打开服务
enum InstallService {
    /// 调起 TrollStore 安装
    static func trollStoreInstall(ipaURL: URL) {
        let encoded = ipaURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let candidates = [
            "apple-magnifier://install?url=\(encoded)",
            "trollstore://install?url=\(encoded)"
        ]
        for c in candidates {
            if let u = URL(string: c), UIApplication.shared.canOpenURL(u) {
                UIApplication.shared.open(u)
                return
            }
        }
        toast("未检测到 TrollStore，请使用「保存 / 分享」打开")
    }

    static func toast(_ s: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: s, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            if let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                root.present(alert, animated: true)
            }
        }
    }
}
