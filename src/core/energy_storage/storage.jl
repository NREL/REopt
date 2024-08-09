# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
    mutable struct StorageTypes

Used to store index sets used in decision variables and keys for accessing the various energy 
storage attributes.

Includes inner constructors for `BAUScenario`, `Scenario`, and `MPCScenario`. The constructor for the a
`Scenario` takes in a `Dict{String, AbstractStorage}`

```julia
mutable struct StorageTypes
    all::Vector{String}
    elec::Vector{String}
    thermal::Vector{String}
    hot::Vector{String}
    cold::Vector{String}
    ev::Vector{String}
end
```
"""
mutable struct StorageTypes
    all::Vector{String}
    elec::Vector{String}
    thermal::Vector{String}
    hot::Vector{String}
    cold::Vector{String}
    ev::Vector{String}

    function StorageTypes()
        new(
            String[],
            String[],
            String[],
            String[],
            String[],
            String[],
        )
    end

    function StorageTypes(d::Dict{String, AbstractStorage})
        all_storage = String[]
        elec_storage = String[]
        hot_storage = String[]
        cold_storage = String[]
        ev = String[]

        for (k,v) in d
            if v.max_kw > 0.0 && v.max_kwh > 0.0

                push!(all_storage, k)

                if typeof(v) <: AbstractElectricStorage
                    push!(elec_storage, k)
                    # EV's are of type AbstractElectricStorage too, but also electric_vehicle attribute (and "EV" in v.name)
                    if !isnothing(v.electric_vehicle)  # Alternatively could check for "EV" in v.name
                        push!(ev, k)
                    end
                elseif typeof(v) <: ThermalStorage
                    if occursin("Hot", k)
                        push!(hot_storage, k)
                    elseif occursin("Cold", k)
                        push!(cold_storage, k)
                    else
                        throw(@error("Thermal Storage not labeled as Hot or Cold."))
                    end
                end
            end
        end

        thermal_storage = union(hot_storage, cold_storage)

        new(
            all_storage,
            elec_storage,
            thermal_storage,
            hot_storage,
            cold_storage,
            ev
        )
    end
end


struct Storage
    types::StorageTypes
    attr::Dict{String, AbstractStorage}

    """
        Storage()

    Create an empty `Storage` struct. Used in `BAUScenario`.
    """
    function Storage()

        new(
            StorageTypes(),
            Dict{String, AbstractStorage}()
        )

    end

    """
        Storage(d::Dict{String, AbstractStorage})

    
    """
    function Storage(d::Dict{String, AbstractStorage})
        types = StorageTypes(d)
        new(
            types,
            d
        )
    end
end
