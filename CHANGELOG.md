# Changelog

## 0.3.0 — 2026-10-03 (experimental)

- Replace the Python runtime with Windows PowerShell 5.1 and built-in .NET / Windows Forms.
- Keep double-click Apply.cmd / Restore.cmd, advisory compatibility hashes, original-file backup, rollback and restore safeguards.
- Support existing format-1 backups created by the earlier Python tool.
- Add a native, dependency-free test suite, including byte-for-byte real-EXE patch/restore verification.
- Update all five READMEs to remove the Python installation requirement.
- Record the fullscreen hang investigation separately; no fullscreen fix is claimed without reproduction.

## 0.2.0 — 2026-09-27 (experimental)

- Change tested-version SHA-256 mismatches for EXEs, game archives, and plugins to warnings; continue without a force flag.
- Detect original/patched font markers independently of the whole-file hash, keeping repeat installation idempotent for variant builds.
- Back up and replace an existing different plugin instead of rejecting it.
- Preserve patch-offset, backup-integrity, and restore-conflict protections.
- Update all five READMEs and regression tests for the advisory compatibility checks.

## 0.1.0 — 2026-09-27 (experimental)

- Support only Steam App 4358140 build 25049578 and the documented EXE/archive hashes.
- Add a local, version-locked font literal patch and `Shift_JIS` configuration update.
- Require the separately acquired, hash-verified utf8hack v1.2.0 intel32 clang plugin.
- Add original-file backups, installation rollback, conflict-aware restore, and an English folder/file picker.
- Document the exact Windows/locale environment and limited startup verification.
- Add complete English, Traditional Chinese, Simplified Chinese, Japanese, and Korean READMEs with ASCII filenames.
- License original project code/documentation under MIT; exclude game/third-party binaries.
