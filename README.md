# To the Wives Who Were Heroes — Startup, fullscreen and voice fixes

English · [繁體中文](docs/README.zh-TW.md) · [简体中文](docs/README.zh-CN.md) · [日本語](docs/README.ja.md) · [한국어](docs/README.ko.md)

- **Startup failure:** fixes the ANSI-to-Unicode error while keeping your current system locale and UTF-8 setting, without switching to a Japanese system locale.
- **Fullscreen black screen:** corrects resolution detection under high DPI scaling, fits the desktop while preserving aspect ratio, and keeps the game usable after switching away and back.
- **Missing voices and backlog replay:** restores Japanese voice playback in English, Traditional Chinese, Simplified Chinese and Korean scenarios by cross-referencing the Japanese scripts.

This is an unofficial patch. The [Steam store](https://store.steampowered.com/app/4358140/) requires a Japanese system locale. [Official troubleshooting](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## Install

### Startup and fullscreen

1. Download [Apply.cmd](Apply.cmd) using the file page's download button. Download `utf8hack.intel32.clang.7z` from [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) and extract `utf8hack.dll`.
2. In Steam, right-click the game → **Manage → Browse local files**. Put `Apply.cmd` and `utf8hack.dll` in that folder.
3. Close the game, double-click **Apply.cmd**, then launch through Steam.

### Voices and backlog replay

1. Close the game and download [patch_3.xp3](patch_3.xp3) using the file page's download button. In Steam, right-click the game → **Manage → Browse local files** and put it beside `yuusyatsuma.eXe`.
2. Keep the original `patch_1.xp3` and `patch_2.xp3`. If `patch_3.xp3` already exists, back it up outside the game folder and identify it before replacing it; another patch may conflict with this one.
3. Restart through Steam and re-enter the affected scene. Existing backlog entries do not gain missing replay links retroactively.

The voice patch can be installed independently; `Apply.cmd` and `utf8hack.dll` are not required for voice-only installation.

## How it works

| File | Change |
|---|---|
| `utf8hack.tpm` | A copy of `utf8hack.dll` that loads as an engine plugin. |
| `yuusyatsuma.cf` | Uses `Shift_JIS` (CP932) for scripts; fullscreen automatically fits the current desktop resolution while preserving aspect ratio, with borders on non-16:9 screens. |
| `yuusyatsuma.eXe` | Changes `ＭＳ Ｐゴシック` to ASCII `MS PGothic` and adds a DPI-aware declaration, preventing encoding errors and incorrect fullscreen resolution detection. |
| `patch_3.xp3` | Overrides 54 scenario scripts to restore voice commands, voice IDs and backlog replay, and fill a missing subtitle/pause in both Chinese translations. |

The Japanese scenarios are the reference for corresponding dialogue and voice commands. The patch changes 985 lines across 54 scripts, not 985 unique voice lines. It uses the existing Japanese audio and includes no new recordings. See the [voice patch report](docs/VOICE_PATCH_REPORT.txt) for the specific changes.

## Tested

**Update compatibility (2026-10-29):** Steam build **26287432** is also compatible with the existing downloads; no reinstall is needed. All 54 voice-overlay source scripts are unchanged. This is a file-level verification, not a new gameplay test. [Details](docs/TESTING.md#steam-build-26287432-compatibility).

Steam build **25049578**: base **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23**. Tested on Windows **11 Pro 25H2 (26200.9457), x64**, system locale **zh-TW**, code page **UTF-8 (65001)**. Display: **3840×2160, 225% scaling**.

Normal Steam launch, windowed main menu/music, fullscreen display, clicks and Alt+Tab verified. Full gameplay, save/load and other environments are untested. EXE/plugin hash mismatches only warn. [Test details](docs/TESTING.md)

Voice patch: all scenario language pairs were compared, and voice/replay command dispatch was checked with the original engine parser. This is script-level verification, not a complete playthrough or line-by-line listening test. [Scope and changes](docs/VOICE_PATCH_REPORT.txt)

## Restore and credits

For startup/fullscreen changes, put [Restore.cmd](Restore.cmd) in the game folder and run it with the game closed. A successful restore removes the backup; you can apply those fixes again directly. `Restore.cmd` does not remove the voice patch.

For the voice patch, close the game and remove only the `patch_3.xp3` supplied here, or rename it to `patch_3.xp3.disabled`. Restore any earlier `patch_3.xp3` that you backed up.

Plugin: [utf8hack](https://github.com/uyjulian/utf8hack), originally by **miahmie** ([original source](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)). This project's code and documentation use [MIT](LICENSE); see [notices](docs/THIRD_PARTY_NOTICES.md) for third-party licensing. For concerns or removal requests, use [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues).

The game script content included in `patch_3.xp3` remains the property of its respective rights holders and is not covered by the MIT license.
