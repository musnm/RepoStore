import SwiftUI

// MARK: - 某个源的应用列表
struct RepoDetailView: View {
    @EnvironmentObject var store: Store
    let repoID: UUID
    @Binding var searchText: String
    @State private var unlockTarget: Repo?
    @State private var gridMode = false

    private var repo: Repo? { store.repos.first(where: { $0.id == repoID }) }

    private var filtered: [AppItem] {
        guard let repo else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return repo.apps }
        return repo.apps.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(q) ||
            $0.developer.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let repo, repo.requiresUnlock && !repo.isUnlocked {
                LockedView(repo: repo) { unlockTarget = repo }
            } else {
                ScrollView {
                    if gridMode {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                                  spacing: 12) {
                            ForEach(filtered) { app in
                                NavigationLink { AppDetailView(item: app) } label: {
                                    AppGridCell(item: app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { app in
                                NavigationLink { AppDetailView(item: app) } label: {
                                    AppRow(item: app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }
                }
                .searchable(text: $searchText, prompt: "搜索应用")
            }
        }
        .navigationTitle(repo?.name ?? "源")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    gridMode.toggle()
                } label: {
                    Image(systemName: gridMode ? "list.bullet" : "square.grid.2x2")
                }
            }
        }
        .sheet(item: $unlockTarget) { r in
            UnlockSheet(repo: r).environmentObject(store)
        }
    }
}

// MARK: - 锁定状态
struct LockedView: View {
    let repo: Repo
    var onUnlock: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.18)).frame(width: 96, height: 96)
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(colors: [.orange, .yellow],
                                                    startPoint: .top, endPoint: .bottom))
            }
            Text("这个源需要解锁")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
            Text("输入解锁码后即可浏览和下载源内的应用")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 50)
            Button(action: onUnlock) {
                Label("输入解锁码", systemImage: "key.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.gradient))
            }
        }
    }
}

// MARK: - 列表行
struct AppRow: View {
    let item: AppItem
    var body: some View {
        HStack(spacing: 12) {
            AppIconView(urlString: item.iconURL, seed: item.name, size: 54, corner: 13)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSub)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !item.version.isEmpty {
                        Text("v\(item.version)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.15)))
                    }
                    if !item.sizeText.isEmpty {
                        Text(item.sizeText)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSub)
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20))
                .foregroundStyle(Theme.gradient)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - 网格单元
struct AppGridCell: View {
    let item: AppItem
    var body: some View {
        VStack(spacing: 8) {
            AppIconView(urlString: item.iconURL, seed: item.name, size: 62, corner: 15)
            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(item.version.isEmpty ? " " : "v\(item.version)")
                .font(.system(size: 10))
                .foregroundColor(Theme.textSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - 全部应用页
struct AllAppsView: View {
    @EnvironmentObject var store: Store
    @Binding var searchText: String

    private var all: [AppItem] {
        let flat = store.repos.flatMap { $0.apps }
        var dict: [String: AppItem] = [:]
        for a in flat {
            if let exist = dict[a.bundleIdentifier] {
                if a.version.compare(exist.version, options: .numeric) == .orderedDescending {
                    dict[a.bundleIdentifier] = a
                }
            } else {
                dict[a.bundleIdentifier] = a
            }
        }
        let list = Array(dict.values)
        let q = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = q.isEmpty ? list : list.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(q)
        }
        return filtered.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if all.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 38)).foregroundColor(Theme.textSub)
                        Text(store.repos.isEmpty ? "先去「源」标签添加软件源" : "没有匹配的应用")
                            .font(.system(size: 14)).foregroundColor(Theme.textSub)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(all) { app in
                                NavigationLink { AppDetailView(item: app) } label: {
                                    AppRow(item: app)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 8)
                    }
                }
            }
            .navigationTitle("全部应用")
            .searchable(text: $searchText, prompt: "搜索应用")
        }
    }
}
