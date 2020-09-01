using JuMP, Gurobi, Printf, DataFrames, CSV

T = collect(1:12) #Time periods (Months)
I = collect(1:2) #Real machines

#Demand per month
D = [
    707000,
    753000,
    724000,
    784000,
    699000,
    543000,
    564000,
    522000,
    693000,
    743000,
    760000,
    731000,
]

# Units
# 1 - Fast machine
# 2 - Slow machine

#Production cost per unit
c = [4, 2, 3]

#Max capacity per month (given in units)
K = [400000, 650000, 200000]

#Efficiencies
eta1 = 1            #Efficiency of machine 1
eta2_bar = 0.7      #Mean efficiency for machine 2
P = 0.1            #Range of uncertainty for machine 2
eta3 = 0.8          #Effcicieny of machine 3

modARO = Model(with_optimizer(Gurobi.Optimizer))

#Definition of variables
@variable(modARO, p[i in I,t in T] >= 0)   #Production of real machines
@variable(modARO, beta[t in T])     #Recourse fonction (cost of virtual machine 3)
@variable(modARO, y[t in T])     #Certain part of linear decision rule
@variable(modARO, Q[t in T])    #Uncertain part of linear decision rule
@variable(modARO, alpha[t in T] >= 0)    #Absolute value of P*p[2,t]+eta3*Q[t]
@variable(modARO, gamma[t in T] >= 0)    #Absolute value of Q[t]

#Objective
@objective(modARO, Min, sum(c[i]*p[i,t] for i in I for t in T) + sum(beta[t] for t in T))

#Constraints

#Meet the demand (worst case)
@constraint(modARO, dem[t in T], eta1*p[1,t]+eta2_bar*p[2,t]+eta3*y[t]-alpha[t] >= D[t])

#Max production of real machines
@constraint(modARO, max_prod_real[i in I,t in T], p[i,t] <= K[i])
#Max production of virtual machine
@constraint(modARO, max_prod_virtual[t in T], y[t]+gamma[t] <= K[3])

#Cost of virtual machine
@constraint(modARO, cost_virtual[t in T], c[3]*(y[t]+gamma[t]) <= beta[t])

#Absolute value of Q
@constraint(modARO, absQ_l[t in T], -gamma[t] <= Q[t])
@constraint(modARO, absQ_h[t in T], gamma[t] >= Q[t])

#Absolute value of P*p[2,t]+eta3*Q[t]
@constraint(modARO, abs_l[t in T], -alpha[t] <= P*p[2,t]+eta3*Q[t])
@constraint(modARO, abs_h[t in T], alpha[t] >= P*p[2,t]+eta3*Q[t])

#Positive production for virtual machine 3
@constraint(modARO, prod3_pos[t in T], y[t]-alpha[t] >= 0)

optimize!(modARO)

if termination_status(modARO) == MOI.OPTIMAL
    println("Optimal solution found\n")

    print("\t\tt1\tt2\tt3\tt4\tt5\tt6\tt7\tt8\tt9\tt10\tt11\tt12\n")
    print("Machine1:\t")
    for t in T
        @printf("%.0f\t",value.(p[1,t]))
    end
    print("\n")
    print("Machine2:\t")
    for t in T
        @printf("%.0f\t",value.(p[2,t]))
    end
    print("\n")
    print("Machine3(low):\t")
    p3_low = Float64[]
    for t in T
        push!(p3_low, value.(y[t]) - value.(Q[t]))
        @printf("%.0f\t",p3_low[t])
    end
    print("\n")
    print("Machine3(high):\t")
    p3_high = Float64[]
    for t in T
        push!(p3_high, value.(y[t]) + value.(Q[t]))
        @printf("%.0f\t",p3_high[t])
    end
    @printf "\n\nObjective value: %0.3f\n\n" objective_value(modARO)

end

#CSV.write("device-ARO.csv", DataFrame(vcat(value.(p),p3_low',p3_high')), writeheader=false)
