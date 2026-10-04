# FEKO MCP

[Русская инструкция](README.ru.md)

Control **CADFEKO → FEKO solver → POSTFEKO** from an MCP-compatible AI client.
This local stdio server runs Lua API scripts, launches asynchronous jobs,
reads progress, and exports S11, impedance, Touchstone, model files, and images.

Tested with **Windows, Altair FEKO 2026.1, Python 3.11+**. Other FEKO versions
and operating systems have not been validated. You need your own FEKO
installation and suitable licence; neither is included. This is an independent
community integration, not an official Altair product.

## Install

```powershell
git clone https://github.com/Zircon04/feko-mcp.git
cd feko-mcp
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install .
$env:FEKO_HOME = 'C:\Program Files\Altair\2026.1'
$env:FEKO_MCP_WORKSPACE = "$PWD\jobs"
.\.venv\Scripts\feko-mcp.exe doctor
```

Set paths to **your** installation and a writable job directory. `FEKO_HOME`
accepts the release root containing `feko/bin`, or the `feko` directory itself.
If the programs are on PATH, the installation can be discovered. The example
path may differ on your computer. `doctor` checks program paths; FEKO checks
licence availability when a job runs.

## Connect an AI client

Start the stdio server with `feko-mcp`, or `python -m feko_mcp`. Use absolute
paths in the client. Shell environment variables are not automatically inherited
by an already-running desktop app: put them in the MCP configuration.

For Codex, add to `config.toml`, replacing paths:

```toml
[mcp_servers.feko]
command = 'C:\path\to\feko-mcp\.venv\Scripts\python.exe'
args = ['-m', 'feko_mcp']
startup_timeout_sec = 20

[mcp_servers.feko.env]
FEKO_HOME = 'C:\Program Files\Altair\2026.1'
FEKO_MCP_WORKSPACE = 'C:\path\to\feko-jobs'
```

Restart the MCP connection after saving. See [OpenAI's MCP configuration
documentation](https://learn.chatgpt.com/docs/extend/mcp). Clients using
`mcpServers` JSON can use [mcp-config.example.json](mcp-config.example.json).
This server needs no OpenAI API key.

## Tools and workflow

| Tool | Purpose |
|---|---|
| `get_environment` | Check programs, workspace, and example assumptions |
| `read_api` | Read/search installed CADFEKO/POSTFEKO Lua API documentation |
| `run_cad_script` | Run a Lua build with optional text assets in a new job |
| `create_preliminary_model` | Build the included antenna with parameter overrides |
| `start_solver` | Start a solver job and return immediately |
| `get_job_status` | Read stage state and log tails |
| `run_post_script` | Run custom POSTFEKO Lua or the supplied exporter |
| `get_artifacts` | List output paths and sizes |
| `read_result_text` | Read exported tables, notes, or diagnostics |

Check `get_environment`; build a model; poll until `build` completes; call
`start_solver`; wait for `solve`; call `run_post_script`; read the exports.
Keep the returned `job_id`. Use the filename produced by your build script.
Process startup does not mean calculation success: check stage state, exit
code, and FEKO diagnostics. `job_id="example"` reads the bundled model notes,
not precomputed results. Build a new job to obtain results.

Sample prompt:

> Use the FEKO tools to build a centre-fed dipole at 2.4 GHz. Read the installed
> API first, solve on one core, check status, and export S11 referenced to
> 50 ohm. Report solver errors and output paths.

Jobs live in `<workspace>/jobs/<job_id>`. Workers continue after MCP requests
return. There is no built-in cancellation: inspect worker status/PID before
managing a process manually. No network listener is opened. Lua runs with the
local user's permissions: use trusted scripts and clients; this is not a
sandbox for untrusted code.

## Example without an AI client

```powershell
.\.venv\Scripts\feko-mcp.exe example build --smoke
.\.venv\Scripts\feko-mcp.exe example solve --smoke --cores 1
.\.venv\Scripts\feko-mcp.exe example post --smoke
```

The smoke example runs at 2.4 GHz. Omit `--smoke` from all three commands
for 1–10 GHz. Outputs live in `<workspace>/example`. Edit its `parameters.lua`
before rebuilding to change geometry or frequency sampling.

The antenna is a **preliminary reconstruction with assumptions**, not a
validated design. Read the [model notes](src/feko_mcp/examples/MODEL_NOTES.md).
Source PDFs, figures, calculated result binaries, and vendor files are omitted.

## Configuration

| Variable | Default / meaning |
|---|---|
| `FEKO_HOME` | Installation release root; otherwise discover via PATH |
| `FEKO_MCP_BIN_DIR` | Optional directory containing all three executables |
| `FEKO_MCP_WORKSPACE` | `.feko-mcp` in the current working directory |
| `FEKO_MCP_API_DOCS` | Optional path to the local documentation `appendix` directory |
| `FEKO_MCP_MAX_CORES` | CPU count; set lower for licence/resource limits |

`read_api` accepts e.g. `application="cadfeko"`,
`relative_path="object/rectangle.htm"`. It reads local docs, not the internet.

If CADFEKO reports that it cannot open its user settings, check the client's
execution permissions: FEKO also needs access to its own configuration and
licensing files outside the job directory. A missing documentation directory
can be configured separately with `FEKO_MCP_API_DOCS`.

## Development and verification

```powershell
.\.venv\Scripts\python.exe -m pip install -e .
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
# Requires FEKO and a licence; runs a small native dipole:
.\.venv\Scripts\python.exe -m feko_mcp.verify_native
```

CI checks configuration, input validation, worker outcomes, and stdio tools
without FEKO. It does not verify electromagnetic accuracy. Native verification
is opt-in and creates a new job. Report FEKO/Python/OS versions and a minimal
script in issues. See [CONTRIBUTING.md](CONTRIBUTING.md).

MIT licence covers the bridge code. Altair software and third-party source
material retain their own licences and are not redistributed.
