using JuMP, Gurobi, Printf

clearconsole()

model4 = Model(with_optimizer(Gurobi.Optimizer))

# Definition of variables with lower bound 0
@variable(model4, -2<=x1<=10)
@variable(model4, 0<=x2<=15)
@variable(model4, -10<=x3<=10)
@variable(model4, 0<=lambda)
@variable(model4, 0<=mu1)
@variable(model4, 0<=mu2)
@variable(model4, 0<=mu3)
@variable(model4, 0<=u1)
@variable(model4, 0<=u3)

@objective(model4, Max, 10x1+20x2+15x3)

@constraint(model4, con1, 4.5x1 + 5.5x2 + 3x3 + 2lambda + mu1 + mu2 + mu3 <= 10)
@constraint(model4, con2, 7x1 - 2x2 - 2x3 >= 5)
@constraint(model4, con3, lambda + mu1 >= 3.5u1)
@constraint(model4, con4, lambda + mu2 >= 3.5x2)
@constraint(model4, con5, lambda + mu3 >= 2u3)
@constraint(model4, con6, -u1 <= x1)
@constraint(model4, con7, u1 >= x1)
@constraint(model4, con8, -u3 <= x3)
@constraint(model4, con9, u3 >= x3)

optimize!(model4)

if termination_status(model4) == MOI.OPTIMAL
    println("Optimal solution found")

    println("Variable values:")
    @printf "x1: %0.3f\n" value.(x1)
    @printf "x2: %0.3f\n" value.(x2)
    @printf "x3: %0.3f\n" value.(x3)

    @printf "\nObjective value: %0.3f\n\n" objective_value(model4)

end
