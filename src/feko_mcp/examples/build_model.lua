-- Preliminary reconstruction of a published multiband antenna diagram.
-- Topology and undocumented dimensions are assumptions, see MODEL_NOTES.md.
local p = dofile("parameters.lua")
local app = cf.Application.GetInstance()
local project = app:NewProject()
project.ModelAttributes.Unit = cf.Enums.ModelUnitEnum.Millimetres
local vars = project.Definitions.Variables
for _, name in ipairs({"L1","L4","L5","W1","W2","W6","W","L","h",
    "trace_width","radiator_depth","er","tand","feed_overhang","pin_radius","mesh_edge"}) do
    vars:Add(name, tostring(p[name]))
end
for name, expr in pairs({L2="L1", L3="2.5*L1", L6="2.5*L1",
    W3="2*W1", W5="2*W1", W4="0.5*W1"}) do vars:Add(name, expr) end
vars:Add("ground_height", "L5+L4+trace_width")
vars:Add("arm_low", "ground_height+L3")
vars:Add("arm_mid", "arm_low+trace_width+L2")
vars:Add("arm_high", "arm_mid+trace_width+L1")
vars:Add("radiator_y", "arm_high+trace_width+L6")
assert(p.W >= 4*p.W1+0.5*p.W1, "Board W too small for W3 arms")
assert(p.L >= p.L5+p.L4+7*p.L1+4*p.trace_width+p.radiator_depth,
    "Board L too small for the stated clearances")

local geo = project.Contents.Geometry
local media = project.Definitions.Media
local fr4 = media.Dielectric:AddDielectric("er", "tand", 1850)
fr4.Label = "FR4_assumed_tand"
fr4.Colour = "#91AD73"

local slab = geo:AddCuboid(cf.Point(0,0,0), "W", "L", "h")
slab.Label = "Finite_FR4_substrate"
slab.Origin.U = "-W/2"
slab.Regions[1].Medium = fr4
slab.Regions[1].SolutionMethod = cf.Enums.RegionSolutionMethodEnum.SEP
for _, face in pairs(slab.Faces) do face.Medium = media.DielectricBoundaryMedium end

local function rect(label, x, y, z, width, depth)
    local r = geo:AddRectangle(cf.Point(0,0,0), width, depth)
    r.Label = label
    r.Origin.U = x; r.Origin.V = y; r.Origin.N = z
    r.Faces[1].Medium = media.PerfectElectricConductor
    return r
end

-- Ground at z=0, with a clearance underneath the top-side feed and stub.
local ground = rect("Partial_ground", "-W/2", 0, 0, "W", "ground_height")
local vertical_slot = rect("Ground_feed_clearance", "-W6/2-L4", "trace_width", 0,
    "W6+2*L4", "L5+L4-trace_width")
local horizontal_slot = rect("Ground_stub_clearance", "W6/2-W5-L4", "L5-trace_width-L4", 0,
    "W5+2*L4", "trace_width+2*L4")
ground = geo:Subtract(ground, {vertical_slot,horizontal_slot})
ground.Label = "Defected_partial_ground"

local ground_parts = {ground}
for _, side in ipairs({-1,1}) do
    local side_name = side < 0 and "left" or "right"
    local xstem = side < 0 and "-W4/2-trace_width" or "W4/2"
    table.insert(ground_parts, rect("Ground_stem_"..side_name, xstem,
        "ground_height", 0, "trace_width", "arm_high+trace_width-ground_height"))
    for i, arm in ipairs({{"arm_high","W1"},{"arm_mid","W2"},{"arm_low","W3"}}) do
        local xa = side < 0 and "-W4/2-"..arm[2] or "W4/2"
        table.insert(ground_parts, rect("Ground_arm_"..side_name.."_"..i, xa, arm[1], 0,
            arm[2], "trace_width"))
    end
end
table.insert(ground_parts, rect("Ground_port_extension", "-W6/2", "-feed_overhang", 0,
    "W6", "feed_overhang"))
local grounded = geo:Union(ground_parts)
grounded.Label = "Bottom_ground_and_six_branches"

-- Top-side feed, a left-facing tuning stub and terminal rectangular radiator.
local feed = rect("Top_feed", "-W6/2", "-feed_overhang", "h", "W6",
    "radiator_y+radiator_depth+feed_overhang")
local stub = rect("Top_left_tuning_stub", "W6/2-W5", "L5-trace_width", "h",
    "W5", "trace_width")
local radiator = rect("Top_terminal_radiator", "-W5/2", "radiator_y", "h",
    "W5", "radiator_depth")
local top = geo:Union({feed,stub,radiator})
top.Label = "Top_feed_stub_and_radiator"

-- An ideal source pin outside the dielectric replaces the undocumented SMA.
local pin = geo:AddLine(cf.Point(0,-p.feed_overhang,0),cf.Point(0,-p.feed_overhang,p.h))
pin.Label = "Ideal_feed_pin_SMA_not_modelled"
pin.StartPoint.V = "-feed_overhang"
pin.EndPoint.V = "-feed_overhang"; pin.EndPoint.N = "h"
local assembly = geo:Union({slab,grounded,top,pin})
assembly.Label = "MBA_PRELIMINARY_RECONSTRUCTION"
assert(#assembly.Wires == 1, "Expected exactly one feed pin")
local port = project.Contents.Ports:AddWirePort(assembly.Wires[1])
port.Label = "Ideal_50ohm_feed"
port.Location = cf.Enums.WirePortLocationEnum.Middle
local source = project.Contents.SolutionConfigurations.GlobalSources:AddVoltageSource(port)
source.Label = "Feed_1V_50ohm"
source.Magnitude = "1"; source.Impedance = "50"

local freq = project.Contents.SolutionConfigurations.GlobalFrequency
local fp = freq:GetProperties()
fp.RangeType = cf.Enums.FrequencyRangeTypeEnum.LinearSpacedDiscrete
fp.Start = tostring(p.frequency_start); fp.End = tostring(p.frequency_end)
fp.NumberOfDiscreteValues = tostring(p.frequency_count)
if p.frequency_mode == "adaptive" and not smoke_test then
    fp.RangeType=cf.Enums.FrequencyRangeTypeEnum.Continuous
end
if smoke_test then fp.RangeType=cf.Enums.FrequencyRangeTypeEnum.Single; fp.Start="2.4e9" end
freq:SetProperties(fp)
project.Mesher.Settings.MeshSizeOption = cf.Enums.MeshSizeOptionEnum.Custom
project.Mesher.Settings.TriangleEdgeLength = "mesh_edge"
project.Mesher.Settings.WireRadius = "pin_radius"
project.Mesher.Settings.WireSegmentLength = "h/4"
local modelname = smoke_test and "mba_smoke.cfx" or "mba_preliminary.cfx"
app:SaveAs(modelname)
project.Mesher:Mesh()
app:Save()
local report = assert(io.open(smoke_test and "smoke_build_summary.txt" or "build_summary.txt", "w"))
report:write("Model: ",modelname,"\nStatus: PRELIMINARY; geometry assumptions apply\n")
report:write("Triangle count: ", tostring(assembly.SimulationMeshInfo.TriangleCount),"\n")
report:write("Wire segment count (flat): ", tostring(assembly.SimulationMeshInfo.SegmentCount),"\n")
report:write("Wire segment count (curvilinear): ", tostring(assembly.SimulationMeshInfo.CurvilinearSegmentCount),"\n")
report:write("Port count: ", tostring(#project.Contents.Ports),"\n")
report:close()
print("BUILD_COMPLETE "..modelname)
