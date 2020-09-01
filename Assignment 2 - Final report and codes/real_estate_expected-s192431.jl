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


#Function to calculate mean of x weighted by w
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

#Calculate expected values of uncertain parameter p
p_ex =zeros(length(I))
for i in I
  for s in S
    p_ex[i] = weightedmean(p[i,:],prob)
  end
end

#Declare Gurobi model
model_real_estate_exp = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_real_estate_exp, 0<=b[i in I], Int) #m^2 bought from location i

#Objective
@objective(model_real_estate_exp, Max, sum(b[i]*p_ex[i] for i in I)-sum(b[i]*p_init[i] for i in I))

#Initial budget fully spent
@constraint(model_real_estate_exp, budget, sum(b[i]*p_init[i] for i in I) == B)

optimize!(model_real_estate_exp)

if termination_status(model_real_estate_exp) == MOI.OPTIMAL
    print("\n\n")
    @printf "Gain: %0.3f\n" objective_value(model_real_estate_exp)
    @printf "Objective: %0.3f\n" objective_value(model_real_estate_exp)
    for i in I
        @printf("Area: %s %0.1f\n",I_names[i], value.(b[i]))
    end
end
