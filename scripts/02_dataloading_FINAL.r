# ==============================================================================
# 02_dataloading_BULLETPROOF.R
# ==============================================================================

load_nss_data <- function() {
  cat("Loading NSS 77th Round Data (Bulletproof Mode)...\n")

  # 1. FILE PATHS
  file_social <- "Visit1  Level - 03 (Block 4) - demographic and other particulars of household members  .sav"
  file_crops_L6 <- "Visit 1 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav"
  file_crops_L7 <- "Visit 1 Level 07 (Block 6) output of crops produced during the period July - December 2018.sav"
  file_land <- "Visit1  Level - 04 (Block 5) - particulars of land of the household and its operation during the period July- December 2018.sav"

  # 2. HELPER: Load & Standardize Names
  read_clean <- function(f) {
    path <- file.path(DATA_PATH, f)
    if (!file.exists(path)) stop(paste("File missing:", f))
    df <- read_sav(path)
    names(df) <- toupper(names(df)) # Force Uppercase
    return(df)
  }

  # 3. LOAD DEMOGRAPHICS (Block 4)
  cat("  -> Loading Demographics...\n")
  blk4 <- read_clean(file_social)
  VARS_KEYS <- c("FSU_SLNO", "SSS", "HH_NO", "VISITNO")

  blk4_clean <- blk4 %>%
    select(all_of(VARS_KEYS),
      SOCIAL_GROUP = any_of(c("B4Q3", "SOCIAL_GROUP")),
      MPCE         = any_of(c("B4Q5", "MPCE")),
      DISTRICT     = any_of(c("DISTRICT")),
      WEIGHT       = any_of(c("MLT", "MULTIPLIER"))
    ) %>%
    distinct(across(all_of(VARS_KEYS)), .keep_all = TRUE)

  # 4. LOAD CROPS (L6 + L7)
  cat("  -> Loading Crops (L6 & L7)...\n")
  c6 <- read_clean(file_crops_L6)
  c7 <- read_clean(file_crops_L7)

  # Merge keys: HHID + Crop Serial No (B6Q1) + Crop Code (B6Q2)
  join_keys <- c(VARS_KEYS, "B6Q1", "B6Q2")

  # MERGE and KEEP EVERYTHING (No select() here to avoid dropping columns)
  blk6_full <- left_join(c6, c7, by = join_keys)

  # 5. LOAD LAND (Block 5)
  cat("  -> Loading Land...\n")
  blk5 <- read_clean(file_land)
  blk5_agg <- blk5 %>%
    select(all_of(VARS_KEYS), LEASE_TERMS = any_of("B5Q10"), LAND_AREA = any_of("B5Q3")) %>%
    group_by(across(all_of(VARS_KEYS))) %>%
    summarise(
      total_land = sum(LAND_AREA, na.rm = TRUE),
      is_sharecropper = as.integer(any(LEASE_TERMS == 3, na.rm = TRUE)),
      .groups = "drop"
    )

  # 6. FINAL MERGE
  cat("  -> Final Merge...\n")
  df_final_raw <- blk6_full %>%
    left_join(blk4_clean, by = VARS_KEYS) %>%
    left_join(blk5_agg, by = VARS_KEYS)

  # Lowercase all names for consistency
  names(df_final_raw) <- tolower(names(df_final_raw))

  # 7. SAFE RENAMING (The Fix)
  # We check for standard codes and rename them to our analysis variables.
  cat("  -> Renaming variables to standard format...\n")

  df_renamed <- df_final_raw %>%
    rename(
      # Map Crop Code
      crop_code = b6q2,

      # Map Quantity (Try B6Q12)
      qty_sold = any_of(c("b6q12", "quantity")),

      # Map Value (Try B6Q13)
      val_sold = any_of(c("b6q13", "value")),

      # Map Agency (Try Agency1 or B6Q15)
      agency = any_of(c("agency1", "b6q15", "agency")),

      # Map Reason for Sale
      reason_sale = any_of(c("b6q16", "reason_sale", "reason"))
    )

  cat(paste("Success! Loaded", nrow(df_renamed), "records.\n"))
  return(df_renamed)
}

df_raw <- load_nss_data()
