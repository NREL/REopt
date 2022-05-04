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
    add_flexible_hvac_results(m::JuMP.AbstractModel, p::REoptInputs{Scenario}, d::Dict; _n="")

Add the FlexibleHVAC results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

FlexibleHVAC results:
- `purchased` "true" or "false", indicating if it is optimal to purchase the FlexibleHVAC system
- `upgrade_cost` Amount paid to install the FlexibleHVAC system 
- `temperatures_degC_node_by_time` An array of temperature time-series for each node in the RC model
"""
function add_flexible_hvac_results(m::JuMP.AbstractModel, p::REoptInputs{Scenario}, d::Dict; _n="")
    r = Dict{String, Any}()
    binFlexHVAC = value(m[:binFlexHVAC]) > 0.5 ? 1.0 : 0.0
    r["purchased"] = string(Bool(binFlexHVAC))
    # TODO if not purchased then don't provide temperature data? require BAU run with FlexHVAC and output BAU temperature?
    # WHY IS THE OPTIMAL RUN DIFFERENT FROM BAU ???
    
    r["upgrade_cost"] = Int(binFlexHVAC) * p.s.flexible_hvac.installed_cost

    if binFlexHVAC ≈ 1.0
        if any(value.(m[:lower_comfort_slack]) .>= 1.0) || any(value.(m[:upper_comfort_slack]) .>= 1.0)
            @warn "The comfort limits were violated by at least one degree Celcius to keep the problem feasible."
        end
        r["temperatures_degC_node_by_time"] = value.(m[Symbol("dvTemperature"*_n)]).data
    else
        r["temperatures_degC_node_by_time"] = p.s.flexible_hvac.bau_hvac.temperatures
    end

    d["FlexibleHVAC"] = r
	nothing
end

function add_flexible_hvac_results(m::JuMP.AbstractModel, p::REoptInputs{BAUScenario}, d::Dict; _n="")
    r = Dict{String, Any}()

    r["temperatures_degC_node_by_time"] = m[Symbol("dvTemperature"*_n)]

    d["FlexibleHVAC"] = r
	nothing
end