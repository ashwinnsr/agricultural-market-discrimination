# ==============================================================================
# 00_run_all.R - Master Script to Run All Analysis Steps
# ==============================================================================

# Set working directory to the location of this script if run interactively
try({
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
  } else {
    # Fallback if not in RStudio but sourced via command line
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      setwd(dirname(sub("--file=", "", file_arg[1])))
    }
  }
}, silent = TRUE)

message("Current working directory: ", getwd())
message("Starting full analysis pipeline...")

# List of scripts in order of execution
scriptsToRun <- c(
  "01_new_setup.r",
  "02_dataloading_FINAL.r",
  "03_cleaning.r",
  "04_updated_new_analysis.r",
  "05_visualisation_new.r",
  "06_analysis_ST_Land_Penalty.r",
  "07_mechanisms_analysis.r",
  "08_state_wise_agency.R"
)

# Keep track of execution time
start_time <- Sys.time()

# Source each script and log progress
for (script in scriptsToRun) {
  message(sprintf("\n\n%s", strrep("=", 80)))
  message(sprintf("▶ RUNNING: %s", script))
  message(sprintf("▶ TIME: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  message(sprintf("%s\n", strrep("=", 80)))
  
  script_start <- Sys.time()
  
  tryCatch({
    # Source the script inline to keep variables in global environment
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
