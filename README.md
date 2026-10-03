# To the Wives Who Were Heroes — Startup and fullscreen fix

English · [繁體中文](docs/README.zh-TW.md) · [简体中文](docs/README.zh-CN.md) · [日本語](docs/README.ja.md) · [한국어](docs/README.ko.md)

- **Startup failure:** fixes the ANSI-to-Unicode error while keeping your current system locale and UTF-8 setting, without switching to a Japanese system locale.
- **Fullscreen black screen:** corrects resolution detection under high DPI scaling, fits the desktop while preserving aspect ratio, and keeps the game usable after switching away and back.

This is an unofficial patch. The [Steam store](https://store.steampowered.com/app/4358140/) requires a Japanese system locale. [Official troubleshooting](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## Install

1. Download [Apply.cmd](Apply.cmd) using the file page's download button. Download `utf8hack.intel32.clang.7z` from [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) and extract `utf8hack.dll`.
2. In Steam, right-click the game → **Manage → Browse local files**. Put `Apply.cmd` and `utf8hack.dll` in that folder.
3. Close the game, double-click **Apply.cmd**, then launch through Steam.

## How it works

| File | Change |
|---|---|
| `utf8hack.tpm` | A copy of `utf8hack.dll` that loads as an engine plugin. |
| `yuusyatsuma.cf` | Uses `Shift_JIS` (CP932) for scripts; fullscreen automatically fits the current desktop resolution while preserving aspect ratio, with borders on non-16:9 screens. |
| `yuusyatsuma.eXe` | Changes `ＭＳ Ｐゴシック` to ASCII `MS PGothic` and adds a DPI-aware declaration, preventing encoding errors and incorrect fullscreen resolution detection. |

## Tested

Steam build **25049578**: base **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23**. Tested on Windows **11 Pro 25H2 (26200.9457), x64**, system locale **zh-TW**, code page **UTF-8 (65001)**. Display: **3840×2160, 225% scaling**.

Normal Steam launch, windowed main menu/music, fullscreen display, clicks and Alt+Tab verified. Full gameplay, save/load and other environments are untested. EXE/plugin hash mismatches only warn. [Test details](docs/TESTING.md)

## Restore and credits

Put [Restore.cmd](Restore.cmd) in the game folder and run it with the game closed. A successful restore removes the backup; you can apply the patch again directly.

Plugin: [utf8hack](https://github.com/uyjulian/utf8hack), originally by **miahmie** ([original source](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)). This project's code and documentation use [MIT](LICENSE); see [notices](docs/THIRD_PARTY_NOTICES.md) for third-party licensing. For concerns or removal requests, use [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues).
