using JuMP, Gurobi, Printf, CSV, DataFrames

T = collect(1:12) #Time periods (Months)
I = collect(1:2) #Machines

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
c = [4, 2]

#Max capacity per month (given in units)
K = [400000, 650000]

#Efficiencies
eta1 = 1            #Efficiency of machine 1
eta2_bar = 0.7      #Mean efficiency for machine 2
P = 0.1            #Range of uncertainty for machine 2

modRO = Model(with_optimizer(Gurobi.Optimizer))

#Definition of variables
@variable(modRO, p[i in I,t in T] >= 0)

#Objective
@objective(modRO, Min, sum(c[i]*p[i,t] for i in I for t in T))

#Constraints

#Meet the demand (worst case)
@constraint(modRO, dem[t in T], eta1*p[1,t]+eta2_bar*p[2,t]-P*p[2,t] >= D[t])

#Max production
@constraint(modRO, max_prod[i in I,t in T], p[i,t] <= K[i])

optimize!(modRO)

if termination_status(modRO) == MOI.OPTIMAL
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
    @printf "\n\nObjective value: %0.3f\n\n" objective_value(modRO)

end

#CSV.write("device-RO.csv", DataFrame(value.(p)), writeheader=false)
