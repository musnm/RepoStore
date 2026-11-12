import SwiftUI
import UIKit

// MARK: - 颜色扩展
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - 主题
enum Theme {
    static let accent = Color(hex: "5B7CFA")
    static let accent2 = Color(hex: "9B6BFF")
    static let bg = Color(hex: "0B0D14")
    static let card = Color(hex: "161A26")
    static let card2 = Color(hex: "1E2333")
    static let textSub = Color(hex: "8A90A6")

    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 根据字符串稳定生成渐变色板
    static func palette(for key: String) -> [Color] {
        let palettes: [[String]] = [
            ["5B7CFA", "9B6BFF"],
            ["FF6B6B", "FFA36B"],
            ["22C1C3", "4FACFE"],
            ["F857A6", "FF5858"],
            ["43E97B", "38F9D7"],
            ["FA709A", "FEE140"],
            ["667EEA", "764BA2"],
            ["00C6FF", "0072FF"],
            ["F7971E", "FFD200"],
            ["EE0979", "FF6A00"]
        ]
        var h = 5381
        for c in key.unicodeScalars { h = (h &* 33) &+ Int(c.value) }
        let p = palettes[abs(h) % palettes.count]
        return p.map { Color(hex: $0) }
    }

    static func gradient(for key: String) -> LinearGradient {
        LinearGradient(colors: palette(for: key),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 卡片容器
struct GlassCard<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
