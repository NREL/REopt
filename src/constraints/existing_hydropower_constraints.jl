# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)
	@info "Adding constraints for existing hydropower"
		
	if p.s.existing_hydropower.computation_type == "quadratic1" || p.s.existing_hydropower.computation_type == "quadratic2"
		
		if p.s.existing_hydropower.computation_type == "quadratic1"
			@info "Adding quadratic1 constraint for power output, updated version"
			@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			m[:dvRatedProduction][t,ts] == 9810*0.95*0.001 * m[:dvWaterOutFlow][t,ts] * ((m[:dvWaterVolume][ts] * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept)
			)
		end
		
		if p.s.existing_hydropower.computation_type == "quadratic2"
			@info "Adding quadratic2 constraint for power output, updated version"
			@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
											 (-0.0000973*((m[:dvWaterOutFlow][t,ts])^2) + (0.0189* m[:dvWaterOutFlow][t,ts]) + 0.0358 ) *
											((m[:dvWaterVolume][ts] * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept)
			)
		end

	#elseif p.s.existing_hydropower.computation_type == "linearized_constraints"
		#TODO: add linearized constraints

	elseif p.s.existing_hydropower.computation_type == "average_power_conversion"
		# This is a simplified constraint that uses an average conversion for water flow and kW output
		@info "Adding hydropower power output constraint using the average power conversion"

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
				m[:dvRatedProduction][t,ts] == m[:dvWaterOutFlow][t,ts] * (1/p.s.existing_hydropower.average_cubic_meters_per_second_per_kw) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
			)
	else 
		throw(@error("Invalid input for the computation_type field"))
	end

	# Total water volume is between the max and min levels
	@constraint(m, [ts in p.time_steps],
		m[:dvWaterVolume][ts] <= p.s.existing_hydropower.cubic_meter_maximum
	)
	@constraint(m, [ts in p.time_steps],
		p.s.existing_hydropower.cubic_meter_minimum <= m[:dvWaterVolume][ts] 
	)

	# Water flow rate is between the maximum and minimum allowable levels
	@constraint(m, [ts in p.time_steps], # t in p.techs.existing_hydropower],
		 sum(m[:dvWaterOutFlow][t, ts] for t in p.techs.existing_hydropower) + m[:dvSpillwayWaterFlow][ts] >= p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_total_of_all_turbines   # m[:dvWaterOutFlow][t, ts]
	)
	 
	@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps], 
			m[:dvWaterOutFlow][t, ts] >=  m[:binTurbineActive][t,ts]*p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine    #p.s.existing_hydropower.existing_kw_per_turbine / (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step)
		)

	# The total water volume changes based on the water flow rates
	@constraint(m, [ts in p.time_steps[2:end]], m[:dvWaterVolume][ts] == m[:dvWaterVolume][ts-1] + ((3600/p.s.settings.time_steps_per_hour)* (p.s.existing_hydropower.water_inflow_cubic_meter_per_second[ts] - m[:dvSpillwayWaterFlow][ts] - sum(m[:dvWaterOutFlow][t,ts] for t in p.techs.existing_hydropower)))) # m[:dvWaterOutFlow][ts]) 
	@constraint(m, m[:dvWaterVolume][1] == p.s.existing_hydropower.initial_reservoir_volume) 
	
	# Total water volume must be the same in the beginning and the end
	@constraint(m, m[:dvWaterVolume][1] == m[:dvWaterVolume][maximum(p.time_steps)])

	# Total power out must be less than or equal to 
	#@constraint(m,[ts in p.time_steps, t in p.techs.existing_hydropower],
		#m[:dvHydroPowerOut][ts] == m[:dvHydroToGrid][ts] + m[:dvHydroToStorage][ts] + m[:dvHydroToLoad][ts]
	#)

	# Limit power output from the hydropower turbines to the existing kW capacity:
	@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:binTurbineActive][t,ts]*p.s.existing_hydropower.existing_kw_per_turbine)

	# Limit the water flow through the spillway, if a value was input
	if !isnothing(p.s.existing_hydropower.spillway_maximum_cubic_meter_per_second)
		@constraint(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][ts] <= p.s.existing_hydropower.spillway_maximum_cubic_meter_per_second)
	end 

	# Define the minimum operating time (in time steps) for the hydropower turbine
	
	if p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine > 1
		print("\n Adding minimum operating time constraint \n")
		@variable(m, indicator_min_operating_time[t in p.techs.existing_hydropower, ts in p.time_steps], Bin)
		@constraint(m, m[:indicator_min_operating_time]["ExistingHydropower_Turbine1", 2175] == 1)
		for t in p.techs.existing_hydropower, ts in 1:8750 #(length(p.time_steps)- p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine - 1 )
			@constraint(m, m[:indicator_min_operating_time][t, ts] => { m[:binTurbineActive][t,ts+1] + m[:binTurbineActive][t,ts+2] + m[:binTurbineActive][t,ts+3] + m[:binTurbineActive][t,ts+4] + m[:binTurbineActive][t,ts+5] >= 5 })# { sum(m[:binTurbineActive][t,ts+i] for i in 1:p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine) >= p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine} )
			@constraint(m, !m[:indicator_min_operating_time][t, ts] => { m[:binTurbineActive][t,ts+1] - m[:binTurbineActive][t,ts] <= 0  } )
		end
	end
	

	# TODO: remove this constraint that prevents a spike in the spillway use during the first time step
	@constraint(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][1] == 1)

end

