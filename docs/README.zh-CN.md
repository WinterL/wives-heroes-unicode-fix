# 致曾是勇者的人妻们 — 启动与全屏补丁

[English](../README.md) · [繁體中文](README.zh-TW.md) · 简体中文 · [日本語](README.ja.md) · [한국어](README.ko.md)

- **启动失败**：修复 ANSI 转 Unicode 错误，保留原有系统区域和 UTF-8 设置，不必将系统区域改为日语。
- **切换全屏后黑屏**：修正高 DPI 缩放导致的分辨率误判，按桌面大小等比例显示，切出再切回游戏也能正常操作。

本补丁为非官方方案；[Steam 官方说明](https://store.steampowered.com/app/4358140/)要求将系统区域设为日语。[官方排错公告](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## 安装

1. 下载 [Apply.cmd](../Apply.cmd)（文件页右上角下载按钮）。再从 [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) 下载 `utf8hack.intel32.clang.7z`，解压取出 `utf8hack.dll`。
2. 在 Steam 中右键点击游戏 → **管理 → 浏览本地文件**，放入 `Apply.cmd` 和 `utf8hack.dll`。
3. 关闭游戏，双击 **Apply.cmd**，完成后从 Steam 启动。

## 原理

| 文件 | 修改内容 |
|---|---|
| `utf8hack.tpm` | 由 `utf8hack.dll` 复制而来，让引擎加载插件。 |
| `yuusyatsuma.cf` | 以 `Shift_JIS`（CP932）读取脚本；全屏按当前桌面分辨率自动等比例放大或缩小，非 16:9 屏幕会留黑边。 |
| `yuusyatsuma.eXe` | 将 `ＭＳ Ｐゴシック` 改为 ASCII `MS PGothic`，并加入 DPI-aware 声明，消除编码错误与全屏分辨率误判。 |

## 测试范围

Steam build **25049578**：本体 **0.26.6.22**、Patch 1 **1.26.6.12**、Patch 2 **2.26.7.23**。测试环境：Windows **11 Pro 25H2（26200.9457）、x64**；系统区域 **zh-TW**，代码页 **UTF-8（65001）**。屏幕 **3840×2160、缩放 225%**。

已从 Steam 正常启动，确认窗口主菜单、音乐、全屏显示、点击与 Alt+Tab 正常。完整游玩、存读档及其他环境未测试。EXE／插件哈希不匹配只警告。[测试详情](TESTING.md)

## 还原与许可

将 [Restore.cmd](../Restore.cmd) 放入游戏文件夹，关闭游戏后运行。还原成功会删除备份，可直接再次应用补丁。

插件：[utf8hack](https://github.com/uyjulian/utf8hack)，原作者 **miahmie**（[原始源码](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)）。本项目代码与文档采用 [MIT](../LICENSE)；其他许可见[第三方声明](THIRD_PARTY_NOTICES.md)。如有疑虑，请通过 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) 提出移除请求。
