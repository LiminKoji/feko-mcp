"""Resolve user configuration without machine-specific installation paths."""
from dataclasses import dataclass
import os
from pathlib import Path
import shutil

EXAMPLES = Path(__file__).resolve().parent / "examples"

@dataclass(frozen=True)
class Settings:
    installation: Path | None
    commands: dict[str, str]
    api_docs: Path | None
    workspace: Path
    max_cores: int

    @classmethod
    def load(cls):
        home = os.environ.get("FEKO_HOME")
        installation = Path(home).expanduser().resolve() if home else None
        explicit_bin = os.environ.get("FEKO_MCP_BIN_DIR")
        if explicit_bin:
            bin_dir = Path(explicit_bin).expanduser().resolve()
        elif installation:
            # FEKO_HOME may refer to the release root or its feko directory.
            bin_dir = installation / "feko" / "bin"
            if not bin_dir.is_dir() and (installation / "bin").is_dir():
                bin_dir = installation / "bin"
        else:
            found = shutil.which("cadfeko") or shutil.which("cadfeko.exe")
            bin_dir = Path(found).resolve().parent if found else None
            if bin_dir:
                installation = bin_dir.parent.parent
        suffix = ".exe" if os.name == "nt" else ""
        commands = {name: str(bin_dir / (name + suffix)) if bin_dir else
                    (shutil.which(name) or name + suffix)
                    for name in ("cadfeko", "runfeko", "postfeko")}
        explicit_docs = os.environ.get("FEKO_MCP_API_DOCS")
        api_docs = Path(explicit_docs).expanduser().resolve() if explicit_docs else None
        if api_docs is None and installation:
            for base in (installation, installation.parent):
                candidate = base / "help/feko/html/topics/feko/user_guide/appendix"
                if candidate.is_dir():
                    api_docs = candidate
                    break
        workspace = Path(os.environ.get("FEKO_MCP_WORKSPACE", str(Path.cwd() / ".feko-mcp"))).expanduser().resolve()
        max_cores = int(os.environ.get("FEKO_MCP_MAX_CORES", str(os.cpu_count() or 1)))
        if max_cores < 1:
            raise ValueError("FEKO_MCP_MAX_CORES must be positive")
        return cls(installation, commands, api_docs, workspace, max_cores)

    def executable_exists(self, name):
        command = self.commands[name]
        return Path(command).is_file() or shutil.which(command) is not None

    def require(self, name):
        if not self.executable_exists(name):
            raise FileNotFoundError(f"Cannot find {name}. Set FEKO_HOME or FEKO_MCP_BIN_DIR, or add FEKO to PATH.")
        return self.commands[name]
