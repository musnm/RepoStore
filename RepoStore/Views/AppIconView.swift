import SwiftUI
import UIKit

/// 通用远程图片（带缓存 + 渐变色兜底）
struct AppIconView: View {
    let urlString: String?
    let seed: String
    var size: CGFloat = 52
    var corner: CGFloat = 12

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: Theme.palette(for: seed),
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
        .onAppear(perform: load)
    }

    private var initial: String {
        String(seed.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    private func load() {
        guard let s = urlString, let u = URL(string: s), !s.isEmpty else { return }
        let key = s as NSString
        if let cached = ImageCache.shared.object(forKey: key) {
            image = cached
            return
        }
        URLSession.shared.dataTask(with: u) { data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
            ImageCache.shared.setObject(img, forKey: key, cost: data.count)
            DispatchQueue.main.async { self.image = img }
        }.resume()
    }
}

final class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
    private init() { shared.countLimit = 300 }
}
