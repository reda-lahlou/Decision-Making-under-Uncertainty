library("cluster")
library('tseries')
library('forecast')


## TASK 1 - LINEAR TIME SERIES ANALYSIS

##Import
data <- read.csv("prices.csv", sep = ";")
data <- data[,2]; 

## Define data as time series
data <- ts(data)

## Plot data
plot(c(1:length(data)),data,type="l",ylab = "Price in ZIP2000 (DKK/m^2)", xlab="Time period", lwd=2, col='red')

##Data do not seem stationary: increasing mean and non constant variance

## Log transformation to stabilize the variance
log_data <- log(data)
plot(c(1:length(log_data)),log_data,type="l",ylab = "Log-price in ZIP2000 (DKK/m^2)", xlab="Time period", lwd=2, col='red')
#Compare the ACF
par(mfrow=c(1,2))
acf(data,main='ACF for Data',length(data)/2)
acf(log_data,main='ACF for log-data',length(log_data)/2)
par(mfrow=c(1,1))

## Differentiated log data
d_log_data <- diff(log_data,1)
plot(c(1:length(d_log_data)),d_log_data,type="l",ylab = "Differentiated log-price", xlab="Time period", lwd=2, col='red')

# Differentiated data
d_data <- diff(data,1)
plot(c(1:length(d_data)),d_data,type="l",ylab = "Differentiated price", xlab="Time period", lwd=2, col='red')

## Differentiated twice log data
d2_log_data <- diff(diff(log_data,1),1)
plot(c(1:length(d2_log_data)),d2_log_data,type="l",ylab = "Twice differentiated log-price", xlab="Time period", lwd=2, col='red')

#Compare the ACF
par(mfrow=c(1,2))
acf(d_log_data,main='Differentiated',length(d_log_data)/2)
acf(d2_log_data,main='Twice differentiated',length(d2_log_data)/2)
par(mfrow=c(1,1))

#ACF and PACF of the transformed data
par(mfrow=c(1,2))
acf(d2_log_data,main="ACF",length(d2_log_data)/2)
pacf(d2_log_data,main="PACF",length(d2_log_data)/2)
par(mfrow=c(1,1))

#Begin with arima(1,2,1) on log-data
fit_log.a = Arima(log_data, order = c(1,2,1))
summary(fit_log.a)
par(mfrow=c(1,2))
acf(fit_log.a$residuals, main ="ACF of the residuals", lag.max=50)
pacf(fit_log.a$residuals, main ="PACF of the residuals",lag.max=50)
par(mfrow=c(1,1))

#Try increasing each of the arima parameters
fit_log.b = Arima(log_data, order = c(2,2,1))
fit_log.c = Arima(log_data, order = c(1,3,1))
fit_log.d = Arima(log_data, order = c(1,2,2))
par(mfrow=c(2,3))
acf(fit_log.b$residuals, main ="ARIMA(2,2,1)", lag.max=50)
acf(fit_log.c$residuals, main ="ARIMA(1,3,1)", lag.max=50)
acf(fit_log.d$residuals, main ="ARIMA(1,2,2)", lag.max=50)
pacf(fit_log.b$residuals, main ="ARIMA(2,2,1)",lag.max=50)
pacf(fit_log.c$residuals, main ="ARIMA(1,3,1)",lag.max=50)
pacf(fit_log.d$residuals, main ="ARIMA(1,2,2)",lag.max=50)
par(mfrow=c(1,1))

# Check residuals of the final model:
hist(fit_log.a$residuals,prob = T,breaks = 20,col='deepskyblue1',main='Histogram residuals')
curve(dnorm(x, mean(fit_log.a$residuals), sd(fit_log.a$residuals)), add=TRUE, col="red", lwd=2)

par(mfrow=c(1,2))
qqnorm(fit_log.a$residuals,main='Q-Q plot residuals')
qqline(fit_log.a$residuals)

plot(c(fitted(fit_log.a)),c(fit_log.a$residuals),pch=20,col='red',xlab = 'Fitted Values',ylab='Residuals',main='Residual vs Fitted residuals')
abline(h=0)
par(mfrow=c(1,1))




## TASK 2 - SCENARIO GENERATION

steps <- 1 # predict 1 period ahead
scen <- 100 # number of scenarios
time = 1:length(data)

# Data structure to store the scenarios
scenarios <- matrix(NA,nrow =steps ,ncol =scen)
# Loop over scenarios and simulate with the arima model a prediction for the next period
for(w in 1:scen){
  scenarios[,w]  <- exp(simulate(fit_log.a, nsim=1, future=TRUE, seed=w))
}

# Plot the scenarios
colors <- rainbow(scen)
plot(time,data, col="dodgerblue2",  type="l",lty=1,lwd=2, main = "scenarios",
     ylab = "Price in ZIP2000 (DKK/m^2)", xlab="Time period")
for(w in 1:scen){
  points(112,scenarios[,w], col = colors[w],lwd=0.1)
}
#Zoom
ymin = min(scenarios)
ymax = max(scenarios)
plot(time,data, col="dodgerblue2",  type="l",lty=1,lwd=2, main = "scenarios",
     ylab = "Price in ZIP2000 (DKK/m^2)", xlab="Time period", xlim=c(105,112),ylim=c(ymin,ymax))
for(w in 1:scen){
  points(112,scenarios[,w], col = colors[w],lwd=0.1, xlim=c(105,112),ylim=c(ymin,ymax))
}

### SCENARIO REDUCTION ###


reduce <- 10 # amout of reduced scenarios
red <- pam(t(scenarios),reduce) # Clustering method: Partition Around Medioids (PAM)
red_scenarios <- red$medoids 


# Plot reduce set of scenarios
colors <- rainbow(reduce)

ymin_red = min(red_scenarios)
ymax_red = max(red_scenarios)

plot(time,data, col="dodgerblue2",  type="l",lty=1,lwd=2, main = "scenarios",
     ylab = "Price in ZIP2000 (DKK/m^2)", xlab="Time period")
for(w in 1:reduce){
  points(112,red_scenarios[w,], col = colors[w],lwd=0.1)
}

#Zoom
plot(time,data, col="dodgerblue2",  type="l",lty=1,lwd=2, main = "scenarios",
     ylab = "Price in ZIP2000 (DKK/m^2)", xlab="Time period", xlim=c(105,112),ylim=c(ymin_red,ymax_red))
for(w in 1:reduce){
  points(112,red_scenarios[w,], col = colors[w],lwd=0.1, xlim=c(105,112),ylim=c(ymin_red,ymax_red))
}

# Probability Distribution for reduced number of scenarios
prob <- 1/scen
prob_red <-0 
for (i in 1:reduce) {
  prob_red[i] <- prob *length(red$clustering[red$clustering==i])
}
print(prob_red)

red_scenarios_table <- cbind(red_scenarios,prob_red)
print(red_scenarios_table)     
