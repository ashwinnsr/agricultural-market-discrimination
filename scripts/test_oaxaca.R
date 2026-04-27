setwd('c:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts')
tryCatch({
  source('01_setup.R')
  source('02_dataloading_FINAL.r')
  source('03_cleaning.r')
  
  # Check df_final
  df_pair <- df_final[df_final$caste_cat %in% c('General', 'SC'), ]
  df_pair$is_general <- as.integer(df_pair$caste_cat == 'General')
  
  cat('\nDimensions after filtering SC/Gen:\n')
  print(dim(df_pair))
  
  df_pair <- subset(df_pair, 
    is.finite(log_unit_price) & 
    is.finite(log_qty_sold) & 
    is.finite(log_mpce) & 
    is.finite(log_total_land)
  )
  
  cat('\nDimensions after is.finite drop:\n')
  print(dim(df_pair))
  
  library(oaxaca)
  oaxaca_formula <- log_unit_price ~ log_qty_sold + log_mpce + log_total_land | is_general
  
  res <- tryCatch(oaxaca(oaxaca_formula, data=df_pair, R=NULL), error=function(e) e)
  
  if (inherits(res, "error")) {
     cat('\nOAXACA ERROR IS:\n')
     print(res)
  } else {
     cat('\nOAXACA RAN SUCCESSFULLY!\n')
  }
  
}, error = function(e){
  cat('GLOBAL SCRIPT ERROR:', e$message, '\n')
})
