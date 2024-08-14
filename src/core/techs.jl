# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
    Techs(p::REoptInputs, s::BAUScenario)

Create a `Techs` struct for the BAUInputs
"""
function Techs(p::REoptInputs, s::BAUScenario)
    pvtechs = String[pv.name for pv in s.pvs]

    all_techs = copy(pvtechs)
    elec = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    techs_no_curtail = String[]
    segmented_techs = String[]
    gentechs = String[]
    pbi_techs = String[]
    heating_techs = String[]
    cooling_techs = String[]
    boiler_techs = String[]
    chp_techs = String[]
    requiring_oper_res = String[]  
    providing_oper_res = String[]
    electric_chillers = String[]
    absorption_chillers = String[]
    steam_turbines = String[]
    techs_can_supply_steam_turbine = String[]
    electric_heaters = String[]
    techs_can_serve_space_heating = String[]
    techs_can_serve_dhw = String[]
    techs_can_serve_process_heat = String[]
    ghp_techs = String[]

    if p.s.generator.existing_kw > 0
        push!(all_techs, "Generator")
        push!(gentechs, "Generator")
        push!(elec, "Generator")
    end

    if !isnothing(s.existing_boiler)
        push!(all_techs, "ExistingBoiler")
        push!(heating_techs, "ExistingBoiler")
        push!(boiler_techs, "ExistingBoiler")
        if s.existing_boiler.can_serve_space_heating
            push!(techs_can_serve_space_heating, "ExistingBoiler")
        end
        if s.existing_boiler.can_serve_dhw
            push!(techs_can_serve_dhw, "ExistingBoiler")
        end       
        if s.existing_boiler.can_serve_process_heat
            push!(techs_can_serve_process_heat, "ExistingBoiler")
        end  
    end

    if !isnothing(s.existing_chiller)
        push!(all_techs, "ExistingChiller")
        push!(electric_chillers, "ExistingChiller")
    end

    cooling_techs = union(electric_chillers, absorption_chillers)
    fuel_burning_techs = union(gentechs, boiler_techs, chp_techs)
    thermal_techs = union(heating_techs, boiler_techs, cooling_techs)

    dc_couple_with_stor = String[pv.name for pv in s.pvs if pv.dc_coupled_with_storage]
    ac_couple_with_stor = setdiff(elec, dc_couple_with_stor)

    Techs(
        all_techs,
        elec,
        dc_couple_with_stor,
        ac_couple_with_stor,
        pvtechs,
        gentechs,
        pbi_techs,
        techs_no_curtail,
        techs_no_turndown,
        segmented_techs,
        heating_techs,
        cooling_techs,
        boiler_techs,
        fuel_burning_techs,
        thermal_techs,
        chp_techs,
        requiring_oper_res,
        providing_oper_res,
        electric_chillers,
        absorption_chillers,
        steam_turbines,
        techs_can_supply_steam_turbine,
        electric_heaters,
        techs_can_serve_space_heating,
        techs_can_serve_dhw,
        techs_can_serve_process_heat,
        ghp_techs
    )
end


"""
    Techs(s::Scenario) 

Create a `Techs` struct for the REoptInputs.
"""
function Techs(s::Scenario)
    #TODO: refactor code duplicated in Tech(s::MPCScenario)
    pvtechs = String[pv.name for pv in s.pvs]
    if length(Base.Set(pvtechs)) != length(pvtechs)
        throw(@error("PV names must be unique, got $(pvtechs)"))
    end

    all_techs = copy(pvtechs)
    elec = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    gentechs = String[]
    pbi_techs = String[]
    techs_no_curtail = String[]
    segmented_techs = String[]
    heating_techs = String[]
    cooling_techs = String[]
    boiler_techs = String[]
    chp_techs = String[]
    requiring_oper_res = String[] 
    providing_oper_res = String[]
    electric_chillers = String[]
    absorption_chillers = String[]
    steam_turbines = String[]
    techs_can_supply_steam_turbine = String[]
    electric_heaters = String[]   
    techs_can_serve_space_heating = String[]
    techs_can_serve_dhw = String[] 
    techs_can_serve_process_heat = String[]
    ghp_techs = String[]

    if s.wind.max_kw > 0
        push!(all_techs, "Wind")
        push!(elec, "Wind")
        append!(techs_no_turndown, ["Wind"])
        if s.settings.off_grid_flag
            push!(requiring_oper_res, "Wind")
            push!(providing_oper_res, "Wind")
        end
    end

    if s.generator.existing_kw + s.generator.max_kw > 0
        push!(all_techs, "Generator")
        push!(gentechs, "Generator")
        push!(elec, "Generator")
        if s.settings.off_grid_flag
            push!(providing_oper_res, "Generator")
        end
    end

    if !isnothing(s.existing_boiler)
        push!(all_techs, "ExistingBoiler")
        push!(heating_techs, "ExistingBoiler")
        push!(boiler_techs, "ExistingBoiler")
        if s.existing_boiler.can_supply_steam_turbine
            push!(techs_can_supply_steam_turbine, "ExistingBoiler")
        end   
        if s.existing_boiler.can_serve_space_heating
            push!(techs_can_serve_space_heating, "ExistingBoiler")
        end
        if s.existing_boiler.can_serve_dhw
            push!(techs_can_serve_dhw, "ExistingBoiler")
        end       
        if s.existing_boiler.can_serve_process_heat
            push!(techs_can_serve_process_heat, "ExistingBoiler")
        end   
    end

    if !isnothing(s.boiler)
        push!(all_techs, "Boiler")
        push!(heating_techs, "Boiler")
        push!(boiler_techs, "Boiler")
        if s.boiler.can_supply_steam_turbine
            push!(techs_can_supply_steam_turbine, "Boiler")
        end        
        if s.boiler.can_serve_space_heating
            push!(techs_can_serve_space_heating, "Boiler")
        end
        if s.boiler.can_serve_dhw
            push!(techs_can_serve_dhw, "Boiler")
        end
        if s.boiler.can_serve_process_heat
            push!(techs_can_serve_process_heat, "Boiler")
        end
    end
    
    if !isnothing(s.chp)
        push!(all_techs, "CHP")
        push!(elec, "CHP")
        push!(chp_techs, "CHP")
        if s.chp.can_supply_steam_turbine
            push!(techs_can_supply_steam_turbine, "CHP")
        end
        if s.chp.can_serve_space_heating
            push!(techs_can_serve_space_heating, "CHP")
        end
        if s.chp.can_serve_dhw
            push!(techs_can_serve_dhw, "CHP")
        end
        if s.chp.can_serve_process_heat
            push!(techs_can_serve_process_heat, "CHP")
        end
    end

    if !isempty(s.ghp_option_list) && !isnothing(s.ghp_option_list[1])
        #push!(all_techs, "GHP")  #TODO: refactor GHP so that it's a part of all_techs, potentially adding in things like sizes for the binary options?
        push!(heating_techs, "GHP")
        push!(cooling_techs, "GHP")
        push!(ghp_techs, "GHP")
        if any((!isnothing(ghp) && ghp.can_supply_steam_turbine) for ghp in s.ghp_option_list)
            push!(techs_can_supply_steam_turbine, "GHP")
        end
        if any(ghp.can_serve_space_heating for ghp in s.ghp_option_list)
            push!(techs_can_serve_space_heating, "GHP")
        end
        if any(ghp.can_serve_dhw for ghp in s.ghp_option_list)
            push!(techs_can_serve_dhw, "GHP")
        end
        if any(ghp.can_serve_process_heat for ghp in s.ghp_option_list)
            push!(techs_can_serve_process_heat, "GHP")
        end
    end

    if !isnothing(s.existing_chiller)
        push!(all_techs, "ExistingChiller")
        push!(cooling_techs, "ExistingChiller")
        push!(electric_chillers, "ExistingChiller")
    end

    if !isnothing(s.absorption_chiller)
        push!(all_techs, "AbsorptionChiller")
        push!(cooling_techs, "AbsorptionChiller")
        push!(absorption_chillers, "AbsorptionChiller")
    end

    if !isnothing(s.steam_turbine)
        push!(all_techs, "SteamTurbine")
        push!(elec, "SteamTurbine")
        push!(heating_techs, "SteamTurbine")
        push!(steam_turbines, "SteamTurbine")
        if s.steam_turbine.can_serve_space_heating
            push!(techs_can_serve_space_heating, "SteamTurbine")
        end
        if s.steam_turbine.can_serve_dhw
            push!(techs_can_serve_dhw, "SteamTurbine")
        end
        if s.steam_turbine.can_serve_process_heat
            push!(techs_can_serve_process_heat, "SteamTurbine")
        end
    end    

    if !isnothing(s.electric_heater)
        push!(all_techs, "ElectricHeater")
        push!(heating_techs, "ElectricHeater")
        push!(electric_heaters, "ElectricHeater")
        if s.electric_heater.can_supply_steam_turbine
            push!(techs_can_supply_steam_turbine, "ElectricHeater")
        end
        if s.electric_heater.can_serve_space_heating
            push!(techs_can_serve_space_heating, "ElectricHeater")
        end
        if s.electric_heater.can_serve_dhw
            push!(techs_can_serve_dhw, "ElectricHeater")
        end
        if s.electric_heater.can_serve_process_heat
            push!(techs_can_serve_process_heat, "ElectricHeater")
        end
    end

    if s.settings.off_grid_flag
        append!(requiring_oper_res, pvtechs)
        append!(providing_oper_res, pvtechs)
    end

    thermal_techs = union(heating_techs, boiler_techs, chp_techs, cooling_techs)
    fuel_burning_techs = union(gentechs, boiler_techs, chp_techs)

    dc_couple_with_stor = String[pv.name for pv in s.pvs if pv.dc_coupled_with_storage]
    ac_couple_with_stor = setdiff(elec, dc_couple_with_stor)

    Techs(
        all_techs,
        elec,
        dc_couple_with_stor,
        ac_couple_with_stor,
        pvtechs,
        gentechs,
        pbi_techs,
        techs_no_curtail,
        techs_no_turndown,
        segmented_techs,
        heating_techs,
        cooling_techs,
        boiler_techs,
        fuel_burning_techs,
        thermal_techs,
        chp_techs,
        requiring_oper_res, 
        providing_oper_res, 
        electric_chillers,
        absorption_chillers,
        steam_turbines,
        techs_can_supply_steam_turbine,
        electric_heaters,
        techs_can_serve_space_heating,
        techs_can_serve_dhw,
        techs_can_serve_process_heat,
        ghp_techs
    )
end


"""
    Techs(s::MPCScenario) 

Create a `Techs` struct for the MPCInputs
"""
function Techs(s::MPCScenario)
    pvtechs = String[pv.name for pv in s.pvs]
    if length(Base.Set(pvtechs)) != length(pvtechs)
        throw(@error("PV names must be unique, got $(pvtechs)"))
    end

    all_techs = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    gentechs = String[]
    if s.generator.size_kw > 0
        push!(all_techs, "Generator")
        push!(gentechs, "Generator")
    end

    Techs(
        all_techs,
        all_techs,
        String[],
        all_techs,
        pvtechs,
        gentechs,
        String[],
        String[],
        techs_no_turndown,
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[],
        String[]
    )
end