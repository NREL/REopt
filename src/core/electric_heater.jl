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

struct ElectricHeater <: AbstractThermalTech
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    om_cost_per_kwh::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    can_supply_steam_turbine::Bool
    cop_heating::Real
end


"""
ElectricHeater

If a user provides the `ElectricHeater` key then the optimal scenario has the option to purchase 
this new `ElectricHeater` to meet the heating load in addition to using the `ExistingBoiler`
 to meet the heating load. 

```julia
function ElectricHeater(;
    min_kw::Real = 0.0, # Minimum thermal power size
    max_kw::Real = BIG_NUMBER, # Maximum thermal power size
    installed_cost_per_kw::Union{Real, nothing} = nothing, # Thermal power-based cost
    om_cost_per_kw::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    om_cost_per_kwh::Union{Real, nothing} = nothing, # Thermal energy-based variable O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    can_supply_steam_turbine::Union{Bool, nothing} = nothing # If the boiler can supply steam to the steam turbine for electric production
)
```
"""
function ElectricHeater(;
        min_kw::Real = 0.0,
        max_kw::Real = BIG_NUMBER,
        installed_cost_per_kw::Union{Real, nothing} = nothing,
        om_cost_per_kw::Union{Real, nothing} = nothing,
        om_cost_per_kwh::Union{Real, nothing} = nothing,
        macrs_option_years::Int = 0,
        macrs_bonus_fraction::Real = 0.0,
        can_supply_steam_turbine::Union{Bool, nothing} = nothing,
        cop_heating::Union{Bool, nothing} = nothing
    )

    defaults = get_electric_heater_defaults()

    # populate defaults as needed
    if isnothing(installed_cost_per_kw)
        installed_cost_per_kw = defaults["installed_cost_per_kw"]
    end
    if isnothing(om_cost_per_kw)
        om_cost_per_kw = defaults["om_cost_per_kw"]
    end
    if isnothing(om_cost_per_kwh)
        om_cost_per_kwh = defaults["om_cost_per_kwh"]
    end
    if isnothing(can_supply_steam_turbine)
        can_supply_steam_turbine = defaults["can_supply_steam_turbine"]
    end
    if isnothing(cop_heating)
        cop_heating = defaults["cop_heating"]
    end

    ElectricHeater(
        min_kw,
        max_kw,
        installed_cost_per_kw,
        om_cost_per_kw,
        om_cost_per_kwh,
        macrs_option_years,
        macrs_bonus_fraction,
        can_supply_steam_turbine,
        cop_heating
    )
end

"""
function get_electric_heater_defaults()

Obtains defaults for the electric heater from a JSON data file. 

inputs
None

returns
eh_defaults::Dict -- Dictionary containing defaults for electric heater
"""
function get_electric_heater_defaults()
    eh_defaults = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "electric_heater", "electric_heater_defaults.json"))
    return eh_defaults
end