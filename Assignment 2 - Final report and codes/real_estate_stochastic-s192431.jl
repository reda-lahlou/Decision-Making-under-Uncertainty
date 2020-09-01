#Import packages
using JuMP
using Gurobi
using Printf
using MathOptFormat
using CSV

#Areas
I_names = ["zip2000","zip2800","zip7400","zip8900"]
I = collect(1:4)
#Scenarios
S = collect(1:12)



# Initial price in DKK/m2 in area i, access by p_init[i]
p_init = [42371,32979,15337,14192]

#Budget
B = 25000000

#Forecasted price in DKK/m2 in area i and scenario s
#Reads price data from scenarios.csv file
#Access price by calling p[i,s]
df_p = CSV.read("scenarios.csv", delim=";")
array_p = Array(df_p)
p = zeros(Float32,length(I),length(S))
for i=1:size(array_p,1)
    p[Int(array_p[i,2]),Int(array_p[i,1])]=array_p[i,3]
end

#Probabilities
prob = [0.09 0.13 0.08 0.10 0.08 0.06 0.07 0.10 0.05 0.07 0.12 0.05]

beta = 0.2
alpha = 0.9

#Declare Gurobi model
model_real_estate_CVaR = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_real_estate_CVaR, 0<=b[i in I], Int) #m^2 bought from location i
@variable(model_real_estate_CVaR, eta) #Value-at-risk for level alpha
@variable(model_real_estate_CVaR, 0<=delta[s in S]) #Max between 0 and the difference between eta and the objective value in scenario s

@objective(model_real_estate_CVaR, Max, (1-beta)*(sum(b[i]*prob[s]*p[i,s] for i in I for s in S)-sum(b[i]*p_init[i] for i in I))+beta*(eta-1/(1-alpha)*sum(prob[s]*delta[s] for s in S)))

#Initial budget fully spent
@constraint(model_real_estate_CVaR, budget, sum(b[i]*p_init[i] for i in I) == B)
#CVaR constraint
@constraint(model_real_estate_CVaR, cvar[s in S], eta-sum(b[i]*(p[i,s]-p_init[i]) for i in I) <= delta[s])

optimize!(model_real_estate_CVaR)

CVaR = value.(eta)-1/(1-alpha)*sum(prob[s]*value.(delta[s]) for s in S)
Gain = sum(value.(b[i])*prob[s]*p[i,s] for i in I for s in S) - sum(value.(b[i])*p_init[i] for i in I)

if termination_status(model_real_estate_CVaR) == MOI.OPTIMAL
    print("\n\n")
    @printf "Gain: %0.3f\n" Gain
    @printf "CVaR: %0.3f\n" CVaR
    @printf "Objective: %0.3f\n" objective_value(model_real_estate_CVaR)
    for i in I
        @printf("Area: %s %0.1f\n",I_names[i], value.(b[i]))
    end
end
