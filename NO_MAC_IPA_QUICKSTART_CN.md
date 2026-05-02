# 没有 Mac，生成 iPhone 可安装 IPA

你的证书和全能签没问题时，推荐走这条链路：

```text
GitHub Actions 云端 macOS 编译 Flutter iOS
        ↓
下载 unsigned IPA
        ↓
手机全能签签名安装
        ↓
真机打开 App 测试
```

这条链路不需要你自己有 Mac，也不需要本地装 Xcode。

## 1. 上传项目到 GitHub

建议新建一个私有仓库，例如：

```text
reader-rebuild-ios
```

上传整个 `reader-rebuild` 目录。

不要上传这些内容：

```text
.codex-ops/
*.txt 里的设备 token
旧 IPA
旧破解/补丁目录
```

我已经加了 `.gitignore`，正常上传这个项目目录即可。

## 2. 运行云端 iOS 编译

进入 GitHub 仓库页面：

1. 点击 `Actions`。
2. 选择 `Build unsigned iOS IPA`。
3. 点击 `Run workflow`。
4. `bundle_id` 填一个固定且唯一的值，例如：

```text
com.xie.readerrebuild
```

5. `app_name` 可以保持：

```text
LeonBooks
```

6. 等待编译完成。
7. 下载 `unsigned-ios-ipa` 产物。

下载后你会拿到：

```text
LeonBooks-unsigned.ipa
```

## 3. 用全能签安装

在 iPhone 上：

1. 把 `LeonBooks-unsigned.ipa` 发到手机。
2. 用全能签导入 IPA。
3. 选择你一直在用的证书。
4. 签名。
5. 安装。
6. 如果系统提示信任证书，到设置里信任。

如果安装失败，优先改这几项：

- `bundle_id` 换一个没装过的，例如 `com.xie.readerrebuild.test1`。
- 删除手机上旧版本后再装。
- 确认证书没有被 iOS 设备拦截或吊销。
- 确认全能签能重签 Flutter 里的 `Frameworks`。

## 4. 首次打开 App

设置页填写：

```text
API URL:
http://47.251.109.233/reader-rebuild-1961c0e97312/api
```

设备 token 手动粘贴，不要放进 GitHub。

## 5. 真机跑通标准

至少跑完这些：

1. App 能正常启动。
2. 后端地址和 token 能连接成功。
3. 书架能加载。
4. 搜索能返回结果。
5. 小说章节能打开正文。
6. 漫画章节能加载图片并流畅滑动。
7. TTS 能播放声音。
8. 离线章节能下载，断网后还能打开。
9. 连续使用 10 分钟不闪退。

## 6. 当前限制

这个方案可以完成“真机安装和人工跑通测试”。

它不能直接做到 Xcode 那种实时调试日志。如果要抓崩溃日志，可以后续再接：

- Firebase Crashlytics
- Sentry
- Xcode Devices 日志
- 云真机平台日志
