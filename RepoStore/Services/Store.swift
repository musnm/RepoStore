import SwiftUI
import Combine

@MainActor
final class Store: ObservableObject {
    @Published var repos: [Repo] = []
    @Published var downloads: [String: DownloadState] = [:]
    @Published var loadingRepos: Set<UUID> = []
    @Published var errorMessage: String?

    private let saveKey = "repostore.repos.v1"

    init() { load() }

    // MARK: 持久化
    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let list = try? JSONDecoder().decode([Repo].self, from: data) else { return }
        repos = list
    }

    func save() {
        if let data = try? JSONEncoder().encode(repos) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    // MARK: 源管理
    func addRepo(url: String) {
        var u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        if !u.lowercased().hasPrefix("http") { u = "https://" + u }
        guard !repos.contains(where: { $0.url == u }) else { return }
        repos.append(Repo(url: u))
        save()
        if let r = repos.last {
            Task { await refresh(r.id) }
        }
    }

    func removeRepo(_ id: UUID) {
        repos.removeAll { $0.id == id }
        save()
    }

    // MARK: 刷新
    func refresh(_ id: UUID) async {
        guard let idx = repos.firstIndex(where: { $0.id == id }) else { return }
        loadingRepos.insert(id)
        defer { loadingRepos.remove(id) }
        do {
            let updated = try await RepoService.shared.fetch(repos[idx])
            if let i = repos.firstIndex(where: { $0.id == id }) {
                var u = updated
                u.isUnlocked = repos[i].isUnlocked
                u.unlockToken = repos[i].unlockToken
                if u.apps.isEmpty { u.apps = repos[i].apps }
                repos[i] = u
                save()
            }
        } catch RepoError.locked {
            if let i = repos.firstIndex(where: { $0.id == id }) {
                repos[i].requiresUnlock = true
                repos[i].isUnlocked = false
            }
            save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAll() async {
        let ids = repos.map(\.id)
        for id in ids {
            await refresh(id)
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    // MARK: 解锁
    func unlock(_ id: UUID, code: String) async -> Bool {
        guard let idx = repos.firstIndex(where: { $0.id == id }) else { return false }
        let res = await UnlockService.verify(code: code, for: repos[idx])
        if res.ok {
            repos[idx].isUnlocked = true
            repos[idx].unlockToken = res.token ?? code
            save()
            await refresh(id)
            return true
        } else {
            errorMessage = res.message
            return false
        }
    }

    func lock(_ id: UUID) {
        guard let idx = repos.firstIndex(where: { $0.id == id }) else { return }
        repos[idx].isUnlocked = false
        repos[idx].unlockToken = nil
        save()
    }

    // MARK: 下载
    func download(_ item: AppItem) {
        downloads[item.id] = .downloading(progress: 0)
        Task {
            do {
                let url = try await RepoService.shared.download(item) { p in
                    Task { @MainActor in
                        self.downloads[item.id] = .downloading(progress: p)
                    }
                }
                self.downloads[item.id] = .finished(url)
            } catch {
                self.downloads[item.id] = .failed(error.localizedDescription)
            }
        }
    }

    func state(of item: AppItem) -> DownloadState {
        downloads[item.id] ?? .idle
    }
}
