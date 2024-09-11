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
`HydrogenStorage` is an optional REopt input with the following keys and default values:

```julia
    min_kg::Real = 0.0
    max_kg::Real = 1.0e6
    soc_min_fraction::Float64 = 0.05
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_kg::Real = 500.0
    replace_cost_per_kg::Real = 300.0
    replacement_year::Int = 25
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kg::Real = 0.0
    minimum_avg_soc_fraction::Float64 = 0.0
    soc_min_applies_during_outages::Bool = false
    daily_leakage_fraction::Float64 = 0.0
    require_start_and_end_charge_to_be_equal::Bool = true
```
"""
Base.@kwdef struct HydrogenStorageDefaults
    min_kg::Real = 0.0
    max_kg::Real = 1.0e6
    soc_min_fraction::Float64 = 0.05
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_kg::Real = 1524
    replace_cost_per_kg::Real = 300.0
    replacement_year::Int = 25
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kg::Real = 0.0
    minimum_avg_soc_fraction::Float64 = 0.0
    soc_min_applies_during_outages::Bool = false
    daily_leakage_fraction::Float64 = 0.0
    require_start_and_end_charge_to_be_equal::Bool = true
end


"""
    function HydrogenStorage(d::Dict, f::Financial, settings::Settings)

Construct HydrogenStorage struct from Dict with keys-val pairs from the 
REopt HydrogenStorage and Financial inputs.
"""
struct HydrogenStorage <: AbstractHydrogenStorage
    min_kg::Real
    max_kg::Real
    soc_min_fraction::Float64
    soc_init_fraction::Float64
    installed_cost_per_kg::Real
    replace_cost_per_kg::Real
    replacement_year::Int
    macrs_option_years::Int
    macrs_bonus_fraction::Float64
    macrs_itc_reduction::Float64
    total_itc_fraction::Float64
    total_rebate_per_kg::Real
    net_present_cost_per_kg::Real
    minimum_avg_soc_fraction::Float64
    soc_min_applies_during_outages::Bool
    daily_leakage_fraction::Float64
    require_start_and_end_charge_to_be_equal::Bool

    function HydrogenStorage(d::Dict, f::Financial)  
        s = HydrogenStorageDefaults(;d...)

        if s.replacement_year >= f.analysis_years
            @warn "Hydrogen storage tank replacement costs (per_kg) will not be considered because replacement_year >= analysis_years."
        end

        net_present_cost_per_kg = effective_cost(;
            itc_basis = s.installed_cost_per_kg,
            replacement_cost = s.replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kg,
            replacement_year = s.replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction
        )

        net_present_cost_per_kg -= s.total_rebate_per_kg
    
        return new(
            s.min_kg,
        s.max_kg,
            s.soc_min_fraction,
            s.soc_init_fraction,
            s.installed_cost_per_kg,
            s.replace_cost_per_kg,
            s.replacement_year,
            s.macrs_option_years,
            s.macrs_bonus_fraction,
            s.macrs_itc_reduction,
            s.total_itc_fraction,
            s.total_rebate_per_kg,
            net_present_cost_per_kg,
            s.minimum_avg_soc_fraction,
            s.soc_min_applies_during_outages,
            s.daily_leakage_fraction,
            s.require_start_and_end_charge_to_be_equal
        )
    end
end
