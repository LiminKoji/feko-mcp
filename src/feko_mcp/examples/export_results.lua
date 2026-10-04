-- Export the solved source impedance, S11 referenced to 50 Ohm, and views.
local base = model_base or "mba_preliminary"
local app = pf.GetApplication()
app:NewProject()
app:OpenFile(base..".fek")
local excitation = app.Models[1].Configurations[1].Excitations[1]
assert(excitation.DataSetAvailable, "No solved excitation data")
local data = excitation.ContinuousFrequencyAxis and excitation:GetDataSet(91)
    or excitation:GetDataSet()
local out = assert(io.open(base.."_results.csv", "w"))
out:write("frequency_Hz,Z_real_ohm,Z_imag_ohm,S11_real,S11_imag,S11_dB,VSWR\n")
for i=1,#data.Axes["Frequency"] do
    local v = data[i]
    local f = v:AxisValue(pf.Enums.DataSetAxisEnum.Frequency)
    local z = v.Impedance
    local s = (z-50)/(z+50)
    local m = s:Magnitude()
    local db = 20*math.log(math.max(m,1e-15))/math.log(10)
    local vswr = (1+m)/(1-m)
    out:write(string.format("%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g\n",
        f,z.re,z.im,s.re,s.im,db,vswr))
end
out:close()
excitation:ExportData(base.."_S11",pf.Enums.FrequencyUnitEnum.Hz,
    pf.Enums.NetworkParameterTypeEnum.Scattering,pf.Enums.NetworkParameterFormatEnum.RI,50,91)

local graph = app.CartesianGraphs:Add()
graph.WindowTitle = "Preliminary model S11"
graph.Title.Text = "S11 - preliminary reconstruction"
graph.Footer.Text = "Assumed geometry, PEC metal; spatial mesh convergence not verified"
local trace = graph.Traces:Add(excitation)
trace.Quantity.Type = pf.Enums.ImpedanceQuantityTypeEnum.ReflectionCoefficient
trace.Quantity.UseCustomReferenceImpedance = true
trace.Quantity.ReferenceImpedanceExpression = "50"
trace.Quantity.ComplexComponent = pf.Enums.ComplexComponentEnum.Magnitude
trace.Quantity.ValuesScaledToDB = true
graph:Restore(); graph:SetSize(1000,600)
graph:ExportImage(base.."_S11", "png", 1500,900)
local view = app.Views[1]
view:Restore(); view:SetSize(800,800)
view.Axes.MainVisible = false; view.Axes.MiniVisible = false
view:SetViewDirection(pf.Enums.ViewDirectionEnum.Top); view:ZoomToExtents()
view.Format.ZoomDistance = view.Format.ZoomDistance*0.25
view:ExportImage(base.."_top", "png",1200,1200)
view:SetViewDirection(pf.Enums.ViewDirectionEnum.Bottom); view:ZoomToExtents()
view.Format.ZoomDistance = view.Format.ZoomDistance*0.25
view:ExportImage(base.."_bottom", "png",1200,1200)
local dielectric_hidden = pcall(function() view.MeshRendering.Faces.DielectricVisible = false end)
view:SetViewDirection(pf.Enums.ViewDirectionEnum.Top); view:ZoomToExtents()
view.Format.ZoomDistance = view.Format.ZoomDistance*0.25
view:ExportImage(base.."_metal_overlay", "png",1200,1200)
if dielectric_hidden then view.MeshRendering.Faces.DielectricVisible = true end
view:SetViewDirection(pf.Enums.ViewDirectionEnum.Isometric); view:ZoomToExtents()
view.Format.ZoomDistance = view.Format.ZoomDistance*0.25
view:ExportImage(base.."_isometric", "png",1200,1000)
app:SaveAs(base..".pfs")
print("EXPORT_COMPLETE "..base)
