# Changelog

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
