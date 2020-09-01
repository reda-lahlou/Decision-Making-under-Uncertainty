#Import packages
using JuMP
using Gurobi
using Printf
using MathOptFormat
using CSV

#Locations
I = collect(1:5)
#Capacity level
L = collect(0:4)
#Markets
M = collect(1:15)
#Furniture products
F = collect(1:6)
#Time periods
T = collect(1:10)
#Scenarios
S = collect(1:5)


#Demand data
#Read demand data from demand.csv file
#Access demand by calling b[m,f,t,s]
df_b = CSV.read("demand.csv", delim=",")
array_b = Array(df_b)
b = zeros(Int,length(M),length(F),length(T),length(S))
for i=1:size(array_b,1)
    b[array_b[i,1],array_b[i,2],array_b[i,3],array_b[i,4]]=array_b[i,5]
end

#Distance d_location[i][j] between locations
d_location = [[0,287.24,50.33,365.85,500.03],
[287.24,0,246.2,131.55,213.34],
[50.33,246.2,0,317.17,459.53],
[365.85,131.55,317.17,0,205.8],
[500.03,213.34,459.53,205.8,0]]

#Distance d_market[m][i] between market and location
d_market = [[616.85,335.27,571.24,265.27,155.8],
[475.93,305.51,461.39,410.98,299.45],
[623.42,336.27,582.07,305.36,123.98],
[382.46,611.06,393.31,622.04,812.03],
[754.14,520.22,730.99,572.78,377.21],
[282.45,325.13,296.99,455.6,469.9],
[249.23,158.67,198.91,140,331.49],
[576.89,454.74,573.26,566.08,449.64],
[186.96,293.62,152.4,298.48,487.65],
[654.54,447.24,604.24,317.42,390.37],
[656.54,547.46,656.56,658.78,536.15],
[443.03,642.79,488.84,761.99,815.49],
[577.53,386.87,561.43,476.39,326.26],
[443.21,622.56,439.83,605.96,807.16],
[205.88,379.23,191.76,389.01,577.48]]

#Production capacity per capacity level (values represent total capacity, not additional capacity)
k_production = [0,2000,4000,5000,8000] #Value of 0 for level 0 has been added

#Storage capacity per capacity level (values represent total capacity, not additional capacity)
k_storage = [0,500,1000,2000,3000] #Value of 0 for level 0 has been added

#Building cost per capacity level
c_building = [0, 22.55000, 30.00000, 57.50000, 82.30000] #Value of 0 for level 0 has been added

#Operational cost per location
c_operational = [2.00000, 6.00000, 3.00000, 5.00000, 4.50000]

#Transportation cost
c_transport = 0.00300

#Probability per scenario
prob = [0.15, 0.06,0.4,0.3,0.09]

#Minimum distance between locations
D = 150

#Big value
Up = 100000

#Declare Gurobi model
model_UKEA = Model(with_optimizer(Gurobi.Optimizer))

#Variable definition
@variable(model_UKEA, 0<=y_fac[i in I, m in M], Bin) #1 if m is supplied by i, 0 else
@variable(model_UKEA, 0<=y_open[i in I], Bin) # 0 if i closed, 1 if open
@variable(model_UKEA, 0<=y_l[i in I, l in L], Bin) # 1 if i is at level l, 0 else
@variable(model_UKEA, 0<=p[i in I, f in F, t in T, s in S]) #Production of f by i at time t in scenario s
@variable(model_UKEA, 0<=mar[i in I, m in M, f in F, t in T, s in S]) #Quantity of f supplied by i to m at time t in scenario s
@variable(model_UKEA, 0<=ex[i in I, j in I, f in F, t in T, s in S]) #Quantity of f supplied by i to j at time s in scenario s
@variable(model_UKEA, 0<=st[i in I, f in F, t in T, s in S]) #Quantity of f found in the stock of i at the end of time t in scenario s

#Minimize total cost for facilities
@objective(model_UKEA, Min,
        sum(c_building[l+1]*y_l[i,l] for l in L for i in I)
        + 10*sum(c_operational[i]*y_open[i] for i in I)
        + c_transport*sum(prob[s]*mar[i,m,f,t,s]*d_market[m][i] for i in I for m in M for f in F for t in T for s in S)
        + c_transport*sum(prob[s]*ex[i,j,f,t,s]*d_location[i][j] for i in I for j in I for f in F for t in T for s in S))

# Demand satisfaction
@constraint(model_UKEA, supply[m in M,f in F,t in T,s in S], sum(mar[i,m,f,t,s] for i in I) == b[m,f,t,s])
#Max production
@constraint(model_UKEA, max_prod[i in I,t in T,s in S], sum(p[i,f,t,s] for f in F) <= sum(k_production[l+1]*y_l[i,l] for l in L))
#Max storage
@constraint(model_UKEA, max_stock[i in I,t in T,s in S], sum(st[i,f,t,s] for f in F) <= sum(k_storage[l+1]*y_l[i,l] for l in L))
#Minimum distance between facilities
@constraint(model_UKEA, min_dist[i in I, j in setdiff(I,i)], y_open[i]*(d_location[i][j]<D) == (1-y_open[j])*(d_location[i][j]<D))
#One level per facility
@constraint(model_UKEA, one_l[i in I], sum(y_l[i,l] for l in L) == 1)
#Facility closed has level 0, open has level 1
@constraint(model_UKEA, open[i in I], y_l[i,0] == 1-y_open[i])
#One facility per market
@constraint(model_UKEA, one_f[m in M], sum(y_fac[i,m] for i in I) == 1)
#Facility only supplies assigned market
@constraint(model_UKEA, only[i in I, m in M, f in F, t in T, s in S], mar[i,m,f,t,s] <= Up*y_fac[i,m])
#Storage balance
@constraint(model_UKEA, storage_balance[i in I,f in F,t in collect(2:10),s in S], st[i,f,t,s] == st[i,f,t-1,s]+p[i,f,t,s]-(sum((ex[i,j,f,t,s]-ex[j,i,f,t,s]) for j in I)+sum(mar[i,m,f,t,s] for m in M)))
@constraint(model_UKEA, storage_balance_init[i in I,f in F,s in S], st[i,f,1,s] == p[i,f,1,s]-(sum((ex[i,j,f,1,s]-ex[j,i,f,1,s]) for j in I)+sum(mar[i,m,f,1,s] for m in M)))

optimize!(model_UKEA)

#Getting level of location i
level = zeros(5)
for i in I
    for l in L
        if value.(y_l[i,l]) == 1
            level[i] = l
        end
    end
end

#Getting location assigned to market m
assign = zeros(15)
for m in M
    for i in I
        if value.(y_fac[i,m]) == 1
            assign[m] = i
        end
    end
end


#Getting a maximal value of the sum of a variable over the furniture for a facility i in scenario s
function maxim(y,i,s)
    m = 0
    for t in T
        x = sum(value.(y[i,f,t,s]) for f in F)
        if x>m
            m=x
        end
    end
return(m)
end


print("\n\n")
for i in I
    print("\nLocation: $i\n")
    print("\t\ts1\ts2\ts3\ts4\ts5\t\n")
    l1="Production:"
    l0="Max production:"
    l2="Supp market:"
    l3="Export:\t"
    l4="Max stock:"
    for s in S
        l1 *= "\t$(@sprintf("%.1f",sum(value.(p[i,f,t,s]) for f in F for t in T)))"
        l0 *= "\t$(@sprintf("%.1f",maxim(p,i,s)))"
        l2 *= "\t$(@sprintf("%.1f",sum(value.(mar[i,m,f,t,s]) for m in M for f in F for t in T)))"
        l3 *= "\t$(@sprintf("%.1f",sum(value.(ex[i,j,f,t,s]) for j in I for f in F for t in T)))"
        l4 *= "\t$(@sprintf("%.1f",maxim(st,i,s)))"
    end
    print(l1)
    print("\n")
    print(l0)
    print("\n")
    print(l2)
    print("\n")
    print(l3)
    print("\n")
    print(l4)
    print("\n\n")
end


if termination_status(model_UKEA) == MOI.OPTIMAL
    println("\nOptimal solution found\n")
    for i in I
        output_line = "Location: $i\t"
        if value.(y_open[i])==1
            output_line *= "open\t\t"
        else
            output_line *= "not open\t"
        end
        output_line *= "$(@sprintf("%.0f",level[i]))\t\n"
        print(output_line)
    end
    for m in M
        output_line = "Market : $m\t"
        output_line *= "$(@sprintf("%.1f",assign[m]))\t\n"
        print(output_line)
    end
    @printf "\nObjective value: %0.3f\n\n" objective_value(model_UKEA)

else
    error("No solution.")
end
