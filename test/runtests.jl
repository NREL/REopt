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
using Test
using JuMP
using HiGHS
using JSON
using REopt


if "Xpress" in ARGS
    @testset "test_with_xpress" begin
        include("test_with_xpress.jl")
    end

elseif "CPLEX" in ARGS
    @testset "test_with_cplex" begin
        include("test_with_cplex.jl")
    end

else  # run HiGHS tests

    @testset "Inputs" begin
        @testset "hybrid profile" begin
            electric_load = REopt.ElectricLoad(; 
                blended_doe_reference_percents = [0.2, 0.2, 0.2, 0.2, 0.2],
                blended_doe_reference_names    = ["RetailStore", "LargeOffice", "MediumOffice", "SmallOffice", "Warehouse"],
                annual_kwh                     = 50000.0,
                year                           = 2017,
                city                           = "Atlanta",
                latitude                       = 35.2468, 
                longitude                      = -91.7337
            )
            @test sum(electric_load.loads_kw) ≈ 50000.0
        end
    end

    @testset "January Export Rates" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        data = JSON.parsefile("./scenarios/monthly_rate.json")

        # create wholesale_rate with compensation in January > retail rate
        jan_rate = data["ElectricTariff"]["monthly_energy_rates"][1]
        data["ElectricTariff"]["wholesale_rate"] =
            append!(repeat([jan_rate + 0.1], 31 * 24), repeat([0.0], 8760 - 31*24))
        data["ElectricTariff"]["monthly_demand_rates"] = repeat([0], 12)

        s = Scenario(data)
        inputs = REoptInputs(s)
        results = run_reopt(model, inputs)

        @test results["PV"]["size_kw"] ≈ 70.3084 atol=0.01
        @test results["Financial"]["lcc"] ≈ 430747.0 rtol=1e-5 # with levelization_factor hack the LCC is within 5e-5 of REopt API LCC
        @test all(x == 0.0 for x in results["PV"]["year_one_to_load_series_kw"][1:744])
    end

    @testset "Blended tariff" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, "./scenarios/no_techs.json")
        @test results["ElectricTariff"]["year_one_energy_cost_before_tax"] ≈ 1000.0
        @test results["ElectricTariff"]["year_one_demand_cost_before_tax"] ≈ 136.99
    end

    @testset "Solar and Storage" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        r = run_reopt(model, "./scenarios/pv_storage.json")

        @test r["PV"]["size_kw"] ≈ 216.6667 atol=0.01
        @test r["Financial"]["lcc"] ≈ 1.240037e7 rtol=1e-5
        @test r["ElectricStorage"]["size_kw"] ≈ 55.9 atol=0.1
        @test r["ElectricStorage"]["size_kwh"] ≈ 78.9 atol=0.1
    end

    @testset "Outage with Generator" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, "./scenarios/generator.json")
        @test results["Generator"]["size_kw"] ≈ 8.13 atol=0.01
        @test (sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 1:9) + 
            sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 13:8760)) == 0
        p = REoptInputs("./scenarios/generator.json")
        simresults = simulate_outages(results, p)
        @test simresults["resilience_hours_max"] == 11
    end

    # TODO test MPC with outages
    @testset "MPC" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        r = run_mpc(model, "./scenarios/mpc.json")
        @test maximum(r["ElectricUtility"]["to_load_series_kw"][1:15]) <= 98.0 
        @test maximum(r["ElectricUtility"]["to_load_series_kw"][16:24]) <= 97.0
        @test sum(r["PV"]["to_grid_series_kw"]) ≈ 0
    end

    @testset "Complex Incentives" begin
        """
        This test was compared against the API test:
            reo.tests.test_reopt_url.EntryResourceTest.test_complex_incentives
        when using the hardcoded levelization_factor in this package's REoptInputs function.
        The two LCC's matched within 0.00005%. (The Julia pkg LCC is 1.0971991e7)
        """
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, "./scenarios/incentives.json")
        @test results["Financial"]["lcc"] ≈ 1.096852612e7 atol=1e4  
    end

    @testset "Fifteen minute load" begin
        d = JSON.parsefile("scenarios/no_techs.json")
        d["ElectricLoad"] = Dict("loads_kw" => repeat([1.0], 35040))
        d["Settings"] = Dict("time_steps_per_hour" => 4)
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, d)
        @test results["ElectricLoad"]["annual_calculated_kwh"] ≈ 8760
    end

    try
        rm("Highs.log", force=true)
    catch
        @warn "Could not delete test/Highs.log"
    end

    @testset "AVERT region abberviations" begin
        """
        This test checks 5 scenarios (in order)
        1. Coordinate pair inside an AVERT polygon
        2. Coordinate pair near a US border
        3. Coordinate pair < 5 miles from US border
        4. Coordinate pair > 5 miles from US border
        5. Coordinate pair >> 5 miles from US border
        """
        (r, d) = REopt.region_abbreviation(65.27661752129738, -149.59278391820223)
        @test r == "AKGD"
        (r, d) = REopt.region_abbreviation(21.45440792261567, -157.93648793163402)
        @test r == "HIOA"
        (r, d) = REopt.region_abbreviation(19.686877556659436, -155.4223641905743)
        @test r == "HIMS"
        (r, d) = REopt.region_abbreviation(39.86357200140234, -104.67953917092028)
        @test r == "RM"
        @test d ≈ 0.0 atol=1
        (r, d) = REopt.region_abbreviation(47.49137892652077, -69.3240287592685)
        @test r == "NE"
        @test d ≈ 7986 atol=1
        (r, d) = REopt.region_abbreviation(47.50448307102053, -69.34882434376593)
        @test r === nothing
        @test d ≈ 10297 atol=1
        (r, d) = REopt.region_abbreviation(55.860334445251354, -4.286554357755312)
        @test r === nothing
    end

    @testset "PVspecs" begin
        ## Scenario 1: Palmdale, CA; array-type = 0 (Ground-mount)
        post_name = "pv.json" 
        post = JSON.parsefile("./scenarios/$post_name")
        scen = Scenario(post)
     
        @test scen.pvs[1].tilt ≈ post["Site"]["latitude"] 
        @test scen.pvs[1].azimuth ≈ 180
    
        ## Scenario 2: Palmdale, CA; array-type = 1 (roof)
        post["PV"]["array_type"] = 1 
        scen = Scenario(post)
    
        @test scen.pvs[1].tilt ≈ 10
    
        ## Scenario 3:Cape Town; array-type = 0 (ground)
        post["Site"]["latitude"] = -33.974732
        post["Site"]["longitude"] = 19.130050
        post["PV"]["array_type"] = 0 
        scen = Scenario(post)
    
        @test scen.pvs[1].tilt ≈ abs(post["Site"]["latitude"])
        @test scen.pvs[1].azimuth ≈ 0

        ## Scenario 4:Cape Town; array-type = 0 (ground); user-provided tilt (should not get overwritten)
        post["PV"]["tilt"] = 17
        scen = Scenario(post)
        @test scen.pvs[1].tilt ≈ 17
    end

    @testset "AlternativeFlatLoads" begin
        input_data = JSON.parsefile("./scenarios/flatloads.json")
        s = Scenario(input_data)
        inputs = REoptInputs(s)

        # FlatLoad_8_5 => 8 hrs/day, 5 days/week, 52 weeks/year
        active_hours_8_5 = 8 * 5 * 52
        @test count(x->x>0, s.space_heating_load.loads_kw, dims=1)[1] == active_hours_8_5
        # FlatLoad_16_7 => only hours 6-22 should be >0, and each day is the same portion of the total year
        @test sum(s.electric_load.loads_kw[1:5]) + sum(s.electric_load.loads_kw[23:24]) == 0.0
        @test sum(s.electric_load.loads_kw[6:22]) / sum(s.electric_load.loads_kw) - 1/365 ≈ 0.0 atol=0.000001
    end

    @testset "Backup Generator Reliability" begin
        input_dict = Dict(
            "critical_loads_kw" => [1,2,2,1],
            "battery_starting_soc_series_fraction" => [0.5,0.5,0.5,0.5],
            "max_outage_duration" => 3,
            "num_generators" => 2, "generator_size_kw" => 1,
            "generator_operational_availability" => 1,
            "generator_failure_to_start" => 0.0,
            "generator_mean_time_to_failure" => 5,
            "battery_operational_availability" => 1,
            "num_battery_bins" => 3,
            "battery_size_kwh" => 2,
            "battery_size_kw" => 1,
            "battery_charge_efficiency" => 1,
            "battery_discharge_efficiency" => 1,
            "battery_minimum_soc_fraction" => 0)
        


        #Given outage starts in time period 1
        #____________________________________
        #Outage hour 1:
        #2 generators:         Prob = 0.64,     Battery = 2, Survived
        #1 generator:          Prob = 0.32,     Battery = 1, Survived
        #0 generator:          Prob = 0.04,     Battery = 0, Survived
        #Survival Probability 1.0

        #Outage hour 2:
        #2 generators:         Prob = 0.4096,   Battery = 2, Survived
        #2 gen -> 1 gen:       Prob = 0.2048,   Battery = 1, Survived
        #1 gen -> 1 gen:       Prob = 0.256,    Battery = 0, Survived
        #0 generators:         Prob = 0.1296,   Battery = -1, Failed
        #Survival Probability: 0.8704

        #Outage hour 3:
        #2 generators:         Prob = 0.262144, Battery = 0, Survived
        #2 gen -> 2 -> 1       Prob = 0.131072, Battery = 1, Survived
        #2 gen -> 1 -> 1       Prob = 0.16384,  Battery = 0, Survived
        #1 gen -> 1 -> 1       Prob = 0.2048,   Battery = -1, Failed
        #0 generators          Prob = 0.238144, Battery = -1, Failed
        #Survival Probability: 0.557056        
        @test backup_reliability(input_dict)["unlimited_fuel_cumulative_survival_final_time_step"][1] ≈ 0.557056

        #Test multiple generator types
        input_dict = Dict(
            "critical_loads_kw" => [1,2,2,1], 
            "battery_starting_soc_series_fraction" => [0.5,0.5,0.5,0.5],
            "max_outage_duration" => 3,
            "num_generators" => [1,1],
            "generator_size_kw" => [1,1],
            "generator_operational_availability" => [1,1],
            "generator_failure_to_start" => [0.0, 0.0],
            "generator_mean_time_to_failure" => [5, 5], 
            "num_battery_bins" => 3,
            "battery_size_kwh" => 2,
            "battery_size_kw" => 1,
            "battery_charge_efficiency" => 1,
            "battery_discharge_efficiency" => 1,
            "battery_minimum_soc_fraction" => 0)

        @test backup_reliability(input_dict)["unlimited_fuel_cumulative_survival_final_time_step"][1] ≈ 0.557056

        #8760 of flat load. Battery can survive 4 hours. 
        #Survival after 24 hours should be chance of generator surviving 20 or more hours
        input_dict = Dict(
            "critical_loads_kw" => 100 .* ones(8760),
            "max_outage_duration" => 24,
            "num_generators" => 1,
            "generator_size_kw" => 100,
            "generator_operational_availability" => 0.98,
            "generator_failure_to_start" => 0.1,
            "generator_mean_time_to_failure" => 100,
            "num_battery_bins" => 101,
            "battery_size_kwh" => 400,
            "battery_size_kw" => 100,
            "battery_charge_efficiency" => 1,
            "battery_discharge_efficiency" => 1,
            "battery_minimum_soc_fraction" => 0)

        reliability_results = backup_reliability(input_dict)
        @test reliability_results["unlimited_fuel_mean_cumulative_survival_by_duration"][24] ≈ (0.99^20)*(0.9*0.98) atol=0.00001

        #More realistic case of hospital load with 2 generators, PV, and battery
        reliability_inputs = JSON.parsefile("./scenarios/backup_reliability_inputs.json")
        @test backup_reliability(reliability_inputs)["mean_cumulative_survival_final_time_step"] ≈ 0.904242 atol=0.0001
        
        for input_key in [
                    "generator_size_kw",
                    "battery_size_kw",
                    "battery_size_kwh",
                    "battery_minimum_soc_fraction",
                    "pv_size_kw",
                    "critical_loads_kw",
                    "pv_production_factor_series"
                ]
            delete!(reliability_inputs, input_key)
        end
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        p = REoptInputs("./scenarios/backup_reliability_reopt_inputs.json")
        results = run_reopt(model, p)
        reliability_inputs["use_full_battery_charge"] = true
        reliability = backup_reliability(results, p, reliability_inputs)
        @test reliability["mean_cumulative_survival_final_time_step"] ≈ 0.817088 atol=0.0001
    end                            

    # removed Wind test for two reasons
    # 1. reduce WindToolKit calls in tests
    # 2. HiGHS does not support SOS or indicator constraints, which are needed for export constraints

    # @testset "Minimize Unserved Load" is too slow with Cbc (killed after 8 hours)
    
    @testset "Simulated load function consistency with REoptInputs.s (Scenario)" begin
        """

        This tests the consistency between getting DOE commercial reference building (CRB) load data
            from the simulated_load function and the processing of REoptInputs.s (Scenario struct).
                
        The simulated_load function is used for the /simulated_load endpoint in the REopt API,
            in particular for the webtool/UI to display loads before running REopt, but is also generally
            an external way to access CRB load data without running REopt.

        One particular test specifically for the webtool/UI is for the heating load because there is just a 
            single heating load instead of separated space heating and domestic hot water loads.
        
        """
        input_data = JSON.parsefile("./scenarios/simulated_load.json")
        
        input_data["ElectricLoad"] = Dict([("blended_doe_reference_names", ["Hospital", "FlatLoad_16_5"]),
                                        ("blended_doe_reference_percents", [0.2, 0.8])
                                    ])
        
        input_data["CoolingLoad"] = Dict([("blended_doe_reference_names", ["LargeOffice", "FlatLoad"]),
                                        ("blended_doe_reference_percents", [0.5, 0.5])
                                    ])
        
        # Heating load from the UI will call the /simulated_load endpoint first to parse single heating mmbtu into separate Space and DHW mmbtu
        annual_mmbtu = 10000.0
        doe_reference_name_heating = ["LargeOffice", "FlatLoad"]
        percent_share_heating = [0.3, 0.7]
        
        d_sim_load_heating = Dict([("latitude", input_data["Site"]["latitude"]),
                                    ("longitude", input_data["Site"]["longitude"]),
                                    ("load_type", "heating"),  # since annual_tonhour is not given
                                    ("doe_reference_name", doe_reference_name_heating),
                                    ("percent_share", percent_share_heating),
                                    ("annual_mmbtu", annual_mmbtu)
                                    ])
        
        sim_load_response_heating = simulated_load(d_sim_load_heating)                            
        
        input_data["SpaceHeatingLoad"] = Dict([("blended_doe_reference_names", doe_reference_name_heating),
                                        ("blended_doe_reference_percents", percent_share_heating),
                                        ("annual_mmbtu", sim_load_response_heating["space_annual_mmbtu"])
                                    ])
        
        input_data["DomesticHotWaterLoad"] = Dict([("blended_doe_reference_names", doe_reference_name_heating),
                                        ("blended_doe_reference_percents", percent_share_heating),
                                        ("annual_mmbtu", sim_load_response_heating["dhw_annual_mmbtu"])
                                    ])
        
        s = Scenario(input_data)
        inputs = REoptInputs(s)
        
        # Call simulated_load function to check cooling
        d_sim_load_elec_and_cooling = Dict([("latitude", input_data["Site"]["latitude"]),
                                            ("longitude", input_data["Site"]["longitude"]),
                                            ("load_type", "electric"),  # since annual_tonhour is not given
                                            ("doe_reference_name", input_data["ElectricLoad"]["blended_doe_reference_names"]),
                                            ("percent_share", input_data["ElectricLoad"]["blended_doe_reference_percents"]),
                                            ("cooling_doe_ref_name", input_data["CoolingLoad"]["blended_doe_reference_names"]),
                                            ("cooling_pct_share", input_data["CoolingLoad"]["blended_doe_reference_percents"]),                    
                                            ])
        
        sim_load_response_elec_and_cooling = simulated_load(d_sim_load_elec_and_cooling)
        sim_electric_kw = sim_load_response_elec_and_cooling["loads_kw"]
        sim_cooling_ton = sim_load_response_elec_and_cooling["cooling_defaults"]["loads_ton"]
        
        total_heating_fuel_load_reopt_inputs = (s.space_heating_load.loads_kw + s.dhw_load.loads_kw) ./ REopt.KWH_PER_MMBTU ./ REopt.EXISTING_BOILER_EFFICIENCY
        @test sim_load_response_heating["loads_mmbtu_per_hour"] ≈ round.(total_heating_fuel_load_reopt_inputs, digits=3) atol=0.001
        
        @test sim_electric_kw ≈ s.electric_load.loads_kw atol=0.1
        @test sim_cooling_ton ≈ s.cooling_load.loads_kw_thermal ./ REopt.KWH_THERMAL_PER_TONHOUR atol=0.1    
    end
end
