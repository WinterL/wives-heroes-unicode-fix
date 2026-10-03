# Test evidence

## Reference build and environment

| Item | Tested value |
|---|---|
| Steam app / build | 4358140 / 25049578 |
| Base / Patch 1 / Patch 2 | 0.26.6.22 / 1.26.6.12 / 2.26.7.23 |
| Engine file version | KiriKiri 2, 2.32.2.426 |
| Windows | Windows 11 Pro 25H2, 26200.9457, x64 |
| System locale / user culture | zh-TW / zh-TW |
| ANSI / OEM code pages | 65001 / 65001 (UTF-8) |
| Plugin | utf8hack v1.2.0, intel32.clang |
| Display used for manual fullscreen tests | 3840×2160, 225% scaling |

Game versions came from the title-screen version metadata: `data.xp3/image_0/verDat0.ks`, `patch_1.xp3/verDat1.ks`, and `patch_2.xp3/verDat2.ks`. The engine's file version and PE product version are not game versions. Display language was not separately recorded. No Japanese locale or locale emulator was used.

Reference hashes are in [supported_versions.json](../scripts/supported_versions.json). EXE and plugin hash mismatches only warn; archive hashes are reference data and are not checked during installation. Patch-location, backup-integrity and restore-conflict checks remain strict.

## Official guidance and this workaround

The [Steam store](https://store.steampowered.com/app/4358140/) requires a Japanese-language environment and half-width alphanumeric paths, and recommends windowed play. The [official troubleshooting notice](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) suggests restarting the game or PC in windowed mode for the shown error, and checking the Japanese system region for misaligned character art. This workaround keeps the tested zh-TW locale and UTF-8 code page unchanged; the character-art issue has not been verified.

## Game observations

Initial comparisons ran on 2026-09-26; later manual fullscreen tests ran through 2026-10-03.

| Configuration | Result |
|---|---|
| Original engine | ANSI-to-Unicode error while loading `startup.tjs` |
| Plugin + `Shift_JIS` | Script loading progressed; another conversion error during native Layer creation |
| Above + ASCII font-name edit | Startup error resolved; user confirmed windowed main menu and music |
| Above + System-DPI-aware manifest, `fsres=nochange`, `fszoom=inner` | User confirmed normal Steam launch, fullscreen image and clicks, Alt+Tab, and return to windowed mode |

The original fullscreen failure requested 1707×960, a DPI-virtualized size unsupported by the display, and logged `DISP_CHANGE_BADMODE`. The embedded manifest makes normal Steam launches System DPI aware. Keeping the desktop resolution avoids the observed resolution-switching/focus problem; engine scaling fills the tested 16:9 screen without changing its resolution.

The configuration contains `nochange` and `inner`, not a fixed 4K size. [Engine options](https://krkrz.github.io/krkr2doc/kr2doc/contents/CommandLine.html) and the [scaling implementation](https://github.com/krkrz/krkr2/blob/master/kirikiri2/trunk/kirikiri2/src/core/visual/win32/WindowImpl.cpp#L884) select a scale for the desktop dimensions reported by the engine, preserving the game's aspect ratio; other aspect ratios can leave black bars. Other resolutions have not been hardware-tested. [System DPI awareness](https://learn.microsoft.com/en-us/windows/win32/hidpi/high-dpi-desktop-application-development-on-windows#system-dpi-awareness) uses one system DPI, so mixed-DPI monitor moves and changes made while the game is running are outside the verified scope.

Full gameplay, save/load, Steam features, Windows 10, other locales and other store builds are unverified. The automated patcher tests below do not run the game.

## Patcher tests

From the repository root, using Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -File .\tests\patch.Tests.ps1
```

On 2026-10-03, **all 8 workflow tests passed: 7 synthetic and 1 optional real-file test**, in the final native Windows PowerShell 5.1 run. The suite reported **17.48 seconds**; no comparable full-run timing was recorded for the previous suite.

| Workflow | Regression covered |
|---|---|
| Configuration | UTF-8/UTF-16, BOM, CRLF/LF and unrelated text survive; generic display settings replace existing values. |
| Installation preflight | Missing DLL, wrong folder, unknown font bytes, invalid PE and existing backup stop before writes. |
| Restore preflight | Later game edits, unexpected backup files, invalid metadata and corrupt backups are preserved. |
| Failure recovery | Partial installation rolls back; interrupted backup cleanup reconstructs removed files and can be retried. |
| Packaged CMD lifecycle | Apply → Restore → Apply works, repeated Apply is harmless, old plugins and saves survive, and hash warnings do not block. |
| Legacy upgrade | User edits are protected; failed metadata updates roll back; successful upgrade reuses the installed plugin and retains the original backup. |
| Manifest integrity | UAC/Common Controls, resource language, RCDATA, headers and trailing data survive; conflicting DPI settings are rejected. |
| Real files (optional) | Actual CMD fresh/reapply/legacy-upgrade paths produce the manually tested EXE hash and restore original bytes. |

The synthetic PE contains no game assets. One unchanged baseline is shared, while the two manifest-specific fixtures are built only for the resource test. Byte assertions use a separate case-sensitive native comparison; resource integrity checks do not reuse the production PE parser's bounds. Actual CMD tests use a different working directory and game paths containing spaces, punctuation and non-ASCII characters.

For the optional test, set `PATCH_TEST_GAME_DIR` to an unmodified local game copy and `PATCH_TEST_PLUGIN` to the downloaded DLL. Only EXE, config and plugin copies are used in temporary folders; the supplied installation and game archives are not modified or executed. Successful Restore removes the verified backup, allowing direct reapplication.

The standalone launchers contain their PowerShell code and reference hashes. They use the built-in Windows PowerShell with `-Command`; no PowerShell execution-policy settings are changed. Existing format-1 backups from the previous Python patcher remain compatible.

Packaging audit (2026-10-03): all 12 PowerShell functions in `Apply.cmd` and all 6 in `Restore.cmd` are reachable from their respective entry points. Only Apply includes the native manifest helper; Restore contains no font, encoding or manifest-editing logic. Backup integrity, restoration conflicts and failed-install rollback checks remain intact.
