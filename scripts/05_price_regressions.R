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

# M6: Categorical land class FE instead of continuous log_total_land
cat("M6: Categorical land class FE (replaces log_total_land) + District FE...\n")
price_models$m6_landclass <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + visit_fac | crop_code + district + land_class_simple,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# M7: caste_cat x land_class_simple interaction
# Reference level is "Marginal" (smallest well-populated class; "Landless" was
# merged in during cleaning to avoid a rank-deficient design matrix).
# IMPORTANT: Treat M7 as exploratory. If any interaction cell has fewer than
# ~50 observations per caste (especially SC x Large), coefficient estimates
# will be driven by single influential households and SEs may still blow up
# even after the Landless fix. Inspect cell sizes below before reporting.
cat("M7: caste_cat x land_class_simple interaction + District FE...\n")
price_models$m7_caste_x_land <- feols(
  log_unit_price ~ caste_cat * land_class_simple + log_qty_sold + log_mpce + visit_fac | crop_code + district,
  data    = df_reg,
  weights = ~weight,
  cluster = ~fsu_id
)

# CELL-SIZE DIAGNOSTIC: must run before trusting any interaction coefficient
cat("\n[M7 CELL-SIZE DIAGNOSTIC] Observations per caste x land class cell:\n")
cell_sizes <- df_reg %>%
  filter(!is.na(land_class_simple)) %>%
  group_by(caste_cat, land_class_simple) %>%
  summarise(n = n(), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = land_class_simple, values_from = n, values_fill = 0)
print(cell_sizes)

# Flag any SC cell with < 50 obs as unreliable
sc_cells <- df_reg %>%
  filter(caste_cat == "SC", !is.na(land_class_simple)) %>%
  group_by(land_class_simple) %>%
  summarise(n_sc = n(), .groups = "drop")
sc_thin <- sc_cells %>% filter(n_sc < 50)
if (nrow(sc_thin) > 0) {
  cat("\n[WARNING] The following SC x land-class cells have < 50 observations.\n")
  cat("  Coefficients for these cells are likely driven by individual outlier households.\n")
  cat("  DO NOT report these as robust findings:\n")
  print(sc_thin)
}

# Print main OLS table including M6
cat("\n=== OLS PRICE DISCRIMINATION TABLE ===\n")
print(etable(
  price_models[c("m1_base","m2_controls","m3_district","m4_state","m5_no_qty","m6_landclass")],
  keep      = "caste_cat",
  fitstat   = c("n","r2","ar2"),
  headers   = c("M1:CropFE","M2:+Controls","M3:+District","M4:+State","M5:NoQty","M6:LandClassFE"),
  digits    = 3,
  se.below  = TRUE
))

# Print M7 interaction table & run joint F-test
cat("\n=== M7 INTERACTION: CASTE x LAND CLASS ===\n")
print(etable(
  price_models$m7_caste_x_land,
  keep      = "caste_cat",
  fitstat   = c("n","r2"),
  digits    = 3,
  se.below  = TRUE
))

cat("\n[F-TEST] Joint significance of caste_cat x land_class_simple interaction terms:\n")
cat("NOTE: Interpret with caution. If individual SEs for specific cells (e.g. SC x Large)\n")
cat("are still very large (>10x the coefficient), the VCOV matrix for that block may still\n")
cat("be ill-conditioned, making the Wald statistic unreliable even if it returns a p-value.\n")
cat("The F-test should only be treated as informative once the cell-size diagnostic above\n")
cat("confirms no thin cells (< 50 obs per caste per class) survive into the model.\n")
int_terms <- grep("caste_cat.*:land_class_simple", names(coef(price_models$m7_caste_x_land)), value = TRUE)
if (length(int_terms) > 0) {
  print(wald(price_models$m7_caste_x_land, keep = int_terms))
} else {
  cat("  No interaction terms found in model. Check factor levels.\n")
}

# ==============================================================================
# DIAGNOSTIC: ST geographic concentration (Fix 6)
# If ST farmers are clustered in specific low-price districts, district FE
# absorbs the caste-correlated price variation that M4 (state FE) reveals.
# ==============================================================================
df_reg_diag <- df_reg %>%
  mutate(state_dist = paste(state, district, sep = "_"))

st_district_conc <- df_reg_diag %>%
  filter(caste_cat == "ST") %>%
  group_by(state_dist) %>%
  summarise(n_st = n(), .groups = "drop") %>%
  arrange(desc(n_st)) %>%
  mutate(cum_share = cumsum(n_st) / sum(n_st))

cat("\n=== DIAGNOSTIC: ST GEOGRAPHIC CONCENTRATION ===\n")
cat(sprintf("ST observations are located in %d distinct state-districts (out of %d total districts in sample).\n",
            n_distinct(df_reg_diag$state_dist[df_reg_diag$caste_cat == "ST"]),
            n_distinct(df_reg_diag$state_dist)))

if (nrow(st_district_conc) > 0) {
  idx_50 <- min(which(st_district_conc$cum_share >= 0.5))
  idx_80 <- min(which(st_district_conc$cum_share >= 0.8))
  cat(sprintf("  50%% of all ST obs are concentrated in the top %d state-districts.\n", idx_50))
  cat(sprintf("  80%% of all ST obs are concentrated in the top %d state-districts.\n", idx_80))
  
  st_districts <- st_district_conc %>% filter(cum_share <= 0.5) %>% pull(state_dist)
  
  cat("\nMean log unit price by caste in ST-concentrated districts (top 50% ST obs):\n")
  mean_prices_conc <- df_reg_diag %>%
    filter(state_dist %in% st_districts) %>%
    group_by(caste_cat) %>%
    summarise(
      mean_log_price = weighted.mean(log_unit_price, weight, na.rm=TRUE),
      n_obs = n(),
      .groups = "drop"
    )
  print(mean_prices_conc)
  
  cat("\nMean log unit price by caste in non-ST-concentrated districts:\n")
  mean_prices_nonconc <- df_reg_diag %>%
    filter(!(state_dist %in% st_districts)) %>%
    group_by(caste_cat) %>%
    summarise(
      mean_log_price = weighted.mean(log_unit_price, weight, na.rm=TRUE),
      n_obs = n(),
      .groups = "drop"
    )
  print(mean_prices_nonconc)
}
cat("================================================\n\n")

# ==============================================================================
# QUANTILE REGRESSIONS
# Q10 = distress sales; Q50 = median; Q90 = premium
# ==============================================================================
cat("\n\n--- Quantile Regressions (10th / 50th / 90th) ---\n")
cat("(May take a few minutes; using Frisch-Newton algorithm)\n")

qr_models <- list()
qr_boot_ses <- list()
B <- 100  # Number of bootstrap replications for cluster bootstrap

set.seed(2024)

for (tau in c(0.1, 0.5, 0.9)) {
  cat(sprintf("  Running quantile tau=%.1f...\n", tau))
  qr_df <- df_reg %>%
    group_by(crop_group) %>% filter(n() >= 10) %>% ungroup() %>%
    group_by(state) %>% filter(n() >= 10) %>% ungroup() %>%
    mutate(
      crop_group = factor(crop_group),
      state      = factor(state)
    ) %>% droplevels()

  # Fit original model
  m_orig <- tryCatch(
    rq(
      log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land +
        crop_group + state,
      tau    = tau,
      data   = qr_df,
      weights = qr_df$weight,
      method = "fn"
    ),
    error = function(e) { cat("  Error at tau=", tau, ":", e$message, "\n"); NULL }
  )
  
  if (is.null(m_orig)) next
  qr_models[[paste0("q", tau*100)]] <- m_orig
  
  # Run cluster bootstrap (resample FSUs)
  cat(sprintf("    Computing cluster-bootstrap standard errors (B=%d)...\n", B))
  fsu_indices <- split(seq_len(nrow(qr_df)), qr_df$fsu_id)
  
  boot_res <- replicate(B, {
    sampled_fsus <- sample(names(fsu_indices), length(fsu_indices), replace = TRUE)
    boot_idx <- unlist(fsu_indices[sampled_fsus], use.names = FALSE)
    boot_sample <- qr_df[boot_idx, ]
    tryCatch({
      fit <- rq(
        log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land +
          crop_group + state,
        tau    = tau,
        data   = boot_sample,
        weights = boot_sample$weight,
        method = "fn"
      )
      cf <- coef(fit)
      c(
        SC  = if ("caste_catSC"  %in% names(cf)) as.numeric(cf["caste_catSC"])  else NA_real_,
        ST  = if ("caste_catST"  %in% names(cf)) as.numeric(cf["caste_catST"])  else NA_real_,
        OBC = if ("caste_catOBC" %in% names(cf)) as.numeric(cf["caste_catOBC"]) else NA_real_
      )
    }, error = function(e) c(SC = NA_real_, ST = NA_real_, OBC = NA_real_))
  })
  
  # Calculate empirical standard errors (SD of bootstrap coefficients)
  boot_se_sc  <- sd(boot_res["SC", ], na.rm = TRUE)
  boot_se_st  <- sd(boot_res["ST", ], na.rm = TRUE)
  boot_se_obc <- sd(boot_res["OBC", ], na.rm = TRUE)
  
  qr_boot_ses[[paste0("q", tau*100)]] <- c(SC = boot_se_sc, ST = boot_se_st, OBC = boot_se_obc)
}

cat("\n=== QUANTILE REGRESSION RESULTS (with cluster-bootstrap SEs) ===\n")
for (nm in names(qr_models)) {
  if (!is.null(qr_models[[nm]])) {
    coefs <- coef(qr_models[[nm]])
    sc_coef <- coefs["caste_catSC"]
    st_coef <- coefs["caste_catST"]
    obc_coef <- coefs["caste_catOBC"]
    
    sc_se  <- qr_boot_ses[[nm]]["SC"]
    st_se  <- qr_boot_ses[[nm]]["ST"]
    obc_se <- qr_boot_ses[[nm]]["OBC"]
    
    # Calculate p-values based on normal approximation of bootstrap distribution
    sc_p  <- 2 * (1 - pnorm(abs(sc_coef / sc_se)))
    st_p  <- 2 * (1 - pnorm(abs(st_coef / st_se)))
    obc_p <- 2 * (1 - pnorm(abs(obc_coef / obc_se)))
    
    cat(sprintf("  %s:\n", nm))
    cat(sprintf("    SC  = %+.3f (%+5.1f%%) | SE = %.3f | p = %.4f\n", sc_coef, 100*(exp(sc_coef)-1), sc_se, sc_p))
    cat(sprintf("    ST  = %+.3f (%+5.1f%%) | SE = %.3f | p = %.4f\n", st_coef, 100*(exp(st_coef)-1), st_se, st_p))
    cat(sprintf("    OBC = %+.3f (%+5.1f%%) | SE = %.3f | p = %.4f\n", obc_coef, 100*(exp(obc_coef)-1), obc_se, obc_p))
  }
}

# ==============================================================================
# HETEROGENEITY BY LAND SIZE
# ==============================================================================
cat("\n\n--- Heterogeneity: Price Discrimination by Land Size ---\n")

land_het_results <- data.frame()
for (sz in c("Marginal", "Small", "Semi-Medium", "Medium", "Large")) {
  df_sz <- df_reg %>% filter(land_class_simple == sz)
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
