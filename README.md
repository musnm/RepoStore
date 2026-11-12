# RepoStore

一个用 SwiftUI 写的 iOS 软件源客户端。添加一个 JSON 源地址，就能浏览源里的应用、下载 IPA，并通过系统分享面板保存或用其他 App 打开。

## 功能

- **源管理** —— 添加 / 删除 / 刷新
- **解锁码** —— 源可要求解锁码；支持本地内置卡密比对，也支持远程 `unlockURL` 校验拿 token
- **应用浏览** —— 列表 / 网格两种视图、搜索、图标远程加载（失败自动渐变色兜底）
- **下载** —— 实时进度、失败重试
- **保存与打开** —— 下载完成弹出系统分享面板（存储到文件 / 用其他 App 打开 / 发送），另有一键 TrollStore 按钮
- **离线缓存** —— 源与应用列表本地持久化

## 源格式

一个源就是一个 JSON 文件（任何静态托管都能放：GitHub Pages / Cloudflare Pages / VPS）：

```json
{
  "name": "我的源",
  "identifier": "com.you.repo",
  "subtitle": "一句话介绍",
  "iconURL": "https://example.com/icon.png",
  "requiresUnlock": true,
  "unlockURL": "https://example.com/api/unlock",
  "apps": [
    {
      "name": "示例应用",
      "bundleIdentifier": "com.example.app",
      "version": "1.0.0",
      "size": 12345678,
      "iconURL": "https://example.com/app.png",
      "downloadURL": "https://example.com/app.ipa",
      "description": "应用简介",
      "developer": "作者",
      "category": "工具"
    }
  ]
}
```

字段兼容：`apps` / `packages` / `items` 三种数组名都识别；`bundleIdentifier` / `bundleid` / `bundleID`、`iconURL` / `icon`、`downloadURL` / `url` 都自动匹配。

### 解锁流程

1. 拉取源时若返回 401/403，或 JSON 里 `requiresUnlock: true`，App 显示锁定界面
2. 用户输入解锁码
3. 若有 `unlockURL`，POST 下面的 JSON 过去：

   ```json
   { "code": "xxxx", "repo": "...", "identifier": "...", "device": "iPhone14,2", "os": "16.1.2" }
   ```

   期望返回：

   ```json
   { "ok": true, "token": "xxxx" }
   ```

   之后拉取源会带上请求头 `X-Unlock-Token: <token>`

4. 若没有 `unlockURL`，与 App 内置卡密表比对（见 `RepoStore/Services/UnlockService.swift` 里的 `localCodes`）

远程校验失败会自动回落到本地比对。

## 构建

本仓库用 GitHub Actions 自动构建 **unsigned IPA**（`.github/workflows/build.yml`）：

1. push 到 `main`，或在 Actions 页面手动触发 `Build IPA`
2. 构建完成后在 Artifact 里下载 `RepoStore-ipa`

工作流会：

- 用 XcodeGen 生成工程
- `xcodebuild` 无签名编译（arm64）
- 打包成 `Payload/RepoStore.app` → `RepoStore.ipa`
- 用 `ldid -S` 伪签名，方便 TrollStore 直接安装

下载的 IPA 可以用 TrollStore 安装，或用自签证书签名后安装。

## 本地开发

```bash
brew install xcodegen
xcodegen generate
open RepoStore.xcodeproj
```

需要 Xcode 15+，部署目标 iOS 16.0。

## 目录结构

```
RepoStore/
├── Models/          Repo.swift, AppItem.swift
├── Services/        RepoService / UnlockService / InstallService / Store / Theme
├── Views/           RootView / RepoDetailView / AppDetailView / UnlockSheet
│                    AddRepoView / SettingsView / AppIconView
├── Info.plist
└── RepoStoreApp.swift
```

## 注意

- `NSAppTransportSecurity` 开了 `NSAllowsArbitraryLoads`，方便放 http 源。只用 https 的话建议关掉。
- 自签证书可能被苹果吊销（掉签），重要数据请先备份。
- 请只用于你自己有权使用的应用。
