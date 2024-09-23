# filters relevant capacity results
function filterCapacity(in_df::DataFrame, scr::String)

    # filter relevant rows
    filter!(x -> x.variable in (:capaConv, :capaStSize, :capaStIn), in_df)
    # de-select irrelevant columns and rename remaining ones
    select!(in_df, [:variable, :value])
    in_df = rename(in_df, :value => :capacity)
    # change variable name and add scenario info
    rename_dic = Dict(:capaConv => "wind", :capaStSize => "hydro size", :capaStIn => "hydro pump")
    in_df[!,:variable] = map(x -> rename_dic[x], in_df[!,:variable])  
    # add scenario info and return
    in_df[!,:scenario] .= scr  
    
    return sort(select(in_df,[:scenario,:variable,:capacity]), [:variable])
end

# filters relevant cost results
function getCosts(mod_m::anyModel, scr)

    # ge relevant costs
    costFix_df =  reportResults(:cost, mod_m, rtnOpt = (:csvDf,))
    select!(costFix_df, [:variable, :value])
    # format output
    rename_dic = Dict(:costExpConv => "wind", :costExpStSize => "hydro size", :costExpStIn => "hydro pump", :costLss => "unmet demand")
    costFix_df[!,:variable] = map(x -> rename_dic[x], costFix_df[!,:variable])  
    costFix_df[!,:scenario] .= scr

    return costFix_df

end

# initialize radar plot
function initializeRadar(seg_int::Int, crc_int::Int, labelCrc_arr::Array{String,1}, leg_arr::Array{String,1}, ang_fl::Float64)

    # Create the figure with the specified size
  
    # Convert size from centimeters to inches (needed for the Figure constructor)
    wid = 21.034 * 28.3465
    hei = 13 * 28.3465
    dpi = 600

    # Set the DPI and font scaling
    fig_obj = Figure(size = (wid, hei), pt_per_unit = 1)
    ax_obj = Axis(fig_obj[1,1])

    #colsize!(fig_obj.layout, 1, Fixed(400))

    ax_obj.aspect = DataAspect()
    xlims!(ax_obj, -1.3, 1.5)  # Adjust these values as needed
    ylims!(ax_obj, -1.2, 1.2)  # Adjust these values as needed

    # set axis attributes
    ax_obj.xgridvisible = false
    ax_obj.ygridvisible = false
    ax_obj.xminorgridvisible = false
    ax_obj.yminorgridvisible = false
    ax_obj.leftspinevisible = false
    ax_obj.rightspinevisible = false
    ax_obj.bottomspinevisible = false
    ax_obj.topspinevisible = false
    ax_obj.xminorticksvisible = false
    ax_obj.yminorticksvisible = false
    ax_obj.xticksvisible = false
    ax_obj.yticksvisible = false
    ax_obj.xticklabelsvisible = false
    ax_obj.yticklabelsvisible = false
    ax_obj.aspect = DataAspect()

    # labels for lines
    l_int = length(labelCrc_arr)
    radL_arr = (0:(l_int - 1)) * 2π / l_int .+ 0.5π
    xL_arr, yL_arr = map(y -> map(x -> abs(x) < 1e-2 ? 0.0 : x, y), [cos.(radL_arr), sin.(radL_arr)])

    movLab_dic = Dict(:left => 0.05, :right => -0.05, :top => -0.05, :bottom => 0.05, :center => 0.0)
    for i in eachindex(radL_arr)
        # get horizintal and vertical positon of text
        horPos_sym = xL_arr[i] < 0.0 ? :right : (xL_arr[i] > 0.0 ? :left : :center)
        verPos_sym = yL_arr[i] < 0.0 ? :top : (yL_arr[i] > 0.0 ? :bottom : :center)
        # place text    
        text!(ax_obj, xL_arr[i] + movLab_dic[horPos_sym], yL_arr[i] + movLab_dic[verPos_sym], text= labelCrc_arr[i], fontsize = 10, align = (horPos_sym, verPos_sym), color = ax_obj.xlabelcolor)
    end

    # draw circles
    crc_arr = (1.0:crc_int) / crc_int
    for i in crc_arr
        poly!(ax_obj, Circle(Point2f(0, 0), i), color = :transparent, strokewidth=1, strokecolor=ax_obj.xgridcolor)
    end

    # draw lines
    radS_arr = (0:(seg_int - 1)) * 2π / seg_int .+ 0.5π
    xCrc_arr = cos.(radS_arr)
    yCrc_arr = sin.(radS_arr)
    arrows!(ax_obj, zeros(seg_int), zeros(seg_int), xCrc_arr, yCrc_arr, color=ax_obj.xgridcolor, linestyle=:solid, arrowhead= ' ')

    # draw legend
    radLeg_arr = (0:(length(leg_arr) - 1)) * 2π / length(leg_arr) .+ 0.5π
    xLeg_arr, yLeg_arr = map(y -> map(x -> abs(x) < 1e-2 ? 0.0 : x, y), [cos.(radLeg_arr), sin.(radLeg_arr)])
    rad_arr = (1.0:crc_int) / crc_int

    movLeg_dic = Dict(:left => 0.05, :right => -0.05, :top => 0.0, :bottom => 0.0, :center => 0.0)

    for i in eachindex(radLeg_arr)
        arrows!(ax_obj, [0], [0], [cos(radLeg_arr[i])], [sin(radLeg_arr[i])], color=:black, linestyle=:solid, arrowhead= ' ', linewidth = 0.92)
        
        horPos_sym = xLeg_arr[i] < 0.0 ? :right : (xLeg_arr[i] >= 0.0 ? :left : :center)
        verPos_sym = yLeg_arr[i] < 0.0 ? :bottom : (yLeg_arr[i] > 0.0 ? :top : :center)

        text!(ax_obj, xLeg_arr[i] + movLeg_dic[horPos_sym], yLeg_arr[i] + movLeg_dic[verPos_sym], text= leg_arr[i], fontsize = 10, color = ax_obj.xlabelcolor, align = (horPos_sym, verPos_sym))
        
        for j in eachindex(rad_arr)
            scatter!(ax_obj, rad_arr[j] * xLeg_arr[i], rad_arr[j] * yLeg_arr[i], color = :black, markersize = 5)
        end

    end

    return fig_obj, ax_obj
end

# add data to radar plot
function addData!(fig_obj::Figure, ax_obj::Axis, value_arr::Array{Float64,1}, label_str::String, color_tup::Tuple{Float64, Float64, Float64}, alphaFill_fl::Float64; line_fl::Float64 = 1.5, linestyle::Symbol = :solid, points_boo::Bool=false)
    
    value_arr = value_arr ./ [3.0, 800.0, 8.0]
    # get points for radar plot
    l_int = length(value_arr)
    rad_arr = (0:(l_int - 1)) * 2π / l_int .+ 0.5π
    x_arr = value_arr .* cos.(rad_arr)
    y_arr = value_arr .* sin.(rad_arr)

    # format radar plot
    if alphaFill_fl != 0.0
        pp_obj = poly!(ax_obj, [(x_arr[i], y_arr[i]) for i in eachindex(x_arr)], color = RGBA{Float32}(color_tup[1], color_tup[2], color_tup[3], alphaFill_fl), strokewidth= 0.0, strokecolor=RGBA{Float32}(color_tup[1], color_tup[2], color_tup[3]), label = label_str)
    else
        push!(x_arr, x_arr[1])
        push!(y_arr, y_arr[1])
        lines!(x_arr, y_arr, linewidth = line_fl, color=RGBA{Float32}(color_tup[1], color_tup[2], color_tup[3]), label = label_str, linestyle = linestyle)
    end

    [delete!(leg) for leg in fig_obj.content if leg isa Legend]
    fig_obj[1,2] = Legend(fig_obj, ax_obj, framevisible = false, labelsize = 10)

    ax_obj.aspect = DataAspect()
    xlims!(ax_obj, -1.8, 1.7)  # Adjust these values as needed
    ylims!(ax_obj, -1.2, 1.2)  # Adjust these values as needed

    if points_boo
        scatter!(ax_obj, x_arr, y_arr)
    end

end

# run stochastic model but with capacities fixed to names scenario and return the costs
function runStochFixed(allRes_df::DataFrame, scr::String)
    # create model
    inStoch_arr = ["general_inputs", "timeSeries_inputs", "scenario_inputs"]
    stochFix_m = anyModel(inStoch_arr, "results", objName = "stochasticFixed_" * scr, supTsLvl = 1, frsLvl = 0)
    createOptModel!(stochFix_m)
    setObjective!(:cost, stochFix_m)

    # fix capacities
    relCapa_df = filter(x -> x.scenario == scr, allRes_df)

    windCapa_fl = filter(x -> x.variable == "wind", relCapa_df)[1,:capacity]
    @constraint(stochFix_m.optModel, stochFix_m.parts.tech[:wind].var[:capaConv][1,:var] == windCapa_fl)

    hydroSize_fl = filter(x -> x.variable == "hydro size", relCapa_df)[1,:capacity]
    @constraint(stochFix_m.optModel, stochFix_m.parts.tech[:hydro].var[:capaStSize][1,:var] == hydroSize_fl)

    hydroPump_fl = filter(x -> x.variable == "hydro pump", relCapa_df)[1,:capacity]
    @constraint(stochFix_m.optModel, stochFix_m.parts.tech[:hydro].var[:capaStIn][1,:var] == hydroPump_fl)

    # solve model
    set_optimizer(stochFix_m.optModel, HiGHS.Optimizer)
    optimize!(stochFix_m.optModel)

    return getCosts(stochFix_m, scr::String)
end

# stacked bar plot for cost comparison
function stackedBarCosts(cost_df::DataFrame)
    scr_arr = unique(cost_df[!,:scenario])
    var_arr = unique(cost_df[!,:variable])

    fig = Figure()
    colors = Makie.wong_colors()[[2,3,5,6,7]]
    ax = Axis(fig[1,1], xticks = (1:5, scr_arr), xticklabelrotation = pi/4, title = "Costs of the stochastic solution compared to heuristics")

    tbl = (cat = [1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5],
        height = cost_df[!,:value],
        grp = repeat([1,2,3,4], 5))

    barplot!(ax, tbl.cat, tbl.height, stack = tbl.grp, color = colors[tbl.grp])

    labels = var_arr
    elements = [PolyElement(polycolor = colors[i]) for i in 1:length(labels)]
    Legend(fig[1,2], elements, labels, "")
    return fig
end