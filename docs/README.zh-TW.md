# 致曾是勇者的人妻們 — 啟動、全螢幕與語音修補

[English](../README.md) · 繁體中文 · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

- **啟動失敗**：修正 ANSI 轉 Unicode 錯誤，保留原本系統語系與 UTF-8 設定，不必改成日文系統語系。
- **全螢幕黑畫面**：修正高 DPI 縮放造成的解析度誤判，按桌面大小等比例顯示，切出再切回遊戲也能正常操作。
- **缺少配音與回顧重播**：以日文劇本交互參照，修復英文、繁中、簡中與韓文劇本的日文配音及回顧重播。

本修補為非官方方案；[Steam 官方說明](https://store.steampowered.com/app/4358140/)要求使用日文系統語系。[官方排錯公告](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## 安裝

### 啟動與全螢幕

1. 下載 [Apply.cmd](../Apply.cmd)（檔案頁右上角下載鈕）。再從 [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) 下載 `utf8hack.intel32.clang.7z`，解壓縮取出 `utf8hack.dll`。
2. 在 Steam 對遊戲按右鍵 → **管理 → 瀏覽本機檔案**，放入 `Apply.cmd` 和 `utf8hack.dll`。
3. 關閉遊戲，雙擊 **Apply.cmd**，完成後從 Steam 啟動。

### 配音與回顧重播

1. 關閉遊戲，下載 [patch_3.xp3](../patch_3.xp3)（檔案頁右上角下載鈕）。在 Steam 對遊戲按右鍵 → **管理 → 瀏覽本機檔案**，將檔案放在 `yuusyatsuma.eXe` 旁。
2. 保留原本的 `patch_1.xp3` 與 `patch_2.xp3`。若已有 `patch_3.xp3`，先備份至遊戲資料夾外並確認來源，再決定是否替換；其他同名補丁可能與本補丁衝突。
3. 從 Steam 重開遊戲並重新進入該場景。舊回顧紀錄不會自動補上缺失的重播連結。

語音補丁可獨立安裝；只修復語音時，不需要 `Apply.cmd` 或 `utf8hack.dll`。

## 原理

| 檔案 | 修改內容 |
|---|---|
| `utf8hack.tpm` | 由 `utf8hack.dll` 複製而來，讓引擎載入外掛。 |
| `yuusyatsuma.cf` | 以 `Shift_JIS`（CP932）讀取腳本；全螢幕依當前桌面解析度自動等比例放大或縮小，非 16:9 螢幕會留黑邊。 |
| `yuusyatsuma.eXe` | 將 `ＭＳ Ｐゴシック` 改為 ASCII `MS PGothic`，並加入 DPI-aware 宣告，排除編碼錯誤與全螢幕解析度誤判。 |
| `patch_3.xp3` | 覆蓋 54 個劇本，修復語音指令、音檔編號與回顧重播，並補回繁中、簡中各一處缺失字幕及停頓。 |

以日文劇本的對應台詞與語音指令交互參照，共修改 54 個腳本、985 行，並非 985 句獨立台詞。使用遊戲既有的日文音檔，未新增錄音。具體改動見[語音修補報告](VOICE_PATCH_REPORT.txt)。

## 測試範圍

**更新相容性（2026-10-29）：** Steam build **26287432** 也相容於現有下載檔，無須重新安裝。語音補丁覆蓋的 54 個來源劇本皆未改變。本次為檔案層級驗證，未重新實機遊玩。[詳情](TESTING.md#steam-build-26287432-compatibility)。

Steam build **25049578**：本體 **0.26.6.22**、Patch 1 **1.26.6.12**、Patch 2 **2.26.7.23**。實測環境：Windows **11 Pro 25H2（26200.9457）、x64**；系統語系 **zh-TW**，字碼頁 **UTF-8（65001）**。螢幕 **3840×2160、縮放 225%**。

已從 Steam 正常啟動，確認視窗主選單、音樂、全螢幕顯示、點擊與 Alt+Tab 正常。完整遊玩、存讀檔及其他環境未測。EXE／外掛雜湊不符只警告。[測試詳情](TESTING.md)

語音補丁已完成全劇本語言對照，並使用原引擎解析器檢查語音與重播指令的派送。這是腳本層級驗證，未逐條路線實機遊玩或逐句聽音。[範圍與改動](VOICE_PATCH_REPORT.txt)

## 還原與授權

還原啟動／全螢幕修改：將 [Restore.cmd](../Restore.cmd) 放入遊戲資料夾，關閉遊戲後執行。還原成功會刪除備份，可直接再次套用這兩項修補。`Restore.cmd` 不會移除語音補丁。

還原語音補丁：關閉遊戲，只移除本專案的 `patch_3.xp3`，或改名為 `patch_3.xp3.disabled`。若先前備份過其他 `patch_3.xp3`，請將它還原。

外掛：[utf8hack](https://github.com/uyjulian/utf8hack)，原作者 **miahmie**（[原始碼](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)）。本專案程式與文件採 [MIT](../LICENSE)；其他授權見[第三方聲明](THIRD_PARTY_NOTICES.md)。如有疑慮，請透過 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) 提出移除請求。

`patch_3.xp3` 內的遊戲劇本內容仍屬原權利人所有，不適用本專案的 MIT 授權。
