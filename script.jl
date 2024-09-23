# install package (only needed once)
using Pkg 
Pkg.add("HiGHS")
Pkg.add(url="https://github.com/leonardgoeke/AnyMOD.jl", rev = "dev")
Pkg.add("CairoMakie")
Pkg.add("Colors")
Pkg.add("CSV")

# load package and specific functions (needed every time)
using HiGHS, AnyMOD, CairoMakie, Colors, CSV
include("functions.jl")


# create and solve deterministic model for reference case
allRes_df = DataFrame(scenario = String[], variable = String[], capacity = Float64[])
inDet_arr = ["general_inputs", "timeSeries_inputs/base"]

# ! create and solve model for base case
base_m = anyModel(inDet_arr, "results", objName = "base", supTsLvl = 1, frsLvl = 0)
createOptModel!(base_m)
setObjective!(:cost, base_m)

set_optimizer(base_m.optModel, HiGHS.Optimizer)
optimize!(base_m.optModel)

# get overall results
resDet_df =  reportResults(:summary, base_m, rtnOpt = (:csvDf,:csv))

# get capacity results and add to overall dataframe
capaDet_df = filterCapacity(resDet_df, "base")
append!(allRes_df, capaDet_df)

# initialize radar plot and add first data
capaRadarPlot_obj, axisCapaRadarPlot_obj = initializeRadar(3, 3, unique(capaDet_df[!,:variable]), ["3 GW","800 GWh","8 GW"], 45.0)
addData!(capaRadarPlot_obj, axisCapaRadarPlot_obj, capaDet_df[!,:capacity], "base", (239/255, 147/255, 71/255), 0.5)

# ! create and solve model for extreme cases
for x in ("highDemLowHydro", "highDemLowWind")

    # create and solve deterministic model for reference case
    inDet_arr = ["general_inputs", "timeSeries_inputs/" * x]

    # create and solve model for base case
    ext_m = anyModel(inDet_arr, "results", objName = x, supTsLvl = 1, frsLvl = 0)
    createOptModel!(ext_m)
    setObjective!(:cost, ext_m)

    set_optimizer(ext_m.optModel, HiGHS.Optimizer)
    optimize!(ext_m.optModel)

    # get overall results
    resExt_df =  reportResults(:summary, ext_m, rtnOpt = (:csvDf,:csv))

    # get capacity results and add to overall dataframe
    capaExt_df = filterCapacity(resExt_df, x)
    append!(allRes_df, capaExt_df)

    # add data to rader plot
    if x == "highDemLowHydro"
        addData!(capaRadarPlot_obj, axisCapaRadarPlot_obj, capaExt_df[!,:capacity], x, (103/255,130/255,228/255), 0.3)
    else
        addData!(capaRadarPlot_obj, axisCapaRadarPlot_obj, capaExt_df[!,:capacity], x, (179/255, 236/255, 116/255), 0.3)
    end

end

# add convex hull as robust solution
convexHull_df = combine(x -> (capacity = maximum(x.capacity), scenario = "convexHull"), groupby(allRes_df, :variable))
append!(allRes_df, convexHull_df)
addData!(capaRadarPlot_obj, axisCapaRadarPlot_obj, convexHull_df[!,:capacity], "convexHull", (0/255, 0/255, 0/255), 0.0, linestyle = :dot)


# ! create and solve model for stochastic case
inStoch_arr = ["general_inputs", "timeSeries_inputs", "scenario_inputs"]

stoch_m = anyModel(inStoch_arr, "results", objName = "stochastic", supTsLvl = 1, frsLvl = 0)
createOptModel!(stoch_m)
setObjective!(:cost, stoch_m)

set_optimizer(stoch_m.optModel, HiGHS.Optimizer)
optimize!(stoch_m.optModel)

# get overall results
resStoch_df =  reportResults(:summary, stoch_m, rtnOpt = (:csvDf,:csv))

# get capacity results and add to overall dataframe
capaStoch_df = filterCapacity(resStoch_df, "stochastic")
append!(allRes_df, capaStoch_df)

# get costs
cost_df = getCosts(stoch_m, "stochastic")
addData!(capaRadarPlot_obj, axisCapaRadarPlot_obj, capaStoch_df[!,:capacity], "stochastic", (0/255, 0/255, 0/255), 0.0)


# ! compare costs to get value of stochastic solution and compare

for scr in ("base", "highDemLowHydro", "highDemLowWind", "convexHull")
    append!(cost_df, runStochFixed(allRes_df, scr))
end

stackedBarCosts(cost_df)
