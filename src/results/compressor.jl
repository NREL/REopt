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
`Compressor` results keys:
- `size_kw` Optimal compressor capacity
    - `lifecycle_om_cost_after_tax` Lifecycle operations and maintenance cost in present value, after tax
- `year_one_hydrogen_compressed_kg` Total hydrogen compressed over the first year
- `year_one_electricity_consumed_kwh` Total energy consumed by the compressor over the first year
- `electricity_consumed_series_kw` Vector of power consumed by the compressor over the first year
- `hydrogen_compressed_series_kg` Vector of hydrogen compressed going into the high pressure tank 

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 
    
"""
function add_compressor_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `Compressor` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["Compressor"]), digits=4)

    CompressorConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(CompressorConsumption).data, digits=3)
    FuelCellToCompressor = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToCompressor"*_n)][t, ts] for t in p.techs.fuel_cell)
                            )
    r["electricity_from_fuel_cell_series_kw"] = round.(value.(FuelCellToCompressor).data, digits=3)
    r["year_one_electricity_consumed_kwh"] = round(sum(r["electricity_consumed_series_kw"]), digits=2)
    GridToCompressor = @expression(m, [ts in p.time_steps],
                                m[Symbol("dvGridToCompressor"*_n)][ts]
                            )
    r["electricity_from_grid_series_kw"] = round.(value.(GridToCompressor).data, digits=3)

    if p.s.electrolyzer.require_compression
        CompressorProduction = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
                                / p.s.compressor.efficiency_kwh_per_kg
                            )
    else
        CompressorProduction = repeat([0], length(p.time_steps))
    end

    r["hydrogen_compressed_series_kg"] = round.(value.(CompressorProduction).data, digits=3)
    r["year_one_hydrogen_compressed_kg"] = round(sum(r["hydrogen_compressed_series_kg"]), digits=2)                      

    d["Compressor"] = r

end

"""
MPC `Compressor` results keys:
- `hydrogen_compressed_series_kg`
- `electricity_consumed_series_kw`
"""
function add_compressor_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    # Adds the `Compressor` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    CompressorProduction = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToStorage"*_n)]["HydrogenStorageHP", t, ts] for t in p.techs.compressor)
                            )
    r["hydrogen_compressed_series_kg"] = round.(value.(CompressorProduction), digits=3)
    
    CompressorConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(CompressorConsumption), digits=3)
    
    d["Compressor"] = r

end