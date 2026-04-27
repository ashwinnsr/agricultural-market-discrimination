source("C:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts/01_setup.R")
source("C:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts/02_dataloading_FINAL.r")
source("C:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts/03_cleaning.r")

cat("\n--- Check NA in Caste by Visit ---\n")
print(table(df_final$visit, is.na(df_final$caste_cat)))

cat("\n--- Check NA in Land Size by Visit ---\n")
print(table(df_final$visit, is.na(df_final$land_size)))
