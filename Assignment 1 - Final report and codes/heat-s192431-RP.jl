#Import packages
using JuMP
using Gurobi
using Printf
using MathOptFormat
using Statistics

#Sets
scenarios = collect(1:3)
periods = collect(1:24)
heat_units = collect(1:2)

#Heat demand forecast per hour and scenario
d = [[8.9,8.88,5.73],[8.7,9.08,7.24],[7.02,8.98,7.54],[7.02,9.28,7.54],[7.02,9.08,7.54],
[6.03,9.18,7.14],[6.13,9.08,7.14],[5.83,9.28,7.44],[5.73,7.42,7.34],[6.03,7.12,7.14],
[5.73,7.32,7.24],[7.14,8.56,7.54],[7.34,8.36,7.54],[7.34,8.36,7.14],[7.34,8.36,7.54],
[7.44,8.36,7.24],[7.54,8.36,5.93],[7.14,10.58,5.93],[7.24,10.28,5.93],[7.44,10.48,6.29],
[7.44,10.28,6.19],[7.54,10.18,6.39],[7.24,10.28,6.39],[7.34,10.18,6.59]]

#Scenario probabilities
pi = [0.5, 0.3125, 0.1875]

#Parameter Heat Units
qmax = [10, 6]
c = [420,250]

#Storage capacity
K = 100

#Declare Gurobi model
model_heat = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_heat, 0<=q_h[i in heat_units, t in periods]) #Heat production for each unit, period and scenario
@variable(model_heat, 0<=s_in[t in periods, s in scenarios]) #Storage inflow per period and scenario
@variable(model_heat, 0<=s_out[t in periods, s in scenarios]) #Storage outflow per period and scenario
@variable(model_heat, 0<=s_level[t in periods, s in scenarios]) #Storage level per period and scenario
@variable(model_heat, 0<=q_miss[t in periods, s in scenarios]) #Missing heat
@objective(model_heat, Min,
         sum(c[i]*q_h[i,t] for i in heat_units for t in periods)
         +sum(10000*pi[s]*q_miss[t,s] for t in periods for s in scenarios))


#Max heat unit production
@constraint(model_heat, max_heat_production[i in heat_units, t in periods], q_h[i,t] <= qmax[i])

#Demand satisfaction
@constraint(model_heat, demand_satisfaction[t in periods, s in scenarios],
                sum(q_h[i,t] for i in heat_units) - s_in[t,s] + s_out[t,s]== d[t][s] - q_miss[t,s])

#Storage balance
@constraint(model_heat, storage_balance[t in collect(2:24), s in scenarios], s_level[t,s]-s_level[t-1,s]-s_in[t,s]+s_out[t,s]==0)
@constraint(model_heat, storage_balance_init[s in scenarios], s_level[1,s]-s_in[1,s]+s_out[1,s]==0)
#Storage capacity
@constraint(model_heat, storage_capacity[t in periods, s in scenarios], s_level[t,s] <= K)


optimize!(model_heat)

if termination_status(model_heat) == MOI.OPTIMAL
    @printf "\nSTOCHASTIC MODEL"
    @printf "\nObjective value: %0.3f\n\n" objective_value(model_heat)
    RP = objective_value(model_heat)
else
    error("No solution.")
end
