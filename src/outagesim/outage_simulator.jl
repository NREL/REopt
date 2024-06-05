# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function simulate_outage(;init_time_step, diesel_kw, fuel_available, b, m, diesel_min_turndown, batt_kwh, batt_kw,
                    batt_roundtrip_efficiency, n_time_steps, n_steps_per_hour, batt_soc_kwh, crit_load, sum_ev_kwh_t0,
                    sum_ev_total_kwh, sum_ev_kw_t0, tot_ev_rdtrp_eff, incoming_ev_kwh, incoming_max_ev_kwh, incoming_ev_kw)
    """
    Determine how long the critical load can be met with gas generator and energy storage.
    :param init_time_step: Int, initial time step
    :param diesel_kw: float, generator capacity
    :param fuel_available: float, gallons
    :param b: float, diesel fuel burn rate intercept coefficient (y = m*x + b)  [gal/hr]
    :param m: float, diesel fuel burn rate slope (y = m*x + b)  [gal/kWh]
    :param diesel_min_turndown:
    :param batt_kwh: float, battery capacity
    :param batt_kw: float, battery inverter capacity (AC rating)
    :param batt_roundtrip_efficiency:
    :param batt_soc_kwh: float, battery state of charge in kWh
    :param n_time_steps: Int, number of time steps in a year
    :param n_steps_per_hour: Int, number of time steps per hour
    :param crit_load: list of float, load after DER (PV, Wind, ...)
    :return: float, number of hours that the critical load can be met using load following
    """
    for i in 0:n_time_steps-1
        t = (init_time_step - 1 + i) % n_time_steps + 1  # for wrapping around end of year
        load_kw = crit_load[t]
        
        sum_ev_kwh_t0 += incoming_ev_kwh[i+1]
        sum_ev_kw_t0 += incoming_ev_kw[i+1]
        sum_ev_total_kwh += incoming_max_ev_kwh[i+1]

        if load_kw < 0  # load is met
            if batt_soc_kwh < batt_kwh  # charge battery if there's room in the battery
                batt_soc_kwh += minimum([
                    batt_kwh - batt_soc_kwh,     # room available
                    batt_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # inverter capacity
                    -load_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # excess energy
                ])
            elseif sum_ev_kwh_t0 < sum_ev_total_kwh
                sum_ev_kwh_t0 += minimum([
                    sum_ev_kwh_t0 - sum_ev_total_kwh,     # room available
                    sum_ev_kw_t0 / n_steps_per_hour * tot_ev_rdtrp_eff,  # inverter capacity
                    -load_kw / n_steps_per_hour * tot_ev_rdtrp_eff,  # excess energy
                ])
            else
                # no excess energy in this ts. load is positive and must be met.
                nothing
            end

        else  # check if we can meet load with generator then storage
            fuel_needed = (m * maximum([load_kw, diesel_min_turndown * diesel_kw]) + b) / n_steps_per_hour
            # (gal/kWh * kW + gal/hr) * hr = gal
            if load_kw <= diesel_kw && fuel_needed <= fuel_available  # diesel can meet load
                fuel_available -= fuel_needed
                if load_kw < diesel_min_turndown * diesel_kw  # extra generation goes to battery
                    if batt_soc_kwh < batt_kwh  # charge battery if there's room in the battery
                        batt_soc_kwh += minimum([
                            batt_kwh - batt_soc_kwh,     # room available
                            batt_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # inverter capacity
                            (diesel_min_turndown * diesel_kw - load_kw) / n_steps_per_hour * batt_roundtrip_efficiency  # excess energy
                        ])
                    elseif sum_ev_kwh_t0 < sum_ev_total_kwh
                        sum_ev_kwh_t0 += minimum([
                            sum_ev_kwh_t0 - sum_ev_total_kwh,     # room available
                            sum_ev_kw_t0[init_time_step+i] / n_steps_per_hour * tot_ev_rdtrp_eff,  # inverter capacity
                            -load_kw / n_steps_per_hour * tot_ev_rdtrp_eff,  # excess energy
                        ])
                    else
                        # no excess energy in this ts. load is positive and must be met.
                        nothing
                    end
                end
                load_kw = 0

            else  # diesel can meet part or no load
                if fuel_needed > fuel_available && load_kw <= diesel_kw  # tank is limiting factor
                    load_kw -= maximum([0, (fuel_available * n_steps_per_hour - b) / m])  # (gal/hr - gal/hr) * kWh/gal = kW
                    fuel_available = 0

                elseif fuel_needed <= fuel_available && load_kw > diesel_kw  # diesel capacity is limiting factor
                    load_kw -= diesel_kw
                    # run diesel gen at max output
                    fuel_available = maximum([0, fuel_available - (diesel_kw * m + b) / n_steps_per_hour])
                                                                # (kW * gal/kWh + gal/hr) * hr = gal
                else  # fuel_needed > fuel_available && load_kw > diesel_kw  # limited by fuel and diesel capacity
                    # run diesel at full capacity and drain tank
                    load_kw -= minimum([diesel_kw, maximum([0, (fuel_available * n_steps_per_hour - b) / m])])
                    fuel_available = 0
                end

                if minimum([batt_kw, batt_soc_kwh * n_steps_per_hour]) >= load_kw  # battery can carry balance
                    # prevent battery charge from going negative
                    batt_soc_kwh = maximum([0, batt_soc_kwh - load_kw / n_steps_per_hour])
                end

                if minimum([sum_ev_kw_t0, sum_ev_kwh_t0 * n_steps_per_hour]) >= load_kw  # ev can carry balance
                    # prevent battery charge from going negative
                    sum_ev_kwh_t0 = maximum([0, sum_ev_kwh_t0 - load_kw / n_steps_per_hour])
                    load_kw = 0
                end
            end
        end

        if round(load_kw, digits=5) > 0  # failed to meet load in this time step
            return i / n_steps_per_hour
        end
    end

    return n_time_steps / n_steps_per_hour  # met the critical load for all time steps
end


"""
    simulate_outages(;batt_kwh=0, batt_kw=0, pv_kw_ac_hourly=[], init_soc=[], critical_loads_kw=[], 
        wind_kw_ac_hourly=[], batt_roundtrip_efficiency=0.829, diesel_kw=0, fuel_available=0, b=0, m=0, 
        diesel_min_turndown=0.3
    )

Time series simulation of outages starting at every time step of the year. Used to calculate how many time steps the 
critical load can be met in every outage, which in turn is used to determine probabilities of meeting the critical load.

# Arguments
- `batt_kwh`: float, battery storage capacity
- `batt_kw`: float, battery inverter capacity
- `pv_kw_ac_hourly`: list of floats, AC production of PV system
- `init_soc`: list of floats between 0 and 1 inclusive, initial state-of-charge
- `critical_loads_kw`: list of floats
- `wind_kw_ac_hourly`: list of floats, AC production of wind turbine
- `batt_roundtrip_efficiency`: roundtrip battery efficiency
- `diesel_kw`: float, diesel generator capacity
- `fuel_available`: float, gallons of diesel fuel available
- `b`: float, diesel fuel burn rate intercept coefficient (y = m*x + b*rated_capacity)  [gal/kwh/kw]
- `m`: float, diesel fuel burn rate slope (y = m*x + b*rated_capacity)  [gal/kWh]
- `diesel_min_turndown`: minimum generator turndown in fraction of generator capacity (0 to 1)

Returns a dict
```
    "resilience_by_time_step": vector of time steps that critical load is met for outage starting in every time step,
    "resilience_hours_min": minimum of "resilience_by_time_step",
    "resilience_hours_max": maximum of "resilience_by_time_step",
    "resilience_hours_avg": average of "resilience_by_time_step",
    "outage_durations": vector of integers for outage durations with non zero probability of survival,
    "probs_of_surviving": vector of probabilities corresponding to the "outage_durations",
    "probs_of_surviving_by_month": vector of probabilities calculated on a monthly basis,
    "probs_of_surviving_by_hour_of_the_day":vector of probabilities calculated on a hour-of-the-day basis,
}
```
"""
function simulate_outages(;batt_kwh=0, batt_kw=0, pv_kw_ac_hourly=[], init_soc=[], critical_loads_kw=[], wind_kw_ac_hourly=[],
                     batt_roundtrip_efficiency=0.829, diesel_kw=0, fuel_available=0, b=0, m=0, diesel_min_turndown=0.3, ev_dict=Dict(), floater_evs=Dict()
                     )
    n_time_steps = length(critical_loads_kw)
    n_steps_per_hour = Int(n_time_steps / 8760)
    r = repeat([0.0], n_time_steps)

    if batt_kw == 0 || batt_kwh == 0
        init_soc = repeat([0], n_time_steps)  # default is 0

        @info isempty(ev_dict)

        if (isempty(pv_kw_ac_hourly) || (sum(pv_kw_ac_hourly) == 0)) && (isempty(wind_kw_ac_hourly) || (sum(wind_kw_ac_hourly) == 0)) && diesel_kw == 0 && isempty(ev_dict)
            # no pv, generator, wind, nor battery --> no resilience
            return Dict(
                "resilience_by_time_step" => r,
                "resilience_hours_min" => 0,
                "resilience_hours_max" => 0,
                "resilience_hours_avg" => 0,
                "outage_durations" => Int[],
                "probs_of_surviving" => Float64[],
            )
        end
    end

    if isempty(pv_kw_ac_hourly)
        pv_kw_ac_hourly = repeat([0], n_time_steps)
    end
    if isempty(wind_kw_ac_hourly)
        wind_kw_ac_hourly = repeat([0], n_time_steps)
    end
    load_minus_der = [ld - pv - wd for (pv, wd, ld) in zip(pv_kw_ac_hourly, wind_kw_ac_hourly, critical_loads_kw)]

    # total EV kWh available, can be discharged at max allowable discharge rate
    init_ts_ev_avail_kwh = zeros(n_time_steps)
    sum_ev_total_kwh = zeros(n_time_steps)
    max_crate_series_kw = zeros(n_time_steps)
    tot_ev_rdtrp_eff = 0.0

    if length(ev_dict) > 0
        for ev in keys(ev_dict)
            init_ts_ev_avail_kwh += ev_dict[ev]["ev_kwh_series"] # for instantaneous kWh value
            sum_ev_total_kwh += ev_dict[ev]["max_size_kwh_series"] # for instantaneous maximum kWh value
            max_crate_series_kw += ev_dict[ev]["ev_kw_series"] # for instantaneous kW value
            tot_ev_rdtrp_eff += ev_dict[ev]["roundtrip_efficiency"]
        end
    else
        nothing
    end

    tot_ev_rdtrp_eff = tot_ev_rdtrp_eff/length(ev_dict)
    floater_ev_resp = handle_floater_evs(floater_evs, n_time_steps)

    """
    Simulation starts here
    """
    # outer loop: do simulation starting at each time step
    # + floater_ev_resp["tot_ev_rdtrp_eff"],
    for time_step in 1:n_time_steps
        r[time_step] = REopt.simulate_outage(;
            init_time_step = time_step,
            diesel_kw = diesel_kw,
            fuel_available = fuel_available,
            b = b, m = m,
            diesel_min_turndown = diesel_min_turndown,
            batt_kwh = batt_kwh,
            batt_kw = batt_kw,
            batt_roundtrip_efficiency = batt_roundtrip_efficiency,
            n_time_steps = n_time_steps,
            n_steps_per_hour = n_steps_per_hour,
            batt_soc_kwh = init_soc[time_step] * batt_kwh,
            crit_load = load_minus_der,
            sum_ev_kwh_t0 = array_operation(ev_dict, "ev_kwh_series", time_step) + floater_ev_resp["sum_ev_kwh_t0"],
            sum_ev_total_kwh = array_operation(ev_dict, "max_size_kwh_series", time_step) + floater_ev_resp["sum_ev_total_kwh"],
            sum_ev_kw_t0 = array_operation(ev_dict, "ev_kw_series", time_step) + floater_ev_resp["sum_ev_kw_t0"],
            tot_ev_rdtrp_eff = array_operation(ev_dict, "roundtrip_efficiency")/length(ev_dict),
            incoming_ev_kwh = array_circshift(ev_dict, "ev_kwh_series", time_step, n_time_steps) .+ floater_ev_resp["incoming_ev_kwh"],
            incoming_max_ev_kwh = array_circshift(ev_dict, "max_size_kwh_series", time_step, n_time_steps) .+ floater_ev_resp["incoming_max_ev_kwh"],
            incoming_ev_kw = array_circshift(ev_dict, "ev_kw_series", time_step, n_time_steps) .+ floater_ev_resp["incoming_ev_kw"]
        )
    end
    results = process_results(r, n_time_steps)
    return results
end

function handle_floater_evs(floater_evs::Dict, n_time_steps)
    
    resp = Dict()
    resp["sum_ev_kwh_t0"] = 0.0
    resp["sum_ev_total_kwh"] = 0.0
    resp["sum_ev_kw_t0"] = 0.0
    resp["tot_ev_rdtrp_eff"] = 0.0
    resp["incoming_ev_kwh"] = zeros(n_time_steps)
    resp["incoming_max_ev_kwh"] = zeros(n_time_steps)
    resp["incoming_ev_kw"] = zeros(n_time_steps)

    for ev in keys(floater_evs)

        if floater_evs[ev]["arrts"] == 1
            resp["sum_ev_kwh_t0"] += floater_evs[ev]["arrsoc"]*floater_evs[ev]["kwh"]
            resp["sum_ev_total_kwh"] += floater_evs[ev]["kwh"]
            resp["sum_ev_kw_t0"] += floater_evs[ev]["kw"]
            resp["tot_ev_rdtrp_eff"] += floater_evs[ev]["eff_prob"]
        else
            resp["tot_ev_rdtrp_eff"] = floater_evs[ev]["eff_prob"]
            
            base = zeros(n_time_steps)
            
            base[floater_evs[ev]["arrts"]] = floater_evs[ev]["arrsoc"]*floater_evs[ev]["kwh"]
            resp["incoming_ev_kwh"] += copy(base)
            
            base[floater_evs[ev]["arrts"]] = floater_evs[ev]["kwh"]
            resp["incoming_max_ev_kwh"] += copy(base)
            
            base[floater_evs[ev]["arrts"]] = floater_evs[ev]["kw"]
            resp["incoming_ev_kw"] += copy(base);
        end
    end

    resp["tot_ev_rdtrp_eff"] = resp["tot_ev_rdtrp_eff"]/length(floater_evs)
    return resp
end

# sum key values across EVs for each ts of osim
function array_operation(ev_dict::Dict, key::String, ts::Int64)
    to_sum = 0
    
    for ev in keys(ev_dict)
        to_sum += ev_dict[ev][key][ts]
    end
    return to_sum
end

# determine average roundtrip efficiency of EVs
function array_operation(ev_dict::Dict, key::String)
    to_sum = 0
    
    for ev in keys(ev_dict)
        to_sum += ev_dict[ev][key]
    end
    
    return to_sum
end

# determine incoming EVs in context of moving osim timesteps.
function array_circshift(ev_dict::Dict, key::String, time_step::Int64, n_time_steps::Int64)

    vec = zeros(n_time_steps)
    
    for ev in keys(ev_dict)
        ev_vec = circshift(ev_dict[ev][key], -time_step+1)
        ev_vec[findfirst(!iszero, ev_vec)+1:end] .= 0.0

        vec += ev_vec
    end
    return vec
end

function process_results(r, n_time_steps)

    r_min = minimum(r)
    r_max = maximum(r)
    r_avg = round((float(sum(r)) / float(length(r))), digits=2)

    x_vals = collect(range(1, stop=Int(floor(r_max)+1)))
    y_vals = Array{Float64, 1}()

    for hrs in x_vals
        push!(y_vals, round(sum([h >= hrs ? 1 : 0 for h in r]) / n_time_steps, 
                            digits=4))
    end
    return Dict(
        "resilience_by_time_step" => r,
        "resilience_hours_min" => r_min,
        "resilience_hours_max" => r_max,
        "resilience_hours_avg" => r_avg,
        "outage_durations" => x_vals,
        "probs_of_surviving" => y_vals,
    )
end


"""
    simulate_outages(d::Dict, p::REoptInputs; microgrid_only::Bool=false)

Time series simulation of outages starting at every time step of the year. Used to calculate how many time steps the 
critical load can be met in every outage, which in turn is used to determine probabilities of meeting the critical load.

# Arguments
- `d`::Dict from `reopt_results`
- `p`::REoptInputs the inputs that generated the Dict from `reopt_results`
- `microgrid_only`::Bool whether or not to simulate only the optimal microgrid capacities or the total capacities. This input is only relevant when modeling multiple outages.

Returns a dict
```julia
{
    "resilience_by_time_step": vector of time steps that critical load is met for outage starting in every time step,
    "resilience_hours_min": minimum of "resilience_by_time_step",
    "resilience_hours_max": maximum of "resilience_by_time_step",
    "resilience_hours_avg": average of "resilience_by_time_step",
    "outage_durations": vector of integers for outage durations with non zero probability of survival,
    "probs_of_surviving": vector of probabilities corresponding to the "outage_durations",
    "probs_of_surviving_by_month": vector of probabilities calculated on a monthly basis,
    "probs_of_surviving_by_hour_of_the_day":vector of probabilities calculated on a hour-of-the-day basis,
}
```
"""
function simulate_outages(d::Dict, p::REoptInputs, floater_evs::Dict; microgrid_only::Bool=false)
    batt_roundtrip_efficiency = (p.s.storage.attr["ElectricStorage"].charge_efficiency *
                                p.s.storage.attr["ElectricStorage"].discharge_efficiency)

    # TODO handle generic PV names
    pv_kw_ac_hourly = zeros(length(p.time_steps))
    if "PV" in keys(d) && !(microgrid_only && !Bool(get(d["Outages"], "PV_upgraded", false)))
        pv_kw_ac_hourly = (
            get(d["PV"], "electric_to_storage_series_kw", zeros(length(p.time_steps)))
          + get(d["PV"], "electric_curtailed_series_kw", zeros(length(p.time_steps)))
          + get(d["PV"], "electric_to_load_series_kw", zeros(length(p.time_steps)))
          + get(d["PV"], "electric_to_grid_series_kw", zeros(length(p.time_steps)))
        )
    end

    wind_kw_ac_hourly = zeros(length(p.time_steps))
    if "Wind" in keys(d) && !(microgrid_only && !Bool(get(d["Outages"], "Wind_upgraded", false)))
        wind_kw_ac_hourly = (
            get(d["Wind"], "electric_to_storage_series_kw", zeros(length(p.time_steps)))
          + get(d["Wind"], "electric_curtailed_series_kw", zeros(length(p.time_steps)))
          + get(d["Wind"], "electric_to_load_series_kw", zeros(length(p.time_steps)))
          + get(d["Wind"], "electric_to_grid_series_kw", zeros(length(p.time_steps)))
        )
    end

    batt_kwh = 0
    batt_kw = 0
    init_soc = zeros(length(p.time_steps))
    if "ElectricStorage" in keys(d)
        batt_kwh = get(d["ElectricStorage"], "size_kwh", 0)
        batt_kw = get(d["ElectricStorage"], "size_kw", 0)
        init_soc = get(d["ElectricStorage"], "soc_series_fraction", zeros(length(p.time_steps)))
    end
    if microgrid_only && !Bool(get(d["Outages"], "electric_storage_microgrid_upgraded", false))
        batt_kwh = 0
        batt_kw = 0
        init_soc = zeros(length(p.time_steps))
    end

    diesel_kw = 0
    if "Generator" in keys(d)
        diesel_kw = get(d["Generator"], "size_kw", 0)
    end
    if microgrid_only
        diesel_kw = get(d["Outages"], "generator_microgrid_size_kw", 0)
    end

	fuel_slope_gal_per_kwhe, fuel_intercept_gal_per_hr = fuel_slope_and_intercept(
		electric_efficiency_full_load=p.s.generator.electric_efficiency_full_load, 
		electric_efficiency_half_load=p.s.generator.electric_efficiency_half_load,
        fuel_higher_heating_value_kwh_per_unit = p.s.generator.fuel_higher_heating_value_kwh_per_gal
	)

    # EVs will stay and charge onsite when they arrive after outage
    # We need to monitor a running sum of available EV kWh and total kW
    # in inner for loop, we take the available kWh and only add to it going forward if an EV arrives back onsite.
    ev_dict = Dict()

    for ev in p.s.storage.types.ev
        ev_dict[ev] = Dict()
        ev_dict[ev]["roundtrip_efficiency"] = p.s.storage.attr[ev].charge_efficiency*p.s.storage.attr[ev].discharge_efficiency
        ev_dict[ev]["ev_kwh_series"] = d[ev]["soc_series_fraction"].*d[ev]["size_kwh"]
        ev_dict[ev]["ev_kw_series"] = p.s.storage.attr[ev].electric_vehicle.ev_on_site_series.*d[ev]["size_kw"]
        ev_dict[ev]["max_size_kwh_series"] = p.s.storage.attr[ev].electric_vehicle.ev_on_site_series.*d[ev]["size_kwh"]
    end

    simulate_outages(;
        batt_kwh = batt_kwh, 
        batt_kw = batt_kw, 
        pv_kw_ac_hourly = pv_kw_ac_hourly,
        init_soc = init_soc, 
        critical_loads_kw = p.s.electric_load.critical_loads_kw, 
        wind_kw_ac_hourly = wind_kw_ac_hourly,
        batt_roundtrip_efficiency = batt_roundtrip_efficiency,
        diesel_kw = diesel_kw, 
        fuel_available = p.s.generator.fuel_avail_gal,
        b = fuel_intercept_gal_per_hr,
        m = fuel_slope_gal_per_kwhe, 
        diesel_min_turndown = p.s.generator.min_turn_down_fraction,
        ev_dict = ev_dict,
        floater_evs = floater_evs
    )
end
