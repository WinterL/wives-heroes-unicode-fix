# To the Wives Who Were Heroes — Unicode startup fix

[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

An **experimental, unofficial** three-file compatibility fix for the Windows Steam release of **To the Wives Who Were Heroes / かつて勇者だった妻達へ**. It addresses KiriKiri 2's ANSI-to-Unicode startup error while keeping the existing Traditional Chinese system locale and UTF-8 code page. No Japanese locale, Locale Emulator, or engine replacement is required.

**Status:** the tested combination passed the original startup failures and created a named game window and initial settings. Full menu rendering, gameplay, audio and save/load have **not** been verified. See [test evidence and limitations](TESTING.md).

## Game and upstream links

- [Steam game — App 4358140](https://store.steampowered.com/app/4358140/)
- [DLsite original game — RJ01464205](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html) — reference only; the DLsite build is **not tested or supported**.
- [utf8hack source/releases used in this fix](https://github.com/uyjulian/utf8hack) — original author credited by the README: **miahmie**.
- [Original utf8hack source in KiriKiri 2](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)

## Exactly which version?

| Item | Tested value |
|---|---|
| Steam build | **25049578** |
| Game version metadata used by the title screen | Base **0.26.6.22**; Patch 1 **1.26.6.12**; Patch 2 **2.26.7.23** |
| KiriKiri 2 engine file version | **2.32.2.426** — not the game version |
| Windows | **Windows 11 Pro 25H2, 26200.9457, x64** |
| System locale / user culture | **zh-TW / zh-TW** |
| System ANSI / OEM code pages | **65001 / 65001 (UTF-8)** |
| Plugin | utf8hack **v1.2.0**, **intel32.clang** |

The game versions were read from local version metadata used by the title-screen script; they are not a screenshot-based claim. Only this exact Steam dataset was tested. The patcher checks the EXE **and all three game archive hashes** in [supported_versions.json](supported_versions.json) and refuses other builds. Windows 10, other locales and other store versions are unverified. A 64-bit Windows system still needs the **32-bit** plugin because the game is 32-bit.

## Installation for beginners

1. Close the game. Own and install the game through Steam. Get [Python 3.10 or newer for Windows](https://www.python.org/downloads/windows/) if needed; include its launcher / PATH option during installation. The patcher was tested with Python 3.13.12.
2. Download this repository with **Code → Download ZIP**, then **Extract All**. Do not run it inside the ZIP.
3. Open [upstream release v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0). Download **`utf8hack.intel32.clang.7z`** and extract it with [7-Zip](https://www.7-zip.org/) or another compatible extractor. Keep the extracted **`utf8hack.dll`**. The plugin is intentionally not included here.
4. In Steam, right-click the game → **Manage → Browse local files**. Note that folder; it contains `yuusyatsuma.eXe` and `data.xp3`.
5. Double-click **`Apply.cmd`** in this repository. In the first picker, select the **game folder**. In the next picker, select the **extracted `utf8hack.dll`**. Confirm the installation. The dialogs are in English. Hash verification may take a little time because it reads all game archives.
6. The tool automatically backs up the affected original files into **`.unicode-fix-backup`** inside the game folder, then applies the fix. If the version/plugin differs, it stops rather than guessing. Keep the backup.
7. In Steam → game **Properties → General → Launch Options**, remove any old command that redirects to a separate test copy. Leave the field empty for this patch. Click **Play** normally.

No system language change or reboot is required by this patch. The repository contains no game files and does not download/upload anything automatically. Only the selected game folder is modified. Existing `savedata` is untouched; saves from a separate test copy are **not** migrated.

## What changes?

| File | Change |
|---|---|
| `yuusyatsuma.eXe` | At file offset `0x2C82EA`, replace the CP932 font-name literal `ＭＳ Ｐゴシック` with ASCII `MS PGothic`, padded to the same byte length. All other EXE bytes remain unchanged. |
| `yuusyatsuma.cf` | Set `readencoding=Shift_JIS`, retaining other settings, encoding, BOM and line endings. The `\xNN` form is KiriKiri's configuration syntax. |
| `utf8hack.tpm` | Copy the verified upstream DLL under the `.tpm` extension so the engine loads it before scripts. It hooks text reading in memory and decodes scripts with CP932. |

The plugin fixes script decoding, but alone still failed during native Layer initialization in the test. The font literal edit fixes that second conversion. The game archives, translations, save format and Windows code page are not changed. KiriKiri Z was evaluated and hit a separate menu compatibility error, so it is not part of this patch.

## Restore and troubleshooting

- Close the game and run **`Restore.cmd`**; select the same game folder. It restores the backed-up files and removes the added plugin only if no plugin existed before. It preserves savedata and retains the backup.
- If files changed after patching (for example a Steam update), automatic restore refuses to overwrite them. Keep the backup and inspect the situation first.
- If a backup already exists after a restore/failed attempt, keep it somewhere safe outside the game folder before applying again. The installer never overwrites an existing backup.
- Unsupported version/plugin: stop and check the exact build/asset above. There is no force mode.
- Permission/locked-file error: close the game and check folder write access. The tool attempts to roll back completed writes if installation fails.
- Steam updates or **Verify integrity** may replace patched files; an added plugin may remain. Do not apply an old patch blindly to a new build.
- This is an experimental runtime plugin. Do not disable security protection if it is blocked; investigate the report and upstream provenance.

## Command line and tests

```text
python patch.py check --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
python patch.py apply --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes" --plugin "D:\Downloads\utf8hack.dll"
python patch.py restore --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
python -m unittest -v test_patch.py
```

These are example paths; select your actual paths. `check` does not modify files. [TESTING.md](TESTING.md) explains the test scope and the optional private integration test.

## License, privacy and removal requests

The original patcher, scripts, tests and documentation in this repository use the **[MIT License](LICENSE)**. The game, engines and utf8hack retain their own rights and licenses; MIT does **not** cover them or grant permission to redistribute a patched game EXE. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

All repository filenames are ASCII. No personal installation paths, account tokens, save files, game assets or raw user logs are included. Backups stay on the user's computer and contain no embedded absolute path in their manifest. This is an unofficial project, with no publisher or upstream endorsement.

If there are copyright, licensing, attribution or other concerns, **please contact the maintainer through [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) to request removal**. Identify the relevant file/link and concern; the maintainer will review it and remove the material when appropriate. Do not attach game files or private data. Private-repository Issues are accessible only to people granted access.
