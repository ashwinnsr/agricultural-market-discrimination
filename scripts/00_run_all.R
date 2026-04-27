# ==============================================================================
# 00_run_all.R - Master Script to Run All Analysis Steps (Rewrite)
# ==============================================================================

# Set working directory to the location of this script
try({
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  } else {
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      setwd(dirname(sub("--file=", "", file_arg[1])))
    }
  }
}, silent = TRUE)

message("Current working directory: ", getwd())
message("Starting full analysis pipeline (Rewritten Architecture)...")

scriptsToRun <- c(
  "01_setup.R",
  "02_dataloading_FINAL.r",
  "03_cleaning.r",
  "04_descriptives.r",
  "05_price_regressions.R",
  "06_oaxaca.R",
  "07_agency_regressions.R",
  "08_visualisations.R",
  "09_mechanisms.R",
  "10_state_maps.R"
)

start_time <- Sys.time()

for (script in scriptsToRun) {
  message(sprintf("\n\n%s", strrep("=", 80)))
  if(!file.exists(script)) {
    message(sprintf("❌ Target script %s does not exist. Skipping...", script))
    next
  }
  message(sprintf("▶ RUNNING: %s", script))
  message(sprintf("▶ TIME: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  message(sprintf("%s\n", strrep("=", 80)))
  
  script_start <- Sys.time()
  
  tryCatch({
    source(script, echo = FALSE)
    
    script_end <- Sys.time()
    script_duration <- round(difftime(script_end, script_start, units = "mins"), 2)
    message(sprintf("\n✅ SUCCESS: %s (Took %s minutes)", script, script_duration))
    
  }, error = function(e) {
    message(sprintf("\n❌ ERROR in %s: %s", script, e$message))
    stop(sprintf("Pipeline halted at %s due to error.", script))
  })
}

end_time <- Sys.time()
total_duration <- round(difftime(end_time, start_time, units = "mins"), 2)

message(sprintf("\n\n%s", strrep("=", 80)))
message(sprintf("🎉 FULL ANALYSIS PIPELINE COMPLETED SUCCESSFULLY!"))
message(sprintf("Total duration: %s minutes", total_duration))
message(sprintf("%s\n", strrep("=", 80)))
