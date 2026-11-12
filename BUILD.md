# 怎么把它变成能装的 IPA

代码已完整，但 **GitHub 免费账户没有 macOS runner**，所以 Actions 只能做 Linux 侧检查，出不了 IPA。
下面是三条真实可行的出包路径，按省事程度排序。

---

## 方案一：用 Mac 构建（最正统，推荐）

任何一台装了 Xcode 的 Mac（也可以用朋友的、或者云 Mac）：

```bash
brew install xcodegen
git clone https://github.com/musnm/RepoStore.git
cd RepoStore
xcodegen generate
open RepoStore.xcodeproj
```

然后在 Xcode 里：

1. 选中 `RepoStore` target → Signing & Capabilities
2. 勾选 **Automatically manage signing**，选你的开发者账号（免费 Apple ID 也行）
3. 改 bundle id 成唯一的，比如 `com.你的名字.repostore`
4. 选真机 → Product → Archive → Distribute App → **Ad Hoc** 或 **Development**
5. 导出 `.ipa`

> 免费 Apple ID 签的 App **7 天过期**，到期要重签。想要长期用，走 TrollStore（方案二）。

---

## 方案二：TrollStore（你的 iOS 16.1.2 最合适）

TrollStore 装 App 需要的是**伪签名** IPA，不需要真证书。任何一处能出 `Payload/RepoStore.app` 就行：

**在 Mac 上出无签名 IPA：**

```bash
xcodebuild -project RepoStore.xcodeproj \
  -scheme RepoStore -configuration Release -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64

mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/RepoStore.app Payload/
ldid -S Payload/RepoStore.app/RepoStore
zip -r RepoStore.ipa Payload
```

把这个 `RepoStore.ipa` 传到手机上，用 **TrollStore → 点开 IPA → Install** 即可。永久有效，不掉签。

> `ldid -S` 是关键 —— 打上 TrollStore 认识的伪签名，否则 TrollStore 会拒绝安装。

---

## 方案三：找免费/便宜的 Mac CI

如果你没有 Mac，但又想要 CI 自动出包，这几个服务有 macOS runner：

| 服务 | 免费额度 |
|---|---|
| **Codemagic** | 每月 500 分钟 macOS，需注册 |
| **Bitrise** | 有免费档，macOS 机器额度少 |
| **Cirrus CI** | 开源项目免费，含 macOS |
| **GitHub Actions** | 免费账户**没有** macOS；付费 Team/Enterprise 才有 |

用 GitHub 登录后把本仓库接进去，构建命令直接抄上面的方案二脚本即可。

---

## 出包后怎么装

| 环境 | 情况 |
|---|---|
| **TrollStore** | 直接装无签名/伪签名 IPA，永久有效 ✅ 你的 iOS 16.1.2 支持 |
| **自签证书** | 用全能签 / LCSign / AltStore 签，7 天或 1 年（看证书） |
| **越狱** | 随便装 |

---

## 调试建议

首次跑起来如果白屏或崩溃，先在 Xcode 里连真机跑一次，Console 会直接告诉你原因。
最常出问题的两处：

1. **`Info.plist` 路径** —— 确认 `INFOPLIST_FILE` 指向 `RepoStore/Info.plist`
2. **`LSApplicationQueriesSchemes`** —— 少了 `apple-magnifier` 的话，TrollStore 按钮会静默失效

---

## 想自己验证源格式

把 `example-repo.json` 传到任意静态托管（GitHub Pages 就行），拿到直链后在 App 里「添加源」。
先不填解锁码，能正常列出 2 个应用就说明源格式没问题。
