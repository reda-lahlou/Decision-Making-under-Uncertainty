#Wait-and-see approach

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
model_heat1 = Model(with_optimizer(Gurobi.Optimizer))
model_heat2 = Model(with_optimizer(Gurobi.Optimizer))
model_heat3 = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_heat1, 0<=q_h1[i in heat_units, t in periods]) #Heat production for each unit, period and scenario
@variable(model_heat1, 0<=s_in1[t in periods]) #Storage inflow per period and scenario
@variable(model_heat1, 0<=s_out1[t in periods]) #Storage outflow per period and scenario
@variable(model_heat1, 0<=s_level1[t in periods]) #Storage level per period and scenario
@variable(model_heat1, 0<=q_miss1[t in periods]) #Missing heat

@variable(model_heat2, 0<=q_h2[i in heat_units, t in periods]) #Heat production for each unit, period and scenario
@variable(model_heat2, 0<=s_in2[t in periods]) #Storage inflow per period and scenario
@variable(model_heat2, 0<=s_out2[t in periods]) #Storage outflow per period and scenario
@variable(model_heat2, 0<=s_level2[t in periods]) #Storage level per period and scenario
@variable(model_heat2, 0<=q_miss2[t in periods]) #Missing heat

@variable(model_heat3, 0<=q_h3[i in heat_units, t in periods]) #Heat production for each unit, period and scenario
@variable(model_heat3, 0<=s_in3[t in periods]) #Storage inflow per period and scenario
@variable(model_heat3, 0<=s_out3[t in periods]) #Storage outflow per period and scenario
@variable(model_heat3, 0<=s_level3[t in periods]) #Storage level per period and scenario
@variable(model_heat3, 0<=q_miss3[t in periods]) #Missing heat

@objective(model_heat1, Min,
         sum(c[i]*q_h1[i,t] for i in heat_units for t in periods)
         +sum(10000*q_miss1[t] for t in periods))

@objective(model_heat2, Min,
         sum(c[i]*q_h2[i,t] for i in heat_units for t in periods)
         +sum(10000*q_miss2[t] for t in periods))

@objective(model_heat3, Min,
         sum(c[i]*q_h3[i,t] for i in heat_units for t in periods)
         +sum(10000*q_miss3[t] for t in periods))

#Max heat unit production
@constraint(model_heat1, max_heat_production[i in heat_units, t in periods], q_h1[i,t] <= qmax[i])
@constraint(model_heat2, max_heat_production[i in heat_units, t in periods], q_h2[i,t] <= qmax[i])
@constraint(model_heat3, max_heat_production[i in heat_units, t in periods], q_h3[i,t] <= qmax[i])

#Demand satisfaction
@constraint(model_heat1, demand_satisfaction[t in periods],
                sum(q_h1[i,t] for i in heat_units) - s_in1[t] + s_out1[t]== d[t][1] - q_miss1[t])
@constraint(model_heat2, demand_satisfaction[t in periods],
                sum(q_h2[i,t] for i in heat_units) - s_in2[t] + s_out2[t]== d[t][2] - q_miss2[t])
@constraint(model_heat3, demand_satisfaction[t in periods],
                sum(q_h3[i,t] for i in heat_units) - s_in3[t] + s_out3[t]== d[t][3] - q_miss3[t])

#Storage balance
@constraint(model_heat1, storage_balance[t in collect(2:24)], s_level1[t]-s_level1[t-1]-s_in1[t]+s_out1[t]==0)
@constraint(model_heat1, storage_balance_init, s_level1[1]-s_in1[1]+s_out1[1]==0)
@constraint(model_heat2, storage_balance[t in collect(2:24)], s_level2[t]-s_level2[t-1]-s_in2[t]+s_out2[t]==0)
@constraint(model_heat2, storage_balance_init, s_level2[1]-s_in2[1]+s_out2[1]==0)
@constraint(model_heat3, storage_balance[t in collect(2:24)], s_level3[t]-s_level3[t-1]-s_in3[t]+s_out3[t]==0)
@constraint(model_heat3, storage_balance_init, s_level3[1]-s_in3[1]+s_out3[1]==0)

#Storage capacity
@constraint(model_heat1, storage_capacity[t in periods], s_level1[t] <= K)
@constraint(model_heat2, storage_capacity[t in periods], s_level2[t] <= K)
@constraint(model_heat3, storage_capacity[t in periods], s_level3[t] <= K)

optimize!(model_heat1)
optimize!(model_heat2)
optimize!(model_heat3)


if termination_status(model_heat1) == MOI.OPTIMAL
    @printf "\nObjective value scenario 1: %0.3f\n\n" objective_value(model_heat1)
    WS1 = objective_value(model_heat1)
else
    error("No solution.")
end

if termination_status(model_heat2) == MOI.OPTIMAL
    @printf "\nObjective value scenario 2: %0.3f\n\n" objective_value(model_heat2)
    WS2 = objective_value(model_heat2)
else
    error("No solution.")
end

if termination_status(model_heat3) == MOI.OPTIMAL
    @printf "\nObjective value scenario 3: %0.3f\n\n" objective_value(model_heat3)
    WS3 = objective_value(model_heat3)
else
    error("No solution.")
end

WS = WS1*pi[1]+WS2*pi[2]+WS3*pi[3]
@printf "\nExpected value of wait-and-see approach: %0.3f\n\n" WS
