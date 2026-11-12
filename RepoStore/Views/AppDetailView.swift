import SwiftUI
import UIKit

struct AppDetailView: View {
    @EnvironmentObject var store: Store
    let item: AppItem

    @State private var shareItems: [Any]?
    @State private var showShare = false

    private var state: DownloadState { store.state(of: item) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    actionCard
                    if !item.description.isEmpty { descCard }
                    infoCard
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
        }
    }

    // MARK: 头部
    private var headerCard: some View {
        VStack(spacing: 14) {
            AppIconView(urlString: item.iconURL, seed: item.name, size: 96, corner: 22)
                .shadow(color: Theme.palette(for: item.name)[0].opacity(0.45),
                        radius: 22, x: 0, y: 12)
            VStack(spacing: 5) {
                Text(item.name)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if !item.developer.isEmpty {
                    Text(item.developer)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSub)
                }
                HStack(spacing: 8) {
                    if !item.version.isEmpty { pill("v\(item.version)", Theme.accent) }
                    if !item.sizeText.isEmpty { pill(item.sizeText, Theme.textSub) }
                    if !item.category.isEmpty { pill(item.category, Theme.accent2) }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }

    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(c)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(c.opacity(0.15)))
    }

    // MARK: 下载 / 操作区
    private var actionCard: some View {
        VStack(spacing: 12) {
            switch state {
            case .idle:
                bigButton(icon: "arrow.down.circle.fill", title: "下载 IPA") {
                    store.download(item)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

            case .downloading(let p):
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Theme.gradient)
                        Text("下载中…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accent)
                    }
                    ProgressView(value: p)
                        .tint(Theme.accent)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card2))

            case .failed(let msg):
                VStack(spacing: 10) {
                    Label(msg, systemImage: "xmark.octagon.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    bigButton(icon: "arrow.clockwise", title: "重试") {
                        store.download(item)
                    }
                }

            case .finished(let url):
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("下载完成")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(url.lastPathComponent)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSub)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)

                    bigButton(icon: "square.and.arrow.up.fill",
                              title: "保存 / 分享 / 打开方式") {
                        shareItems = [url]
                        showShare = true
                    }
                    HStack(spacing: 10) {
                        secondaryButton(icon: "bolt.fill", title: "TrollStore") {
                            InstallService.trollStoreInstall(ipaURL: url)
                        }
                        secondaryButton(icon: "arrow.clockwise", title: "重新下载") {
                            store.download(item)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func bigButton(icon: String, title: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.gradient))
        }
    }

    private func secondaryButton(icon: String, title: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.card2))
        }
    }

    // MARK: 描述
    private var descCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSub)
            Text(item.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: 信息
    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("Bundle ID", item.bundleIdentifier)
            Divider().background(Color.white.opacity(0.06))
            infoRow("版本", item.version.isEmpty ? "-" : item.version)
            if !item.sizeText.isEmpty {
                Divider().background(Color.white.opacity(0.06))
                infoRow("大小", item.sizeText)
            }
            Divider().background(Color.white.opacity(0.06))
            infoRow("下载地址", item.downloadURL)
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundColor(Theme.textSub)
            Spacer()
            Text(v).font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                .lineLimit(1).truncationMode(.middle)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}
