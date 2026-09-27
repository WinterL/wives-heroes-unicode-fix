"""Version-locked local patcher. Game files and third-party binaries are not bundled."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

ORIGINAL_SHA256 = "2c7a2231df58d82d9eba7b80038641ad716918f3159540c1f3d1a128d2e361f8"
PATCHED_SHA256 = "c5bf3867b8617280f2c91c1b7f4ac183202923a200fcff0e414d36c6adb07847"
PLUGIN_SHA256 = "e9bd9a1f354b906b16201a24732d8ffd186cadc30e803dcf33281e297671ea69"
OFFSET = 0x2C82EA
OLD = bytes.fromhex("826c827220826f835383568362834e00")
NEW = b"MS PGothic\0".ljust(len(OLD), b"\0")
EXE, CONFIG, PLUGIN = "yuusyatsuma.eXe", "yuusyatsuma.cf", "utf8hack.tpm"
FILES = (EXE, CONFIG, PLUGIN)
BACKUP = ".unicode-fix-backup"
METADATA = json.loads(Path(__file__).with_name("supported_versions.json").read_text(encoding="utf-8"))
ARCHIVES = METADATA["archives_sha256"]


class PatchError(Exception):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def verify_archives(game: Path) -> None:
    for name, expected in ARCHIVES.items():
        checksum = hashlib.sha256()
        with (game / name).open("rb") as stream:
            for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
                checksum.update(block)
        if checksum.hexdigest() != expected:
            raise PatchError("Unsupported game archive: " + name + ". Only the documented Steam build is supported.")


def patch_executable(data: bytes) -> bytes:
    if digest(data) != ORIGINAL_SHA256:
        raise PatchError("Unsupported EXE. This patch only supports the documented SHA-256. No force mode exists.")
    if data[OFFSET:OFFSET + len(OLD)] != OLD:
        raise PatchError("Font bytes do not match the expected version.")
    result = data[:OFFSET] + NEW + data[OFFSET + len(OLD):]
    if digest(result) != PATCHED_SHA256:
        raise PatchError("Patched EXE verification failed.")
    return result


def patch_config(data: bytes) -> bytes:
    # Preserve encoding, BOM, existing settings, and line endings.
    bom, encoding = b"", "utf-8"
    for prefix, name in ((b"\xff\xfe", "utf-16-le"), (b"\xfe\xff", "utf-16-be"), (b"\xef\xbb\xbf", "utf-8")):
        if data.startswith(prefix):
            bom, encoding = prefix, name
            break
    try:
        text = data[len(bom):].decode(encoding)
    except UnicodeError as exc:
        raise PatchError("Unsupported configuration encoding; no files changed.") from exc
    value = 'readencoding="' + "".join("\\x%X" % ord(c) for c in "Shift_JIS") + '"'
    newline = "\r\n" if "\r\n" in text else "\n"
    lines, found = [], False
    for line in text.splitlines(keepends=True):
        if re.match(r"^[ \t]*readencoding[ \t]*=", line):
            ending = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
            line, found = value + ending, True
        lines.append(line)
    result = "".join(lines)
    if not found:
        if result and not result.endswith(("\n", "\r")):
            result += newline
        result += value + newline
    return bom + result.encode(encoding)


def atomic_write(path: Path, data: bytes) -> None:
    fd, temp = tempfile.mkstemp(prefix=".unicode-fix-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def game_path(folder: Path) -> Path:
    game = folder.expanduser().resolve(strict=True)
    if not game.is_dir():
        raise PatchError("Select a game folder.")
    for name in FILES:
        if (game / name).is_symlink():
            raise PatchError("Symbolic links are not supported for target files.")
    for name in (EXE, CONFIG, "data.xp3", "patch_1.xp3", "patch_2.xp3"):
        if not (game / name).is_file():
            raise PatchError("Missing required game file: " + name)
    return game


def check(folder: Path) -> str:
    game = game_path(folder)
    verify_archives(game)
    current = digest((game / EXE).read_bytes())
    if current == ORIGINAL_SHA256:
        patch_config((game / CONFIG).read_bytes())
        return "Supported original EXE. No files changed."
    if current == PATCHED_SHA256:
        if not (game / PLUGIN).is_file() or digest((game / PLUGIN).read_bytes()) != PLUGIN_SHA256:
            raise PatchError("EXE is patched, but the expected plugin is missing or different.")
        if patch_config((game / CONFIG).read_bytes()) != (game / CONFIG).read_bytes():
            raise PatchError("EXE is patched, but readencoding is not configured.")
        return "Expected patched EXE, plugin, and configuration are present. Gameplay is not verified by this check."
    raise PatchError("Unsupported EXE SHA-256: " + current)


def install(folder: Path, plugin_file: Path) -> str:
    game = game_path(folder)
    if digest((game / EXE).read_bytes()) == PATCHED_SHA256:
        return check(game)
    verify_archives(game)
    backup = game / BACKUP
    if backup.exists():
        raise PatchError("A backup already exists. Restore or inspect it before installing again; it will not be overwritten.")
    plugin = plugin_file.read_bytes()
    if digest(plugin) != PLUGIN_SHA256:
        raise PatchError("Wrong plugin. Obtain utf8hack.intel32.clang.7z from upstream v1.2.0 and extract utf8hack.dll.")
    before = {name: (game / name).read_bytes() if (game / name).exists() else None for name in FILES}
    if before[PLUGIN] is not None and digest(before[PLUGIN]) != PLUGIN_SHA256:
        raise PatchError("A different utf8hack.tpm already exists; refusing to overwrite it.")
    after = {EXE: patch_executable(before[EXE]), CONFIG: patch_config(before[CONFIG]), PLUGIN: plugin}
    backup.mkdir()
    for name, data in before.items():
        if data is not None:
            atomic_write(backup / name, data)
    manifest = {
        "format": 1,
        "before": {name: digest(data) if data is not None else None for name, data in before.items()},
        "after": {name: digest(data) for name, data in after.items()},
    }
    atomic_write(backup / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode("utf-8"))
    written = []
    try:
        for name, data in after.items():
            atomic_write(game / name, data)
            written.append(name)
        for name, data in after.items():
            if (game / name).read_bytes() != data:
                raise PatchError("Written file verification failed: " + name)
    except Exception as exc:
        failures = []
        for name in reversed(written):
            try:
                if before[name] is None:
                    (game / name).unlink()
                else:
                    atomic_write(game / name, before[name])
            except OSError:
                failures.append(name)
        note = " Manual recovery required for: " + ", ".join(failures) if failures else " Completed writes were rolled back."
        raise PatchError("Install failed. Backup retained in " + BACKUP + "." + note) from exc
    return "Patch installed. Original files are in " + BACKUP + ". Clear old Steam launcher overrides, then launch from Steam."


def restore(folder: Path) -> str:
    game = game_path(folder)
    backup = game / BACKUP
    if backup.is_symlink():
        raise PatchError("Backup must not be a symbolic link.")
    try:
        manifest = json.loads((backup / "manifest.json").read_text(encoding="utf-8"))
        if manifest["format"] != 1 or set(manifest["before"]) != set(FILES) or set(manifest["after"]) != set(FILES):
            raise ValueError()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise PatchError("A valid backup manifest is required.") from exc
    originals = {}
    for name in FILES:
        expected = manifest["before"][name]
        data = (backup / name).read_bytes() if expected is not None else None
        if data is not None and digest(data) != expected:
            raise PatchError("Backup checksum mismatch: " + name)
        current = digest((game / name).read_bytes()) if (game / name).exists() else None
        if current not in (manifest["before"][name], manifest["after"][name]):
            raise PatchError("File changed after installation; restore stopped to preserve it: " + name)
        originals[name] = data
    for name, data in originals.items():
        if data is None:
            (game / name).unlink(missing_ok=True)
        else:
            atomic_write(game / name, data)
    return "Original files restored. Backup retained; savedata was not modified."


def interactive(action: str) -> None:
    import tkinter as tk
    from tkinter import filedialog, messagebox
    root = tk.Tk()
    root.withdraw()
    folder = filedialog.askdirectory(title="Select the game folder (contains yuusyatsuma.eXe)")
    if not folder:
        root.destroy()
        return
    try:
        if action == "restore":
            if not messagebox.askyesno("Restore original files", "Close the game first. Restore the backed-up EXE, configuration and plugin?"):
                return
            result = restore(Path(folder))
        else:
            check(Path(folder))
            plugin = filedialog.askopenfilename(title="Select upstream v1.2.0 intel32 clang utf8hack.dll", filetypes=[("Plugin", "*.dll *.tpm")])
            if not plugin:
                return
            if not messagebox.askyesno("Apply compatibility patch", "Close the game first. Back up the original files and apply the three-file patch? Windows locale and saves stay unchanged."):
                return
            result = install(Path(folder), Path(plugin))
        messagebox.showinfo("Unicode startup fix", result)
    except (PatchError, OSError, ValueError) as exc:
        messagebox.showerror("Patch stopped", str(exc))
    finally:
        root.destroy()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("apply", "check", "restore"), nargs="?", default="apply")
    parser.add_argument("--game-dir", type=Path)
    parser.add_argument("--plugin", type=Path)
    args = parser.parse_args()
    if args.game_dir is None:
        if args.action == "check":
            parser.error("check requires --game-dir")
        interactive(args.action)
        return 0
    try:
        if args.action == "check":
            result = check(args.game_dir)
        elif args.action == "restore":
            result = restore(args.game_dir)
        else:
            if args.plugin is None:
                parser.error("apply requires --plugin")
            result = install(args.game_dir, args.plugin)
        print(result)
        return 0
    except (PatchError, OSError, ValueError) as exc:
        print("ERROR:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
