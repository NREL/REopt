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
`FuelCell` results keys:
- `size_kw` Optimal fuel cell capacity
- `lifecycle_fixed_om_cost_after_tax` Lifecycle fixed operations and maintenance cost in present value, after tax
- `year_one_fixed_om_cost_before_tax` fixed operations and maintenance cost over the first year, before considering tax benefits
- `lifecycle_variable_om_cost_after_tax` Lifecycle variable operations and maintenance cost in present value, after tax
- `year_one_variable_om_cost_before_tax` variable operations and maintenance cost over the first year, before considering tax benefits
- `hydrogen_consumed_series_kg` Vector of hydrogen consumed to produce power over the first year
- `year_one_hydrogen_consumed_kg` Hydrogen consumed to produce power over the first year
- `year_one_energy_produced_kwh` Hydrogen consumed to produce power over the first year
- `electric_to_storage_series_kw` Vector of power sent to battery over the first year
- `electric_to_grid_series_kw` Vector of power sent to grid over the first year
- `electric_to_load_series_kw` Vector of power sent to load over the first year
- `electric_curtailed_series_kw` Vector of power curtailed over the first year
- `annual_energy_produced_kwh` Average annual energy produced in an average year
- `annual_energy_exported_kwh` Average annual energy exported to grid in an average year

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 
    
"""
function add_fuel_cell_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `Compressor` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["FuelCell"]), digits=4)

    for t in p.techs.fuel_cell

        FuelCellConsumption = @expression(m, [ts in p.time_steps],
                                p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] / p.s.fuel_cell.efficiency_kwh_per_kg
                                )

        r["hydrogen_consumed_series_kg"] = round.(value.(FuelCellConsumption), digits=3).data
        r["year_one_hydrogen_consumed_kg"] = round(sum(r["hydrogen_consumed_series_kg"]), digits=2)

        if !isempty(p.s.storage.types.elec)
            FuelCelltoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) for ts in p.time_steps)
        else
            FuelCelltoBatt = repeat([0], length(p.time_steps))
        end
        r["electric_to_storage_series_kw"] = round.(value.(FuelCelltoBatt), digits=3)

        r["electric_to_grid_series_kw"] = zeros(size(r["electric_to_storage_series_kw"]))
        r["annual_energy_exported_kwh"] = 0.0
        if !isempty(p.s.electric_tariff.export_bins)
            FuelCelltoGrid = @expression(m, [ts in p.time_steps],
                    sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t]))
            r["electric_to_grid_series_kw"] = round.(value.(FuelCelltoGrid), digits=3).data

            r["annual_energy_exported_kwh"] = round(
                sum(r["electric_to_grid_series_kw"]) * p.hours_per_time_step, digits=0)
        end

        FuelCelltoCUR = (m[Symbol("dvCurtail"*_n)][t, ts] for ts in p.time_steps)
        r["electric_curtailed_series_kw"] = round.(value.(FuelCelltoCUR), digits=3)
        FuelCelltoLoad = (m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
                    - r["electric_curtailed_series_kw"][ts]
                    - r["electric_to_grid_series_kw"][ts]
                    - r["electric_to_storage_series_kw"][ts] for ts in p.time_steps
        )
        r["electric_to_load_series_kw"] = round.(value.(FuelCelltoLoad), digits=3)
        @expression(m, Year1FuelCellProd,
		p.hours_per_time_step * sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts]
			for ts in p.time_steps))
        r["year_one_energy_produced_kwh"] = round(value(Year1FuelCellProd), digits=3)
        r["annual_energy_produced_kwh"] = round(r["year_one_energy_produced_kwh"] * p.levelization_factor[t], digits=2)

        FuelCellPerUnitSizeOMCosts = @expression(m, p.third_party_factor * p.pwf_om * sum(m[:dvSize][t] * p.om_cost_per_kw[t] for t in p.techs.fuel_cell))
        r["year_one_fixed_om_cost_before_tax"] = round(value(FuelCellPerUnitSizeOMCosts) / (p.pwf_om * p.third_party_factor), digits=0)
        r["lifecycle_fixed_om_cost_after_tax"] = round(value(FuelCellPerUnitSizeOMCosts) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
    end

    d["FuelCell"] = r

end

"""
MPC `FuelCell` results keys:
- `hydrogen_consumed_series_kg`
- `electric_to_storage_series_kw`
- `electric_to_load_series_kw`
"""
function add_fuel_cell_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    for t in p.techs.fuel_cell
        FuelCellConsumption = @expression(m, [ts in p.time_steps],
                                p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] / p.s.fuel_cell.efficiency_kwh_per_kg
                                )

        r["hydrogen_consumed_series_kg"] = round.(value.(FuelCellConsumption), digits=3)

        if !isempty(p.s.storage.types.elec)
            FuelCelltoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) for ts in p.time_steps)
        else
            FuelCelltoBatt = repeat([0], length(p.time_steps))
        end
        r["electric_to_storage_series_kw"] = round.(value.(FuelCelltoBatt), digits=3)

        FuelCelltoLoad = (m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
                    - r["electric_to_storage_series_kw"][ts] for ts in p.time_steps
        )
        r["electric_to_load_series_kw"] = round.(value.(FuelCelltoLoad), digits=3)

        d["FuelCell"] = r
    end
end