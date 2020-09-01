#Expected value problem

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
pi0 = [0.5, 0.3125, 0.1875]

#Parameter Heat Units
qmax = [10, 6]
c = [420,250]

#Storage capacity
K = 100

function weightedmean(x,w)
    sumx = 0
    sumw = 0
    n = length(x)
    for i in 1:n
        sumx = sumx+x[i]*w[i]
        sumw = sumw+w[i]
    end
return sumx/sumw
end

d_ex =zeros(24)
for t in periods
  for s in scenarios
    d_ex[t] = weightedmean(d[t],pi0)
  end
end

#Declare Gurobi model
model_heat_ex = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_heat_ex, 0<=q_h_ex[i in heat_units, t in periods]) #Heat production for each unit, period
@variable(model_heat_ex, 0<=s_in_ex[t in periods]) #Storage inflow per period
@variable(model_heat_ex, 0<=s_out_ex[t in periods]) #Storage outflow per period
@variable(model_heat_ex, 0<=s_level_ex[t in periods]) #Storage level per period
@variable(model_heat_ex, 0<=q_miss_ex[t in periods]) #Missing heat
@objective(model_heat_ex, Min,
         sum(c[i]*q_h_ex[i,t] for i in heat_units for t in periods)
         +sum(10000*q_miss_ex[t] for t in periods))


#Max heat unit production
@constraint(model_heat_ex, max_heat_production[i in heat_units, t in periods], q_h_ex[i,t] <= qmax[i])

#Demand satisfaction
@constraint(model_heat_ex, demand_satisfaction[t in periods],
                sum(q_h_ex[i,t] for i in heat_units) - s_in_ex[t] + s_out_ex[t]== d_ex[t] - q_miss_ex[t])

#Storage balance
@constraint(model_heat_ex, storage_balance[t in collect(2:24)], s_level_ex[t]-s_level_ex[t-1]-s_in_ex[t]+s_out_ex[t]==0)
@constraint(model_heat_ex, storage_balance_init, s_level_ex[1]-s_in_ex[1]+s_out_ex[1]==0)
#Storage capacity
@constraint(model_heat_ex, storage_capacity[t in periods], s_level_ex[t] <= K)


optimize!(model_heat_ex)

#SETTING THE FIRST STAGE VARIABLES TO VALUES FOUND ABOVE

q_h = value.(q_h_ex)

#Declare Gurobi model
model_heat = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_heat, 0<=s_in[t in periods, s in scenarios]) #Storage inflow per period and scenario
@variable(model_heat, 0<=s_out[t in periods, s in scenarios]) #Storage outflow per period and scenario
@variable(model_heat, 0<=s_level[t in periods, s in scenarios]) #Storage level per period and scenario
@variable(model_heat, 0<=q_miss[t in periods, s in scenarios]) #Missing heat
@objective(model_heat, Min,
         sum(c[i]*q_h[i,t] for i in heat_units for t in periods)
         +sum(10000*pi0[s]*q_miss[t,s] for t in periods for s in scenarios))

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
    @printf "\nEXPECTED VALUE PROBLEM"
    @printf "\nObjective value: %0.3f\n\n" objective_value(model_heat)
    RP = objective_value(model_heat)
else
    error("No solution.")
end
