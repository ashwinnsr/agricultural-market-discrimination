# ==============================================================================
# 03_cleaning.R
# Cleans df_raw into df_final -- the analytic dataset.
# Key fixes from methodology review:
#   - Agency = b6q10 (NOT b6q11 which is satisfaction)
#   - Uses b6q18 (all-disposal rate) as preferred price measure
#   - Falls back to b6q13/b6q12 (major disposal only) when b6q18 missing
#   - Symmetric 1%-99% outlier trimming (not asymmetric 95th global)
#   - Correct crop taxonomy from codebook
#   - Satisfaction with sale (b6q11) kept as own variable for analysis
# ==============================================================================

if (!exists("df_raw")) stop("Run 02_dataloading_FINAL.r first.")

cat("=== CLEANING AND PREPARING ANALYTIC DATASET ===\n")

process_data <- function(df) {

  # --------------------------------------------------------------------------
  # STEP 1: SELECT AND RENAME CORE VARIABLES
  # Using confirmed column names from str() output
  # --------------------------------------------------------------------------
  cat("[1] Renaming and selecting core variables...\n")

  df_sel <- df %>%
    mutate(
      # --- IDENTIFIERS ---
      hhid        = as.character(hhid),
      fsu_id      = as.character(fsu_slno),
      crop_code   = as.character(b6q2),
      visit       = as.character(visit),

      # --- AGENCY OF SALE (b6q10) -- THE CORRECT VARIABLE ---
      # 1=Local trader, 2=APMC, 3=Input dealer, 4=Cooperative,
      # 5=Government, 6=FPO, 7=Private processor, 8=Contract, 9=Others
      # FIX: haven::zap_labels strips value labels from labelled integers
      # as.character() on a labelled int returns the LABEL string (e.g. "Local Trader")
      # which as.numeric() then converts to NA. zap_labels returns the raw number.
      agency_code = as.numeric(haven::zap_labels(b6q10)),

      # --- SATISFACTION WITH SALE (b6q11) -- SEPARATE OUTCOME ---
      # 1=satisfactory, 2=lower than market, 3=delayed payment,
      # 4=deductions for loans, 5=faulty weighing, 9=other
      satisfaction_code = as.character(as.numeric(haven::zap_labels(b6q11))),

      # --- PRODUCTION ---
      qty_produced     = as.numeric(b6q8),   # total quantity produced
      area_irrigated   = as.numeric(b6q4),
      area_unirrigated = as.numeric(b6q6),
      preharvest_area  = as.numeric(b6q9),

      # --- MAJOR DISPOSAL (b6q12, b6q13) ---
      qty_major  = as.numeric(b6q12),        # qty in major disposal
      val_major  = as.numeric(b6q13),        # value in major disposal (Rs.)

      # --- ALL DISPOSAL (b6q16, b6q17, b6q18) -- PREFERRED ---
      qty_all    = as.numeric(b6q16),        # total qty sold (all disposals)
      val_all    = as.numeric(b6q17),        # total value sold (Rs.)
      rate_all   = as.numeric(b6q18),        # Rs./unit from all disposals (pre-computed)

      # --- HOUSEHOLD CHARACTERISTICS ---
      social_group  = as.numeric(haven::zap_labels(social_group)),
      mpce          = as.numeric(haven::zap_labels(mpce)),
      weight        = as.numeric(hh_weight),
      state         = stringr::str_pad(as.character(state), 2, pad = "0"),
      district      = as.character(district),

      # --- LAND (from Block 5) ---
      total_land      = as.numeric(total_land),
      is_sharecropper = as.integer(is_sharecropper)
    )

  # --------------------------------------------------------------------------
  # STEP 2: CONSTRUCT UNIT PRICE
  # Prefer b6q18 (rate from ALL disposals) -- more complete.
  # Fall back to val_major / qty_major for the major disposal only.
  # --------------------------------------------------------------------------
  cat("[2] Constructing unit price...\n")

  df_price <- df_sel %>%
    mutate(
      # Primary: rate from all disposals
      unit_price = case_when(
        !is.na(rate_all) & rate_all > 0                     ~ rate_all,
        !is.na(qty_major) & qty_major > 0 & !is.na(val_major) ~ val_major / qty_major,
        TRUE                                                 ~ NA_real_
      ),
      # Which quantity to use for controls
      qty_sold = case_when(
        !is.na(qty_all) & qty_all > 0   ~ qty_all,
        !is.na(qty_major) & qty_major > 0 ~ qty_major,
        TRUE                             ~ NA_real_
      )
    ) %>%
    # Only include rows that are actual crop sales (not summary rows b6q1=="9")
    filter(as.character(b6q1) != "9") %>%
    filter(!is.na(unit_price) & unit_price > 0) %>%
    filter(!is.na(qty_sold)   & qty_sold > 0)

  cat("   Rows with valid price & qty:", nrow(df_price), "\n")

  # --------------------------------------------------------------------------
  # STEP 3: FILTER OUT DUMMY/TOTAL CROP CODES
  # Code "9999" = total/not applicable row
  # --------------------------------------------------------------------------
  df_price <- df_price %>% filter(crop_code != "9999")
  cat("   After removing summary rows:", nrow(df_price), "\n")

  # --------------------------------------------------------------------------
  # STEP 4: SOCIAL GROUP CATEGORIES
  # --------------------------------------------------------------------------
  cat("[3] Creating social group categories...\n")
  df_cats <- df_price %>%
    mutate(
      caste_cat = case_when(
        social_group == 1 ~ "ST",
        social_group == 2 ~ "SC",
        social_group == 3 ~ "OBC",
        TRUE              ~ "General"
      ),
      caste_cat = factor(caste_cat, levels = c("General","OBC","SC","ST"))
    )

  # --------------------------------------------------------------------------
  # STEP 5: AGENCY CATEGORIES (b6q10)
  # --------------------------------------------------------------------------
  cat("[4] Categorising market channels (b6q10)...\n")
  df_cats <- df_cats %>%
    mutate(
      agency_label = case_when(
        agency_code == 1 ~ "Local Trader",
        agency_code == 2 ~ "APMC Mandi",
        agency_code == 3 ~ "Input Dealer",
        agency_code == 4 ~ "Cooperative",
        agency_code == 5 ~ "Government",
        agency_code == 6 ~ "FPO",
        agency_code == 7 ~ "Private Processor",
        agency_code == 8 ~ "Contract Farming",
        agency_code == 9 ~ "Others",
        TRUE             ~ NA_character_
      ),
      # Binary indicators for key channels
      sold_to_trader    = as.integer(agency_code == 1),
      sold_to_apmc      = as.integer(agency_code == 2),
      sold_to_coop      = as.integer(agency_code == 4),
      sold_to_govt      = as.integer(agency_code == 5),
      sold_to_fpo       = as.integer(agency_code == 6),
      sold_to_formal    = as.integer(agency_code %in% c(2, 4, 5, 6, 7, 8)),  # non-trader formal
      sold_to_informal  = as.integer(agency_code %in% c(1, 3, 9))             # local/informal
    )

  # --------------------------------------------------------------------------
  # STEP 6: SATISFACTION CATEGORIES (b6q11)
  # --------------------------------------------------------------------------
  df_cats <- df_cats %>%
    mutate(
      satisfied         = as.integer(satisfaction_code == "1"),
      dissatisfied_price = as.integer(satisfaction_code == "2"),  # lower than market
      dissatisfied_delay = as.integer(satisfaction_code == "3"),  # delayed payment
      dissatisfied_loan  = as.integer(satisfaction_code == "4"),  # loan deduction
      dissatisfied_weigh = as.integer(satisfaction_code == "5")   # faulty weighing
    )

  # --------------------------------------------------------------------------
  # STEP 7: ATTACH CROP TAXONOMY (from setup)
  # --------------------------------------------------------------------------
  cat("[5] Attaching crop taxonomy...\n")
  df_cats <- df_cats %>%
    left_join(CROP_TAXONOMY, by = "crop_code") %>%
    mutate(
      crop_group  = replace_na(crop_group, "Other"),
      msp_eligible = replace_na(msp_eligible, FALSE)
    )

  # --------------------------------------------------------------------------
  # STEP 8: LAND SIZE CATEGORIES
  # --------------------------------------------------------------------------
  df_cats <- df_cats %>%
    mutate(
      land_size = cut(
        total_land,
        breaks = c(-Inf, 0, 0.5, 2, 5, Inf),
        labels = c("Landless","Marginal","Small","Medium","Large"),
        right  = TRUE, include.lowest = TRUE
      )
    )

  # --------------------------------------------------------------------------
  # STEP 9: LOG TRANSFORMATIONS
  # --------------------------------------------------------------------------
  df_cats <- df_cats %>%
    mutate(
      log_unit_price = log(unit_price),
      log_qty_sold   = log(qty_sold),
      log_mpce       = log(pmax(mpce, 1, na.rm = TRUE)),
      log_total_land = log(pmax(total_land, 0.01, na.rm = TRUE))
    )

  # --------------------------------------------------------------------------
  # STEP 10: TWO-STAGE SYMMETRIC OUTLIER REMOVAL
  # Stage 1: Global crop-level trimming (1st–99th percentile) -- removes
  #          data-entry errors (e.g. Rs. 100,000/kg for paddy)
  # Stage 2: State-crop trimming (1st–99th percentile) -- adjusts for
  #          genuine regional price differences
  # SYMMETRIC: same threshold on both tails (no asymmetric 95th on top)
  # --------------------------------------------------------------------------
  cat("[6] Two-stage symmetric outlier trimming (1%-99%)...\n")
  n_before <- nrow(df_cats)

  df_trimmed <- df_cats %>%
    # Stage 1: Global by crop
    group_by(crop_code) %>%
    mutate(
      g_p01 = quantile(unit_price, 0.01, na.rm = TRUE),
      g_p99 = quantile(unit_price, 0.99, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    filter(unit_price >= g_p01 & unit_price <= g_p99) %>%
    # Stage 2: State × crop
    group_by(crop_code, state) %>%
    mutate(
      sc_p01 = quantile(unit_price, 0.01, na.rm = TRUE),
      sc_p99 = quantile(unit_price, 0.99, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    filter(unit_price >= sc_p01 & unit_price <= sc_p99) %>%
    select(-g_p01, -g_p99, -sc_p01, -sc_p99)

  n_after <- nrow(df_trimmed)
  cat(sprintf("   Removed %d outlier rows (%.1f%% of data)\n",
              n_before - n_after, 100*(n_before - n_after)/n_before))

  # --------------------------------------------------------------------------
  # STEP 11: UNIQUE HOUSEHOLD-CROP-VISIT ID
  # --------------------------------------------------------------------------
  df_final_out <- df_trimmed %>%
    mutate(
      hh_id = paste(hhid, visit, sep = "_")
    )

  cat("\n✅ Final analytic dataset:\n")
  cat("   Rows:", nrow(df_final_out), "\n")
  cat("   Unique households:", n_distinct(df_final_out$hhid), "\n")
  cat("   States:", n_distinct(df_final_out$state), "\n")
  cat("   Crops:", n_distinct(df_final_out$crop_code), "\n")
  cat("   Visit distribution:\n")
  print(table(df_final_out$visit))
  cat("   Caste distribution:\n")
  print(table(df_final_out$caste_cat))
  cat("   Agency distribution:\n")
  print(table(df_final_out$agency_label, useNA="ifany"))

  return(df_final_out)
}

df_final <- process_data(df_raw)
