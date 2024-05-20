# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingHydropower` results keys:
- `size_kw` the turbine input into the model capacity
- `electric_to_storage_series_kw` Vector of power sent to battery in an average year
- `electric_to_grid_series_kw` Vector of power sent to grid in an average year
- `electric_to_load_series_kw` Vector of power sent to load in an average year
- `annual_energy_produced_kwh` Average annual energy produced over analysis period

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""

# TODO: change all of this to hydropower

function add_existing_hydropower_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
	# Adds the `ExistingHydropower` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
	# Note: the node number is an empty string if evaluating a single `Site`.
	# TODO: add _n to the hydropower code

    r = Dict{String, Any}()

	#GenPerUnitSizeOMCosts = @expression(m, p.third_party_factor * p.pwf_om * sum(m[:dvSize][t] * p.om_cost_per_kw[t] for t in p.techs.gen))

	#GenPerUnitProdOMCosts = @expression(m, p.third_party_factor * p.pwf_om * p.hours_per_time_step *
 #		sum(m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.s.generator.om_cost_per_kwh
 #			for t in p.techs.gen, ts in p.time_steps)
 #	)
	r["fixed_size_kw_per_turbine"] = p.s.existing_hydropower.existing_kw_per_turbine # round(value(sum(m[:dvSize][t] for t in p.techs.existing_hydropower)), digits=2)
	
	#r["lifecycle_fixed_om_cost_after_tax"] = round(value(GenPerUnitSizeOMCosts) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
	#r["lifecycle_variable_om_cost_after_tax"] = round(value(m[:TotalPerUnitProdOMCosts]) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
	#r["lifecycle_fuel_cost_after_tax"] = round(value(m[:TotalGenFuelCosts]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
	#r["year_one_fuel_cost_before_tax"] = round(value(m[:TotalGenFuelCosts]) / p.pwf_fuel["Generator"], digits=2)
	#r["year_one_variable_om_cost_before_tax"] = round(value(GenPerUnitProdOMCosts) / (p.pwf_om * p.third_party_factor), digits=0)
	#r["year_one_fixed_om_cost_before_tax"] = round(value(GenPerUnitSizeOMCosts) / (p.pwf_om * p.third_party_factor), digits=0)

	# sum these power flows from all of the turbines
	if !isempty(p.s.storage.types.elec)
		hydropowerToBatt = @expression(m, [ts in p.time_steps],
			sum(m[:dvProductionToStorage][b, t, ts] for b in p.s.storage.types.elec, t in p.techs.existing_hydropower))
	else
		hydropowerToBatt = zeros(length(p.time_steps))
	end
	r["electric_to_storage_series_kw_all_turbines_combined"] = round.(value.(hydropowerToBatt).data, digits=3)

	# Compute the curtailed power
	HydroCurtailment = @expression(m, [ts in p.time_steps],
		sum(m[Symbol("dvCurtail")][t, ts] for t in p.techs.existing_hydropower))
	
	r["electric_curtailed_series_kw_all_turbines_combined"] = round.(value.(HydroCurtailment).data, digits=3)

	# Hydropower to grid
	hydropowerToGrid = @expression(m, [ts in p.time_steps],
		sum(m[:dvProductionToGrid][t, u, ts] for t in p.techs.existing_hydropower, u in p.export_bins_by_tech[t])
	)
	r["electric_to_grid_series_kw_all_turbines_combined"] = round.(value.(hydropowerToGrid).data, digits=3)

	# Hydropower to load
	hydropowerToLoad = @expression(m, [ts in p.time_steps],
		sum(m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
			for t in p.techs.existing_hydropower) -
			hydropowerToBatt[ts] - hydropowerToGrid[ts] - HydroCurtailment[ts]
	)
	r["electric_to_load_series_kw_all_turbines_combined"] = round.(value.(hydropowerToLoad).data, digits=3)
	
	# Total hydropower power output
	TotalHydropowerPowerOutput = @expression(m, [ts in p.time_steps],
		sum(m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
			for t in p.techs.existing_hydropower) - HydroCurtailment[ts]
	)
	r["total_power_output_series_kw_all_turbines_combined"] = round.(value.(TotalHydropowerPowerOutput).data, digits=3)
	
	# Reservoir volume
	reservoir_volume = @expression(m, [ts in p.time_steps], m[:dvWaterVolume][ts])
	r["reservoir_water_volume_cubic_meters"] = round.(value.(reservoir_volume).data, digits=3) 

	r["input_to_model_tributary_water_flow"] = p.s.existing_hydropower.water_inflow_cubic_meter_per_second

	water_outflow_total = @expression(m, [ts in p.time_steps],
		#m[:dvWaterOutFlow][ts]
		sum(m[:dvWaterOutFlow][t, ts] for t in p.techs.existing_hydropower) # use this line next
		)
	r["water_outflow_for_all_turbines_combined"] = round.(value.(water_outflow_total).data, digits=3) 

	AnnualExistingHydropowerProd = @expression(m,
		p.hours_per_time_step * sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts] *
		p.levelization_factor[t]
			for t in p.techs.existing_hydropower, ts in p.time_steps)
	)
	r["annual_energy_produced_kwh"] = round(value(AnnualExistingHydropowerProd), digits=0) # includes curtailment
    
	spillway_water_flow = @expression(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][ts])
	r["spillway_water_outflow_cubic_meters_per_second"] = round.(value.(spillway_water_flow).data, digits = 3)

	for i in p.techs.existing_hydropower
		print("\n Saving results for turbine "*string(i))
	    r[string(i)*"_results"] = Dict([])
		water_outflow_individual = @expression(m, [ts in p.time_steps], m[:dvWaterOutFlow][i, ts])
		r[string(i)*"_results"]["water_outflow"] = round.(value.(water_outflow_individual).data, digits=3)

		individual_turbine_power_curtailment = @expression(m, [ts in p.time_steps], m[Symbol("dvCurtail")][i, ts])
		r[string(i)*"_results"]["electric_curtailed_series_kw"] = round.(value.(individual_turbine_power_curtailment), digits=3)

		individual_turbine_power_output = @expression(m, [ts in p.time_steps], (m[:dvRatedProduction][i, ts] * p.production_factor[i, ts] * p.levelization_factor[i]) - individual_turbine_power_curtailment[ts])
		r[string(i)*"_results"]["power_output_kw"] = round.(value.(individual_turbine_power_output).data, digits=3)
		r[string(i)*"_results"]["turbine_on_or_off"] = value.(m[:binTurbineActive][i,:]).data


		individual_turbine_power_to_grid = @expression(m, [ts in p.time_steps], sum(m[:dvProductionToGrid][i, u, ts] for u in p.export_bins_by_tech[i]))

		if !isempty(p.s.storage.types.elec)
			individual_turbine_power_to_batt = @expression(m, [ts in p.time_steps],
				sum(m[:dvProductionToStorage][b, i, ts] for b in p.s.storage.types.elec))
			else
				individual_turbine_power_to_batt = zeros(length(p.time_steps))
			end
		

		individual_turbine_power_to_load = @expression(m, [ts in p.time_steps], 
		(m[:dvRatedProduction][i, ts] * p.production_factor[i, ts] * p.levelization_factor[i]) - individual_turbine_power_to_batt[ts] - individual_turbine_power_to_grid[ts] - individual_turbine_power_curtailment[ts])

		r[string(i)*"_results"]["power_to_load_kw"] = round.(value.(individual_turbine_power_to_load).data, digits=3)
		r[string(i)*"_results"]["power_to_battery_kw"] = round.(value.(individual_turbine_power_to_batt).data, digits=3)
		r[string(i)*"_results"]["power_to_grid_kw"] = round.(value.(individual_turbine_power_to_grid).data, digits=3)

	end

	d["ExistingHydropower"] = r
    nothing
end

# TODO: add results for hydropower MPC