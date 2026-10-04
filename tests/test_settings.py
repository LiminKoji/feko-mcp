import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from feko_mcp.settings import Settings

class SettingsTests(unittest.TestCase):
    def test_release_root_and_feko_home_layouts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "feko" / "bin"
            binary.mkdir(parents=True)
            docs = root / "help/feko/html/topics/feko/user_guide/appendix"
            docs.mkdir(parents=True)
            for home in (root, root / "feko"):
                with self.subTest(home=home), patch.dict(os.environ, {"FEKO_HOME": str(home)}, clear=True):
                    settings = Settings.load()
                    self.assertEqual(Path(settings.commands["cadfeko"]).parent, binary.resolve())
                    self.assertEqual(settings.api_docs, docs.resolve())

    def test_explicit_paths_and_cpu_limit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            values = {"FEKO_MCP_BIN_DIR": str(root / "bin"), "FEKO_MCP_API_DOCS": str(root / "docs"),
                      "FEKO_MCP_WORKSPACE": str(root / "data"), "FEKO_MCP_MAX_CORES": "2"}
            with patch.dict(os.environ, values, clear=True):
                settings = Settings.load()
                self.assertEqual(settings.max_cores, 2)
                self.assertEqual(settings.workspace, (root / "data").resolve())
                self.assertEqual(settings.api_docs, (root / "docs").resolve())
                with self.assertRaises(FileNotFoundError):
                    settings.require("cadfeko")

    def test_invalid_core_limit(self):
        with patch.dict(os.environ, {"FEKO_MCP_MAX_CORES": "0"}, clear=True):
            with self.assertRaises(ValueError):
                Settings.load()
