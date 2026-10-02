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

Game versions came from the title-screen version metadata: `data.xp3/image_0/verDat0.ks`, `patch_1.xp3/verDat1.ks`, and `patch_2.xp3/verDat2.ks`. The engine's file version and PE product version are not game versions. Display language was not separately recorded. No Japanese locale or locale emulator was used.

Reference hashes are in [supported_versions.json](../scripts/supported_versions.json). EXE and plugin hash mismatches only warn; archive hashes are reference data and are not checked during installation. Patch-location, backup-integrity and restore-conflict checks remain strict.

## Official guidance and this workaround

The [Steam store](https://store.steampowered.com/app/4358140/) requires a Japanese system locale and half-width alphanumeric paths, and recommends windowed play. The [official troubleshooting notice](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) suggests restarting the game or PC in windowed mode for the shown error, and checking the Japanese system region for misaligned character art. This workaround cleared the startup error with the tested zh-TW locale and UTF-8 code page unchanged; character-art compatibility and fullscreen are not claimed as fixed.

## Game observations

Initial comparisons ran on 2026-09-26; later manual fullscreen tests ran through 2026-10-03.

| Configuration | Result |
|---|---|
| Original engine | ANSI-to-Unicode error while loading `startup.tjs` |
| Plugin + `Shift_JIS` | Script loading progressed; another conversion error during native Layer creation |
| Above + ASCII font-name edit | Startup error resolved; user confirmed windowed main menu and music |

**Fullscreen remains unresolved:** selecting the game's fullscreen menu turns the display black while music continues. Changing display-mode options did not fix it. A diagnostic run recorded `DISP_CHANGE_BADMODE` while requesting 1707×960; a DPI compatibility hypothesis is still unconfirmed and is not part of this patch.

Full gameplay, save/load, Steam features, Windows 10, other locales and other store builds are unverified. The automated patcher tests below do not run the game.

## Patcher tests

From the repository root, using Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -File .\tests\patch.Tests.ps1
```

On 2026-10-03, **all 13 tests passed: 12 synthetic and 1 optional real-file test**, using native Windows PowerShell 5.1. The suite covers file-byte boundaries, configuration encoding/newlines, advisory hashes, backup and restore, modified-file conflicts, and rollback. It also runs the standalone CMD files from a different working directory, using game paths containing spaces, punctuation and non-ASCII characters, and checks missing-file errors. No external modules or test framework are required.

To include the optional test, set `PATCH_TEST_GAME_DIR` to an unmodified local game copy and `PATCH_TEST_PLUGIN` to the downloaded DLL before running the same command. It copies the EXE, config and plugin to a temporary fixture, then runs the actual `Apply.cmd` and `Restore.cmd`. It verifies the patched EXE against the startup-tested hash and checks byte-for-byte restoration. It does not write to the supplied installation or read game archives.

Actual CMD tests run Apply → Restore → Apply → Restore, including existing-plugin and real-file fixtures. Restore verifies all original files before removing its backup, allowing the next Apply without manual cleanup. Unknown backup files, directories, links and invalid manifests stop restoration before writes. A locked backup-file test confirms that interrupted cleanup recreates removed backup files and can be retried; if that repair also fails, the error explicitly reports an incomplete backup.

The standalone launchers contain their PowerShell code and reference hashes. They use the built-in Windows PowerShell with `-Command`; no PowerShell execution-policy settings are changed. Existing format-1 backups from the previous Python patcher remain compatible.

Packaging audit (2026-10-03): all 9 functions in `Apply.cmd` and all 5 in `Restore.cmd` are reachable from their respective entry points. All script constants are used; neither launcher contains an action selector or import-only option.
The generated payloads exactly match the common module plus the corresponding apply/restore module. Apply excludes the restore function; Restore excludes all font, encoding and installation logic.
Excluding the CMD header and MIT notice, the payloads are 9,141 and 6,384 bytes respectively. Backup integrity, restoration conflicts and failed-install rollback checks remain intact.
