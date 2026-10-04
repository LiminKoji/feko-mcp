"""Verify stdio MCP -> CADFEKO -> Solver -> POSTFEKO on a small dipole."""
from pathlib import Path
import asyncio
import json
import os
import sys
import time
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from .settings import Settings
ROOT = Settings.load().workspace
ROOT.mkdir(parents=True, exist_ok=True)
DIPOLE = '''local app=cf.Application.GetInstance()
local project=app:NewProject()
local line=project.Contents.Geometry:AddLine(cf.Point(0,0,-0.028),cf.Point(0,0,0.028))
local port=project.Contents.Ports:AddWirePort(line.Wires[1])
port.Location=cf.Enums.WirePortLocationEnum.Middle
local source=project.Contents.SolutionConfigurations.GlobalSources:AddVoltageSource(port)
source.Impedance="50"
project.Contents.SolutionConfigurations.GlobalFrequency.Start="2.4e9"
project.Mesher.Settings.MeshSizeOption=cf.Enums.MeshSizeOptionEnum.Custom
project.Mesher.Settings.WireSegmentLength="0.003"
project.Mesher.Settings.WireRadius="0.0001"
project.Mesher:Mesh()
app:SaveAs("mcp_check.cfx")
'''

async def main():
    parameters = StdioServerParameters(command=sys.executable, args=["-m", "feko_mcp"], env=os.environ.copy())
    async with stdio_client(parameters) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = {tool.name for tool in tools.tools}
            assert {"run_cad_script", "start_solver", "run_post_script", "get_job_status", "read_api"} <= names
            async def call(name, args):
                result = await session.call_tool(name, args)
                assert not result.isError, (name, result.content)
                if result.structuredContent is not None:
                    return result.structuredContent
                return json.loads(result.content[0].text)
            environment = await call("get_environment", {})
            assert all(v["exists"] for v in environment["executables"].values())
            reference = await session.call_tool("read_api", {
                "application": "cadfeko", "relative_path": "object/rectangle.htm"})
            assert not reference.isError and "AddRectangle" in reference.content[0].text
            job = await call("run_cad_script", {"script_text": DIPOLE})
            job_id = job["job_id"]
            async def wait_stage(stage):
                deadline = time.monotonic() + 120
                while time.monotonic() < deadline:
                    status = await call("get_job_status", {"job_id": job_id})
                    record = next((r for r in status["stages"] if r["stage"] == stage), {})
                    if record.get("state") == "completed":
                        return
                    assert record.get("state") != "failed", status
                    await asyncio.sleep(0.5)
                raise AssertionError("Stage timeout: " + stage)
            await wait_stage("build")
            await call("start_solver", {"job_id": job_id, "model_filename": "mcp_check.cfx", "cores": 1})
            await wait_stage("solve")
            await call("run_post_script", {"job_id": job_id, "model_base": "mcp_check"})
            await wait_stage("post")
            artifacts = await call("get_artifacts", {"job_id": job_id})
            filenames = {p["name"] for p in artifacts["files"]}
            assert {"mcp_check.cfx", "mcp_check.bof", "mcp_check_results.csv", "mcp_check.pfs"} <= filenames
            csv_result = await session.call_tool("read_result_text", {
                "job_id": job_id, "filename": "mcp_check_results.csv"})
            assert not csv_result.isError and "2400000000" in csv_result.content[0].text
            report = {"status": "passed", "transport": "stdio", "tools": sorted(names),
                      "job_id": job_id, "checks": ["initialize", "list_tools", "read installed API",
                      "native CADFEKO build", "native FEKO solve", "native POSTFEKO export", "read artifacts"]}
            (ROOT / "verification-native.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
            print(json.dumps(report, indent=2))

if __name__ == "__main__":
    asyncio.run(main())
