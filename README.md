# 椒盐阅读

一个安静、克制的双端 RSS 阅读器 —— Windows 桌面 + Android 手机，同一套 Flutter 代码。

不追求功能大而全，只把「读」这件事做好：干净的排版、可调的字体、离线可读的正文。

## 特性

- **订阅** —— 支持 RSS 2.0 / RSS 1.0 / Atom，自动识别源类型并给出可读的报错
- **正文 · 点开即看** —— 优先取 `content:encoded` 全文；只有摘要的文章会在刷新后于后台预抓原文正文（去广告与导航），点开即见全文，未就绪时可随时手动抓取或用浏览器打开
- **配图缓存** —— 文章配图缓存到本机（上限 128 MB，超出自动清理最久未看的），重看不再等下载，已读内容离线也能看；设置 → 图片缓存可查看占用并清空
- **液态玻璃界面** —— 窗口底层铺一层柔和极光渐变，导航条、设置分组、文章卡片、阅读页顶部栏、对话框都是半透明磨砂玻璃（各有实时模糊），浅色与深色主题都成立；Windows 11 上窗口本身还挂系统 Mica，能透出桌面壁纸的色调
- **阅读排版** —— 字号 / 行距 / 栏宽可调，支持浅色、深色、跟随系统
- **字体** —— 系统字体、内置字体（思源宋体、霞鹜文楷，首次选择时从国内镜像下载，可离线使用）、本地导入字体
- **整理** —— 未读 / 全部 / 收藏 / 分组，搜索
- **迁移与同步** —— OPML 导入导出；WebDAV（如坚果云）双向同步订阅与已读、收藏状态
- **应用内更新** —— 设置 → 关于里检查新版本，Android 可直接下载安装，Windows 下载压缩包后覆盖目录

## 下载

前往 [Releases](https://github.com/yanchou3/salt-reader/releases)：

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Android | `salt-reader-<版本>-android.apk` | 直接安装；首次需允许「安装未知应用」 |
| Windows | `salt-reader-windows-x64.zip` | 解压后运行 `rss_reader.exe`；升级时覆盖原目录即可 |

> 安装包较大是因为 Flutter 运行时与字体资源都打包在内，安装后无需联网即可阅读已有内容。

> **Android 签名变更（v0.1.9 起）**：安装包已改用正式 keystore 签名。因签名不同，从 v0.1.8 及更早版本升级时会提示「应用未安装」，**需先卸载旧版本再装新包**；卸载会清空本机数据，请先通过 WebDAV 同步或导出 OPML 做好备份。此后的版本升级不再受此影响。

## 隐私

**没有账号体系，没有埋点，没有第三方统计，也没有任何自建服务器中转。**

联网只发生在下面这几种情况，且全部由你的操作触发：

1. 拉取你订阅的 RSS 源 —— 只连该源的地址
2. 抓取原文全文与显示文章配图 —— 只连该文章所在站点的地址；配图会缓存到本机，可在设置里清空
3. WebDAV 同步 —— 只连你自己填的 WebDAV 服务器
4. 检查更新 —— 只连 GitHub 的 Releases 接口

订阅、文章、已读与收藏记录都保存在本机。WebDAV 的地址、用户名与密码同样只保存本机，用于同步请求。

## 从源码构建

需要 Flutter 3.47+。

```bash
flutter pub get

# Windows
flutter build windows --release

# Android
flutter build apk --release
```

Windows 产物在 `build/windows/x64/runner/Release/`，Android 产物在 `build/app/outputs/flutter-apk/app-release.apk`。

### 注意：Android 构建不要开启 R8

`shared_preferences_android` 2.5+ 使用 Pigeon 的 jnigen 绑定，Dart 侧按**硬编码的 JNI 签名**查找 Java 方法，签名串中包含 `Lkotlin/coroutines/Continuation;`。R8 会把 `kotlin.coroutines.Continuation` 重命名，导致运行时抛：

```
NoSuchMethodError: SharedPreferencesApiRegistrar.getAll(...Continuation;)
```

因此本项目在 `android/gradle.properties` 中设置了 `shrink=false`，并在 `android/app/build.gradle.kts` 里显式关闭 `isMinifyEnabled` / `isShrinkResources`。请勿开启，否则应用一运行就会报错。

## 许可

暂未指定开源许可（保留所有权利）。如需在其它项目中使用，请先联系作者。
