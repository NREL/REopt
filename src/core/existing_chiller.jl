# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingChiller` is an optional REopt input with the following keys and default values:
```julia
    loads_kw_thermal::Vector{<:Real},
    cop::Union{Real, Nothing} = nothing,
    max_thermal_factor_on_peak_load::Real=1.25
```

!!! note "Max ExistingChiller size" 
    The maximum size [kW] of the `ExistingChiller` will be set based on the peak thermal load as follows:
    ```julia 
    max_kw = maximum(loads_kw_thermal) * max_thermal_factor_on_peak_load
    ```
"""
struct ExistingChiller <: AbstractThermalTech
    max_kw::Real
    cop::Union{Real, Nothing}
    max_thermal_factor_on_peak_load::Real
end


function ExistingChiller(;
        loads_kw_thermal::Vector{<:Real},
        cop::Union{Real, Nothing} = nothing,
        max_thermal_factor_on_peak_load::Real=1.25
    )
    max_kw = maximum(loads_kw_thermal) * max_thermal_factor_on_peak_load
    ExistingChiller(
        max_kw,
        cop,
        max_thermal_factor_on_peak_load
    )
end
