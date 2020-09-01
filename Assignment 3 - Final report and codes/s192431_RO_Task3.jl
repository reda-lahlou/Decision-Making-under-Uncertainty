using JuMP, Gurobi, Printf

clearconsole()

model3 = Model(with_optimizer(Gurobi.Optimizer))

# Definition of variables with lower bound 0
@variable(model3, -2<=x1<=10)
@variable(model3, 0<=x2<=15)
@variable(model3, -10<=x3<=10)
@variable(model3, 0 <= lambda)
@variable(model3, 0 >= mu)

@objective(model3, Max, 10x1+20x2+15x3)

@constraint(model3, con1, 5x1 + 8lambda + 2mu <= 10)
@constraint(model3, con2, 7x1 - 2x2 - 2x3 >= 5)
@constraint(model3, con3, lambda + mu >= x2)
@constraint(model3, con4, lambda + mu >= x3)

optimize!(model3)

if termination_status(model3) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Variable values:")
    @printf "x1: %0.3f\n" value.(x1)
    @printf "x2: %0.3f\n" value.(x2)
    @printf "x3: %0.3f\n" value.(x3)

    @printf "\nObjective value: %0.3f\n\n" objective_value(model3)

end
