# ==============================================================================
# 11_maharashtra_hh_income.R
# PURPOSE: Compute HOUSEHOLD-LEVEL total agricultural income for Maharashtra
#          by combining Visit 1 (July–Dec 2018) and Visit 2 (Jan–June 2019).
#
# DESIGN:
#   - The same FSU (and hence the same households) are revisited in Visit 2
#     (matching pattern: "one and half" for Maharashtra Urban, "equal" for Rural)
#   - So the same HHID can appear in BOTH visits.
#   - We sum income across both visits to get ANNUAL agricultural income.
#
# OUTPUT:  mh_hh_income  -- one row per unique household in Maharashtra
# ==============================================================================

# ------ 0. Prerequisites ------------------------------------------------------
# Run 01_setup.R for packages and DATA_PATH, then this script is self-contained.
source("C:/Users/ashwin/Documents/Agrarian_ market acess/code/scripts/01_setup.R")

# Maharashtra state code in NSS 77th round
MH_STATE_CODE <- "27"

cat("=== MAHARASHTRA HOUSEHOLD-LEVEL AGRICULTURAL INCOME ===\n\n")

# ------ 1. Helper functions ---------------------------------------------------
read_clean <- function(filename) {
  path <- file.path(DATA_PATH, filename)
  if (!file.exists(path)) stop(paste("File missing:", filename))
  df <- haven::read_sav(path)
  names(df) <- toupper(names(df))
  df
}

safe_num <- function(x) as.numeric(as.character(haven::zap_labels(x)))

# ------ 2. Load Block 6 crop sales (Level 6 + Level 7, both visits) ----------
# Income = B6Q17 (total sale value, all disposals) per crop-sale row.
# We need both levels because B6Q17 lives in Level 07.

cat("[1] Loading Block 6 crop-sale data (both visits)...\n")

blk6_keys <- c("HHID", "B6Q1", "B6Q2")

load_blk6 <- function(f_l6, f_l7, visit_label) {
  l6 <- read_clean(f_l6)
  l7 <- read_clean(f_l7)

  # Keep only disposal/value columns from Level 07 to avoid column clashes
  l7_slim <- l7 %>%
    select(all_of(blk6_keys),
           matches("^B6Q1[5-9]$|^B6Q2[012]$")) %>%
    distinct(HHID, B6Q1, B6Q2, .keep_all = TRUE)  # safety: no dup join keys

  combined <- left_join(l6, l7_slim, by = blk6_keys) %>%
    mutate(
      visit        = visit_label,
      state_code   = stringr::str_pad(as.character(STATE), 2, pad = "0"),
      panel_id     = substr(as.character(HHID), 1, 8),
      qty_sold_all = safe_num(B6Q16),   # total qty sold across all disposals
      val_sold_all = safe_num(B6Q17),   # total sale value Rs. (all disposals)
      val_major    = safe_num(B6Q13),   # major disposal value (fallback)
      qty_major    = safe_num(B6Q12),   # major disposal qty  (fallback)
      crop_code    = as.character(B6Q2),
      crop_serial  = as.character(B6Q1)
    ) %>%
    # Exclude summary / total rows
    filter(crop_serial != "9", crop_code != "9999")

  cat("   Visit", visit_label, ":", nrow(combined), "total rows |",
      sum(combined$state_code == MH_STATE_CODE, na.rm = TRUE), "Maharashtra rows\n")
  combined
}

blk6_all <- bind_rows(
  load_blk6(
    "Visit 1 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav",
    "Visit 1 Level 07 (Block 6) output of crops produced during the period July - December 2018.sav",
    "1"
  ),
  load_blk6(
    "Visit 2 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav",
    "Visit 2 Level 07 (Block 6) output of crops produced during the period July - December 2018.sav",
    "2"
  )
)

# Filter to Maharashtra only at crop-sale level
blk6_mh <- blk6_all %>%
  filter(state_code == MH_STATE_CODE)

cat("   Maharashtra crop-sale rows (both visits):", nrow(blk6_mh), "\n")
cat("   Unique HHIDs across both visits:", n_distinct(blk6_mh$HHID), "\n\n")

# ------ 3. Compute sale income per crop-sale row ------------------------------
# Prefer B6Q17 (all disposals). Fall back to B6Q13 (major disposal only).

blk6_mh <- blk6_mh %>%
  mutate(
    sale_income = case_when(
      !is.na(val_sold_all) & val_sold_all > 0 ~ val_sold_all,
      !is.na(val_major)    & val_major    > 0 ~ val_major,
      TRUE                                    ~ 0
    )
  )

# ------ 4. Sum income across visits at HHID level ----------------------------
# This is the core step: group by HHID (NOT by HHID×visit)
# so that Visit 1 + Visit 2 income is combined for the same household.

cat("[2] Aggregating income across both visits to household level...\n")

hh_income_raw <- blk6_mh %>%
  group_by(panel_id) %>%
  summarise(
    total_agri_income  = sum(sale_income, na.rm = TRUE),   # Annual income from crop sales
    n_crops_sold       = n_distinct(crop_code),             # Crop diversity
    n_crop_sale_txns   = n(),                               # Total sale transactions (both visits)
    visits_present     = paste(sort(unique(visit)), collapse = "&"),  # "1", "2", or "1&2"
    .groups = "drop"
  )

cat("   Unique households (post-aggregation):", nrow(hh_income_raw), "\n")
cat("   Visit coverage breakdown:\n")
print(table(hh_income_raw$visits_present))
cat("\n")

# ------ 5. Load Block 4 (household characteristics: caste, MPCE, weight) -----
# Block 4 is canvassed once (Visit 1 Level-03). Use as household metadata.

cat("[3] Loading Block 4 (household demographics)...\n")

blk4_raw <- read_clean(
  "Visit1  Level - 03 (Block 4) - demographic and other particulars of household members  .sav"
)

blk4_mh <- blk4_raw %>%
  mutate(state_code = stringr::str_pad(as.character(STATE), 2, pad = "0")) %>%
  filter(state_code == MH_STATE_CODE) %>%
  mutate(
    social_group = safe_num(coalesce(
      if ("B4Q3" %in% names(.)) B4Q3 else NULL,
      if ("SOCIAL_GROUP" %in% names(.)) SOCIAL_GROUP else NULL
    )),
    mpce      = safe_num(coalesce(
      if ("B4Q5" %in% names(.)) B4Q5 else NULL,
      if ("MPCE" %in% names(.)) MPCE else NULL
    )),
    hh_weight = safe_num(MLT) / WEIGHT_DIVISOR,
    district  = as.character(DISTRICT),
    nsc       = as.character(NSC),          # sub-sample identifier (for SE)
    fsu_id    = as.character(FSU_SLNO),     # FSU (cluster) for survey design
    panel_id  = substr(as.character(HHID), 1, 8)
  ) %>%
  select(panel_id, state_code, district, fsu_id, nsc, social_group, mpce, hh_weight) %>%
  distinct(panel_id, .keep_all = TRUE)

cat("   Maharashtra households in Block 4:", nrow(blk4_mh), "\n\n")

# ------ 6. Load Block 5 (land) -----------------------------------------------
cat("[4] Loading Block 5 (land holdings)...\n")

blk5_raw <- read_clean(
  "Visit1  Level - 04 (Block 5) - particulars of land of the household and its operation during the period July- December 2018.sav"
)

blk5_mh <- blk5_raw %>%
  mutate(state_code = stringr::str_pad(as.character(STATE), 2, pad = "0")) %>%
  filter(state_code == MH_STATE_CODE) %>%
  mutate(
    land_area  = safe_num(B5Q3),
    lease_term = safe_num(B5Q10),
    panel_id   = substr(as.character(HHID), 1, 8)
  ) %>%
  group_by(panel_id) %>%
  summarise(
    total_land      = sum(land_area, na.rm = TRUE),
    is_sharecropper = as.integer(any(lease_term == 3, na.rm = TRUE)),
    .groups = "drop"
  )

cat("   Maharashtra households with land data:", nrow(blk5_mh), "\n\n")

# ------ 7. Load Block 13 (loans / debt) --------------------------------------
cat("[5] Loading Block 13 (loans)...\n")

blk13_raw <- read_clean(
  "Visit 1 Level 15 (Block 13) loans (cash and kind) payable as on the date of survey.sav"
)

blk13_mh <- blk13_raw %>%
  mutate(state_code = stringr::str_pad(as.character(STATE), 2, pad = "0")) %>%
  filter(state_code == MH_STATE_CODE) %>%
  mutate(
    loan_source  = safe_num(B13Q3),
    loan_amount  = safe_num(B13Q7),
    is_institutional   = as.integer(loan_source <= 13),
    is_informal_lender = as.integer(loan_source %in% c(15, 16, 20)),
    panel_id           = substr(as.character(HHID), 1, 8)
  ) %>%
  group_by(panel_id) %>%
  summarise(
    total_debt        = sum(loan_amount, na.rm = TRUE),
    has_any_loan      = as.integer(any(!is.na(loan_amount))),
    has_institutional = as.integer(any(is_institutional == 1, na.rm = TRUE)),
    has_informal      = as.integer(any(is_informal_lender == 1, na.rm = TRUE)),
    .groups = "drop"
  )

cat("   Maharashtra households with loan data:", nrow(blk13_mh), "\n\n")

# ------ 8. FINAL MERGE: one row per unique Maharashtra household --------------
cat("[6] Final merge to unique-household dataset...\n")

mh_hh_income <- hh_income_raw %>%
  # Block 4: demographics (caste, MPCE, weight)
  left_join(blk4_mh,  by = "panel_id") %>%
  # Block 5: land
  left_join(blk5_mh,  by = "panel_id") %>%
  # Block 13: debt
  left_join(blk13_mh, by = "panel_id") %>%
  # Derived columns
  mutate(
    caste_cat = case_when(
      social_group == 1 ~ "ST",
      social_group == 2 ~ "SC",
      social_group == 3 ~ "OBC",
      TRUE              ~ "General"
    ),
    caste_cat = factor(caste_cat, levels = c("General", "OBC", "SC", "ST")),

    land_size = cut(
      total_land,
      breaks = c(-Inf, 0, 0.5, 2, 5, Inf),
      labels = c("Landless", "Marginal", "Small", "Medium", "Large"),
      right = TRUE, include.lowest = TRUE
    ),

    # Log income (Rs.) -- for regression use
    log_agri_income = log(pmax(total_agri_income, 1)),
    log_mpce        = log(pmax(mpce, 1, na.rm = TRUE)),
    log_total_land  = log(pmax(total_land, 0.01, na.rm = TRUE)),

    # Debt-to-income ratio (capped at 10 to avoid Inf when income=0)
    dti_ratio = pmin(total_debt / pmax(total_agri_income, 1), 10)
  )

# ------ 9. Diagnostics --------------------------------------------------------
cat("\n========== FINAL DATASET SUMMARY ==========\n")
cat("Unique Maharashtra households:", nrow(mh_hh_income), "\n")
cat("Households in BOTH visits    :", sum(mh_hh_income$visits_present == "1&2"), "\n")
cat("Households in Visit 1 ONLY   :", sum(mh_hh_income$visits_present == "1"),   "\n")
cat("Households in Visit 2 ONLY   :", sum(mh_hh_income$visits_present == "2"),   "\n\n")

cat("--- Annual Crop-Sale Income (Rs.) ---\n")
print(summary(mh_hh_income$total_agri_income))

cat("\n--- By Caste Category ---\n")
mh_hh_income %>%
  group_by(caste_cat) %>%
  summarise(
    n          = n(),
    mean_income = round(mean(total_agri_income, na.rm = TRUE)),
    median_income = round(median(total_agri_income, na.rm = TRUE)),
    mean_debt  = round(mean(total_debt, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  print()

cat("\n--- By Land Size ---\n")
mh_hh_income %>%
  group_by(land_size) %>%
  summarise(
    n           = n(),
    mean_income = round(mean(total_agri_income, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  print()

# ------ 10. Save output -------------------------------------------------------
out_path <- "C:/Users/ashwin/Documents/Agrarian_ market acess/code/results/mh_hh_income.rds"
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
saveRDS(mh_hh_income, out_path)
cat("\n✅ Saved to:", out_path, "\n")
cat("   Rows:", nrow(mh_hh_income), "| Columns:", ncol(mh_hh_income), "\n")
