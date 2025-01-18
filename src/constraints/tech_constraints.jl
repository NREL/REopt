# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
function add_tech_size_constraints(m, p; _n="")

    # PV techs can be constrained by space available based on location at site (roof, ground, both)
    @constraint(m, [loc in p.pvlocations],
        sum(m[Symbol("dvSize"*_n)][t] * p.pv_to_location[t][loc] for t in p.techs.pv) <= p.maxsize_pv_locations[loc]
    )

    # max size limit
    @constraint(m, [t in p.techs.all],
        m[Symbol("dvSize"*_n)][t] <= p.max_sizes[t]
    )

    ##Constraint (7c): Minimum size for each tech
    @constraint(m, [t in p.techs.all],
        m[Symbol("dvSize"*_n)][t] >= p.min_sizes[t]
    )

    @constraint(m, [t in p.techs.all],
        m[Symbol("dvPurchaseSize"*_n)][t] >= m[Symbol("dvSize"*_n)][t] - p.existing_sizes[t]
    )

    ## Constraint (7d): Non-turndown technologies are always at rated production
    @constraint(m, [t in p.techs.no_turndown, ts in p.time_steps],
        m[Symbol("dvRatedProduction"*_n)][t,ts] == m[Symbol("dvSize"*_n)][t]
    )

	##Constraint (7e): SteamTurbine is not in techs.no_turndown OR techs.segmented, so handle electric production to dvSize constraint
    if !isempty(p.techs.steam_turbine)
        @constraint(m, [t in p.techs.steam_turbine, ts in p.time_steps],
            m[Symbol("dvRatedProduction"*_n)][t,ts]  <= m[:dvSize][t]
        )
    end  
end


function add_no_curtail_constraints(m, p; _n="")
    for t in p.techs.no_curtail
        for ts in p.time_steps
            fix(m[Symbol("dvCurtail"*_n)][t, ts] , 0.0, force=true)
        end
    end
end

function add_existing_boiler_capex_constraints(m, p; _n="")
    # @variable(m, binExistingBoiler, Int, lower_bound = 0, upper_bound = 1)  # This is same as below with Bin
    @variable(m, binExistingBoiler, Bin)
    # If still using ExistingBoiler in optimal case at all, incur costs (not scaled by size)
    # Force dvSize["ExistingBoiler] to zero if binExistingBoiler is zero:
    @constraint(m, ExistingBoilerCostCon, m[Symbol("dvSize"*_n)]["ExistingBoiler"] <= m[Symbol("binExistingBoiler"*_n)] * BIG_NUMBER)

    if p.s.existing_boiler.retire_in_optimal
        @constraint(m, ExistingBoilerSelect, m[Symbol("binExistingBoiler"*_n)] == 0)
    else
        @constraint(m, ExistingBoilerSelect, m[Symbol("binExistingBoiler"*_n)] <= 1)
    end

    m[:ExistingBoilerCost] = @expression(m, p.third_party_factor *
        sum(p.s.existing_boiler.installed_cost_dollars * m[Symbol("binExistingBoiler"*_n)])
    )
end

function add_existing_chiller_capex_constraints(m, p; _n="")
    # @variable(m, binExistingChiller, Int, lower_bound = 0, upper_bound = 1)  # This is same as below with Bin
    @variable(m, binExistingChiller, Bin)
    # If still using ExistingChiller in optimal case, incur costs (not scaled by size)
    # Force dvSize["ExistingChiller] to zero if binExistingChiller is zero:
    @constraint(m, ExistingChillerCostCon, m[Symbol("dvSize"*_n)]["ExistingChiller"] <= m[Symbol("binExistingChiller"*_n)] * BIG_NUMBER)

    @constraint(m, ExistingChillerSelect, m[Symbol("binExistingChiller"*_n)] <= 1)

    m[:ExistingChillerCost] = @expression(m, p.third_party_factor *
        sum(p.s.existing_chiller.installed_cost_dollars * m[Symbol("binExistingChiller"*_n)])
    )
end