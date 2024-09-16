struct ConcentratingSolar <: AbstractThermalTech
    min_kw::Real
    max_kw::Real
    capacity_factor_series::AbstractVector{<:Real}
    elec_consumption_factor_series::AbstractVector{<:Real}
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    om_cost_per_kwh::Real
    acres_per_kw::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    tech_type::String
    can_supply_steam_turbine::Bool
    can_serve_dhw::Bool
    can_serve_space_heating::Bool
    can_serve_process_heat::Bool
    charge_storage_only::Bool
    emissions_factor_lb_CO2_per_mmbtu::Real
    emissions_factor_lb_NOx_per_mmbtu::Real
    emissions_factor_lb_SO2_per_mmbtu::Real
    emissions_factor_lb_PM25_per_mmbtu::Real
end

"""
    ConcentratingSolar

If a user provides the `ConcentratingSolar` key then the optimal scenario has the option to purchase this new 
`ConcentratingSolar` technology to meet compatible heating loads in addition to using the `ExistingBoiler` 
to meet the heating load(s). 

```julia
function ConcentratingSolar(;
    min_mmbtu_per_hour::Real = 0.0, # Minimum thermal power size
    max_mmbtu_per_hour::Real = BIG_NUMBER, # Maximum thermal power size
    capacity_factor_series::AbstractVector{<:Real} = Float64[],  production factor
    elec_consumption_factor_series::AbstractVector{<:Real} = Float64[], electric consumption factor per kw TODO: (do we need? are we including parasitics?) 
    acres_per_kw::Real = 0, # 
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    installed_cost_per_kw::Real = 293000.0, # Thermal power-based cost
    om_cost_per_kw::Real = 2930.0, # Thermal power-based fixed O&M cost
    om_cost_per_kwh::Real = 0.0, # Thermal energy-based variable O&M cost
    tech_type::String = "natural_gas",  # "restrict_to": ["natural_gas", "landfill_bio_gas", "propane", "diesel_oil", "uranium"]
    can_supply_steam_turbine::Bool = true # If the boiler can supply steam to the steam turbine for electric production
    can_serve_dhw::Bool = true # If Boiler can supply heat to the domestic hot water load
    can_serve_space_heating::Bool = true # If Boiler can supply heat to the space heating load
    can_serve_process_heat::Bool = true # If Boiler can supply heat to the process heating load
    charge_storage_only::Bool = true # If ConcentratingSolar can only supply hot TES (i.e., cannot meet load directly)
    emissions_factor_lb_CO2_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_CO2_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_NOx_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_NOx_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_SO2_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_SO2_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_PM25_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_PM25_per_mmbtu"],fuel_type,0)
)
```
"""
function ConcentratingSolar(;
        min_kw::Real = 0.0,
        max_kw::Real = BIG_NUMBER,
        capacity_factor_series::AbstractVector{<:Real} = Float64[],
        elec_consumption_factor_series::AbstractVector{<:Real} = Float64[],
        macrs_option_years::Int = 0,
        macrs_bonus_fraction::Real = 0.0,
        installed_cost_per_kw::Union{Real,Nothing} = nothing,
        om_cost_per_kw::Union{Real,Nothing} = nothing,  #per kw per year
        om_cost_per_kwh::Union{Real,Nothing} = nothing,   #per kwh produced
        acres_per_kw::Union{Real,Nothing} = nothing,
        tech_type::Union{String,Nothing} = nothing,  # restrict to: ["ptc", "mst", "lf", "swh_evactube", "swh_flatplate"]  TODO update with Jeff's work
        can_supply_steam_turbine::Union{Bool,Nothing} = nothing,
        can_serve_dhw::Union{Bool,Nothing} = nothing,
        can_serve_space_heating::Union{Bool,Nothing} = nothing,
        can_serve_process_heat::Union{Bool,Nothing} = nothing,
        charge_storage_only::Union{Bool,Nothing} = nothing,
        emissions_factor_lb_CO2_per_mmbtu::Real = 0.0,
        emissions_factor_lb_NOx_per_mmbtu::Real = 0.0,
        emissions_factor_lb_SO2_per_mmbtu::Real = 0.0,
        emissions_factor_lb_PM25_per_mmbtu::Real = 0.0
    )

    if isnothing(tech_type)
        throw(@error("ConcentratingSolar.tech_type is a required input but not provided."))
    elseif !(tech_type in CST_TYPES)
        throw(@error("ConcentratingSolar.tech_type value is invalid."))
    if isempty(capacity_factor_series)
        throw(@error("ConcentratingSolar.capacity_factor_series is a required input when modeling a heating load which is served by the ConcentratedSolar system in the optimal case"))
    end
    if isempty(elec_consumption_factor_series)
        throw(@error("ConcentratingSolar.elec_consumption_factor_series is a required input when modeling a heating load which is served by the ConcentratedSolar system in the optimal case"))
    end

    defaults = get_cst_defaults(tech_type)

    """
    min_kw = min_mmbtu_per_hour * KWH_PER_MMBTU
    max_kw = max_mmbtu_per_hour * KWH_PER_MMBTU

    # Convert cost basis of mmbtu/mmbtu_per_hour to kwh/kw
    installed_cost_per_kw = installed_cost_per_mmbtu_per_hour / KWH_PER_MMBTU
    om_cost_per_kw = om_cost_per_mmbtu_per_hour / KWH_PER_MMBTU
    om_cost_per_kwh = om_cost_per_mmbtu / KWH_PER_MMBTU
    """

    ConcentratingSolar(
        min_kw,
        max_kw,
        capacity_factor_series,
        elec_consumption_factor_series,
        installed_cost_per_kw,
        om_cost_per_kw,
        om_cost_per_kwh,
        acres_per_kw,
        macrs_option_years,
        macrs_bonus_fraction,
        tech_type,
        can_supply_steam_turbine,
        can_serve_dhw,
        can_serve_space_heating,
        can_serve_process_heat,
        charge_storage_only,
        emissions_factor_lb_CO2_per_mmbtu,
        emissions_factor_lb_NOx_per_mmbtu,
        emissions_factor_lb_SO2_per_mmbtu,
        emissions_factor_lb_PM25_per_mmbtu
    )
end


"""
function get_cst_defaults(tech_type::String="")

Obtains defaults for the ConcnetratingSolar technology type, taken from a JSON data file. 

inputs
tech_type::String -- identifier of CST technology type

returns
cst_defaults::Dict -- Dictionary containing defaults for ConcentratingSolar technology type
"""
function get_cst_defaults(tech_type::String="")
    if !(tech_type in CST_TYPES)
        throw(@error("Invalid inputs: argument `tech_type` to function get_cst_defaults() is invalid."))
    end
    all_cst_defaults = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "cst", "cst_defaults.json"))
    return all_cst_defaults[tech_type]
end
