# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
`Electrolyzer` results keys:
- `size_kw` Optimal electrolyzer capacity
    - `lifecycle_om_cost_after_tax` Lifecycle operations and maintenance cost in present value, after tax
- `year_one_hydrogen_produced_kg` Total hydrogen produced over the first year
- `year_one_electricity_consumed_kwh` Total energy consumed by the electrolyzer over the first year
- `electricity_consumed_series_kw` Vector of power consumed by the electrolyzer to produce hydrogen over the first year
- `hydrogen_produced_series_kg` Vector of hydrogen produced by the electrolyzer going into the low pressure tank 
- `water_consumed_series_gal` Vector of water consumed by the electrolyzer to produce hydrogen 
- `year_one_water_consumed_gal` Total water consumed by the electrolyzer to produce hydrogen 

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 
    
"""
function add_electrolyzer_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `Electrolyzer` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["Electrolyzer"]), digits=4)

    ElectrolyzerConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(ElectrolyzerConsumption).data, digits=3)
    GridToElectrolyzer = @expression(m, [ts in p.time_steps],
                                m[Symbol("dvGridToElectrolyzer"*_n)][ts]
                            )
    r["electricity_from_grid_series_kw"] = round.(value.(GridToElectrolyzer).data, digits=3)
    FuelCellToElectrolyzer = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToElectrolyzer"*_n)][t, ts] for t in p.techs.fuel_cell)
                            )
    r["electricity_from_fuel_cell_series_kw"] = round.(value.(FuelCellToElectrolyzer).data, digits=3)
    PVToElectrolyzer = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToElectrolyzer"*_n)][t, ts] for t in p.techs.pv)
                            )
    r["electricity_from_pv_series_kw"] = round.(value.(PVToElectrolyzer).data, digits=3)
    r["year_one_electricity_consumed_kwh"] = round(sum(r["electricity_consumed_series_kw"]), digits=2)

    ElectrolyzerProduction = @expression(m, [ts in p.time_steps],
                            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
                            / p.s.electrolyzer.efficiency_kwh_per_kg
                        )
    r["hydrogen_produced_series_kg"] = round.(value.(ElectrolyzerProduction).data, digits=3)
    r["year_one_hydrogen_produced_kg"] = round(sum(r["hydrogen_produced_series_kg"]), digits=2)
    r["water_consumed_series_gal"] = round.(value.(ElectrolyzerProduction).data * 3.78, digits=3)
    r["year_one_water_consumed_gal"] = round(sum(r["hydrogen_produced_series_kg"]) * 3.78, digits=2)

    d["Electrolyzer"] = r

end

"""
MPC `Electrolyzer` results keys:
- `electricity_consumed_series_kw`
- `hydrogen_produced_series_kg`
"""
function add_electrolyzer_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    ElectrolyzerConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(ElectrolyzerConsumption), digits=6)

    ElectrolyzerProduction = @expression(m, [ts in p.time_steps],
                            sum(m[Symbol("dvProductionToStorage"*_n)]["HydrogenStorageLP", t, ts] for t in p.techs.electrolyzer)
                        )
    r["hydrogen_produced_series_kg"] = round.(value.(ElectrolyzerProduction), digits=6)
    d["Electrolyzer"] = r

end