setwd('c:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts')
tryCatch({
  source('01_setup.R')
  source('02_dataloading_FINAL.r')
  source('03_cleaning.r')
  
  for (grp in c("SC", "ST", "OBC")) {
    cat("\n--- Testing General vs", grp, "---\n")
    df_pair <- df_final[df_final$caste_cat %in% c('General', grp), ]
    df_pair$is_general <- as.integer(df_pair$caste_cat == 'General')
    
    # 💥 THE CRITICAL NA DROP 💥
    df_pair <- df_pair[!is.na(df_pair$log_unit_price) & 
                       !is.na(df_pair$log_qty_sold) & 
                       !is.na(df_pair$log_mpce) & 
                       !is.na(df_pair$log_total_land), ]
                       
    cat("n observations:", nrow(df_pair), "\n")
  
    library(oaxaca)
    oaxaca_formula <- log_unit_price ~ log_qty_sold + log_mpce + log_total_land | is_general
    
    res <- try(oaxaca(oaxaca_formula, data=df_pair, R=NULL), silent=TRUE)
    if (inherits(res, "try-error")) {
       cat("ERROR:", res)
    } else {
       cat("SUCCESS! Total gap:", res$twofold$overall["coef", 1], "\n")
    }
  }
}, error = function(e){
  cat('GLOBAL SCRIPT ERROR:', e$message, '\n')
})
