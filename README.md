# To the Wives Who Were Heroes — Startup fix

English · [繁體中文](docs/README.zh-TW.md) · [简体中文](docs/README.zh-CN.md) · [日本語](docs/README.ja.md) · [한국어](docs/README.ko.md)

An unofficial fix for the game's ANSI-to-Unicode startup error on Windows with UTF-8 enabled. [Steam](https://store.steampowered.com/app/4358140/) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## Install

1. Download [Apply.cmd](Apply.cmd) using the file page's download button. Download `utf8hack.intel32.clang.7z` from [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) and extract `utf8hack.dll`.
2. In Steam, right-click the game → **Manage → Browse local files**. Put `Apply.cmd` and `utf8hack.dll` in that folder.
3. Close the game, double-click **Apply.cmd**, then launch through Steam.

## How it works

| File | Change |
|---|---|
| `utf8hack.tpm` | A copy of `utf8hack.dll` that loads as an engine plugin. |
| `yuusyatsuma.cf` | Sets `Shift_JIS` so the plugin reads scripts using CP932. |
| `yuusyatsuma.eXe` | Changes the font name from `ＭＳ Ｐゴシック` to `MS PGothic`, avoiding another encoding error. |

## Tested

Steam build **25049578**: base **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23**. Tested on Windows **11 Pro 25H2 (26200.9457), x64**, system locale **zh-TW**, code page **UTF-8 (65001)**.

Windowed main menu and music work; **fullscreen still goes black**. Full gameplay and save/load are untested. EXE/plugin hash mismatches only warn. [Test details](docs/TESTING.md)

## Restore and credits

Put [Restore.cmd](Restore.cmd) in the game folder and run it with the game closed. Keep `.unicode-fix-backup`; before reapplying after a restore, move that backup outside the game folder.

Plugin: [utf8hack](https://github.com/uyjulian/utf8hack), originally by **miahmie** ([original source](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)). This project's code and documentation use [MIT](LICENSE); see [notices](docs/THIRD_PARTY_NOTICES.md) for third-party licensing. For concerns or removal requests, use [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues).
