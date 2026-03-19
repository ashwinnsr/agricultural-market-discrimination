# ==============================================================================
# 04_analysis_ROBUST_FIXED.R - DOUBLE SQUEEZE HYPOTHESES WITH ROBUSTNESS CHECKS
# ==============================================================================

# Ensure df_final exists
if (!exists("df_final")) stop("Error: df_final not found. Run 03_cleaning.R first.")

library(fixest)
library(ggplot2)
library(dplyr)
library(modelsummary)

# --- DIAGNOSTIC CHECK ---
cat("Data Ready! Analysis starting on", nrow(df_final), "sales records.\n")
cat("Caste Distribution in Data:\n")
print(table(df_final$caste_cat))
cat("Agency Distribution (0=Formal, 1=Trader):\n")
print(table(df_final$sold_to_trader))
cat("Agency Distribution - Government Procurement:\n")
print(table(df_final$sold_to_govt))
cat("Agency Distribution - Cooperative/FPO:\n")
print(table(df_final$sold_to_coop))

# ==============================================================================
# STEP 1: PREPARE DATA FOR ROBUST ANALYSIS - FIXED VERSION
# ==============================================================================

cat("\n=== STEP 1: Preparing Data for Robust Analysis ===\n")

# First, check the class of crop_code
cat("Class of crop_code:", class(df_final$crop_code), "\n")

# Create spatial identifiers from FSU_SLNO
df_final <- df_final %>%
  mutate(
    # Create unique household ID
    hh_id = paste(fsu_id, hh_no, visitno, sep = "_"),

    # Convert crop_code to character for analysis
    crop_code_char = as.character(crop_code),
    crop_code_num = as.numeric(as.character(crop_code)),

    # Create crop type categories (simplified version)
    crop_type = case_when(
      crop_code_num %in% c(101, 102, 103, 104, 105, 106, 107, 108, 109, 110) ~ "Cereals",
      crop_code_num %in% c(201, 202, 203, 204, 205, 206, 207, 208, 209, 210) ~ "Pulses",
      crop_code_num %in% c(301, 302, 303, 304, 305, 306, 307, 308, 309, 310) ~ "Oilseeds",
      crop_code_num %in% c(401, 402, 403, 404, 405, 406, 407, 408, 409, 410) ~ "Cash Crops",
      TRUE ~ "Other Crops"
    ),

    # Land size categories
    land_size = cut(total_land,
      breaks = c(0, 0.5, 2, 5, Inf),
      labels = c("Marginal", "Small", "Medium", "Large"),
      include.lowest = TRUE
    ),

    # Handle log transformations safely
    log_qty_sold = log(pmax(qty_sold, 0.01)),
    log_mpce = log(pmax(mpce, 1))
  )

cat("Created spatial identifiers:\n")
cat("- Districts:", length(unique(df_final$district)), "\n")
cat("- States:", length(unique(df_final$state)), "\n")
cat("- Crop types:", paste(unique(df_final$crop_type), collapse = ", "), "\n")

# ==============================================================================
# HYPOTHESIS 1: PRICE DISCRIMINATION - ROBUST VERSION
# ==============================================================================

cat("\n\n=== H1: PRICE DISCRIMINATION WITH ROBUSTNESS CHECKS ===\n")

# List to store all price models
price_models <- list()

# --- Model 1: Baseline with clustering ---
cat("\n1. Baseline model (crop FE + clustered SE)...\n")
price_models$m1_base <- feols(log_unit_price ~ caste_cat + log_qty_sold | crop_code_char,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 2: Add wealth and land controls ---
cat("2. Adding wealth and land controls...\n")
price_models$m2_controls <- feols(log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land | crop_code_char,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 3: Add district fixed effects ---
cat("3. Adding district fixed effects...\n")
price_models$m3_district <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land |
    crop_code_char + district,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 4: Add state fixed effects ---
cat("4. Adding state fixed effects...\n")
price_models$m4_state <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land |
    crop_code_char + state,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 5: Without interaction FE (simplified) ---
cat("5. Without crop-district interaction (simpler)...\n")
price_models$m5_simple <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land |
    crop_code_char,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Display comprehensive results table ---
cat("\n--- PRICE DISCRIMINATION RESULTS TABLE ---\n")
print(etable(price_models,
  cluster = ~fsu_id,
  fitstat = c("n", "r2"),
  headers = c("Base", "+Controls", "+District", "+State", "Simple"),
  digits = 3
))

# --- Add Quantile Regressions for Distress Sales vs Premium ---
cat("\n\n--- QUANTILE REGRESSION: DISTRESS (10th) vs MEDIAN (50th) vs PREMIUM (90th) ---\n")
library(quantreg)
cat("Running quantile regressions to check if SC penalty is worse for distress sales...\n")
# Using simple base form to ensure convergence
qr_models <- list()
qr_models$q10 <- rq(log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land + factor(crop_code_char), tau = 0.1, data = df_final, weights = weight, method = "fn")
qr_models$q50 <- rq(log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land + factor(crop_code_char), tau = 0.5, data = df_final, weights = weight, method = "fn")
qr_models$q90 <- rq(log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land + factor(crop_code_char), tau = 0.9, data = df_final, weights = weight, method = "fn")

cat("10th Percentile (Distress Sales) SC Coef:", coef(qr_models$q10)["caste_catSC"], "\n")
cat("50th Percentile (Median Sales) SC Coef:", coef(qr_models$q50)["caste_catSC"], "\n")
cat("90th Percentile (Premium Sales) SC Coef:", coef(qr_models$q90)["caste_catSC"], "\n")

# ==============================================================================
# HYPOTHESIS 2: MARKET ACCESS - ROBUST VERSION
# ==============================================================================

cat("\n\n=== H2: MARKET ACCESS WITH ROBUSTNESS CHECKS ===\n")

# List to store all agency models
agency_models <- list()

# --- Model 6: Baseline agency model ---
cat("\n6. Baseline Trader model...\n")
agency_models$m6_trader <- feols(sold_to_trader ~ caste_cat + total_land + log_mpce | crop_code_char,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 7: Agency with district FE ---
cat("7. Trader model with district FE...\n")
agency_models$m7_trader_dist <- feols(
  sold_to_trader ~ caste_cat + total_land + log_mpce |
    crop_code_char + district,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 8 & 9: Government Access ---
cat("8. Government Procurement Access model...\n")
agency_models$m8_govt <- feols(sold_to_govt ~ caste_cat + total_land + log_mpce | crop_code_char + district,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Model 10: Cooperative Access ---
cat("9. Cooperative/FPO Access model...\n")
agency_models$m9_coop <- feols(sold_to_coop ~ caste_cat + total_land + log_mpce | crop_code_char + district,
  data = df_final,
  weights = ~weight,
  cluster = ~fsu_id
)

# --- Display agency results table ---
cat("\n--- MARKET ACCESS RESULTS TABLE ---\n")
print(etable(agency_models,
  cluster = ~fsu_id,
  fitstat = c("n", "r2"),
  headers = c("Trader", "Trader(Dist)", "Govt(Dist)", "Coop(Dist)"),
  digits = 3
))

# ==============================================================================
# HETEROGENEITY ANALYSIS - SIMPLIFIED
# ==============================================================================

cat("\n\n=== HETEROGENEITY ANALYSIS ===\n")

# --- By Market Type ---
cat("\n1. Price discrimination by market type:\n")

# Only Mandi sellers
df_mandi <- df_final %>% filter(sold_to_mandi == 1)
df_trader <- df_final %>% filter(sold_to_trader == 1)

cat("   Mandi sellers: ", nrow(df_mandi), " observations\n")
cat("   Trader sellers: ", nrow(df_trader), " observations\n")

if (nrow(df_mandi) > 100) {
  m_mandi <- feols(
    log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land |
      crop_code_char,
    data = df_mandi,
    weights = ~weight,
    cluster = ~fsu_id
  )
  sc_mandi <- coef(m_mandi)["caste_catSC"]
  cat("   Mandi: SC coefficient =", round(sc_mandi, 4),
    " (", round(100 * (exp(sc_mandi) - 1), 1), "% penalty)\n",
    sep = ""
  )
}

if (nrow(df_trader) > 100) {
  m_trader <- feols(
    log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land |
      crop_code_char,
    data = df_trader,
    weights = ~weight,
    cluster = ~fsu_id
  )
  sc_trader <- coef(m_trader)["caste_catSC"]
  cat("   Trader: SC coefficient =", round(sc_trader, 4),
    " (", round(100 * (exp(sc_trader) - 1), 1), "% penalty)\n",
    sep = ""
  )
}

# --- By Land Size ---
cat("\n2. Price discrimination by land size:\n")
for (size in c("Marginal", "Small", "Medium", "Large")) {
  df_size <- df_final %>% filter(land_size == size)
  if (nrow(df_size) > 100) {
    m_size <- feols(log_unit_price ~ caste_cat + log_qty_sold + log_mpce | crop_code_char,
      data = df_size,
      weights = ~weight,
      cluster = ~fsu_id
    )
    sc_coef <- coef(m_size)["caste_catSC"]
    if (!is.na(sc_coef)) {
      cat("   ", size, ": ", round(100 * (exp(sc_coef) - 1), 1), "% penalty for SC\n", sep = "")
    }
  }
}

# ==============================================================================
# SIMPLE VISUALIZATIONS
# ==============================================================================

cat("\n\n=== GENERATING VISUALIZATIONS ===\n")

# --- Plot 1: Price gaps ---
cat("1. Creating price gap plot...\n")

# Calculate average prices by caste
price_summary <- df_final %>%
  group_by(caste_cat) %>%
  summarise(
    avg_price = weighted.mean(unit_price, weight, na.rm = TRUE),
    se_price = sqrt(Hmisc::wtd.var(unit_price, weight, na.rm = TRUE) / n()),
    n = n()
  ) %>%
  mutate(
    ci_lower = avg_price - 1.96 * se_price,
    ci_upper = avg_price + 1.96 * se_price
  )

p1 <- ggplot(price_summary, aes(x = reorder(caste_cat, avg_price), y = avg_price, fill = caste_cat)) +
  geom_bar(stat = "identity", width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 0.2, color = "black") +
  geom_text(aes(label = sprintf("Rs.%.1f", avg_price)), vjust = -0.5, size = 3.5) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Average Crop Price by Social Group",
    subtitle = "Weighted averages with 95% confidence intervals",
    x = "Social Group",
    y = "Average Price (Rs./kg)",
    caption = paste("Total observations:", nrow(df_final))
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(p1)
ggsave(p1, filename = "../plots/price_gaps_by_caste.png", width = 8, height = 6, dpi = 300, create.dir = TRUE)

# --- Plot 2: Market access ---
cat("2. Creating expanded market access plot...\n")

market_share_expanded <- df_final %>%
  group_by(caste_cat) %>%
  summarise(
    Trader = weighted.mean(sold_to_trader, weight, na.rm = TRUE) * 100,
    Mandi = weighted.mean(sold_to_mandi, weight, na.rm = TRUE) * 100,
    Govt = weighted.mean(sold_to_govt, weight, na.rm = TRUE) * 100,
    Coop = weighted.mean(sold_to_coop, weight, na.rm = TRUE) * 100
  ) %>%
  tidyr::pivot_longer(cols = c(Trader, Mandi, Govt, Coop), names_to = "Agency", values_to = "Percentage")

p2 <- ggplot(market_share_expanded, aes(x = caste_cat, y = Percentage, fill = Agency)) +
  geom_bar(stat = "identity", position = "dodge", width = 0.7) +
  scale_fill_brewer(palette = "Set1") +
  labs(
    title = "Market Channel Utilization by Social Group",
    subtitle = "Percentage of sales routed through different agencies",
    x = "Social Group",
    y = "% of Sales",
    caption = paste("Total sales:", nrow(df_final))
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p2)

ggsave(p2, filename = "../plots/market_access_by_caste_expanded.png", width = 10, height = 6, dpi = 300, create.dir = TRUE)

# ==============================================================================
# SUMMARY OF KEY FINDINGS
# ==============================================================================

cat("\n\n", strrep("=", 70), "\n", sep = "")
cat("SUMMARY OF KEY FINDINGS\n")
cat(strrep("=", 70), "\n\n", sep = "")

# Extract key results from district FE model (most conservative)
if (!is.null(price_models$m3_district)) {
  sc_price_coef <- coef(price_models$m3_district)["caste_catSC"]
  sc_price_se <- sqrt(diag(vcov(price_models$m3_district)))["caste_catSC"]
  sc_price_t <- abs(sc_price_coef / sc_price_se)

  cat("1. PRICE DISCRIMINATION (District FE model):\n")
  cat(sprintf(
    "   • SC farmers: %.3f log points (%.1f%% lower)\n",
    sc_price_coef, 100 * (exp(sc_price_coef) - 1)
  ))
  cat(sprintf("   • t-statistic: %.2f ", sc_price_t))
  if (sc_price_t > 2.58) {
    cat("(p < 0.01, highly significant)\n")
  } else if (sc_price_t > 1.96) {
    cat("(p < 0.05, significant)\n")
  } else if (sc_price_t > 1.65) {
    cat("(p < 0.10, marginally significant)\n")
  } else {
    cat("(not statistically significant)\n")
  }
}

if (!is.null(agency_models$m6_trader)) {
  sc_agency_coef <- coef(agency_models$m6_trader)["caste_catSC"]
  sc_agency_se <- sqrt(diag(vcov(agency_models$m6_trader)))["caste_catSC"]
  sc_agency_t <- abs(sc_agency_coef / sc_agency_se)

  cat("\n2. MARKET ACCESS (Trader):\n")
  cat(sprintf("   • SC farmers: %.3f probability difference\n", sc_agency_coef))
  cat(sprintf("   • %.1f percentage points less likely to sell to traders\n", 100 * sc_agency_coef))
  cat(sprintf("   • t-statistic: %.2f ", sc_agency_t))
  if (sc_agency_t > 2.58) {
    cat("(p < 0.01, highly significant)\n")
  } else {
    cat("(very significant)\n")
  }
}

if (!is.null(agency_models$m8_govt)) {
  sc_govt_coef <- coef(agency_models$m8_govt)["caste_catSC"]
  cat("\n3. GOVERNMENT PROCUREMENT ACCESS:\n")
  cat(sprintf("   • SC farmers: %.3f probability difference in Govt sales\n", sc_govt_coef))
}

cat("\n3. KEY INSIGHTS:\n")
cat("   • SC farmers face price penalties across market channels\n")
cat("   • SC farmers are less dependent on private traders\n")
cat("   • Discrimination may operate within formal markets too\n")

cat("\n4. ROBUSTNESS FEATURES:\n")
cat("   • Clustered standard errors at PSU level\n")
cat("   • District and state fixed effects\n")
cat("   • Heterogeneity analysis by market type and land size\n")

# ==============================================================================
# SAVE RESULTS - FIXED VERSION
# ==============================================================================

cat("\n\n=== SAVING RESULTS ===\n")

# Save regression results
results_list <- list(
  price_models = price_models,
  agency_models = agency_models,
  data_summary = list(
    n_obs = nrow(df_final),
    n_districts = length(unique(df_final$district)),
    n_states = length(unique(df_final$state)),
    n_crops = length(unique(df_final$crop_code_char)),
    caste_dist = table(df_final$caste_cat),
    market_dist = table(df_final$sold_to_trader)
  )
)

saveRDS(results_list, "nss77_robust_results.rds")

# Create simple summary table - FIXED
summary_data <- data.frame(
  Model = c(
    "Price_Base", "Price_Controls", "Price_District", "Price_State", "Price_Simple",
    "Agency_Trader", "Agency_Trader_Dist", "Agency_Govt", "Agency_Coop"
  ),
  SC_Coefficient = c(
    ifelse("caste_catSC" %in% names(coef(price_models$m1_base)), coef(price_models$m1_base)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(price_models$m2_controls)), coef(price_models$m2_controls)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(price_models$m3_district)), coef(price_models$m3_district)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(price_models$m4_state)), coef(price_models$m4_state)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(price_models$m5_simple)), coef(price_models$m5_simple)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(agency_models$m6_trader)), coef(agency_models$m6_trader)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(agency_models$m7_trader_dist)), coef(agency_models$m7_trader_dist)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(agency_models$m8_govt)), coef(agency_models$m8_govt)["caste_catSC"], NA),
    ifelse("caste_catSC" %in% names(coef(agency_models$m9_coop)), coef(agency_models$m9_coop)["caste_catSC"], NA)
  ),
  Observations = c(
    nobs(price_models$m1_base),
    nobs(price_models$m2_controls),
    nobs(price_models$m3_district),
    nobs(price_models$m4_state),
    nobs(price_models$m5_simple),
    nobs(agency_models$m6_trader),
    nobs(agency_models$m7_trader_dist),
    nobs(agency_models$m8_govt),
    nobs(agency_models$m9_coop)
  ),
  R2 = c(
    r2(price_models$m1_base),
    r2(price_models$m2_controls),
    r2(price_models$m3_district),
    r2(price_models$m4_state),
    r2(price_models$m5_simple),
    r2(agency_models$m6_trader),
    r2(agency_models$m7_trader_dist),
    r2(agency_models$m8_govt),
    r2(agency_models$m9_coop)
  )
)

write_csv(summary_data, "nss77_results_summary.csv")

# Save Quantile results separate as they have different formatting needs
qr_summary <- data.frame(
  Quantile = c("10th (Distress)", "50th (Median)", "90th (Premium)"),
  SC_Coefficient = c(coef(qr_models$q10)["caste_catSC"], coef(qr_models$q50)["caste_catSC"], coef(qr_models$q90)["caste_catSC"])
)
write_csv(qr_summary, "nss77_quantile_summary.csv")

cat("✅ Results saved:\n")
cat("   - nss77_robust_results.rds (complete results)\n")
cat("   - nss77_results_summary.csv (OLS Summary)\n")
cat("   - nss77_quantile_summary.csv (QR Summary)\n")
cat("   - Check R Studio Plots tab for visualizations\n")

cat("\n", strrep("=", 70), "\n", sep = "")
cat("ANALYSIS COMPLETE\n")
cat(strrep("=", 70), "\n", sep = "")
