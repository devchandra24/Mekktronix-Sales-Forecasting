#Used to estimate sMAPE
smape_cal <- function(outsample, forecasts){
  outsample <- as.numeric(outsample)
  forecasts<-as.numeric(forecasts)
  smape <- (abs(outsample-forecasts))/(abs(outsample)+abs(forecasts))
  return(smape)
}

library(zoo)
library(forecast)
library(tseries)
library(ggplot2)

# Univariate baseline solution using naive base 
require(dplyr)
setwd("/Users/akshaykhatter/Desktop/naive baseline 3")

# Load data
data<-read.csv("yds_train2018.csv", as.is = T)
submission <- read.csv("yds_test2018.csv", as.is = T)
prodexp <- read.csv("promotional_expense.csv", as.is = T)
#holidays <- read.csv("yds_test2018.csv", as.is = T)

# Roll data at monthly resolution
data_monthly <- data %>% group_by( Year, Month, Product_ID, Country) %>% summarise(monthly_sales=sum(Sales))


# Set-up forecasting
uniqCountry <-  unique(data_monthly$Country)
ydsnaiveSumission <- NULL
trainForecastlastpoint <- NULL
for(country in uniqCountry) {
  
  # Filter data based on country and product ID
  data_month_country <- data_monthly %>%
                        select( Year, Month, Country, Product_ID, monthly_sales) %>% 
                        filter(Country==country)
  
  promo_country <- prodexp %>%
    select( Year, Month, Country, Product_Type, Expense_Price) %>% 
    filter(Country==country)
  
  # Unique Product
  uniqProduct <-  unique(data_month_country$Product_ID)                          
  
  for(product in uniqProduct){
    
    # Filter data based on country and product ID
    data_month_filterd <- data_month_country %>%
                          select( Year, Month, Country, Product_ID, monthly_sales) %>% 
                          filter(Product_ID==product)
    
    promo_filterd <- promo_country %>%
      select( Year, Month, Country, Product_Type, Expense_Price) %>% 
      filter(Product_Type==product)
    
  
    
    
    # Use Last point as forecast
    #lastPointValue <- data_month_filterd$monthly_sales[length(data_month_filterd$monthly_sales)]
    
    # Forecast
    submission_filter<-submission %>%
      select(S_No, Year, Month, Country, Product_ID, Sales) %>% 
      filter(Country==country & Product_ID==product)
    horizon <- dim(submission_filter)[1]
    
    #THE STATISTICAL FORECASTING METHOD USED IS ARIMA MODEL OF FORECASTING
    
    data_month_filterd$Date <- as.yearmon(paste(data_month_filterd$Year, data_month_filterd$Month), "%Y %m")
    xi<-ts(data_month_filterd$monthly_sales, frequency = 3, start = first(data_month_filterd$Date))
    data_deseason <- stl(xi, t.window=50, s.window='periodic', robust=TRUE) 
    f <- forecast(data_deseason, h=horizon,
                  forecastfunction=function(x,h,level){
                    fit <- Arima(x, order=c(1,1,7),  include.mean=FALSE)
                    return(forecast(fit,h=horizon,level=level))})
    
    submission_filter$Sales <- as.numeric(f$mean)
    
    ydsnaiveSumission <- rbind(ydsnaiveSumission, submission_filter)
    #trainForecastlastpoint <- rbind(trainForecastlastpoint, data.frame(subset(data_month_filterd, select=-c(monthly_sales)), as.numeric(f$mean)))
  }
}

# Test SMAPE Function
SMAPE_ERR <- mean(smape_cal(outsample=data_monthly$monthly_sales, forecasts=trainForecastlastpoint$lastPointValue))

ydsnaiveSumission<-ydsnaiveSumission[order(ydsnaiveSumission$S_No),]

# Write final submission
write.csv(ydsnaiveSumission, file="yds_submission2018.csv", row.names = F)
