# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_boiler_tech_constraints(m, p; _n="")
    
    m[:TotalBoilerFuelCosts] = @expression(m, sum(p.pwf_fuel[t] *
        sum(m[:dvFuelUsage][t, ts] * p.fuel_cost_per_kwh[t][ts] for ts in p.time_steps)
        for t in p.techs.boiler)
    )

    # Constraint (1e): Total Fuel burn for Boiler
    @constraint(m, BoilerFuelTrackingCon[t in p.techs.boiler, ts in p.time_steps],
        m[:dvFuelUsage][t,ts] == p.hours_per_time_step * (
            sum(m[Symbol("dvHeatingProduction"*_n)][t,q,ts] for q in p.heating_loads) / p.boiler_efficiency[t]
        )
    )
    if "Boiler" in p.techs.boiler  # ExistingBoiler does not have om_cost_per_kwh
        m[:TotalBoilerPerUnitProdOMCosts] = @expression(m, p.third_party_factor * p.pwf_om *
            sum(p.s.boiler.om_cost_per_kwh * p.hours_per_time_step *
            m[Symbol("dvHeatingProduction"*_n)]["Boiler",q,ts] for q in p.heating_loads, ts in p.time_steps)
        )
    else
        m[:TotalBoilerPerUnitProdOMCosts] = 0.0
    end
end

function add_heating_tech_constraints(m, p; _n="")
    # Constraint (7_heating_flow): Flows to Steam turbine, waste, and turbine must be less than or equal to total production
    if !isempty(p.techs.steam_turbine)
        if !isempty(p.s.storage.types.hot)
            @constraint(m, [t in p.techs.can_supply_steam_turbine, q in p.heating_loads, ts in p.time_steps],
                sum(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] for b in p.s.storage.types.hot) + m[Symbol("dvThermalToSteamTurbine"*_n)][t,q,ts] + m[Symbol("dvProductionToWaste"*_n)][t,q,ts]  <=
                m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
            )
            if !isempty(setdiff(union(p.techs.heating, p.techs.chp),p.techs.can_supply_steam_turbine))
                @constraint(m, [t in setdiff(union(p.techs.heating,p.techs.chp),p.techs.can_supply_steam_turbine), q in p.heating_loads, ts in p.time_steps],
                    sum(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] for b in p.s.storage.types.hot) + m[Symbol("dvProductionToWaste"*_n)][t,q,ts]  <=  
                    m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
                )
            end
        else
            @constraint(m, [t in p.techs.can_supply_steam_turbine, q in p.heating_loads, ts in p.time_steps],
                m[Symbol("dvThermalToSteamTurbine"*_n)][t,q,ts] + m[Symbol("dvProductionToWaste"*_n)][t,q,ts]  <=
                m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
            )
            if !isempty(setdiff(union(p.techs.heating, p.techs.chp),p.techs.can_supply_steam_turbine))
                @constraint(m, [t in setdiff(union(p.techs.heating,p.techs.chp),p.techs.can_supply_steam_turbine), q in p.heating_loads, ts in p.time_steps],
                    m[Symbol("dvProductionToWaste"*_n)][t,q,ts]  <=  m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
                )
            end
        end
    else
        if !isempty(p.s.storage.types.hot)
            @constraint(m, [t in union(p.techs.heating, p.techs.chp), q in p.heating_loads, ts in p.time_steps],
                sum(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] for b in p.s.storage.types.hot) + m[Symbol("dvProductionToWaste"*_n)][t,q,ts]  <=
                m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
            )
        else
            @constraint(m, [t in union(p.techs.heating, p.techs.chp), q in p.heating_loads, ts in p.time_steps],
                m[Symbol("dvProductionToWaste"*_n)][t,q,ts]  <=  m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
            )
        end
    end
    
    # Constraint (7_heating_prod_size): Production limit based on size for non-electricity-producing heating techs
    if !isempty(setdiff(p.techs.heating, union(p.techs.elec, p.techs.ghp)))
        @constraint(m, [t in setdiff(p.techs.heating, union(p.techs.elec, p.techs.ghp)), ts in p.time_steps],
            sum(m[Symbol("dvHeatingProduction"*_n)][t,q,ts] for q in p.heating_loads)  <= m[Symbol("dvSize"*_n)][t] * p.heating_cf[t][ts]
        )
    end
    # Constraint (7_heating_load_compatability): Set production variables for incompatible heat loads to zero
    for t in setdiff(union(p.techs.heating, p.techs.chp), p.techs.ghp)
        if !(t in p.techs.can_serve_space_heating)
            for ts in p.time_steps
                fix(m[Symbol("dvHeatingProduction"*_n)][t,"SpaceHeating",ts], 0.0, force=true)
                fix(m[Symbol("dvProductionToWaste"*_n)][t,"SpaceHeating",ts], 0.0, force=true)
            end
        end
        if !(t in p.techs.can_serve_dhw)
            for ts in p.time_steps
                fix(m[Symbol("dvHeatingProduction"*_n)][t,"DomesticHotWater",ts], 0.0, force=true)
                fix(m[Symbol("dvProductionToWaste"*_n)][t,"DomesticHotWater",ts], 0.0, force=true)
            end
        end
        if !(t in p.techs.can_serve_process_heat)
            for ts in p.time_steps
                fix(m[Symbol("dvHeatingProduction"*_n)][t,"ProcessHeat",ts], 0.0, force=true)
                fix(m[Symbol("dvProductionToWaste"*_n)][t,"ProcessHeat",ts], 0.0, force=true)
            end
        end
    end
    
    # Enforce no waste heat for any technology that isn't both electricity- and heat-producing
    for t in setdiff(p.techs.heating, union(p.techs.elec, p.techs.ghp))
        for q in p.heating_loads
            for ts in p.time_steps
                fix(m[Symbol("dvProductionToWaste"*_n)][t,q,ts], 0.0, force=true)
            end
        end
    end
end

function add_heating_cooling_constraints(m, p; _n="")
    @constraint(m, [t in setdiff(intersect(p.techs.cooling, p.techs.heating), p.techs.ghp), ts in p.time_steps],
        sum(m[Symbol("dvHeatingProduction"*_n)][t,q,ts] for q in p.heating_loads) / p.heating_cf[t][ts] + m[Symbol("dvCoolingProduction"*_n)][t,ts] / p.cooling_cf[t][ts] <= m[Symbol("dvSize"*_n)][t]
    )
end
    

function add_ashp_force_in_constraints(m, p; _n="")
    if "ASHPSpaceHeater" in p.techs.ashp 
        if p.s.ashp.force_into_system
            for t in setdiff(p.techs.can_serve_space_heating, ["ASHPSpaceHeater"])
                for ts in p.time_steps
                    fix(m[Symbol("dvHeatingProduction"*_n)][t,"SpaceHeating",ts], 0.0, force=true)
                    fix(m[Symbol("dvProductionToWaste"*_n)][t,"SpaceHeating",ts], 0.0, force=true)
                end
            end
        elseif p.s.ashp.min_allowable_load_service_fraction > 0.0
            @constraint(m, [ts in p.time_steps],
                m[Symbol("dvHeatingProduction"*_n)]["ASHPSpaceHeater","SpaceHeating",ts] >= p.s.ashp.min_allowable_load_service_fraction * p.heating_loads_kw["SpaceHeating"][ts] * m[Symbol("binSegmentASHPSpaceHeater")][1]
            )
        end
    end

    if "ASHPSpaceHeater" in p.techs.cooling 
        if p.s.ashp.force_into_system
            for t in setdiff(p.techs.cooling, ["ASHPSpaceHeater"])
                for ts in p.time_steps
                    fix(m[Symbol("dvCoolingProduction"*_n)][t,ts], 0.0, force=true)
                end
            end
        elseif p.s.ashp.min_allowable_load_service_fraction > 0.0
            @constraint(m, [ts in p.time_steps],
                m[Symbol("dvCoolingProduction"*_n)]["ASHPSpaceHeater",ts] >= p.s.ashp.min_allowable_load_service_fraction * p.s.cooling_load.loads_kw_thermal[ts] * m[Symbol("binSegmentASHPSpaceHeater")][1]
            )
        end 
    end

    if "ASHPWaterHeater" in p.techs.ashp 
        if p.s.ashp_wh.force_into_system
            for t in setdiff(p.techs.can_serve_dhw, ["ASHPWaterHeater"])
                for ts in p.time_steps
                    fix(m[Symbol("dvHeatingProduction"*_n)][t,"DomesticHotWater",ts], 0.0, force=true)
                    fix(m[Symbol("dvProductionToWaste"*_n)][t,"DomesticHotWater",ts], 0.0, force=true)
                end
            end
        elseif p.s.ashp_wh.min_allowable_load_service_fraction > 0.0
            @constraint(m, [ts in p.time_steps],
                m[Symbol("dvHeatingProduction"*_n)]["ASHPWaterHeater","DomesticHotWater",ts] >= p.s.ashp_wh.min_allowable_load_service_fraction * p.heating_loads_kw["DomesticHotWater"][ts] * m[Symbol("binSegmentASHPWaterHeater")][1]
            )
        end
    end
end

function avoided_capex_by_ashp(m, p; _n="")
    m[:AvoidedCapexByASHP] = @expression(m,
    sum(p.avoided_capex_by_ashp_present_value[t] for t in p.techs.ashp)
    )
end

function no_existing_boiler_production(m, p; _n="")
    for ts in p.time_steps
        for q in p.heating_loads
            fix(m[Symbol("dvHeatingProduction"*_n)]["ExistingBoiler",q,ts], 0.0, force=true)
        end
    end
    fix(m[Symbol("dvSize"*_n)]["ExistingBoiler"], 0.0, force=true)
end

function add_cooling_tech_constraints(m, p; _n="")
    # Constraint (7_cooling_prod_size): Production limit based on size for boiler
    @constraint(m, [t in setdiff(p.techs.cooling, p.techs.ghp), ts in p.time_steps_with_grid],
        m[Symbol("dvCoolingProduction"*_n)][t,ts] <= m[Symbol("dvSize"*_n)][t] * p.cooling_cf[t][ts]
    )
    # The load balance for cooling is only applied to time_steps_with_grid, so make sure we don't arbitrarily show cooling production for time_steps_without_grid
    for t in setdiff(p.techs.cooling, p.techs.ghp)
        for ts in p.time_steps_without_grid
            fix(m[Symbol("dvCoolingProduction"*_n)][t, ts], 0.0, force=true)
        end
    end
end

function no_existing_chiller_production(m, p; _n="")
    for ts in p.time_steps
        fix(m[Symbol("dvCoolingProduction"*_n)]["ExistingChiller",ts], 0.0, force=true)
    end
    fix(m[Symbol("dvSize"*_n)]["ExistingChiller"], 0.0, force=true)
end
