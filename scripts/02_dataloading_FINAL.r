# ==============================================================================
# 02_dataloading_FINAL.R
# Loads both Visit 1 and Visit 2 for Block 6 (L6+L7), Block 4, Block 5.
# Also loads Block 13 (loans), Block 14 (MSP), Block 7 (inputs) for merging.
# ==============================================================================

load_all_nss_data <- function() {
  cat("=== LOADING NSS 77TH ROUND DATA (BOTH VISITS) ===\n")
  R_PATH <- "C:/Program Files/R/R-4.5.3/bin/Rscript.exe"

  # Helper: read .sav and standardise column names to UPPERCASE
  read_clean <- function(filename) {
    path <- file.path(DATA_PATH, filename)
    if (!file.exists(path)) stop(paste("File missing:", filename))
    df <- read_sav(path)
    names(df) <- toupper(names(df))
    df
  }

  # Helper: safe as.numeric stripping labelled attributes
  safe_num <- function(x) as.numeric(as.character(x))

  # ===========================================================================
  # 1. BLOCK 6 CROP SALES  -- Level-06 (cols b6q1–b6q14) + Level-07 (b6q15–b6q22)
  #    The two levels share the same rows but have different columns.
  #    Join key: HHID + B6Q1 (crop serial) + B6Q2 (crop code)
  # ===========================================================================
  cat("\n[1] Loading Block 6 crop sales (both levels, both visits)...\n")

  blk6_join_keys <- c("HHID", "B6Q1", "B6Q2")

  load_blk6_visit <- function(f_l6, f_l7, visit_label) {
    l6 <- read_clean(f_l6)
    l7 <- read_clean(f_l7)
    # Level 7 has duplicate id cols + b6q15–b6q22; keep only unique cols
    l7_unique <- l7 %>% select(all_of(blk6_join_keys), matches("^B6Q1[5-9]|^B6Q2[0-2]"))
    combined <- left_join(l6, l7_unique, by = blk6_join_keys) %>%
      mutate(
        visit = visit_label,
        panel_id = substr(as.character(HHID), 1, 8)
      )
    cat("   Visit", visit_label, ":", nrow(combined), "rows loaded\n")
    combined
  }


  blk6 <- bind_rows(
    load_blk6_visit(
      "Visit 1 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav",
      "Visit 1 Level 07 (Block 6) output of crops produced during the period July - December 2018.sav",
      "1"
    ),
    load_blk6_visit(
      "Visit 2 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav",
      "Visit 2 Level 07 (Block 6) output of crops produced during the period July - December 2018.sav",
      "2"
    )
  )
  cat("   Combined Block 6:", nrow(blk6), "rows\n")

  # ===========================================================================
  # 2. BLOCK 4 HOUSEHOLD CHARACTERISTICS (Visit 1 only - canvassed once)
  # ===========================================================================
  cat("\n[2] Loading Block 4 household characteristics (Visit 1)...\n")
  blk4_raw <- read_clean("Visit1  Level - 03 (Block 4) - demographic and other particulars of household members  .sav")

  blk4 <- blk4_raw %>%
    mutate(
      social_group = safe_num(coalesce(
        if ("B4Q3" %in% names(.)) B4Q3 else NULL,
        if ("SOCIAL_GROUP" %in% names(.)) SOCIAL_GROUP else NULL
      )),
      mpce = safe_num(coalesce(
        if ("B4Q5" %in% names(.)) B4Q5 else NULL,
        if ("MPCE" %in% names(.)) MPCE else NULL
      )),
      hh_weight = safe_num(MLT) / WEIGHT_DIVISOR,
      panel_id = substr(as.character(HHID), 1, 8)
    ) %>%
    select(panel_id, STATE, DISTRICT, social_group, mpce, hh_weight) %>%
    distinct(panel_id, .keep_all = TRUE)
  cat("   Households:", nrow(blk4), "\n")

  # ===========================================================================
  # 3. BLOCK 5 LAND (Visit 1 -- July-Dec 2018 reference; Visit 1 Level-04)
  #    We use this for total operational land & sharecropping flag.
  # ===========================================================================
  cat("\n[3] Loading Block 5 land data (Visit 1)...\n")
  blk5_raw <- read_clean("Visit1  Level - 04 (Block 5) - particulars of land of the household and its operation during the period July- December 2018.sav")

  # Identify land area and lease terms columns
  land_col <- names(blk5_raw)[grepl("^B5Q3$", names(blk5_raw))]
  lease_col <- names(blk5_raw)[grepl("^B5Q10$", names(blk5_raw))]

  blk5 <- blk5_raw %>%
    mutate(
      land_area  = if (length(land_col) > 0) safe_num(.data[[land_col[1]]]) else NA_real_,
      lease_term = if (length(lease_col) > 0) safe_num(.data[[lease_col[1]]]) else NA_real_,
      panel_id   = substr(as.character(HHID), 1, 8)
    ) %>%
    group_by(panel_id) %>%
    summarise(
      total_land = sum(land_area, na.rm = TRUE),
      is_sharecropper = as.integer(any(lease_term == 3, na.rm = TRUE)),
      .groups = "drop"
    )
  cat("   Households with land data:", nrow(blk5), "\n")

  # ===========================================================================
  # 4. BLOCK 13 LOANS -- aggregate to household level
  # ===========================================================================
  cat("\n[4] Loading Block 13 loan data...\n")
  blk13_raw <- read_clean("Visit 1 Level 15 (Block 13) loans (cash and kind) payable as on the date of survey.sav")

  blk13 <- blk13_raw %>%
    mutate(
      loan_source = safe_num(B13Q3),
      loan_purpose = safe_num(B13Q4),
      loan_amount = safe_num(B13Q7),
      # Institutional sources: codes 01-13; Non-institutional: 14-20
      is_institutional = as.integer(loan_source <= 13),
      # Moneylender / trader lending
      is_informal_lender = as.integer(loan_source %in% c(15, 16, 20)),
      # Agricultural purpose loan
      is_agri_loan = as.integer(loan_purpose %in% c(1, 2)),
      panel_id = substr(as.character(HHID), 1, 8)
    ) %>%
    group_by(panel_id) %>%
    summarise(
      total_debt = sum(loan_amount, na.rm = TRUE),
      has_any_loan = as.integer(any(!is.na(loan_amount))),
      has_institutional = as.integer(any(is_institutional == 1, na.rm = TRUE)),
      has_informal_lender = as.integer(any(is_informal_lender == 1, na.rm = TRUE)),
      has_agri_loan = as.integer(any(is_agri_loan == 1, na.rm = TRUE)),
      .groups = "drop"
    )
  cat("   Households with loans:", nrow(blk13), "\n")

  # ===========================================================================
  # 5. BLOCK 14 MSP AWARENESS -- crop-household level
  # ===========================================================================
  cat("\n[5] Loading Block 14 MSP awareness data...\n")
  blk14_raw <- read_clean("Visit 1 Level 16 (Block 14) awareness about Minimum Support Price (MSP).sav")

  blk14 <- blk14_raw %>%
    mutate(
      crop_code = as.character(B14Q2),
      msp_aware = as.integer(safe_num(B14Q4) == 1), # 1 = aware
      sold_at_msp = as.integer(safe_num(B14Q6) != 9), # 9 = did not sell at MSP agency
      msp_qty = safe_num(B14Q7),
      msp_rate = safe_num(B14Q8),
      msp_skip_reason = safe_num(B14Q9),
      panel_id = substr(as.character(HHID), 1, 8)
    ) %>%
    # Aggregate to household level: aware of MSP for ANY crop grown
    group_by(panel_id) %>%
    summarise(
      any_msp_aware = as.integer(any(msp_aware == 1, na.rm = TRUE)),
      any_sold_at_msp = as.integer(any(sold_at_msp == 1, na.rm = TRUE)),
      # Reason for not selling at MSP (take modal reason per household)
      msp_skip_reason_mode = as.character(
        ifelse(all(is.na(msp_skip_reason)), NA_character_,
          names(which.max(table(msp_skip_reason[!is.na(msp_skip_reason)])))
        )
      ),
      .groups = "drop"
    )
  cat("   Households with MSP data:", nrow(blk14), "\n")

  # ===========================================================================
  # 6. BLOCK 7 INPUT COSTS -- aggregate paid-out expenses per crop per household
  # ===========================================================================
  cat("\n[6] Loading Block 7 input expenses (Visit 1)...\n")
  # We only load Visit 1 inputs to match Visit 1 crop data; Visit 2 available too
  blk7_v1 <- read_clean("Visit 1 Level 8 (Block 7) particulars of input and other expenses for crop production from July - December 2018.sav")
  blk7_v2 <- read_clean("Visit 2  Level 8 (Block 7) particulars of input and other expenses for crop production from July - December 2018.sav")

  process_blk7 <- function(df, visit_label) {
    df %>%
      mutate(
        crop_code = as.character(B7Q4),
        input_source = safe_num(B7Q5),
        paid_out_exp = safe_num(B7Q7),
        imputed_exp = safe_num(B7Q8),
        input_quality = safe_num(B7Q6),
        visit = visit_label,
        panel_id = substr(as.character(HHID), 1, 8)
      )
  }

  blk7 <- bind_rows(
    process_blk7(blk7_v1, "1"),
    process_blk7(blk7_v2, "2")
  ) %>%
    group_by(panel_id, visit) %>%
    summarise(
      total_paid_input_exp = sum(paid_out_exp, na.rm = TRUE),
      total_imputed_input_exp = sum(imputed_exp, na.rm = TRUE),
      # Share of inputs from institutional sources
      pct_institutional_input = mean(input_source %in% c(2, 4, 5, 6), na.rm = TRUE) * 100,
      .groups = "drop"
    )
  cat("   Input records aggregated:", nrow(blk7), "\n")

  # ===========================================================================
  # 7. FINAL MERGE
  # ===========================================================================
  cat("\n[7] Merging all blocks...\n")

  df_merged <- blk6 %>%
    # Standardise names to lowercase for analysis
    rename_with(tolower) %>%
    # Merge household-level data (Block 4, 5, 13, 14) via panel_id
    left_join(rename_with(blk4, tolower), by = c("panel_id", "state", "district")) %>%
    left_join(rename_with(blk5, tolower), by = "panel_id") %>%
    left_join(rename_with(blk13, tolower), by = "panel_id") %>%
    left_join(rename_with(blk14, tolower), by = "panel_id") %>%
    # Merge input costs (visit-specific)
    left_join(rename_with(blk7, tolower), by = c("panel_id", "visit"))

  cat("   Final merged dataset:", nrow(df_merged), "rows\n")
  cat("   Columns:", ncol(df_merged), "\n")

  return(df_merged)
}

df_raw <- load_all_nss_data()
cat("\n✅ Data loading complete.\n")
