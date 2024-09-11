# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
    Degradation

Inputs used when `ElectricStorage.model_degradation` is `true`:
```julia
Base.@kwdef mutable struct Degradation
    calendar_fade_coefficient::Real = 2.46E-03
    cycle_fade_coefficient::Real = 7.82E-05
    time_exponent::Real = 0.5
    installed_cost_per_kwh_declination_rate::Float64 = 0.05
    maintenance_strategy::String = "augmentation"  # one of ["augmentation", "replacement"]
    maintenance_cost_per_kwh::Vector{<:Real} = Real[]
end
```

None of the above values are required. If `ElectricStorage.model_degradation` is `true` then the 
defaults above are used.
If the `maintenance_cost_per_kwh` is not provided then it is determined using the `ElectricStorage.installed_cost_per_kwh`
and the `installed_cost_per_kwh_declination_rate` along with a present worth factor ``f`` to account for the present cost
of buying a battery in the future. The present worth factor for each day is:

``
f(day) = \\frac{ (1-r_g)^\\frac{day}{365} } { (1+r_d)^\\frac{day}{365} }
``

where ``r_g`` = `installed_cost_per_kwh_declination_rate` and ``r_d`` = `p.s.financial.owner_discount_rate_fraction`.

Note this day-specific calculation of the present-worth factor accumulates differently from the annually updated discount
rate for other net-present value calculations in REopt, and has a higher effective discount rate as a result.  The present 
worth factor is used in two different ways, depending on the `maintenance_strategy`, which is described below.

!!! warn
    When modeling degradation the following ElectricStorage inputs are not used:
    - `replace_cost_per_kw`
    - `replace_cost_per_kwh`
    - `inverter_replacement_year`
    - `battery_replacement_year`
    The are replaced by the `maintenance_cost_per_kwh` vector.

!!! note
    When providing the `maintenance_cost_per_kwh` it must have a length equal to `Financial.analysis_years*365`.


# Battery State Of Health
The state of health [`SOH`] is a linear function of the daily average state of charge [`Eavg`] and
the daily equivalent full cycles [`EFC`]. The initial `SOH` is set to the optimal battery energy capacity 
(in kWh). The evolution of the `SOH` beyond the first day is:

``
SOH[d] = SOH[d-1] - h\\left(
    \\frac{1}{2} k_{cal} Eavg[d-1] / \\sqrt{d} + k_{cyc} EFC[d-1] \\quad \\forall d \\in \\{2\\dots D\\}
\\right)
``

where:
- ``k_{cal}`` is the `calendar_fade_coefficient`
- ``k_{cyc}`` is the `cycle_fade_coefficient`
- ``h`` is the hours per time step
- ``D`` is the total number of days, 365 * `analysis_years`

The `SOH` is used to determine the maintence cost of the storage system, which depends on the `maintenance_strategy`.

# Augmentation Maintenance Strategy
The augmentation maintenance strategy assumes that the battery energy capacity is maintained by replacing
degraded cells daily in terms of cost. Using the definition of the `SOH` above the maintenance cost is:

``
C_{\\text{aug}} = \\sum_{d \\in \\{2\\dots D\\}} 0.8 C_{\\text{install}} f(day) \\left( SOH[d-1] - SOH[d] \\right)
``

where
- the ``0.8`` factor accounts for sunk costs that do not need to be paid;
- ``C_{\\text{install}}`` is the `ElectricStorage.installed_cost_per_kwh`; and
- ``SOH[d-1] - SOH[d]`` is the incremental amount of battery capacity lost in a day.


The ``C_{\\text{aug}}`` is added to the objective function to be minimized with all other costs.

# Replacement Maintenance Strategy
Modeling the replacement maintenance strategy is more complex than the augmentation strategy.
Effectively the replacement strategy says that the battery has to be replaced once the `SOH` hits 80%
of the optimal, purchased capacity. It is possible that multiple replacements could be required under
this strategy.

!!! warn
    The "replacement" maintenance strategy requires integer variables and indicator constraints.
    Not all solvers support indicator constraints and some solvers are slow with integer variables.

The replacement strategy cost is:

``
C_{\\text{repl}} = B_{\\text{kWh}} N_{\\text{repl}} f(d_{80}) C_{\\text{install}}
``

where:
- ``B_{\\text{kWh}}`` is the optimal battery capacity (`ElectricStorage.size_kwh` in the results dictionary);
- ``N_{\\text{repl}}`` is the number of battery replacments required (a function of the month in which the `SOH` reaches 80% of original capacity);
-  ``f(d_{80})`` is the present worth factor at approximately the 15th day of the month that the `SOH` reaches 80% of original capacity.

The ``C_{\\text{repl}}`` is added to the objective function to be minimized with all other costs.

# Example of inputs
The following shows how one would use the degradation model in REopt via the [Scenario](@ref) inputs:
```javascript
{
    ...
    "ElectricStorage": {
        "installed_cost_per_kwh": 390,
        ...
        "model_degradation": true,
        "degradation": {
            "calendar_fade_coefficient": 2.86E-03,
            "cycle_fade_coefficient": 6.22E-05,
            "installed_cost_per_kwh_declination_rate": 0.06,
            "maintenance_strategy": "replacement",
            ...
        }
    },
    ...
}
```
Note that not all of the above inputs are necessary. When not providing `calendar_fade_coefficient` for example the default value will be used.
"""
Base.@kwdef mutable struct Degradation
    calendar_fade_coefficient::Real = 2.46E-03
    cycle_fade_coefficient::Real = 7.82E-05
    time_exponent::Real = 0.5
    installed_cost_per_kwh_declination_rate::Real = 0.05
    maintenance_strategy::String = "augmentation"  # one of ["augmentation", "replacement"]
    maintenance_cost_per_kwh::Vector{<:Real} = Real[]
end


"""
`ElectricStorage` is an optional optional REopt input with the following keys and default values:

```julia
    min_kw::Real = 0.0
    max_kw::Real = 1.0e4
    min_kwh::Real = 0.0
    max_kwh::Real = 1.0e6
    internal_efficiency_fraction::Float64 = 0.975
    inverter_efficiency_fraction::Float64 = 0.96
    rectifier_efficiency_fraction::Float64 = 0.96
    soc_min_fraction::Float64 = 0.2
    soc_min_applies_during_outages::Bool = false
    soc_init_fraction::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Real = 910.0
    installed_cost_per_kwh::Real = 455.0
    replace_cost_per_kw::Real = 715.0
    replace_cost_per_kwh::Real = 318.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.6
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kw::Real = 0.0
    total_rebate_per_kwh::Real = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_fraction * internal_efficiency_fraction^0.5
    discharge_efficiency::Float64 = inverter_efficiency_fraction * internal_efficiency_fraction^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
    model_degradation::Bool = false
    degradation::Dict = Dict()
    minimum_avg_soc_fraction::Float64 = 0.0
    daily_leakage_fraction::Float64 = 0.0
    fixed_dispatch_series::Union{Nothing, Array{Real,1}} = nothing
    require_start_and_end_charge_to_be_equal::Bool = false
```
"""
Base.@kwdef struct ElectricStorageDefaults
    off_grid_flag::Bool = false
    min_kw::Real = 0.0
    max_kw::Real = 1.0e4
    min_kwh::Real = 0.0
    max_kwh::Real = 1.0e6
    internal_efficiency_fraction::Float64 = 0.975
    inverter_efficiency_fraction::Float64 = 0.96
    rectifier_efficiency_fraction::Float64 = 0.96
    soc_min_fraction::Float64 = 0.2
    soc_min_applies_during_outages::Bool = false
    soc_init_fraction::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Real = 910.0
    installed_cost_per_kwh::Real = 455.0
    replace_cost_per_kw::Real = 715.0
    replace_cost_per_kwh::Real = 318.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.6
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kw::Real = 0.0
    total_rebate_per_kwh::Real = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_fraction * internal_efficiency_fraction^0.5
    discharge_efficiency::Float64 = inverter_efficiency_fraction * internal_efficiency_fraction^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
    model_degradation::Bool = false
    degradation::Dict = Dict()
    minimum_avg_soc_fraction::Float64 = 0.0
    daily_leakage_fraction::Float64 = 0.0
    fixed_dispatch_series::Union{Nothing, Array{Real,1}} = nothing
    require_start_and_end_charge_to_be_equal::Bool = false
end


"""
    function ElectricStorage(d::Dict, f::Financial, settings::Settings)

Construct ElectricStorage struct from Dict with keys-val pairs from the 
REopt ElectricStorage and Financial inputs.
"""
struct ElectricStorage <: AbstractElectricStorage
    min_kw::Real
    max_kw::Real
    min_kwh::Real
    max_kwh::Real
    internal_efficiency_fraction::Float64
    inverter_efficiency_fraction::Float64
    rectifier_efficiency_fraction::Float64
    soc_min_fraction::Float64
    soc_min_applies_during_outages::Bool
    soc_init_fraction::Float64
    can_grid_charge::Bool
    installed_cost_per_kw::Real
    installed_cost_per_kwh::Real
    replace_cost_per_kw::Real
    replace_cost_per_kwh::Real
    inverter_replacement_year::Int
    battery_replacement_year::Int
    macrs_option_years::Int
    macrs_bonus_fraction::Float64
    macrs_itc_reduction::Float64
    total_itc_fraction::Float64
    total_rebate_per_kw::Real
    total_rebate_per_kwh::Real
    charge_efficiency::Float64
    discharge_efficiency::Float64
    grid_charge_efficiency::Float64
    net_present_cost_per_kw::Real
    net_present_cost_per_kwh::Real
    model_degradation::Bool
    degradation::Degradation
    minimum_avg_soc_fraction::Float64
    daily_leakage_fraction::Float64
    fixed_dispatch_series::Union{Nothing, Array{Real,1}}
    require_start_and_end_charge_to_be_equal::Bool

    function ElectricStorage(d::Dict, f::Financial)  
        s = ElectricStorageDefaults(;d...)

        if s.inverter_replacement_year >= f.analysis_years
            @warn "Battery inverter replacement costs (per_kw) will not be considered because inverter_replacement_year is greater than or equal to analysis_years."
        end

        if s.battery_replacement_year >= f.analysis_years
            @warn "Battery replacement costs (per_kwh) will not be considered because battery_replacement_year is greater than or equal to analysis_years."
        end

        net_present_cost_per_kw = effective_cost(;
            itc_basis = s.installed_cost_per_kw,
            replacement_cost = s.inverter_replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kw,
            replacement_year = s.inverter_replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction,
            rebate_per_kw = s.total_rebate_per_kw
        )
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = s.installed_cost_per_kwh,
            replacement_cost = s.battery_replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kwh,
            replacement_year = s.battery_replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction
        )

        net_present_cost_per_kwh -= s.total_rebate_per_kwh

        if haskey(d, :degradation)
            degr = Degradation(;dictkeys_tosymbols(d[:degradation])...)
        else
            degr = Degradation()
        end

        # copy the replace_costs in case we need to change them
        replace_cost_per_kw = s.replace_cost_per_kw 
        replace_cost_per_kwh = s.replace_cost_per_kwh
        if s.model_degradation
            if haskey(d, :replace_cost_per_kw) && d[:replace_cost_per_kw] != 0.0 || 
                haskey(d, :replace_cost_per_kwh) && d[:replace_cost_per_kwh] != 0.0
                @warn "Setting ElectricStorage replacement costs to zero. Using degradation.maintenance_cost_per_kwh instead."
            end
            replace_cost_per_kw = 0.0
            replace_cost_per_kwh = 0.0
        end
    
        return new(
            s.min_kw,
            s.max_kw,
            s.min_kwh,
            s.max_kwh,
            s.internal_efficiency_fraction,
            s.inverter_efficiency_fraction,
            s.rectifier_efficiency_fraction,
            s.soc_min_fraction,
            s.soc_min_applies_during_outages,
            s.soc_init_fraction,
            s.can_grid_charge,
            s.installed_cost_per_kw,
            s.installed_cost_per_kwh,
            replace_cost_per_kw,
            replace_cost_per_kwh,
            s.inverter_replacement_year,
            s.battery_replacement_year,
            s.macrs_option_years,
            s.macrs_bonus_fraction,
            s.macrs_itc_reduction,
            s.total_itc_fraction,
            s.total_rebate_per_kw,
            s.total_rebate_per_kwh,
            s.charge_efficiency,
            s.discharge_efficiency,
            s.grid_charge_efficiency,
            net_present_cost_per_kw,
            net_present_cost_per_kwh,
            s.model_degradation,
            degr,
            s.minimum_avg_soc_fraction,
            s.daily_leakage_fraction,
            s.fixed_dispatch_series,
            s.require_start_and_end_charge_to_be_equal
        )
    end
end
