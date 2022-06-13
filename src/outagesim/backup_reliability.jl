# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met
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
Numeric = Union{Int, Float64}

"""
    transition_prob(n::Vector{Int}, n_prime::Vector{Int}, p::Numeric)

Return the probability of going from i to j generators given a failure rate of ``p`` for each i,j pair in vectors ``n`` and ``n_prime``.

Function used to create transition probabilities in Markov matrix.

# Examples
```repl-julia
julia> transition_prob([1,2,3,4], [0,1,2,3], 0.5)
4-element Vector{Float64}:
 0.5
 0.5
 0.375
 0.25
```
"""
function transition_prob(n::Vector{Int}, n_prime::Vector{Int}, p::Numeric)::Vector{Float64} 
    return binomial.(n, n_prime).*(1-p).^(n_prime).*(p).^(n-n_prime)
end


"""
    markov_matrix(N::Int, p::Numeric)

Return an ``N``+1 by ``N``+1 matrix of transition probabilities of going from n (row) to n' (column) given probability ``p``

Row n denotes starting with n-1 generators, with the first row denoting zero working generators. Column n' denots ending with n'-1 generators.

# Examples
```repl-julia
julia> markov_matrix(2, 0.1)
3×3 Matrix{Float64}:
 1.0   0.0   0.0
 0.1   0.9   0.0
 0.01  0.18  0.81
```
"""
function markov_matrix(N::Int, p::Numeric)::Matrix{Float64} 
    #Creates Markov matrix for generator transition probabilities
    M = reshape(transition_prob(repeat(0:N, outer = N + 1), repeat(0:N, inner = N+1), p), N+1, N+1)
    replace!(M, NaN => 0)
    return M
end

"""
    starting_probabilities(N::Int, OA::Numberic, FTS::Numeric)

Return a 1 by ``N``+1 by matrix (row vector) of probabilities of number of generators operationally available (``OA``) and avoiding
a Failure to Start (``FTS``)

The first element denotes no generators successfully starts and element n denotes n-1 generators start

# Arguments
- `N::Int`: the number of generators 
- `OA::Numeric`: Operational Availability. The chance that a generator will be available (not down for maintenance) at the start of the outage
- `FTS::Numeric`: Failure to Start. The chance that a generator fails to successfully start and take load.

# Examples
```repl-julia
julia> starting_probabilities(2, 0.99, 0.05)
1×3 Matrix{Float64}:
 0.00354025  0.11192  0.88454
```
"""
function starting_probabilities(N::Int, OA::Numeric, FTS::Numeric)::Matrix{Float64} 
    M = markov_matrix(N, (1-OA) + FTS*OA) 
    G = hcat(zeros(1, N), 1)
    return G * M
end

"""
    bin_battery_charge(batt_soc_kwh::Vector, num_bins::Int, batt_kwh::Numeric)

Return a vector equal to the length of ``batt_soc_kwh`` of discritized battery charge bins

The first bin denotes zero battery charge, and each additional bin has size of ``batt_kwh``/(``num_bins``-1)
Values are rounded to nearest bin.

# Examples
```repl-julia
julia>  bin_batt_soc_kwh([30, 100, 170.5, 250, 251, 1000], 11, 1000)
6-element Vector{Int64}:
  1
  2
  3
  3
  4
 11
```
"""
function bin_battery_charge(batt_soc_kwh::Vector, num_bins::Int, batt_kwh::Numeric)::Vector{Int}  
    #Bins battery into discrete portions. Zero is one of the bins. 
    bin_size = batt_kwh / (num_bins-1)
    return min.(num_bins, round.(batt_soc_kwh./bin_size).+1)
end

"""
    generator_output(num_generators::Int, gen_capacity::Numeric)

Return a vector equal to the length of ``num_generators``+1 of mazimized generator capacity given 0 to ``num_generators`` are available
"""
function generator_output(num_generators::Int, gen_capacity::Numeric)::Vector{Float64} 
    #Returns vector of maximum generator output
    return collect(0:num_generators).*gen_capacity
end


"""
    get_maximum_generation(batt_kw::Numeric, gen_capacity::Numeric, bin_size::Numeric, 
                           num_bins::Int, num_generators::Int, batt_discharge_efficiency::Numeric)

Return a matrix of maximum total system output.

Rows denote battery state of charge bin and columns denote number of available generators, with the first column denoting zero available generators.

# Arguments
- `batt_kw::Numeric`: battery inverter size
- `gen_capacity::Numeric`: maximum output from single generator. 
- `bin_size::Numeric`: size of discretized battery soc bin. is equal to batt_kwh / (num_bins - 1) 
- `num_bins::Int`: number of battery bins. 
- `num_generators::Int`: number of generators in microgrid.
- `batt_discharge_efficiency::Numeric`: batt_discharge_efficiency = battery_discharge / battery_reduction_in_soc


# Examples
```repl-julia
julia>  get_maximum_generation(1000, 750, 250, 5, 3, 1.0)
5×4 Matrix{Float64}:
    0.0   750.0  1500.0  2250.0
  250.0  1000.0  1750.0  2500.0
  500.0  1250.0  2000.0  2750.0
  750.0  1500.0  2250.0  3000.0
 1000.0  1750.0  2500.0  3250.0
```
"""
function get_maximum_generation(batt_kw::Numeric, gen_capacity::Numeric, bin_size::Numeric, 
                   num_bins::Int, num_generators::Int, batt_discharge_efficiency::Numeric)::Matrix{Float64}
    #Returns a matrix of maximum hourly generation (rows denote number of generators starting at 0, columns denote battery bin)
    N = num_generators + 1
    M = num_bins
    max_battery_discharge = zeros(M, N) 
    generator_prod = zeros(M, N)
    for i in 1:M
       max_battery_discharge[i, :] = fill(min(batt_kw, (i-1)*bin_size*batt_discharge_efficiency), N)
       generator_prod[i, :] = generator_output(num_generators, gen_capacity)
    end
    
    return generator_prod .+ max_battery_discharge
end

"""
    battery_bin_shift(excess_generation::Vector, bin_size::Numeric, batt_kw::Numeric, batt_charge_efficiency::Numeric, batt_discharge_efficiency::Numeric)

Return a vector of number of bins battery is shifted by

# Arguments
- `excess_generation::Vector`: maximum generator output minus net critical load for each number of working generators
- `bin_size::Numeric`: size of battery bin
- `batt_kw::Numeric`: inverter size
- `batt_charge_efficiency::Numeric`: batt_charge_efficiency = increase_in_soc_kwh / grid_input_kwh 
- `batt_discharge_efficiency::Numeric`: batt_discharge_efficiency = battery_discharge / battery_reduction_in_soc

"""
function battery_bin_shift(excess_generation::Vector, bin_size::Numeric, batt_kw::Numeric,
                                batt_charge_efficiency::Numeric, batt_discharge_efficiency::Numeric)::Vector{Int} 
    #Determines how many battery bins to shift by
    #Lose energy charging battery and use more energy discharging battery
    #Need to shift battery up by less and down by more.
    
    #positive excess generation 
    excess_generation[excess_generation .> 0] = excess_generation[excess_generation .> 0] .* batt_charge_efficiency
    excess_generation[excess_generation .< 0] = excess_generation[excess_generation .< 0] ./ batt_discharge_efficiency
    #Battery cannot charge or discharge more than its capacity
    excess_generation[excess_generation .> batt_kw] .= batt_kw
    excess_generation[excess_generation .< -batt_kw] .= -batt_kw
    shift = round.(excess_generation ./ bin_size)
    # shift[is.nan(shift)] = 0
    return shift
end


"""
    shift_gen_battery_prob_matrix!(gen_battery_prob_matrix::Matrix, shift_vector::Vector{Int})

Updates ``gen_battery_prob_matrix`` in place to account for change in battery state of charge bin

shifts probabiilities in column i by ``shift_vector``[i] positions, accounting for accumulation at 0 or full soc   
"""
function shift_gen_battery_prob_matrix!(gen_battery_prob_matrix::Matrix, shift_vector::Vector{Int})
    M = size(gen_battery_prob_matrix, 1)

    for i in 1:length(shift_vector) 
        s = shift_vector[i]
        if s < 0 
            gen_battery_prob_matrix[:, i] = circshift(view(gen_battery_prob_matrix, :, i), s)
            gen_battery_prob_matrix[1, i] += sum(view(gen_battery_prob_matrix, max(2,M+s):M, i))
            gen_battery_prob_matrix[max(2,M+s):M, i] .= 0
        elseif s > 0
            gen_battery_prob_matrix[:, i] = circshift(view(gen_battery_prob_matrix, :, i), s)
            gen_battery_prob_matrix[end, i] += sum(view(gen_battery_prob_matrix, 1:min(s,M-1), i))
            gen_battery_prob_matrix[1:min(s,M-1), i] .= 0
        end
    end
end

"""
    survival_over_time_gen_only(critical_load::Vector, OA::Numeric, FTS::Numeric, FTR::Numeric, num_generators::Int,
                                gen_capacity::Numeric, max_duration::Int; marginal_survival = true)::Matrix{Float64}

Return a matrix of probability of survival with rows denoting outage start and columns denoting outage duration

Solves for probability of survival given only backup generators (no battery backup). 
If ``marginal_survival`` = true then result is chance of surviving in given outage hour, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage hour.

# Arguments
- `critical_load::Vector`: 8760 vector of system critical loads. 
- `OA::Numeric`: Operational Availability of backup generators.
- `FTS::Numeric`: probability of generator Failure to Start and support load. 
- `FTR::Numeric`: hourly Failure to Run probability. FTR is 1/MTTF (mean time to failure). 
- `num_generators::Int`: number of generators in microgrid.
- `gen_capacity::Numeric`: size of generator.
- `max_duration::Int`: maximum outage duration in hours.
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage hour or probability of surviving up to and including hour.

# Examples
Given FTR = 0.2, the chance of no generators failing in 0.64 in hour 1, 0.4096 in hour 2, and 0.262144 in hour 3
Chance of 2 generators failing is 0.04 in hour 1, 0.1296 by hour 1, and 0.238144 by hour 3   
```repl-julia
julia> critical_load = [1,2,1,1]; OA = 1; FTS = 0.0; FTR = 0.2; num_generators = 2; gen_capacity = 1; max_duration = 3;

julia> survival_over_time_gen_only(critical_load, OA, FTS, FTR, num_generators, gen_capacity, max_duration; marginal_survival = true)
4×3 Matrix{Float64}:
 0.96  0.4096  0.761856
 0.64  0.8704  0.761856
 0.96  0.8704  0.761856
 0.96  0.8704  0.262144

julia> survival_over_time_gen_only(critical_load, OA, FTS, FTR, num_generators, gen_capacity, max_duration; marginal_survival = false)
4×3 Matrix{Float64}:
 0.96  0.4096  0.393216
 0.64  0.6144  0.557056
 0.96  0.8704  0.761856
 0.96  0.8704  0.262144
```
"""
                     
function survival_over_time_gen_only(critical_load::Vector, OA::Numeric, FTS::Numeric, FTR::Numeric, num_generators::Int, 
    gen_capacity::Numeric, max_duration::Int; marginal_survival = true)::Matrix{Float64} 

    t_max = length(critical_load)
    #
    generator_production = collect(0:num_generators).*gen_capacity
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_duration)
    #initialize amount of extra generation for each critical load hour and each amount of generators
    generator_markov_matrix = markov_matrix(num_generators, FTR)
  
    #Get starting generator vector
    starting_gens = starting_probabilities(num_generators, OA, FTS) #initialize gen battery prob matrix

    #start loop
    for t  = 1:t_max
        gen_probs = starting_gens
        #
        for d in 1:max_duration
            survival = ones(1, length(generator_production))
            
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            net_gen = generator_production .- critical_load[h]
            survival[net_gen .< 0] .= 0

            gen_probs *= generator_markov_matrix #Update to account for generator failures
            survival_val = gen_probs .* survival
            
            if marginal_survival == false
                gen_probs = gen_probs .* survival
            end
            
            #update expected lost load for given outage start time and outage duration
            survival_probability_matrix[t, d] = sum(survival_val)
            #Update generation battery probability matrix to account for battery shifting
        end
    end
    return survival_probability_matrix
end


"""
    survival_with_battery(net_critical_load::Vector, starting_batt_soc_kwh::Vector, OA::Numeric, FTS::Numeric, FTR::Numeric, num_generators::Int,
                          gen_capacity::Numeric, batt_kwh::Numeric, batt_kw::Numeric, num_bins::Int, max_outage_duration::Int, 
                          batt_charge_efficiency::Numeric, batt_discharge_efficiency::Numeric; marginal_survival = true)::Matrix{Float64} 

Return a matrix of probability of survival with rows denoting outage start and columns denoting outage duration

Solves for probability of survival given both networked generators and battery backup. 
If ``marginal_survival`` = true then result is chance of surviving in given outage hour, 
if ``marginal_survival`` = false then result is chance of surviving up to and including given outage hour.

# Arguments
- `net_critical_load::Vector`: 8760 vector of system critical loads minus solar generation.
- `starting_batt_soc_kwh::Vector`: 8760 vector of battery charge (kwh) for each hour of year. 
- `OA::Numeric`: Operational Availability of backup generators.
- `FTS::Numeric`: probability of generator Failure to Start and support load. 
- `FTR::Numeric`: hourly Failure to Run probability. FTR is 1/MTTF (mean time to failure). 
- `num_generators::Int`: number of generators in microgrid.
- `gen_capacity::Numeric`: size of generator.
- `batt_kwh::Numeric`: energy capacity of battery system.
- `batt_kw::Numeric`: battery system inverter size.
- `num_bins::Int`: number of battery bins. 
- `max_outage_duration::Int`: maximum outage duration in hours.
- `batt_charge_efficiency::Numeric`: batt_charge_efficiency = increase_in_soc_kwh / grid_input_kwh 
- `batt_discharge_efficiency::Numeric`: batt_discharge_efficiency = battery_discharge / battery_reduction_in_soc
- `marginal_survival::Bool`: indicates whether results are probability of survival in given outage hour or probability of surviving up to and including hour.

# Examples
Given FTR = 0.2, the chance of no generators failing in 0.64 in hour 1, 0.4096 in hour 2, and 0.262144 in hour 3
Chance of 2 generators failing is 0.04 in hour 1, 0.1296 by hour 1, and 0.238144 by hour 3   
```repl-julia
julia> net_critical_load = [1,2,2,1]; starting_batt_soc_kwh = [1,1,1,1];  max_outage_duration = 3;
julia> num_generators = 2; gen_capacity = 1; OA = 1; FTS = 0.0; FTR = 0.2;
julia> num_bins = 3; batt_kwh = 2; batt_kw = 1;  batt_charge_efficiency = 1; batt_discharge_efficiency = 1;

julia> survival_with_battery(net_critical_load, starting_batt_soc_kwh, OA, FTS, FTR, num_generators, gen_capacity, batt_kwh, 
       batt_kw, num_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency; marginal_survival = true)
4×3 Matrix{Float64}:
1.0   0.8704  0.393216
0.96  0.6144  0.77824
0.96  0.896   0.8192
1.0   0.96    0.761856

julia> survival_with_battery(net_critical_load, starting_batt_soc_kwh, OA, FTS, FTR, num_generators, gen_capacity, batt_kwh, 
       batt_kw, num_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency; marginal_survival = false)
4×3 Matrix{Float64}:
1.0   0.8704  0.393216
0.96  0.6144  0.57344
0.96  0.896   0.8192
1.0   0.96    0.761856
```
"""
function survival_with_battery(net_critical_load::Vector, starting_batt_soc_kwh::Vector, OA::Numeric, FTS::Numeric, FTR::Numeric, num_generators::Int,
                               gen_capacity::Numeric, batt_kwh::Numeric, batt_kw::Numeric, num_bins::Int, max_outage_duration::Int, batt_charge_efficiency::Numeric,
                               batt_discharge_efficiency::Numeric; marginal_survival = true)::Matrix{Float64} 

    t_max = length(net_critical_load)
    
    #bin size is battery storage divided by num bins-1 because zero is also a bin
    bin_size = batt_kwh / (num_bins-1)
     
    #bin initial battery 
    starting_battery_bins = bin_battery_charge(starting_batt_soc_kwh, num_bins, batt_kwh) 
    #For easier indice reading
    M = num_bins
    N = num_generators + 1
    #Initialize lost load matrix
    survival_probability_matrix = zeros(t_max, max_outage_duration) 
    #initialize vectors and matrices
    generator_markov_matrix = markov_matrix(num_generators, FTR) 
    gen_prod = generator_output(num_generators, gen_capacity)
    maximum_generation = get_maximum_generation(batt_kw, gen_capacity, bin_size, num_bins, num_generators, batt_discharge_efficiency)
    starting_gens = starting_probabilities(num_generators, OA, FTS) 

    #loop through outage time
    tme = time()
    for t = 1:t_max
        gen_battery_prob_matrix = zeros(M, N)
        gen_battery_prob_matrix[starting_battery_bins[t], :] = starting_gens
        
        #loop through outage duration
        for d in 1:max_outage_duration 
            survival = ones(M, N)
            h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year
            
            excess_generation = gen_prod .- net_critical_load[h]
            max_net_generation = maximum_generation .- net_critical_load[h]

            #System fails if net generation is always negative (cannot meet load)
            survival[max_net_generation .< 0, ] .= 0

            #Update probabilities to account for generator failures
            # time_vals["generator_shift"] += @elapsed account_for_generator_failures!(gen_battery_prob_matrix, generator_markov_matrix)
            gen_battery_prob_matrix *= generator_markov_matrix 
            # account_for_generator_failures!(gen_battery_prob_matrix, generator_markov_matrix)

            #Update survival probabilities
            survival_chance = gen_battery_prob_matrix .* survival

            #If marginal survival is false then remove probabilities which did not meet load
            if marginal_survival == false
                gen_battery_prob_matrix = gen_battery_prob_matrix .* survival
            end
            #update expected lost load for given outage start time and outage duration
            survival_probability_matrix[t, d] = sum(survival_chance)
            #Update generation battery probability matrix to account for battery shifting
            shift_gen_battery_prob_matrix!(gen_battery_prob_matrix, battery_bin_shift(excess_generation, bin_size, batt_kw, batt_charge_efficiency, batt_discharge_efficiency))
        end
    end
    return survival_probability_matrix
end


# function get_net_critical_load(critical_load, solar_pv, chp_kw)::Vector{Float64}
#     return (critical_load .- solar_pv) .- chp_kw
# end


#_____________________________________________________________________________________________________________________
#_____________________________________________________________________________________________________________________
#_____________________________________________________________________________________________________________________

function return_backup_reliability(d::Dict, p::REoptInputs)
    #TODO add microgrid_only boolian to scenario
    # microgrid_only = p.s.microgrid_only

    microgrid_only = false

    pv_kw_ac_hourly = zeros(length(p.time_steps))
    if "PV" in keys(d)
        pv_kw_ac_hourly = (
            get(d["PV"], "year_one_to_battery_series_kw", zeros(length(p.time_steps)))
            + get(d["PV"], "year_one_curtailed_production_series_kw", zeros(length(p.time_steps)))
            + get(d["PV"], "year_one_to_load_series_kw", zeros(length(p.time_steps)))
            + get(d["PV"], "year_one_to_grid_series_kw", zeros(length(p.time_steps)))
        )
    end
    if microgrid_only && !Bool(get(d, "PV_upgraded", false))
        pv_kw_ac_hourly = zeros(length(p.time_steps))
    end

    batt_kwh = 0
    batt_kw = 0
    init_soc = []
    if "Storage" in keys(d)
        #TODO change to throw error if multiple storage types
        for b in p.s.storage.types.elec
            batt_charge_efficiency = p.s.storage.attr[b].charge_efficiency
            batt_discharge_efficiency = p.s.storage.attr[b].discharge_efficiency
        end
            
        batt_kwh = get(d["Storage"], "size_kwh", 0)
        batt_kw = get(d["Storage"], "size_kw", 0)
        init_soc = get(d["Storage"], "year_one_soc_series_pct", [])
        starting_batt_soc_kwh = init_soc .* batt_kwh
    end
    if microgrid_only && !Bool(get(d, "storage_upgraded", false))
        batt_kwh = 0
        batt_kw = 0
        init_soc = []
    end

    diesel_kw = 0
    if "Generator" in keys(d)
        diesel_kw = get(d["Generator"], "size_kw", 0)
    end
    if microgrid_only
        diesel_kw = get(d, "Generator_mg_kw", 0)
    end

    #Add backup reliability values
    max_outage_duration = p.s.backup_reliability.max_outage_duration

    if max_outage_duration == 0
        return [] #TODO add zero results
    end
    

    #If gen capacity is 0 then base on diesel_kw
    #If num_gens is zero then either set to 1 or base on ceiling(diesel_kw / gen_capacity)
    gen_oa = p.s.backup_reliability.gen_oa
    gen_fts = p.s.backup_reliability.gen_fts
    gen_ftr = p.s.backup_reliability.gen_ftr
    num_gens = p.s.backup_reliability.num_gens
    gen_capacity = p.s.backup_reliability.gen_capacity
    num_battery_bins = p.s.backup_reliability.num_battery_bins
    microgrid_only = p.s.backup_reliability.microgrid_only
    if gen_capacity < 0.1
        if num_gens <= 1
            gen_capacity = diesel_kw
            num_gens = 1
        else
            gen_capacity = diesel_kw / num_gens
        end
    elseif num_gens == 0
        num_gens = ceil(Int, diesel_kw / gen_capacity)
    end
    
    #No reliability calculations if no generators
    if gen_capacity < 0.1
        return []
    elseif batt_kw < 0.1
        critical_loads_kw = p.s.electric_load.critical_loads_kw
        return [survival_over_time_gen_only(critical_loads_kw, gen_oa, gen_fts, gen_ftr, num_gens, gen_capacity, max_outage_duration, marginal_survival = true),
                survival_over_time_gen_only(critical_loads_kw, gen_oa, gen_fts, gen_ftr, num_gens, gen_capacity, max_outage_duration, marginal_survival = false)]

    else
        net_critical_loads_kw = p.s.electric_load.critical_loads_kw .- pv_kw_ac_hourly
        return [survival_with_battery(net_critical_loads_kw, starting_batt_soc_kwh, gen_oa, gen_fts, gen_ftr, num_gens, gen_capacity, batt_kwh, batt_kw,
                                        num_battery_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency, marginal_survival = true),
                survival_with_battery(net_critical_loads_kw, starting_batt_soc_kwh, gen_oa, gen_fts, gen_ftr, num_gens, gen_capacity, batt_kwh, batt_kw,
                                        num_battery_bins, max_outage_duration, batt_charge_efficiency, batt_discharge_efficiency, marginal_survival = false)] 

    end



end


function process_reliability_results(results, n_timeseteps, max_outage_duration)
    if results == []
        marginal_duration_means = zeros(max_outage_duration)
        marginal_duration_mins = zeros(max_outage_duration)
        marginal_final_resilience = zeros(n_timeseteps)
        cumulative_duration_means = zeros(max_outage_duration)
        cumulative_duration_mins = zeros(max_outage_duration)
        cumulative_final_resilience = zeros(n_timeseteps)
    else
        marginal_results = results[1]
        cumulative_results = results[2]
        marginal_duration_means = mean(marginal_results, dims = 1)
        marginal_duration_mins = minimum(marginal_results, dims = 1)
        marginal_final_resilience = marginal_results[:, max_outage_duration]
        cumulative_duration_means = mean(cumulative_results, dims = 1)
        cumulative_duration_mins = minimum(cumulative_results, dims = 1)
        cumulative_final_resilience = cumulative_results[:, max_outage_duration]
    end

    return Dict(
        "marginal_duration_means" => marginal_duration_means,
        "marginal_duration_mins" => marginal_duration_mins,
        "marginal_final_resilience" => marginal_final_resilience,
        "cumulative_duration_means" => cumulative_duration_means,
        "cumulative_duration_mins" => cumulative_duration_mins,
        "cumulative_final_resilience" => cumulative_final_resilience
    )
end


#TODO allow for multiple generator types
# function backup_reliability(d::Dict, p::REoptInputs)
#     results = return_backup_reliability(d::Dict, p::REoptInputs)
#     return process_reliability_results(results, length(p.time_steps), p.s.backup_reliability.max_outage_duration)
# end


# function simulate_outage(;init_time_step, diesel_kw, fuel_available, b, m, diesel_min_turndown, batt_kwh, batt_kw,
#                     batt_roundtrip_efficiency, n_timesteps, n_steps_per_hour, batt_soc_kwh, crit_load)
#     """
#     Determine how long the critical load can be met with gas generator and energy storage.
#     :param init_time_step: Int, initial time step
#     :param diesel_kw: float, generator capacity
#     :param fuel_available: float, gallons
#     :param b: float, diesel fuel burn rate intercept coefficient (y = m*x + b)  [gal/hr]
#     :param m: float, diesel fuel burn rate slope (y = m*x + b)  [gal/kWh]
#     :param diesel_min_turndown:
#     :param batt_kwh: float, battery capacity
#     :param batt_kw: float, battery inverter capacity (AC rating)
#     :param batt_roundtrip_efficiency:
#     :param batt_soc_kwh: float, battery state of charge in kWh
#     :param n_timesteps: Int, number of time steps in a year
#     :param n_steps_per_hour: Int, number of time steps per hour
#     :param crit_load: list of float, load after DER (PV, Wind, ...)
#     :return: float, number of hours that the critical load can be met using load following
#     """
#     for i in 0:n_timesteps-1
#         t = (init_time_step - 1 + i) % n_timesteps + 1  # for wrapping around end of year
#         load_kw = crit_load[t]

#         if load_kw < 0  # load is met
#             if batt_soc_kwh < batt_kwh  # charge battery if there's room in the battery
#                 batt_soc_kwh += minimum([
#                     batt_kwh - batt_soc_kwh,     # room available
#                     batt_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # inverter capacity
#                     -load_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # excess energy
#                 ])
#             end

#         else  # check if we can meet load with generator then storage
#             fuel_needed = (m * maximum([load_kw, diesel_min_turndown * diesel_kw]) + b) / n_steps_per_hour
#             # (gal/kWh * kW + gal/hr) * hr = gal
#             if load_kw <= diesel_kw && fuel_needed <= fuel_available  # diesel can meet load
#                 fuel_available -= fuel_needed
#                 if load_kw < diesel_min_turndown * diesel_kw  # extra generation goes to battery
#                     if batt_soc_kwh < batt_kwh  # charge battery if there's room in the battery
#                         batt_soc_kwh += minimum([
#                             batt_kwh - batt_soc_kwh,     # room available
#                             batt_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # inverter capacity
#                             (diesel_min_turndown * diesel_kw - load_kw) / n_steps_per_hour * batt_roundtrip_efficiency  # excess energy
#                         ])
#                     end
#                 end
#                 load_kw = 0

#             else  # diesel can meet part or no load
#                 if fuel_needed > fuel_available && load_kw <= diesel_kw  # tank is limiting factor
#                     load_kw -= maximum([0, (fuel_available * n_steps_per_hour - b) / m])  # (gal/hr - gal/hr) * kWh/gal = kW
#                     fuel_available = 0

#                 elseif fuel_needed <= fuel_available && load_kw > diesel_kw  # diesel capacity is limiting factor
#                     load_kw -= diesel_kw
#                     # run diesel gen at max output
#                     fuel_available = maximum([0, fuel_available - (diesel_kw * m + b) / n_steps_per_hour])
#                                                                 # (kW * gal/kWh + gal/hr) * hr = gal
#                 else  # fuel_needed > fuel_available && load_kw > diesel_kw  # limited by fuel and diesel capacity
#                     # run diesel at full capacity and drain tank
#                     load_kw -= minimum([diesel_kw, maximum([0, (fuel_available * n_steps_per_hour - b) / m])])
#                     fuel_available = 0
#                 end

#                 if minimum([batt_kw, batt_soc_kwh * n_steps_per_hour]) >= load_kw  # battery can carry balance
#                     # prevent battery charge from going negative
#                     batt_soc_kwh = maximum([0, batt_soc_kwh - load_kw / n_steps_per_hour])
#                     load_kw = 0
#                 end
#             end
#         end

#         if round(load_kw, digits=5) > 0  # failed to meet load in this time step
#             return i / n_steps_per_hour
#         end
#     end

#     return n_timesteps / n_steps_per_hour  # met the critical load for all time steps
# end


# """
#     simulate_outages(;batt_kwh=0, batt_kw=0, pv_kw_ac_hourly=[], init_soc=[], critical_loads_kw=[], 
#         wind_kw_ac_hourly=[], batt_roundtrip_efficiency=0.829, diesel_kw=0, fuel_available=0, b=0, m=0, 
#         diesel_min_turndown=0.3
#     )

# Time series simulation of outages starting at every time step of the year. Used to calculate how many time steps the 
# critical load can be met in every outage, which in turn is used to determine probabilities of meeting the critical load.

# # Arguments
# - `batt_kwh`: float, battery storage capacity
# - `batt_kw`: float, battery inverter capacity
# - `pv_kw_ac_hourly`: list of floats, AC production of PV system
# - `init_soc`: list of floats between 0 and 1 inclusive, initial state-of-charge
# - `critical_loads_kw`: list of floats
# - `wind_kw_ac_hourly`: list of floats, AC production of wind turbine
# - `batt_roundtrip_efficiency`: roundtrip battery efficiency
# - `diesel_kw`: float, diesel generator capacity
# - `fuel_available`: float, gallons of diesel fuel available
# - `b`: float, diesel fuel burn rate intercept coefficient (y = m*x + b*rated_capacity)  [gal/kwh/kw]
# - `m`: float, diesel fuel burn rate slope (y = m*x + b*rated_capacity)  [gal/kWh]
# - `diesel_min_turndown`: minimum generator turndown in fraction of generator capacity (0 to 1)

# Returns a dict
# ```
#     "resilience_by_timestep": vector of time steps that critical load is met for outage starting in every time step,
#     "resilience_hours_min": minimum of "resilience_by_timestep",
#     "resilience_hours_max": maximum of "resilience_by_timestep",
#     "resilience_hours_avg": average of "resilience_by_timestep",
#     "outage_durations": vector of integers for outage durations with non zero probability of survival,
#     "probs_of_surviving": vector of probabilities corresponding to the "outage_durations",
#     "probs_of_surviving_by_month": vector of probabilities calculated on a monthly basis,
#     "probs_of_surviving_by_hour_of_the_day":vector of probabilities calculated on a hour-of-the-day basis,
# }
# ```
# """
# function simulate_outages(;batt_kwh=0, batt_kw=0, pv_kw_ac_hourly=[], init_soc=[], critical_loads_kw=[], wind_kw_ac_hourly=[],
#                      batt_roundtrip_efficiency=0.829, diesel_kw=0, fuel_available=0, b=0, m=0, diesel_min_turndown=0.3,
#                      )
#     n_timesteps = length(critical_loads_kw)
#     n_steps_per_hour = Int(n_timesteps / 8760)
#     r = repeat([0], n_timesteps)

#     if batt_kw == 0 || batt_kwh == 0
#         init_soc = repeat([0], n_timesteps)  # default is 0

#         if (isempty(pv_kw_ac_hourly) || (sum(pv_kw_ac_hourly) == 0)) && diesel_kw == 0
#             # no pv, generator, nor battery --> no resilience
#             return Dict(
#                 "resilience_by_timestep" => r,
#                 "resilience_hours_min" => 0,
#                 "resilience_hours_max" => 0,
#                 "resilience_hours_avg" => 0,
#                 "outage_durations" => Int[],
#                 "probs_of_surviving" => Float64[],
#             )
#         end
#     end

#     if isempty(pv_kw_ac_hourly)
#         pv_kw_ac_hourly = repeat([0], n_timesteps)
#     end
#     if isempty(wind_kw_ac_hourly)
#         wind_kw_ac_hourly = repeat([0], n_timesteps)
#     end
#     load_minus_der = [ld - pv - wd for (pv, wd, ld) in zip(pv_kw_ac_hourly, wind_kw_ac_hourly, critical_loads_kw)]
#     """
#     Simulation starts here
#     """
#     # outer loop: do simulation starting at each time step
    
#     for time_step in 1:n_timesteps
#         r[time_step] = simulate_outage(;
#             init_time_step = time_step,
#             diesel_kw = diesel_kw,
#             fuel_available = fuel_available,
#             b = b, m = m,
#             diesel_min_turndown = diesel_min_turndown,
#             batt_kwh = batt_kwh,
#             batt_kw = batt_kw,
#             batt_roundtrip_efficiency = batt_roundtrip_efficiency,
#             n_timesteps = n_timesteps,
#             n_steps_per_hour = n_steps_per_hour,
#             batt_soc_kwh = init_soc[time_step] * batt_kwh,
#             crit_load = load_minus_der
#         )
#     end
#     results = process_results(r, n_timesteps)
#     return results
# end


# function process_results(r, n_timesteps)

#     r_min = minimum(r)
#     r_max = maximum(r)
#     r_avg = round((float(sum(r)) / float(length(r))), digits=2)

#     x_vals = collect(range(1, stop=Int(floor(r_max)+1)))
#     y_vals = Array{Float64, 1}()

#     for hrs in x_vals
#         push!(y_vals, round(sum([h >= hrs ? 1 : 0 for h in r]) / n_timesteps, 
#                             digits=4))
#     end
#     return Dict(
#         "resilience_by_timestep" => r,
#         "resilience_hours_min" => r_min,
#         "resilience_hours_max" => r_max,
#         "resilience_hours_avg" => r_avg,
#         "outage_durations" => x_vals,
#         "probs_of_surviving" => y_vals,
#     )
# end


# """
#     simulate_outages(d::Dict, p::REoptInputs; microgrid_only::Bool=false)

# Time series simulation of outages starting at every time step of the year. Used to calculate how many time steps the 
# critical load can be met in every outage, which in turn is used to determine probabilities of meeting the critical load.

# # Arguments
# - `d`::Dict from `reopt_results`
# - `p`::REoptInputs the inputs that generated the Dict from `reopt_results`
# - `microgrid_only`::Bool whether or not to simulate only the optimal microgrid capacities or the total capacities. This input is only relevant when modeling multiple outages.

# Returns a dict
# ```julia
# {
#     "resilience_by_timestep": vector of time steps that critical load is met for outage starting in every time step,
#     "resilience_hours_min": minimum of "resilience_by_timestep",
#     "resilience_hours_max": maximum of "resilience_by_timestep",
#     "resilience_hours_avg": average of "resilience_by_timestep",
#     "outage_durations": vector of integers for outage durations with non zero probability of survival,
#     "probs_of_surviving": vector of probabilities corresponding to the "outage_durations",
#     "probs_of_surviving_by_month": vector of probabilities calculated on a monthly basis,
#     "probs_of_surviving_by_hour_of_the_day":vector of probabilities calculated on a hour-of-the-day basis,
# }
# ```
# """
# function simulate_outages(d::Dict, p::REoptInputs; microgrid_only::Bool=false)
#     batt_roundtrip_efficiency = p.s.storage.charge_efficiency[:elec] * 
#                                 p.s.storage.discharge_efficiency[:elec]

#     # TODO handle generic PV names
#     pv_kw_ac_hourly = zeros(length(p.time_steps))
#     if "PV" in keys(d)
#         pv_kw_ac_hourly = (
#             get(d["PV"], "year_one_to_battery_series_kw", zeros(length(p.time_steps)))
#           + get(d["PV"], "year_one_curtailed_production_series_kw", zeros(length(p.time_steps)))
#           + get(d["PV"], "year_one_to_load_series_kw", zeros(length(p.time_steps)))
#           + get(d["PV"], "year_one_to_grid_series_kw", zeros(length(p.time_steps)))
#         )
#     end
#     if microgrid_only && !Bool(get(d, "PV_upgraded", false))
#         pv_kw_ac_hourly = zeros(length(p.time_steps))
#     end

#     batt_kwh = 0
#     batt_kw = 0
#     init_soc = []
#     if "Storage" in keys(d)
#         batt_kwh = get(d["Storage"], "size_kwh", 0)
#         batt_kw = get(d["Storage"], "size_kw", 0)
#         init_soc = get(d["Storage"], "year_one_soc_series_pct", [])
#     end
#     if microgrid_only && !Bool(get(d, "storage_upgraded", false))
#         batt_kwh = 0
#         batt_kw = 0
#         init_soc = []
#     end

#     diesel_kw = 0
#     if "Generator" in keys(d)
#         diesel_kw = get(d["Generator"], "size_kw", 0)
#     end
#     if microgrid_only
#         diesel_kw = get(d, "Generator_mg_kw", 0)
#     end

#     simulate_outages(;
#         batt_kwh = batt_kwh, 
#         batt_kw = batt_kw, 
#         pv_kw_ac_hourly = pv_kw_ac_hourly,
#         init_soc = init_soc, 
#         critical_loads_kw = p.s.electric_load.critical_loads_kw, 
#         wind_kw_ac_hourly = [],
#         batt_roundtrip_efficiency = batt_roundtrip_efficiency,
#         diesel_kw = diesel_kw, 
#         fuel_available = p.s.generator.fuel_avail_gal,
#         b = p.s.generator.fuel_intercept_gal_per_hr,
#         m = p.s.generator.fuel_slope_gal_per_kwh, 
#         diesel_min_turndown = p.s.generator.min_turn_down_pct
#     )
# end



# function probability_positions(N_array)
#     return vec(collect(Iterators.product(N_array...)))
# end



# function survival_with_battery(net_critical_load::Vector, starting_batt_soc_kwh::Vector, OA::Array{Numeric}, FTS::Array{Numeric}, FTR::Array{Numeric}, 
#     num_generators::Array{Int}, gen_capacity::Array{Numeric}, batt_kwh::Numeric, batt_kw::Numeric, num_bins::Int, max_outage_duration::Int, batt_charge_efficiency::Numeric,
#     batt_discharge_efficiency::Numeric; marginal_survival = true)::Matrix{Float64} 

#     t_max = length(net_critical_load)

#     #bin size is battery storage divided by num bins-1 because zero is also a bin
#     bin_size = batt_kwh / (num_bins-1)

#     #bin initial battery 
#     starting_battery_bins = bin_battery_charge(starting_batt_soc_kwh, num_bins, batt_kwh) 
#     #For easier indice reading
#     M = num_bins
#     N = num_generators .+ 1
#     G = length(num_generators)
#     #Initialize lost load matrix
#     survival_probability_matrix = zeros(t_max, max_outage_duration) 
#     #initialize vectors and matrices
#     generator_markov_matrix = [markov_matrix(num_generators[i], FTR[i]) for i in 1:G]
#     gen_prod = [generator_output(num_generators[i], gen_capacity[i]) for i in 1:G]

#         #TODO fixe maximum generation
#     maximum_generation = get_maximum_generation(batt_kw, gen_capacity, bin_size, num_bins, num_generators, batt_discharge_efficiency)
#     starting_gens = [starting_probabilities(num_generators[i], OA[i], FTS[i]) for i in 1:G] 

#     #loop through outage time
#     tme = time()
#     for t = 1:t_max
#         gen_battery_prob_matrix = zeros(M, N)
#         gen_battery_prob_matrix[starting_battery_bins[t], :] = starting_gens

#         #loop through outage duration
#         for d in 1:max_outage_duration 
#             survival = ones(M, N)
#             h = mod(t + d - 2, t_max) + 1 #determines index accounting for looping around year

#             excess_generation = gen_prod .- net_critical_load[h]
#             max_net_generation = maximum_generation .- net_critical_load[h]

#             #System fails if net generation is always negative (cannot meet load)
#             survival[max_net_generation .< 0, ] .= 0

#             #Update probabilities to account for generator failures
#             # time_vals["generator_shift"] += @elapsed account_for_generator_failures!(gen_battery_prob_matrix, generator_markov_matrix)
#             gen_battery_prob_matrix *= generator_markov_matrix 
#             # account_for_generator_failures!(gen_battery_prob_matrix, generator_markov_matrix)

#             #Update survival probabilities
#             survival_chance = gen_battery_prob_matrix .* survival

#             #If marginal survival is false then remove probabilities which did not meet load
#             if marginal_survival == false
#                 gen_battery_prob_matrix = gen_battery_prob_matrix .* survival
#             end
#             #update expected lost load for given outage start time and outage duration
#             survival_probability_matrix[t, d] = sum(survival_chance)
#             #Update generation battery probability matrix to account for battery shifting
#             shift_gen_battery_prob_matrix!(gen_battery_prob_matrix, battery_bin_shift(excess_generation, bin_size, batt_kw, batt_charge_efficiency, batt_discharge_efficiency))
#         end
#     end
#     return survival_probability_matrix
# end
