import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var showClearConfirm = false

    private var totalApps: Int { store.repos.reduce(0) { $0 + $1.apps.count } }

    private var finishedCount: Int {
        store.downloads.values.filter {
            if case .finished = $0 { return true }
            return false
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        statCard
                        toolsCard
                        aboutCard
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showShare) {
                if let u = shareURL { ShareSheet(items: [u]) }
            }
            .alert("清空所有源？", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    store.repos.removeAll()
                    store.save()
                }
            } message: {
                Text("此操作不可撤销")
            }
        }
    }

    private var statCard: some View {
        HStack(spacing: 0) {
            stat(icon: "square.stack.3d.up.fill", value: "\(store.repos.count)", label: "软件源")
            Divider().frame(height: 34).background(Color.white.opacity(0.08))
            stat(icon: "square.grid.2x2.fill", value: "\(totalApps)", label: "应用")
            Divider().frame(height: 34).background(Color.white.opacity(0.08))
            stat(icon: "arrow.down.circle.fill", value: "\(finishedCount)", label: "已完成")
        }
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.gradient)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textSub)
        }
        .frame(maxWidth: .infinity)
    }

    private var toolsCard: some View {
        VStack(spacing: 0) {
            row(icon: "arrow.clockwise", title: "刷新全部源") {
                Task { await store.refreshAll() }
            }
            divider
            row(icon: "square.and.arrow.up", title: "导出源列表 (JSON)") {
                exportRepos()
            }
            divider
            row(icon: "trash", title: "清空所有源", destructive: true) {
                showClearConfirm = true
            }
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
    }

    private func row(icon: String, title: String, destructive: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(destructive ? .red : Theme.accent)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(destructive ? .red : .white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSub.opacity(0.5))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppIconView(urlString: nil, seed: "RepoStore", size: 44, corner: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text("RepoStore").font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("v1.0.0").font(.system(size: 11)).foregroundColor(Theme.textSub)
                }
                Spacer()
            }
            Text("一个轻量的 iOS 软件源客户端。添加源地址即可浏览并下载应用，下载完成后可通过系统分享面板保存或交给其他 App 打开。")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func exportRepos() {
        let brief = store.repos.map { ["url": $0.url, "name": $0.name] }
        guard let data = try? JSONSerialization.data(withJSONObject: brief,
                                                      options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else { return }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("repos.json")
        try? str.write(to: tmp, atomically: true, encoding: .utf8)
        shareURL = tmp
        showShare = true
    }
}
