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

function add_electric_vehicle_constraints(m, p, b; _n="")

    add_storage_size_constraints(m, p, b)

    @constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b,ts] <= m[Symbol("dvStorageEnergy"*_n)][b]
    )

    @constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts]
    )

	# Stored energy must be greater than minimum required for the next trip
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] 
        >= 
        p.s.storage.attr[b].electric_vehicle.leaving_next_time_step_soc_min[ts] * 
        p.s.storage.attr[b].electric_vehicle.energy_capacity_kwh
    )

    energy_drained_series = p.s.storage.attr[b].electric_vehicle.back_on_site_time_step_soc_drained*p.s.storage.attr[b].electric_vehicle.energy_capacity_kwh

    for ts in p.time_steps
        
        if p.s.storage.attr[b].electric_vehicle.ev_on_site_series[ts]==1
            @constraint(m,
                m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1]
                + p.hours_per_time_step*sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec)*p.s.storage.attr[b].charge_efficiency 
                + p.hours_per_time_step*m[Symbol("dvGridToStorage"*_n)][b, ts]*p.s.storage.attr[b].charge_efficiency
                + sum(p.hours_per_time_step*m[Symbol("dvStorageToEV"*_n)][b, t, ts]*(p.s.storage.attr[b].charge_efficiency*p.s.storage.attr[t].discharge_efficiency) for t in setdiff(p.s.storage.types.elec, p.s.storage.types.ev))
                - p.hours_per_time_step*m[Symbol("dvDischargeFromStorage"*_n)][b,ts]*p.s.storage.attr[b].discharge_efficiency
                + energy_drained_series[ts]
            )
        else
            @constraint(m, m[Symbol("dvStoredEnergy"*_n)][b, ts] == 0)
        end
    
        @constraint(m,
            m[Symbol("dvStoredEnergy"*_n)][b, ts] >= p.s.storage.attr[b].soc_min_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
    	)
    end
    
    for ts in p.time_steps
        @constraint(m,
            m[Symbol("dvStoredEnergy"*_n)][b, ts] 
            >= p.s.storage.attr[b].electric_vehicle.back_on_site_time_step_soc_drained[ts] * 
            p.s.storage.attr[b].electric_vehicle.energy_capacity_kwh
        )
    end

    @constraint(m, [ts in p.time_steps_without_grid], sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) == 0.0)
    @constraint(m, [ts in p.time_steps_without_grid], sum(m[Symbol("dvStorageToEV"*_n)][b, t, ts] for t in setdiff(p.s.storage.types.elec, p.s.storage.types.ev)) == 0.0)
	
	# Power to and from EV is zero when it is off-site
	for ts in p.time_steps
        if iszero(p.s.storage.attr[b].electric_vehicle.ev_on_site_series[ts])
            for t in p.techs.elec
                fix(m[Symbol("dvProductionToStorage"*_n)][b, t, ts], 0.0, force=true)
            end
            fix(m[Symbol("dvGridToStorage"*_n)][b, ts], 0.0, force=true)
            fix(m[Symbol("dvDischargeFromStorage"*_n)][b,ts], 0.0, force=true)
        end
    end

    # If not V2G force discharge from EV to zero
    # TODO make V2G/bi-directional an EV-specific input so this will apply to each EV uniquely
    if !p.s.evse.v2g
        for ts in p.time_steps
            fix(m[Symbol("dvDischargeFromStorage"*_n)][b, ts], 0.0, force=true)
        end
    end
end

function add_ev_supply_equipment_constraints(m, p; _n="")   
    # TODO Add variables in reopt.jl -> add_variables function and then reference all variables as e.g. m[Symbol("binNumEVSE"*_n)][se]
    # Currently EVs can switch EVSE every time step but there is a small cost to try avoiding this unnecessarily;
    # We still want to allow EV's to switch to let other EVs charge, for example, if there are more EVs than EVSEs
    binEVtoEVSE = [@variable(m, [1:p.s.evse.max_num[se], p.s.storage.types.ev, ts in p.time_steps], Bin) 
                                for se in eachindex(p.s.evse.power_rating_kw)]

    # Chosen # of EVSE of each type is the sum of the binary list
    if p.s.evse.force_num_to_max == true
        # Each EVSE (type!) can only have 1 EV hooked up at a given time
        @constraint(m, [se in eachindex(p.s.evse.power_rating_kw), n in 1:p.s.evse.max_num[se], ts in p.time_steps], 
            sum(binEVtoEVSE[se][n, ev, ts] for ev in p.s.storage.types.ev)
            <=
            1.0
        )

        m[:NumberEVSEChosenByType] = [p.s.evse.max_num[se] for se in eachindex(p.s.evse.power_rating_kw)]
    else
        # Decision for the number of EVSE as an index of this binary variable for each type (N of each type of charger)
        # Consider "start" (=value) argument for "warm-start"
        binNumEVSE = [@variable(m, integer=true, start=1, lower_bound=0, upper_bound=p.s.evse.max_num[se]) for se in eachindex(p.s.evse.power_rating_kw)]
        binListEVSE = [@variable(m, [1:p.s.evse.max_num[se]], Bin) for se in eachindex(p.s.evse.power_rating_kw)]
        
        # Create a binary list with 1's for up to the binNumEVSE[se] and 0's after
        # TODO this constraint could be ==, which is better/faster?
        @constraint(m, [se in eachindex(p.s.evse.power_rating_kw)],
            sum(binListEVSE[se][n] for n in 1:p.s.evse.max_num[se]) <= binNumEVSE[se]
        )
        for se in eachindex(p.s.evse.power_rating_kw)
            # The list of 1's must be consecutive starting at index 1 until binNumEVSE is reached, then zeros (can also be all zeros)
            # TODO this constraint is not needed if the above constraint uses "=="
            if p.s.evse.max_num[se] > 1
                @constraint(m, [n in 2:p.s.evse.max_num[se]],
                    binListEVSE[se][n] <= binListEVSE[se][n-1]
                )
            end
            # Each EVSE (type!) can only have 1 EV hooked up at a given time
            @constraint(m, [n in 1:p.s.evse.max_num[se], ts in p.time_steps], 
                sum(binEVtoEVSE[se][n, ev, ts] for ev in p.s.storage.types.ev) 
                <= 
                binListEVSE[se][n]
            )            
        end
        
        m[:EXPbinListEVSE] = @expression(m, [[binListEVSE[se][n] for n in 1:p.s.evse.max_num[se]] for se in eachindex(p.s.evse.power_rating_kw)])
        
        m[:NumberEVSEChosenByType] = @expression(m, [binNumEVSE[se] for se in eachindex(p.s.evse.power_rating_kw)])
    end   

    # Make sure EV is not connected to two different EVSE types at the same time which the above constraint allows
    @constraint(m, [ev in p.s.storage.types.ev, ts in p.time_steps], 
        sum(sum(binEVtoEVSE[se][n, ev, ts] for n in 1:p.s.evse.max_num[se]) for se in eachindex(p.s.evse.power_rating_kw)) 
        <= 
        1.0
    )

    # Each EV can only be hooked up to any charger if it's on-site (summing across evse_max_num[se] for efficiency)
    @constraint(m, [se in eachindex(p.s.evse.power_rating_kw), ev in p.s.storage.types.ev, ts in p.time_steps], 
        sum(binEVtoEVSE[se][n, ev, ts] for n in 1:p.s.evse.max_num[se]) <= p.s.storage.attr[ev].electric_vehicle.ev_on_site_series[ts]
    )    

	# Charger rating is greater than total charging power to each EV
	@constraint(m, [b in p.s.storage.types.ev, ts in p.time_steps],
        sum(sum(se_kw * binEVtoEVSE[se][n, b, ts] 
            for n in 1:p.s.evse.max_num[se]) 
            for (se, se_kw) in enumerate(p.s.evse.power_rating_kw))
        >=
        sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) +
        sum(m[Symbol("dvStorageToEV"*_n)][b, t, ts] for t in filter(x -> !occursin("EV", x), p.s.storage.types.elec)) + 
        m[Symbol("dvGridToStorage"*_n)][b, ts]
    )

    # V2G/V2B (Storage cannot currently export power to grid, so "B"(Building) is more appropriate)
    if p.s.evse.v2g
        @constraint(m, [b in p.s.storage.types.ev, ts in p.time_steps],
            sum(sum(se_kw * binEVtoEVSE[se][n, b, ts] 
                for n in 1:p.s.evse.max_num[se]) 
                for (se, se_kw) in enumerate(p.s.evse.power_rating_kw))*p.s.storage.attr[b].discharge_efficiency
            >=
            sum(m[Symbol("dvDischargeFromStorage"*_n)][b, ts])
        )
    end

    # EV switching cost - first find arrival and departure timesteps to zero out any switching costs there
    arrival_departure_ts = Dict([(ev, zeros(length(p.time_steps))) for ev in p.s.storage.types.ev])
    for ev in p.s.storage.types.ev
        for ts in p.time_steps[2:end]
            delta_ts = p.s.storage.attr[ev].electric_vehicle.ev_on_site_series[ts] - p.s.storage.attr[ev].electric_vehicle.ev_on_site_series[ts-1]
            if delta_ts == 1
                # Arrived on-site this ts
                arrival_departure_ts[ev][ts] = 1.0
            elseif delta_ts == -1
                # Left site this ts
                arrival_departure_ts[ev][ts] = 1.0
            end
        end
    end

    # Still "erroneously" applies a cost for an EVSE that unhooks before the timestep it leaves
    #   or an EV that hooks up after the first timestep it arrives
    #   e.g. to wait for or allow another EV to charge at that EVSE
    cost_per_switch = 1.0
    dvEVSwitching = [@variable(m, [1:p.s.evse.max_num[se], p.s.storage.types.ev, p.time_steps], start=0, Bin) for se in eachindex(p.s.evse.power_rating_kw)]
    for se in eachindex(p.s.evse.power_rating_kw)
        # Incentive for hooking up right away when EV arrives
        @constraint(m, [n in 1:p.s.evse.max_num[se], ev in p.s.storage.types.ev, ts in p.time_steps[2:end]], 
            dvEVSwitching[se][n, ev, ts]
            >= 
            (binEVtoEVSE[se][n, ev, ts] - binEVtoEVSE[se][n, ev, ts-1]) * 
            (1.0 - arrival_departure_ts[ev][ts])
        )
        # Incentive for staying hooked up until right before EV leaves
        @constraint(m, [n in 1:p.s.evse.max_num[se], ev in p.s.storage.types.ev, ts in p.time_steps[2:end]], 
            dvEVSwitching[se][n, ev, ts]
            >= 
            (binEVtoEVSE[se][n, ev, ts-1] - binEVtoEVSE[se][n, ev, ts]) * 
            (1.0 - arrival_departure_ts[ev][ts])
        )        
    end  

    m[:EVSESwitchingCost] = @expression(m, sum(sum(sum(sum(cost_per_switch * dvEVSwitching[se][n, ev, ts] 
                                                        for ts in p.time_steps)
                                                            for ev in p.s.storage.types.ev)
                                                                for n in 1:p.s.evse.max_num[se])
                                                                    for se in eachindex(p.s.evse.power_rating_kw))
    )

    m[:EXPbinEVtoEVSE] = @expression(m, [binEVtoEVSE[se] for se in eachindex(p.s.evse.power_rating_kw)])
    m[:TotalEVSEInstalledCost] = @expression(m, 
        sum(m[:NumberEVSEChosenByType][se] * p.s.evse.installed_cost[se] for se in eachindex(p.s.evse.power_rating_kw))
    )

end