using JuMP, Gurobi, Printf

clearconsole()

model2 = Model(with_optimizer(Gurobi.Optimizer))

# Definition of variables with lower bound 0
@variable(model2, -2<=x1<=10)
@variable(model2, 0<=x2<=15)
@variable(model2, -10<=x3<=10)
@variable(model2, t)

@objective(model2, Max, 10x1+t+15x3)

@constraint(model2, con1, 5x1 + 3x2 + 3x3 <= 10)
@constraint(model2, con2, 7x1 - 2x2 - 2x3 >= 5)
@constraint(model2, con3, t <= 5x2)

optimize!(model2)

if termination_status(model2) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Variable values:")
    @printf "x1: %0.3f\n" value.(x1)
    @printf "x2: %0.3f\n" value.(x2)
    @printf "x3: %0.3f\n" value.(x3)

    @printf "\nObjective value: %0.3f\n\n" objective_value(model2)

end
