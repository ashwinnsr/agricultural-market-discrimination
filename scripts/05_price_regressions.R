# ==============================================================================
# 05_price_regressions.R
# H1: PRICE DISCRIMINATION ANALYSIS
# Tests whether social group predicts unit price received, conditional on
# crop type, quantity, wealth, land, and geographic fixed effects.
#
# Specifications:
#   M1: Baseline with crop FE + clustered SE
#   M2: Add wealth (MPCE) and land controls
#   M3: Add district FE (conservative benchmark)
#   M4: Add state FE
#   M5: Without qty control (upper-bound if qty is endogenous)
#   Q1-Q3: Quantile regressions at 10th, 50th, 90th percentiles
#   H1-H4: Heterogeneity by land size
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(fixest)
library(quantreg)
library(modelsummary)

cat("=== H1: PRICE DISCRIMINATION ANALYSIS ===\n")

# ==============================================================================
# PREP: Ensure factors and crop-district interactions exist
# ==============================================================================
df_reg <- df_final %>%
  mutate(
    crop_x_district = paste(crop_code, district, sep = "_"),
    crop_x_state    = paste(crop_code, state,    sep = "_"),
    visit_fac       = factor(visit)  # control for seasonal half-year
  ) %>%
  filter(!is.na(caste_cat), !is.na(log_unit_price), !is.na(weight))

cat("Regression sample:", nrow(df_reg), "observations\n")
cat("Caste distribution:\n")
print(table(df_reg$caste_cat))

# ==============================================================================
# OLS PRICE MODELS
# Reference category: General (set by factor levels in cleaning)
# ==============================================================================
price_models <- list()

cat("\n--- OLS Models ---\n")

# M1: Crop FE only
cat("M1: Crop FE + visit control...\n")
price_models$m1_base <- feols(
  log_unit_price ~ caste_cat + visit_fac | crop_code,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# M2: Add wealth and land controls
cat("M2: + MPCE and land...\n")
price_models$m2_controls <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# M3: Add district FE (conservative -- absorbs local market conditions)
cat("M3: + District FE...\n")
price_models$m3_district <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# M4: Add state FE (less granular, more observations)
cat("M4: + State FE...\n")
price_models$m4_state <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + state,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# M5: Without qty control (upper-bound estimate if qty is endogenous)
cat("M5: District FE, no qty control...\n")
price_models$m5_no_qty <- feols(
  log_unit_price ~ caste_cat + log_mpce + log_total_land + visit_fac | crop_code + district,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# M6: With MSP-eligible crop indicator (test: are gaps bigger in regulated markets?)
if ("msp_eligible" %in% names(df_reg)) {
  cat("M6: Interaction with MSP eligibility...\n")
  price_models$m6_msp <- feols(
    log_unit_price ~ caste_cat * msp_eligible + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
    data    = df_reg,
    weights = ~weight,
    cluster = ~fsu_id
  )
}

# Print main table
cat("\n=== OLS PRICE DISCRIMINATION TABLE ===\n")
print(etable(
  price_models[c("m1_base","m2_controls","m3_district","m4_state","m5_no_qty")],
  keep      = "caste_cat",
  fitstat   = c("n","r2","ar2"),
  headers   = c("M1:CropFE","M2:+Controls","M3:+District","M4:+State","M5:NoQty"),
  digits    = 3,
  se.below  = TRUE
))

# ==============================================================================
# QUANTILE REGRESSIONS
# Q10 = distress sales; Q50 = median; Q90 = premium
# ==============================================================================
cat("\n\n--- Quantile Regressions (10th / 50th / 90th) ---\n")
cat("(May take a few minutes; using Frisch-Newton algorithm)\n")

qr_models <- list()
for (tau in c(0.1, 0.5, 0.9)) {
  cat(sprintf("  Running quantile tau=%.1f...\n", tau))
  qr_df <- df_reg %>%
    group_by(crop_code) %>% filter(n() >= 10) %>% ungroup() %>%
    group_by(state) %>% filter(n() >= 10) %>% ungroup() %>%
    mutate(
      crop_code = factor(crop_code),
      state     = factor(state)
    ) %>% droplevels()

  qr_models[[paste0("q", tau*100)]] <- tryCatch(
    rq(
      log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land +
        crop_code + state,
      tau    = tau,
      data   = qr_df,
      weights = qr_df$weight,
      method = "fn"
    ),
    error = function(e) { cat("Error at tau=", tau, ":", e$message, "\n"); NULL }
  )
}

cat("\n=== QUANTILE REGRESSION RESULTS (SC Coefficients) ===\n")
for (nm in names(qr_models)) {
  if (!is.null(qr_models[[nm]])) {
    coefs <- coef(qr_models[[nm]])
    sc_coef <- coefs["caste_catSC"]
    st_coef <- coefs["caste_catST"]
    obc_coef <- coefs["caste_catOBC"]
    cat(sprintf("  %s: SC=%.3f (%.1f%%), ST=%.3f (%.1f%%), OBC=%.3f (%.1f%%)\n",
                nm,
                sc_coef,  100*(exp(sc_coef)-1),
                st_coef,  100*(exp(st_coef)-1),
                obc_coef, 100*(exp(obc_coef)-1)))
  }
}

# ==============================================================================
# HETEROGENEITY BY LAND SIZE
# ==============================================================================
cat("\n\n--- Heterogeneity: Price Discrimination by Land Size ---\n")

land_het_results <- data.frame()
for (sz in c("Landless","Marginal","Small","Medium","Large")) {
  df_sz <- df_reg %>% filter(land_size == sz)
  if (nrow(df_sz) < 200) {
    cat(sprintf("  %s: too few obs (%d), skipping\n", sz, nrow(df_sz)))
    next
  }
  m <- tryCatch(
    feols(
      log_unit_price ~ caste_cat + log_qty_sold + log_mpce + visit_fac | crop_code + district,
      data    = df_sz,
      weights = ~weight,
      cluster = ~fsu_id
    ),
    error = function(e) NULL
  )
  if (!is.null(m)) {
    for (grp in c("SC","ST","OBC")) {
      key <- paste0("caste_cat", grp)
      if (key %in% names(coef(m))) {
        est <- coef(m)[key]
        se  <- se(m)[key]
        land_het_results <- rbind(land_het_results, data.frame(
          land_size   = sz,
          group       = grp,
          estimate    = est,
          se          = se,
          ci_lo       = est - 1.96*se,
          ci_hi       = est + 1.96*se,
          pct_penalty = (exp(est)-1)*100,
          n_obs       = nobs(m)
        ))
        cat(sprintf("  %s | %-8s: %.3f log pts = %.1f%% penalty (n=%d)\n",
                    sz, grp, est, (exp(est)-1)*100, nobs(m)))
      }
    }
  }
}

# ==============================================================================
# SUMMARY OUTPUT
# ==============================================================================
cat("\n\n=== KEY FINDINGS SUMMARY ===\n")
cat(sprintf("%-30s | %10s | %10s | %10s\n", "Model", "SC effect", "ST effect", "OBC effect"))
cat(strrep("-", 65), "\n")

for (nm in names(price_models)) {
  m <- price_models[[nm]]
  sc  <- if ("caste_catSC"  %in% names(coef(m))) sprintf("%.3f", coef(m)["caste_catSC"])  else "N/A"
  st  <- if ("caste_catST"  %in% names(coef(m))) sprintf("%.3f", coef(m)["caste_catST"])  else "N/A"
  obc <- if ("caste_catOBC" %in% names(coef(m))) sprintf("%.3f", coef(m)["caste_catOBC"]) else "N/A"
  cat(sprintf("%-30s | %10s | %10s | %10s\n", nm, sc, st, obc))
}

# ==============================================================================
# SAVE
# ==============================================================================
dir.create("../results", showWarnings = FALSE)
saveRDS(list(ols=price_models, quantile=qr_models, heterogeneity=land_het_results),
        "../results/price_regression_results.rds")
write_csv(land_het_results, "../results/land_heterogeneity_price.csv")

cat("\n✅ Price regression results saved.\n")
