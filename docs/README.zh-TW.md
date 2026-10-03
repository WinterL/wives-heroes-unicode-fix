# 致曾是勇者的人妻們 — 啟動與全螢幕修補

[English](../README.md) · 繁體中文 · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

- **啟動失敗**：修正 ANSI 轉 Unicode 錯誤，保留原本系統語系與 UTF-8 設定，不必改成日文系統語系。
- **全螢幕黑畫面**：修正高 DPI 縮放造成的解析度誤判，按桌面大小等比例顯示，切出再切回遊戲也能正常操作。

本修補為非官方方案；[Steam 官方說明](https://store.steampowered.com/app/4358140/)要求使用日文系統語系。[官方排錯公告](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## 安裝

1. 下載 [Apply.cmd](../Apply.cmd)（檔案頁右上角下載鈕）。再從 [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) 下載 `utf8hack.intel32.clang.7z`，解壓縮取出 `utf8hack.dll`。
2. 在 Steam 對遊戲按右鍵 → **管理 → 瀏覽本機檔案**，放入 `Apply.cmd` 和 `utf8hack.dll`。
3. 關閉遊戲，雙擊 **Apply.cmd**，完成後從 Steam 啟動。

## 原理

| 檔案 | 修改內容 |
|---|---|
| `utf8hack.tpm` | 由 `utf8hack.dll` 複製而來，讓引擎載入外掛。 |
| `yuusyatsuma.cf` | 以 `Shift_JIS`（CP932）讀取腳本；全螢幕依當前桌面解析度自動等比例放大或縮小，非 16:9 螢幕會留黑邊。 |
| `yuusyatsuma.eXe` | 將 `ＭＳ Ｐゴシック` 改為 ASCII `MS PGothic`，並加入 DPI-aware 宣告，排除編碼錯誤與全螢幕解析度誤判。 |

## 測試範圍

Steam build **25049578**：本體 **0.26.6.22**、Patch 1 **1.26.6.12**、Patch 2 **2.26.7.23**。實測環境：Windows **11 Pro 25H2（26200.9457）、x64**；系統語系 **zh-TW**，字碼頁 **UTF-8（65001）**。螢幕 **3840×2160、縮放 225%**。

已從 Steam 正常啟動，確認視窗主選單、音樂、全螢幕顯示、點擊與 Alt+Tab 正常。完整遊玩、存讀檔及其他環境未測。EXE／外掛雜湊不符只警告。[測試詳情](TESTING.md)

## 還原與授權

將 [Restore.cmd](../Restore.cmd) 放入遊戲資料夾，關閉遊戲後執行。還原成功會刪除備份，可直接再次套用修補。

外掛：[utf8hack](https://github.com/uyjulian/utf8hack)，原作者 **miahmie**（[原始碼](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)）。本專案程式與文件採 [MIT](../LICENSE)；其他授權見[第三方聲明](THIRD_PARTY_NOTICES.md)。如有疑慮，請透過 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) 提出移除請求。
