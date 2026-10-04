"""STDIO server, environment diagnostics, and reproducible example stages."""
import argparse
import json
import shutil
import subprocess

from .settings import EXAMPLES, Settings

def main():
    parser = argparse.ArgumentParser(description="Local FEKO MCP server (stdio by default)")
    commands = parser.add_subparsers(dest="command")
    commands.add_parser("doctor", help="Check installation paths without running FEKO")
    example = commands.add_parser("example", help="Build/solve/export the preliminary antenna")
    example.add_argument("stage", choices=["build", "solve", "post"])
    example.add_argument("--smoke", action="store_true", help="Single-frequency 2.4 GHz check")
    example.add_argument("--cores", type=int, default=1)
    args = parser.parse_args()
    settings = Settings.load()
    if args.command == "doctor":
        report = {"executables": {name: {"path": command, "exists": settings.executable_exists(name)}
                                  for name, command in settings.commands.items()},
                  "workspace": str(settings.workspace), "max_cores": settings.max_cores,
                  "api_docs": str(settings.api_docs) if settings.api_docs else None}
        print(json.dumps(report, indent=2))
        raise SystemExit(0 if all(v["exists"] for v in report["executables"].values()) else 1)
    if args.command == "example":
        if not 1 <= args.cores <= settings.max_cores:
            parser.error(f"--cores must be between 1 and {settings.max_cores}")
        directory = settings.workspace / "example"
        directory.mkdir(parents=True, exist_ok=True)
        base = "mba_smoke" if args.smoke else "mba_preliminary"
        if args.stage == "build":
            for name in ("build_model.lua", "parameters.lua", "MODEL_NOTES.md"):
                target = directory / name
                if name != "parameters.lua" or not target.exists():
                    shutil.copyfile(EXAMPLES / name, target)
            command = [settings.require("cadfeko"), "--non-interactive", "--run-script", str(directory / "build_model.lua")]
            if args.smoke:
                command += ["--configure-script", "smoke_test=true"]
        elif args.stage == "solve":
            if not (directory / (base + ".cfx")).is_file():
                parser.error("Build the model first")
            command = [settings.require("runfeko"), base + ".cfx", "-np", str(args.cores)]
        else:
            if not (directory / (base + ".bof")).is_file():
                parser.error("Solve the model first")
            command = [settings.require("postfeko"), "--non-interactive", "--run-script", str(EXAMPLES / "export_results.lua"),
                       "--configure-script", f'model_base="{base}"']
        log = directory / f"{base}_{args.stage}.log"
        print(f"{args.stage}: {directory}; log: {log}", flush=True)
        with log.open("w", encoding="utf-8") as stream:
            completed = subprocess.run(command, cwd=directory, stdout=stream, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        print(log.read_text(encoding="utf-8", errors="replace")[-12000:])
        raise SystemExit(completed.returncode)
    from .server import mcp
    mcp.run(transport="stdio")
