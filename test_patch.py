"""Synthetic tests contain no game assets; optional integration only uses local copies."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch as mock_patch

import patch


class PatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.game = Path(self.temp.name) / "Game folder"
        self.game.mkdir()
        self.original = b"MZ" + bytes(patch.OFFSET - 2) + patch.OLD + b"end marker"
        self.expected = self.original[:patch.OFFSET] + patch.NEW + self.original[patch.OFFSET + len(patch.OLD):]
        self.plugin = b"synthetic plugin test fixture"
        self.config = b'; settings\r\nfszoom="\\x6E\\x6F"\r\n'
        (self.game / patch.EXE).write_bytes(self.original)
        (self.game / patch.CONFIG).write_bytes(self.config)
        (self.game / "savedata").mkdir()
        (self.game / "savedata" / "save.bin").write_bytes(b"keep this save")
        archives = {}
        for name in ("data.xp3", "patch_1.xp3", "patch_2.xp3"):
            content = ("synthetic " + name).encode()
            (self.game / name).write_bytes(content)
            archives[name] = patch.digest(content)
        self.plugin_file = Path(self.temp.name) / "utf8hack.dll"
        self.plugin_file.write_bytes(self.plugin)
        mocks = mock_patch.multiple(patch, ORIGINAL_SHA256=patch.digest(self.original), PATCHED_SHA256=patch.digest(self.expected), PLUGIN_SHA256=patch.digest(self.plugin), ARCHIVES=archives)
        mocks.start()
        self.addCleanup(mocks.stop)

    def test_exact_byte_edit(self):
        output = patch.patch_executable(self.original)
        self.assertEqual(output, self.expected)
        self.assertEqual(len(output), len(self.original))
        self.assertEqual(output[:patch.OFFSET], self.original[:patch.OFFSET])
        self.assertEqual(output[patch.OFFSET + len(patch.OLD):], self.original[patch.OFFSET + len(patch.OLD):])

    def test_unknown_exe_refused_without_backup(self):
        (self.game / patch.EXE).write_bytes(self.original + b"different version")
        with self.assertRaises(patch.PatchError):
            patch.install(self.game, self.plugin_file)
        self.assertFalse((self.game / patch.BACKUP).exists())
        self.assertEqual((self.game / patch.CONFIG).read_bytes(), self.config)

    def test_wrong_plugin_refused_without_changes(self):
        self.plugin_file.write_bytes(b"different plugin")
        with self.assertRaises(patch.PatchError):
            patch.install(self.game, self.plugin_file)
        self.assertFalse((self.game / patch.BACKUP).exists())
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.original)

    def test_other_archive_build_refused(self):
        (self.game / "patch_2.xp3").write_bytes(b"newer build")
        with self.assertRaises(patch.PatchError):
            patch.install(self.game, self.plugin_file)
        self.assertFalse((self.game / patch.BACKUP).exists())

    def test_config_encodings_newlines_and_idempotence(self):
        for encoding, bom, newline in (("utf-8", b"", "\r\n"), ("utf-8", b"\xef\xbb\xbf", "\n"), ("utf-16-le", b"\xff\xfe", "\r\n"), ("utf-16-be", b"\xfe\xff", "\n")):
            with self.subTest(encoding=encoding, bom=bom):
                original = bom + ('; keep comment' + newline + 'other="\\x31"' + newline).encode(encoding)
                result = patch.patch_config(original)
                self.assertTrue(result.startswith(original))
                self.assertEqual(patch.patch_config(result), result)
                decoded = result[len(bom):].decode(encoding)
                self.assertEqual(decoded.count("readencoding="), 1)
                self.assertTrue(decoded.endswith(newline))
        changed = patch.patch_config(b'; readencoding=comment\nreadencoding="old"\nother="x"')
        self.assertTrue(changed.startswith(b'; readencoding=comment\n'))
        self.assertTrue(changed.endswith(b'other="x"'))

    def test_install_backup_idempotence_and_restore(self):
        patch.install(self.game, self.plugin_file)
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.expected)
        self.assertEqual((self.game / patch.PLUGIN).read_bytes(), self.plugin)
        backup = self.game / patch.BACKUP
        self.assertEqual((backup / patch.EXE).read_bytes(), self.original)
        self.assertEqual((backup / patch.CONFIG).read_bytes(), self.config)
        manifest = (backup / "manifest.json").read_text()
        self.assertNotIn(str(self.game), manifest)
        self.assertIn("Expected patched", patch.install(self.game, self.plugin_file))
        patch.restore(self.game)
        patch.restore(self.game)
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.original)
        self.assertEqual((self.game / patch.CONFIG).read_bytes(), self.config)
        self.assertFalse((self.game / patch.PLUGIN).exists())
        self.assertEqual((self.game / "savedata" / "save.bin").read_bytes(), b"keep this save")

    def test_preexisting_verified_plugin_is_restored(self):
        (self.game / patch.PLUGIN).write_bytes(self.plugin)
        patch.install(self.game, self.plugin_file)
        patch.restore(self.game)
        self.assertEqual((self.game / patch.PLUGIN).read_bytes(), self.plugin)

    def test_unrelated_plugin_is_not_overwritten(self):
        (self.game / patch.PLUGIN).write_bytes(b"unrelated plugin")
        with self.assertRaises(patch.PatchError):
            patch.install(self.game, self.plugin_file)
        self.assertEqual((self.game / patch.PLUGIN).read_bytes(), b"unrelated plugin")

    def test_existing_backup_is_preserved(self):
        (self.game / patch.BACKUP).mkdir()
        with self.assertRaises(patch.PatchError):
            patch.install(self.game, self.plugin_file)
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.original)

    def test_restore_refuses_new_user_changes(self):
        patch.install(self.game, self.plugin_file)
        changed = (self.game / patch.CONFIG).read_bytes() + b'; user change\r\n'
        (self.game / patch.CONFIG).write_bytes(changed)
        with self.assertRaises(patch.PatchError):
            patch.restore(self.game)
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.expected)
        self.assertEqual((self.game / patch.CONFIG).read_bytes(), changed)

    def test_corrupt_backup_refused(self):
        patch.install(self.game, self.plugin_file)
        (self.game / patch.BACKUP / patch.EXE).write_bytes(b"corrupt")
        with self.assertRaises(patch.PatchError):
            patch.restore(self.game)
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.expected)

    def test_partial_install_failure_rolls_back(self):
        writer = patch.atomic_write

        def fail_configuration(path, data):
            if path == self.game / patch.CONFIG:
                raise OSError("simulated locked file")
            writer(path, data)

        with mock_patch.object(patch, "atomic_write", side_effect=fail_configuration):
            with self.assertRaises(patch.PatchError):
                patch.install(self.game, self.plugin_file)
        self.assertEqual((self.game / patch.EXE).read_bytes(), self.original)
        self.assertEqual((self.game / patch.CONFIG).read_bytes(), self.config)
        self.assertFalse((self.game / patch.PLUGIN).exists())

    def test_check_is_read_only(self):
        self.assertIn("Supported original", patch.check(self.game))
        self.assertFalse((self.game / patch.BACKUP).exists())


class MetadataTests(unittest.TestCase):
    def test_constants_match_published_metadata(self):
        self.assertEqual(patch.ORIGINAL_SHA256, patch.METADATA["exe_original_sha256"])
        self.assertEqual(patch.PATCHED_SHA256, patch.METADATA["exe_patched_sha256"])
        self.assertEqual(patch.PLUGIN_SHA256, patch.METADATA["plugin"]["dll_sha256"])


@unittest.skipUnless(os.environ.get("PATCH_TEST_GAME_DIR") and os.environ.get("PATCH_TEST_PLUGIN"), "Optional local game integration inputs not provided")
class LocalIntegrationTests(unittest.TestCase):
    def test_real_executable_round_trip_in_temporary_copy(self):
        source = Path(os.environ["PATCH_TEST_GAME_DIR"])
        plugin = Path(os.environ["PATCH_TEST_PLUGIN"])
        patch.verify_archives(source)
        original = (source / patch.EXE).read_bytes()
        config = (source / patch.CONFIG).read_bytes()
        with tempfile.TemporaryDirectory() as temp:
            game = Path(temp)
            (game / patch.EXE).write_bytes(original)
            (game / patch.CONFIG).write_bytes(config)
            # Real archives were verified read-only above; avoid duplicating 3.8 GB.
            for name in patch.ARCHIVES:
                (game / name).write_bytes(b"placeholder after real archive verification")
            with mock_patch.object(patch, "verify_archives"):
                patch.install(game, plugin)
                self.assertEqual(patch.digest((game / patch.EXE).read_bytes()), patch.PATCHED_SHA256)
                self.assertIn("Expected patched", patch.check(game))
                patch.restore(game)
            self.assertEqual((game / patch.EXE).read_bytes(), original)
            self.assertEqual((game / patch.CONFIG).read_bytes(), config)
            self.assertFalse((game / patch.PLUGIN).exists())
        self.assertEqual((source / patch.EXE).read_bytes(), original)
        self.assertEqual((source / patch.CONFIG).read_bytes(), config)


if __name__ == "__main__":
    unittest.main()
