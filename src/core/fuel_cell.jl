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
`Fuel Cell` is an optional REopt input with the following keys and default values:
```julia
    min_kw = 0.0,
    max_kw = 1.0e9,
    installed_cost_per_kw = 2655,
    om_cost_per_kw = 16,
    om_cost_per_kwh = 0.0016,
    efficiency_kwh_per_kg = 15.98,
    macrs_option_years = 7,
    macrs_bonus_fraction = 0.8,
    macrs_itc_reduction = 0.5,
    federal_itc_fraction = 0.3,
    federal_rebate_per_kw = 0.0,
    state_ibi_fraction = 0.0,
    state_ibi_max = 1.0e10,
    state_rebate_per_kw = 0.0,
    state_rebate_max = 1.0e10,
    utility_ibi_fraction = 0.0,
    utility_ibi_max = 1.0e10,
    utility_rebate_per_kw = 0.0,
    utility_rebate_max = 1.0e10,
    production_incentive_per_kwh = 0.0,
    production_incentive_max_benefit = 1.0e9,
    production_incentive_years = 1,
    production_incentive_max_kw = 1.0e9,
    can_net_meter = false,
    can_wholesale = false,
    can_export_beyond_nem_limit = false,
    can_curtail= false,
    min_turn_down_fraction = 0.2
```
"""
struct FuelCell <: AbstractFuelCell
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    om_cost_per_kwh::Real
    efficiency_kwh_per_kg::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    macrs_itc_reduction::Real
    federal_itc_fraction::Real
    federal_rebate_per_kw::Real
    state_ibi_fraction::Real
    state_ibi_max::Real
    state_rebate_per_kw::Real
    state_rebate_max::Real
    utility_ibi_fraction::Real
    utility_ibi_max::Real
    utility_rebate_per_kw::Real
    utility_rebate_max::Real
    production_incentive_per_kwh::Real
    production_incentive_max_benefit::Real
    production_incentive_years::Int
    production_incentive_max_kw::Real
    can_net_meter::Bool
    can_wholesale::Bool
    can_export_beyond_nem_limit::Bool
    can_curtail::Bool
    min_turn_down_fraction::Real

    function FuelCell(;
        min_kw = 0.0,
        max_kw = 1.0e9,
        installed_cost_per_kw = 2655,
        om_cost_per_kw = 16,
        om_cost_per_kwh = 0.0016,
        efficiency_kwh_per_kg = 15.98,
        macrs_option_years = 7,
        macrs_bonus_fraction = 0.8,
        macrs_itc_reduction = 0.5,
        federal_itc_fraction = 0.3,
        federal_rebate_per_kw = 0.0,
        state_ibi_fraction = 0.0,
        state_ibi_max = 1.0e10,
        state_rebate_per_kw = 0.0,
        state_rebate_max = 1.0e10,
        utility_ibi_fraction = 0.0,
        utility_ibi_max = 1.0e10,
        utility_rebate_per_kw = 0.0,
        utility_rebate_max = 1.0e10,
        production_incentive_per_kwh = 0.0,
        production_incentive_max_benefit = 1.0e9,
        production_incentive_years = 1,
        production_incentive_max_kw = 1.0e9,
        can_net_meter = false,
        can_wholesale = false,
        can_export_beyond_nem_limit = false,
        can_curtail= false,
        min_turn_down_fraction = 0.2
        )
      
        new(
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            om_cost_per_kwh,
            efficiency_kwh_per_kg,
            macrs_option_years,
            macrs_bonus_fraction,
            macrs_itc_reduction,
            federal_itc_fraction,
            federal_rebate_per_kw,
            state_ibi_fraction,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_fraction,
            utility_ibi_max,
            utility_rebate_per_kw,
            utility_rebate_max,
            production_incentive_per_kwh,
            production_incentive_max_benefit,
            production_incentive_years,
            production_incentive_max_kw,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail,
            min_turn_down_fraction
        )
    end
end