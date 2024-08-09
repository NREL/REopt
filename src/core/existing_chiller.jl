# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingChiller` is an optional REopt input with the following keys and default values:
```julia
    loads_kw_thermal::Vector{<:Real},
    cop::Union{Real, Nothing} = nothing,
    max_thermal_factor_on_peak_load::Real=1.25
    installed_cost_per_kw::Real = 0.0, # This is set to zero because we use absolute cost below, but still need this at zero to avoid double counting
    installed_cost_dollars::Real = 0.0  # Represents needed CapEx in BAU, assuming net present cost basis
```

!!! note "Max ExistingChiller size" 
    The maximum size [kW] of the `ExistingChiller` will be set based on the peak thermal load as follows, and
       this is really the **actual** estimated size of the existing chiller at the site:
    ```julia 
    max_kw = maximum(loads_kw_thermal) * max_thermal_factor_on_peak_load
    ```
"""
struct ExistingChiller <: AbstractThermalTech
    max_kw::Real
    cop::Union{Real, Nothing}
    max_thermal_factor_on_peak_load::Real
    installed_cost_per_kw::Real
    installed_cost_dollars::Real
end


function ExistingChiller(;
        loads_kw_thermal::Vector{<:Real},
        cop::Union{Real, Nothing} = nothing,
        max_thermal_factor_on_peak_load::Real=1.25,
        installed_cost_per_ton::Real = 0.0,
        installed_cost_dollars::Real = NaN
    )
    max_kw = maximum(loads_kw_thermal) * max_thermal_factor_on_peak_load  # This is really the **actual** size in BAU
    
    if isnan(installed_cost_dollars)
        installed_cost_per_kw = installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
        installed_cost_dollars = installed_cost_per_kw * max_kw
    else
        # This is not actually used anywhere with installed_cost_dollars being input, but needed for Struct
        installed_cost_per_kw = installed_cost_dollars / max_kw        
    end

    ExistingChiller(
        max_kw,
        cop,
        max_thermal_factor_on_peak_load,
        installed_cost_per_kw,
        installed_cost_dollars
    )
end

