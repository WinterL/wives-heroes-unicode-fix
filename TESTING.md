# Test evidence and limits

## Identified build

The installed Steam manifest reports **App 4358140 / build 25049578**. The game's own version scripts, used by its title-screen renderer, report:

| Source within the installed archive | Version |
|---|---|
| `data.xp3` / `image_0/verDat0.ks` | `0.26.6.22` |
| `patch_1.xp3` / `verDat1.ks` | `1.26.6.12` |
| `patch_2.xp3` / `verDat2.ks` | `2.26.7.23` |

These values were read locally from the game's metadata, not inferred from a store release date. The title-screen script formats these values; no title-screen screenshot was captured. The process window title observed during the successful startup probe was `かつて勇者だった妻達へ かつて将軍だった魔王へ　結合版`.

The EXE's **file version `2.32.2.426`** identifies the KiriKiri 2 engine. Its PE product version `1.0.0.0` is not used as the game version. Exact input/output and archive hashes are recorded in [supported_versions.json](supported_versions.json). The installer compares the EXE, plugin, and all three archive hashes with the tested reference. Differences are compatibility warnings, not installation blockers. It still requires recognizable font bytes at the patch offset. Backup-integrity and restore-conflict checks remain strict. It does not parse the Steam manifest at runtime.

## Environment

- Windows 11 Pro 25H2, build **26200.9457**, x64.
- Non-Unicode program system locale: **Chinese (Traditional, Taiwan), `zh-TW`**.
- User culture: `zh-TW`. Display language was not separately recorded.
- System ANSI/OEM code pages: **65001 (UTF-8)**; corresponds to the Windows UTF-8 worldwide language support configuration.
- No Locale Emulator; no change to system locale/code page.
- Startup comparison: 2026-09-26. Environment and installed build rechecked: 2026-09-27.
- The Windows registry's legacy `ProductName` string reported Windows 10 Pro; build 26200 / 25H2 identifies Windows 11. See [Microsoft's release table](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information).

## Startup comparison

| Variant | Observed result |
|---|---|
| Unmodified KiriKiri 2 | Reproduced ANSI-to-Unicode failure while loading `startup.tjs` |
| `utf8hack.tpm` + `Shift_JIS` | Scripts loaded; failed again during native Layer / KAGLayer creation |
| Above + `-deffont=Arial` | Same failure |
| Above + the EXE font literal changed to ASCII `MS PGothic` | Repeated startup probes passed those failures; a named game window and initial configuration files were created |
| KiriKiri Z 1.4.0r2 alone | Missing `KAGParser` |
| Z + official Krkr2Compat + required plugins | Reached game scripts but failed in `Menus.tjs` / `サポメ.ks`: `Specify Window class object.` |

The final clean candidate contained the original engine with the font edit, utf8hack, and the configured `.cf`; it did **not** depend on Z's plugins or compatibility layer. The system locale and code pages were rechecked after testing.

## What is not verified

The desktop automation tool could not capture the game window. This establishes a startup workaround, not complete gameplay compatibility. Menu rendering, all artwork, audio, save/load, full playthroughs, Steam overlay/achievements/cloud saves, Windows 10, non-`zh-TW` locales, and DLsite builds are **not verified**. The documented Steam override for a separate local test copy was not end-to-end tested; the published patcher applies directly to a selected installation and does not require that override.

## Patcher checks

Run `python -m unittest -v test_patch.py` for synthetic, copyright-free tests: advisory version/plugin/archive mismatches, byte boundaries, preservation of config encoding/newlines, unknown patch-location refusal, backups, rollback, restore conflict detection, idempotence across unrecognized hashes, and restoration of preexisting plugins. These do not run the game. An optional local integration test accepts `PATCH_TEST_GAME_DIR` (an unmodified installation or retained unmodified test copy) and `PATCH_TEST_PLUGIN`; it uses a temporary copy of the small files, reads the real archive hashes, and never writes to the supplied game folder. Game assets must never be committed as fixtures.

On 2026-09-27, **all 16 tests passed**, including the optional real-file integration test, using Python 3.13.12. The resulting patched EXE matched the previously startup-tested candidate SHA-256 exactly; restoration reproduced the original EXE and configuration byte for byte. This verifies the patcher, not additional gameplay features.

No raw desktop screenshots, full logs, computer/user names, personal paths, save data, credentials, or game content are included as test artifacts.
