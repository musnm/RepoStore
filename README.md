# RepoStore

iOS 第三方软件源客户端（Objective-C + UIKit），支持自定义 JSON 源、ESign 加密源、解锁码、IPA 下载与 TrollStore 安装。

> 当前实现语言为 **Objective-C**（早前的 SwiftUI 版本已不在主分支）。

## 功能

- **自定义源**：粘贴 JSON 源地址即可添加，兼容「轻松签 / 全能签」的 `Source.json` 字段。
- **加密源**：识别 `source[base64]`（ESign）、含 `[K$]`/`[M$]` 分隔的、以及普通 base64 源。**注意**：ESign 解密需要自备密钥头文件（见下方「构建」）。
- **解锁码**：完全由源自己声明的 `unlockURL` 决定，App 不内置任何卡密；解锁后令牌随请求头 `Authorization` / `X-Unlock-Token` 透传。
- **下载管理**：后台下载、实时进度、断点续传、取消清理、下载记录持久化。
- **安装 / 分享**：分享面板（已剔除 AirDrop，规避 TrollStore 签名应用在 AirDrop 图标渲染时的崩溃）、`apple-magnifier://` 直装。
- **自适应布局**：列表行、操作卡片均按内容自动撑高，隐藏控件会折叠掉占位高度。

## 目录

```
objc/
├── build.sh                  # Theos 交叉编译脚本（Linux / Alpine）
├── ent_ts.plist              # TrollStore 伪签名 entitlements
├── entitlements.plist        # 普通伪签名 entitlements
├── RS/
│   ├── RSAppDelegate.{h,m}   # 入口
│   ├── main.m
│   ├── Models/
│   │   ├── RSAppItem.{h,m}   # 应用条目（含 isDownloadable 判定）
│   │   ├── RSRepo.{h,m}      # 源
│   │   └── RSDeobfuscator.*  # ESign / Base64 源解码
│   ├── Services/
│   │   ├── RSStore.{h,m}     # 源持久化、刷新、下载、进度
│   │   ├── RSTheme.{h,m}     # 配色与渐变
│   │   ├── RSUnlockService.* # 解锁码校验（远程）
│   │   └── RSInstallService.*# 分享 / TrollStore 安装
│   └── Views/
│       ├── RSRepoListViewController.m   # 源列表 + 气泡菜单
│       ├── RSRepoDetailViewController.m # 源内应用列表
│       ├── RSAppDetailViewController.m  # 详情 + 下载
│       ├── RSDownloadsViewController.m  # 下载管理
│       ├── RSUnlockViewController.m     # 解锁
│       ├── RSAddRepoViewController.m    # 添加源
│       ├── RSPopMenuView.{h,m}          # 气泡菜单组件
│       ├── RSRepoCell.m / RSAppCell.m
│       └── RSIconView.{h,m}
└── RS/Resources/             # Info.plist、Assets.xcassets
```

## 构建

依赖：

- Theos 工具链（`arm64-apple-darwin14-clang`）与 iPhoneOS SDK
- `ldid`（伪签名）

**必须先自备 `objc/RS/Models/RSEsignKey.h`**，它包含第三方 ESign 解密密钥表，出于授权原因未随仓库分发。缺该文件时 `RSDeobfuscator.m` 会被跳过编译，ESign 加密源不可用，其余功能不受影响。

该头文件需提供：

```objc
extern const unsigned char rs_esign_key[];
#define RS_ESIGN_KEY_LEN  /* key 字节数 */
```

参考实现：Nyasami/Ksign — `AltSourceKit/Utilities/Key/EsignSourceKey.swift`

然后：

```sh
cd objc
sh build.sh
# 产物：objc/build/RepoStore.ipa
```

## 源格式

见 `example-repo.json`。关键字段：

| 字段 | 说明 |
| --- | --- |
| `name` | 应用名（必填） |
| `bundleIdentifier` | Bundle ID |
| `downloadURL` | IPA 地址（必填，且 `size > 0` 才视为可下载） |
| `version` / `versionDate` | 版本 |
| `size` | 字节数 |
| `iconURL` | 图标 |
| `localizedDescription` | 简介（可内含 `分类：xxx`） |
| `developerName` | 开发者 |
| `tintColor` | 十六进制主色，如 `5B7CFA` |

源级字段：`name`、`identifier`、`subtitle`、`iconURL`、`tintColor`、`requiresUnlock`、`unlockURL`、`apps[]`。

`size` 为 0 或 `downloadURL` 为空的条目会被识别为公告 / 通知，界面上不提供下载。

## 许可

仅供学习交流。请勿用于分发侵犯版权的内容。
