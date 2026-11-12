import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false
    @State private var searchText = ""

    var body: some View {
        TabView {
            RepoListView(searchText: $searchText, showAdd: $showAdd)
                .tabItem { Label("源", systemImage: "square.stack.3d.up.fill") }

            AllAppsView(searchText: $searchText)
                .tabItem { Label("全部应用", systemImage: "square.grid.2x2.fill") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $showAdd) {
            AddRepoView()
                .environmentObject(store)
        }
    }
}

// MARK: - 源列表页
struct RepoListView: View {
    @EnvironmentObject var store: Store
    @Binding var searchText: String
    @Binding var showAdd: Bool
    @State private var unlockTarget: Repo?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if store.repos.isEmpty {
                            EmptyStateView(showAdd: $showAdd)
                                .padding(.top, 60)
                        }
                        ForEach(store.repos) { repo in
                            NavigationLink {
                                RepoDetailView(repoID: repo.id, searchText: $searchText)
                            } label: {
                                RepoCard(repo: repo, loading: store.loadingRepos.contains(repo.id))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await store.refresh(repo.id) }
                                } label: { Label("刷新", systemImage: "arrow.clockwise") }
                                if repo.requiresUnlock {
                                    Button {
                                        if repo.isUnlocked { store.lock(repo.id) }
                                        else { unlockTarget = repo }
                                    } label: {
                                        Label(repo.isUnlocked ? "取消解锁" : "输入解锁码",
                                              systemImage: repo.isUnlocked ? "lock.open" : "lock")
                                    }
                                }
                                Button(role: .destructive) {
                                    store.removeRepo(repo.id)
                                } label: { Label("删除", systemImage: "trash") }
                            }
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .refreshable { await store.refreshAll() }
            }
            .navigationTitle("软件源")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $unlockTarget) { repo in
                UnlockSheet(repo: repo).environmentObject(store)
            }
        }
    }
}

// MARK: - 源卡片
struct RepoCard: View {
    let repo: Repo
    let loading: Bool

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(urlString: repo.iconURL,
                        seed: repo.name.isEmpty ? repo.url : repo.name,
                        size: 56, corner: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(repo.name.isEmpty ? "未命名源" : repo.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if repo.requiresUnlock {
                        Image(systemName: repo.isUnlocked ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(repo.isUnlocked ? Theme.accent : .orange)
                    }
                }
                if !repo.subtitle.isEmpty {
                    Text(repo.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSub)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text("\(repo.apps.count) 个应用")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSub)
                    Text("·").foregroundColor(Theme.textSub)
                    Text(repo.url)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSub.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if loading {
                ProgressView().tint(Theme.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSub.opacity(0.6))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    @Binding var showAdd: Bool
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.gradient)
                    .frame(width: 92, height: 92)
                    .blur(radius: 24)
                    .opacity(0.5)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.gradient)
            }
            Text("还没有软件源")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
            Text("添加一个源地址，就能浏览并下载里面的应用")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showAdd = true } label: {
                Label("添加软件源", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.gradient))
            }
        }
    }
}
