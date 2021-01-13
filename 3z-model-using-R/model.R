#install.packages(c('lmer4', 'broom'))
#library(lme4)

data <- read.csv('flat_file.csv')
data$dateInt <- as.integer(data$date)

for (l in levels(data$Province_State)){
  print(l)
  tmp <- data[ which(data$Province_State == l),]
  tmp <- tmp[ which(!is.na(tmp$population)),]
  tmp$FIPS_factor <- as.factor(tmp$FIPS)
  model <- lm(newCases ~ FIPS_factor + dateInt + pActive + herdImmune + dateInt*FIPS_factor, data= tmp)
  write.csv(as.data.frame(summary(model)$coef), paste("model_summaries/lm/",l,".csv"))
}


# cleanData <- data[ which(data$newCases > -1),]




# Drop anything with "Princess" or "Islands" or Guam or Puerto Rico in the name for $Province_State
