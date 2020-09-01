using JuMP, Gurobi, Printf

clearconsole()

model1 = Model(with_optimizer(Gurobi.Optimizer))

# Definition of variables with lower bound 0
@variable(model1, -2<=x1<=10)
@variable(model1, 0<=x2<=15)
@variable(model1, -10<=x3<=10)
@variable(model1, 0<=ua)
@variable(model1, 0<=ub)

@objective(model1, Max, 10x1+20x2+15x3)

@constraint(model1, con1, 5x1 + 3x2 + 3x3 + ua <= 10)
@constraint(model1, con2, 7x1 - 2x2 - 2x3 - ub >= 5)
@constraint(model1, con3, 2x3 <= ua)
@constraint(model1, con4, -ua <= 2x3)
@constraint(model1, con5, x3 <= ub)
@constraint(model1, con6, -ub <= x3)

optimize!(model1)

if termination_status(model1) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Variable values:")
    @printf "x1: %0.3f\n" value.(x1)
    @printf "x2: %0.3f\n" value.(x2)
    @printf "x3: %0.3f\n" value.(x3)

    @printf "\nObjective value: %0.3f\n\n" objective_value(model1)

end
