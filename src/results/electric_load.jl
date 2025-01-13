# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ElectricLoad` results keys:
- `load_series_kw` vector of site load in every time step. Does not (currently) include electric load for any new heating or cool techs.
- `critical_load_series_kw` vector of site critical load in every time step
- `annual_calculated_kwh` sum of the `load_series_kw`
- `offgrid_load_met_series_kw` vector of electric load met by generation techs, for off-grid scenarios only
- `offgrid_load_met_fraction` percentage of total electric load met on an annual basis, for off-grid scenarios only
- `offgrid_annual_oper_res_required_series_kwh` , total operating reserves required (for load and techs) on an annual basis, for off-grid scenarios only
- `offgrid_annual_oper_res_provided_series_kwh` , total operating reserves provided on an annual basis, for off-grid scenarios only

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""
function add_electric_load_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `ElectricLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    r["load_series_kw"] = p.s.electric_load.loads_kw
    r["critical_load_series_kw"] = p.s.electric_load.critical_loads_kw
    r["annual_calculated_kwh"] = round(
        sum(r["load_series_kw"]) * p.hours_per_time_step, digits=2
    )
    
    if p.s.settings.off_grid_flag
        @expression(m, LoadMet[ts in p.time_steps_without_grid], p.s.electric_load.critical_loads_kw[ts] * m[Symbol("dvOffgridLoadServedFraction"*_n)][ts])
        r["offgrid_load_met_series_kw"] =  round.(value.(LoadMet).data, digits=6)
        @expression(m, LoadMetPct, sum(p.s.electric_load.critical_loads_kw[ts] * m[Symbol("dvOffgridLoadServedFraction"*_n)][ts] for ts in p.time_steps_without_grid) /
                sum(p.s.electric_load.critical_loads_kw))
        r["offgrid_load_met_fraction"] = round(value(LoadMetPct), digits=6)
        
        r["offgrid_annual_oper_res_required_series_kwh"] = round.(value.(m[:OpResRequired][ts] for ts in p.time_steps_without_grid), digits=3)
        r["offgrid_annual_oper_res_provided_series_kwh"] = round.(value.(m[:OpResProvided][ts] for ts in p.time_steps_without_grid), digits=3)
    end
    
    d["ElectricLoad"] = r
    nothing
end


function add_electric_load_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    # Adds the `ElectricLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    r["load_series_kw"] = p.s.electric_load.loads_kw
    
    d["ElectricLoad"] = r
    nothing
end