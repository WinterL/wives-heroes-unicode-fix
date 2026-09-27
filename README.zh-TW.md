# 致曾是勇者的人妻們：Unicode 啟動修補

[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

本專案是 Windows Steam 版《致曾是勇者的人妻們／かつて勇者だった妻達へ》的**非官方實驗性修補**。針對吉里吉里 2 的 ANSI → Unicode 啟動錯誤，在保留繁中系統語系及 UTF-8 字碼頁的情況下，修補三個檔案。不需要切換日文語系、Locale Emulator 或更換成吉里吉里 Z。

**目前狀態：**已通過先前的啟動失敗點，建立有遊戲標題的視窗並產生初始設定。尚未驗證完整主選單顯示、實際遊玩、音效及存讀檔。請參閱 [測試紀錄與限制](TESTING.md)。

## 遊戲與外掛來源

- [Steam 遊戲頁面：App 4358140](https://store.steampowered.com/app/4358140/)
- [DLsite 原作：RJ01464205](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)：僅供識別原作，**未測試或支援 DLsite 版本**。
- [本次使用的 utf8hack 原始碼與發布頁](https://github.com/uyjulian/utf8hack)：上游 README 記載的原作者為 **miahmie**。
- [吉里吉里 2 儲存庫中的原始 utf8hack 程式碼](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)

## 確切支援版本與實測環境

| 項目 | 實測內容 |
|---|---|
| Steam build | **25049578** |
| 標題畫面使用的遊戲版本資料 | 本體 **0.26.6.22**；Patch 1 **1.26.6.12**；Patch 2 **2.26.7.23** |
| 吉里吉里 2 引擎檔案版本 | **2.32.2.426**，不是遊戲版本 |
| Windows | **Windows 11 Pro 25H2，26200.9457，x64** |
| 非 Unicode 程式系統語系／使用者文化設定 | **zh-TW／zh-TW** |
| 系統 ANSI／OEM 字碼頁 | **65001／65001（UTF-8）** |
| 外掛 | utf8hack **v1.2.0，intel32.clang** |

遊戲版本來自本機遊戲內供標題畫面使用的版本資料，並非由商店日期推測，也未宣稱已擷取標題畫面。只測試過上述 Steam 資料組合。工具會核對 [supported_versions.json](supported_versions.json) 中的 EXE 與三個資料包的 SHA-256 作為參考；不符時只顯示警告並繼續，不需要 `--force`。修補位置仍須存在預期的字型位元組。Windows 10、其他語系及其他商店版本均未驗證。Windows 雖為 64 位元，遊戲仍需使用 **32 位元外掛**。

## 不熟電腦也能照做的安裝步驟

1. 關閉遊戲，並確保已合法購買、安裝 Steam 遊戲。若尚未安裝，從 [Python 官方網站](https://www.python.org/downloads/windows/) 安裝 Windows 版 Python 3.10 以上，包含 launcher／加入 PATH 選項。本工具以 Python 3.13.12 測試。
2. 在本專案按 **Code → Download ZIP**，下載後按右鍵 → **全部解壓縮**。不要直接在 ZIP 裡執行。
3. 開啟 [utf8hack v1.2.0 發布頁](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0)，下載 **`utf8hack.intel32.clang.7z`**。使用 [7-Zip](https://www.7-zip.org/) 或其他相容工具解壓縮，保留裡面的 **`utf8hack.dll`**。本專案不內附外掛。
4. 在 Steam 對遊戲按右鍵 → **管理 → 瀏覽本機檔案**，記下這個含有 `yuusyatsuma.eXe`、`data.xp3` 的資料夾。
5. 雙擊本專案的 **`Apply.cmd`**。第一個選擇視窗選**遊戲資料夾**，下一個選擇視窗選剛解壓縮的 **`utf8hack.dll`**，然後確認。工具介面是英文；核對大型資料包雜湊需要一些時間。
6. 工具會先在遊戲資料夾建立 **`.unicode-fix-backup`** 備份原檔，再套用修補。版本或外掛雜湊不符時只警告並繼續；若既有外掛不同，會先備份再替換。請保留備份。
7. Steam → 遊戲**內容 → 一般 → 啟動選項**，清除先前用來呼叫獨立測試副本的命令，本方案留白即可。照常按**開始遊戲**。

本修補不要求更改 Windows 語系或重新開機。工具不自動下載或上傳任何資料，只修改你選取的遊戲資料夾。既有 `savedata` 不變；獨立測試副本的進度**不會自動搬過來**。

## 三個檔案的作用

| 檔案 | 具體改動 |
|---|---|
| `yuusyatsuma.eXe` | 在位移 `0x2C82EA` 把 CP932 字型名稱 `ＭＳ Ｐゴシック` 改成英文 ASCII `MS PGothic`，補零維持相同長度，其餘 EXE 位元組不變。 |
| `yuusyatsuma.cf` | 設定 `readencoding=Shift_JIS`，保留其他設定、文字編碼、BOM 與換行格式；`\xNN` 是引擎設定檔語法。 |
| `utf8hack.tpm` | 把選取的上游 DLL 複製為 `.tpm`，讓引擎在腳本前載入。外掛在記憶體中接管文字讀取，以 CP932 解讀腳本。 |

外掛先解決腳本讀取，但實測仍在原生 Layer 初始化遇到另一處字碼轉換錯誤；字型名稱修補處理了第二個失敗點。遊戲資料包、翻譯、存檔格式及系統字碼頁都不改動。吉里吉里 Z 測試遇到另一個選單相容性錯誤，因此不包含在本方案。

## 還原與常見問題

- 關閉遊戲，執行 **`Restore.cmd`**，選同一遊戲資料夾。工具還原備份檔案；只有原先不存在外掛時，才移除本次新增的外掛。存檔與備份保留。
- 若檔案在修補後被其他工具或 Steam 更新修改，還原會停止，避免覆蓋新檔案。請先保留備份並確認情況。
- 還原或失敗後若要重新套用，先把既有 `.unicode-fix-backup` 保存在遊戲資料夾以外的安全位置；工具不覆蓋舊備份。
- 版本／外掛 SHA-256 不符：只警告、繼續套用，但相容性未驗證。命令列會輸出警告，GUI 完成後也會顯示警告摘要。
- 修補位置的字型位元組必須符合原始或已修補標記；無法辨識仍會停止。備份完整性與還原衝突檢查仍嚴格執行，這些是檔案保護，不是版本白名單。
- 權限或檔案鎖定：先關閉遊戲並確認資料夾可寫入。安裝失敗時，工具會嘗試回復已完成的寫入。
- Steam 更新或驗證完整性可能還原 EXE／設定，但保留新增外掛。更新後不要直接套用舊補丁。
- 外掛屬於實驗性執行期修補；若遭安全軟體阻擋，不要關閉防護，應確認警示與上游來源。

## 指令列與測試

```text
python patch.py check --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
python patch.py apply --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes" --plugin "D:\Downloads\utf8hack.dll"
python patch.py restore --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
python -m unittest -v test_patch.py
```

以上是範例路徑，請改成自己的位置。`check` 只檢查、不修改。[TESTING.md](TESTING.md) 說明測試範圍及可選的本機整合測試。

## 授權、隱私與移除請求

本專案自製修補工具、啟動腳本、測試及文件採 **[MIT License](LICENSE)**。MIT 不適用於遊戲、引擎、utf8hack 或修改後的遊戲 EXE，也不授予重新散布它們的權利。第三方授權詳見 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

所有檔名均為 ASCII，沒有個人安裝路徑、帳號憑證、存檔、遊戲素材或原始使用者紀錄。備份只留在使用者電腦，其 manifest 不含絕對路徑。本專案與開發商、發行商及上游作者無官方關係。

如有著作權、授權、署名或其他疑慮，**請透過 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) 聯繫維護者提出移除請求**，說明相關檔案／連結與理由，維護者將檢視並視情況刪除相關內容。請勿上傳遊戲檔案或私人資料。Repo 為私人時，Issues 僅供有存取權限者使用。
