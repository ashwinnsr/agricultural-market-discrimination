setwd('c:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts')
tryCatch({
  source('01_setup.R')
  source('02_dataloading_FINAL.r')
  source('03_cleaning.r')
  cat('\n--- Running 05_price_regressions.R ---\n')
  source('05_price_regressions.R')
  cat('\n--- Running 06_oaxaca.R ---\n')
  source('06_oaxaca.R')
  cat('\nALL GOOD.\n')
}, error = function(e) {
  cat('FAIL:', e$message, '\n')
  quit(status=1)
})
