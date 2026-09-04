# NOTE ON METHODOLOGY:
# 1. This uses a Neumark (1988) / Oaxaca (1973) two-fold decomposition with
#    General Caste as the reference structure:
#      Explained   = (X_A - X_B) * Beta_A  (endowment difference at General returns)
#      Unexplained = X_B * (Beta_A - Beta_B) (return difference / discrimination)
# 2. Within-pair regressions use `crop_group` FE (18 categories) rather than
#    `crop_code` FE (142 categories) because specific crop codes have small cell sizes
#    in caste-subsamples that cause linear dependency and NA predictions in predict().
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(dplyr)
library(fixest)

cat("=== OAXACA-BLINDER DECOMPOSITION OF PRICE GAP ===\n\n")

run_manual_oaxaca <- function(group_label, include_land = TRUE) {
  land_str <- if (include_land) "with land" else "WITHOUT land"
  cat(sprintf("--- General vs %s (%s) ---\n", group_label, land_str))
  
  # Formula used for the two regressions
  formula_rhs <- if (include_land) {
    "~ log_qty_sold + log_mpce + log_total_land + factor(crop_group)"
  } else {
    "~ log_qty_sold + log_mpce + factor(crop_group)"
  }
  
  # Create the dataset
  # NOTE: filter weight > 0 here explicitly -- feols silently drops 0-weight
  # rows, which would otherwise cause a length mismatch between predict()
  # output (n rows used in fit) and df_A$weight (n + k rows including dropped).
  df_pair <- df_final %>%
    filter(caste_cat %in% c("General", group_label)) %>%
    mutate(
      is_general = as.integer(caste_cat == "General"),
      caste_cat  = factor(caste_cat)
    ) %>%
    filter(
      is.finite(log_unit_price),
      is.finite(log_qty_sold),
      is.finite(log_mpce),
      is.finite(log_total_land),
      !is.na(crop_group),
      !is.na(weight),
      weight > 0         # match what feols uses internally
    )
  
  if (nrow(df_pair) < 500) {
    cat("  Insufficient observations, skipping.\n\n")
    return(NULL)
  }
  
  n_gen <- sum(df_pair$is_general == 1)
  n_com <- sum(df_pair$is_general == 0)
  cat(sprintf("  n = %d (General: %d, %s: %d)\n", nrow(df_pair), n_gen, group_label, n_com))
  
  # Ensure factors align properly
  df_pair$crop_group <- factor(df_pair$crop_group)
  
  # Split datasets
  df_A <- df_pair %>% filter(is_general == 1)  # General
  df_B <- df_pair %>% filter(is_general == 0)  # Comparison
  
  # Fit models
  form <- as.formula(paste("log_unit_price", formula_rhs))
  mod_A <- feols(form, data = df_A, weights = ~weight)
  mod_B <- feols(form, data = df_B, weights = ~weight)
  
  # Get common coefficients. If a crop group is missing in B, we substitute beta=0.
  coef_A <- coef(mod_A)
  coef_B <- coef(mod_B)
  
  all_vars <- union(names(coef_A), names(coef_B))
  
  # Means of variables for both groups (weighted)
  # Instead of manually extracting design matrix which can be brittle,
  # we calculate the predicted values for counterfactuals!
  
  # Oaxaca threefold (Viewpoint of Reference, Group A = General):
  # Explained = (X_A - X_B) * Beta_B
  # Unexplained = X_B * (Beta_A - Beta_B)
  # Interaction = (X_A - X_B) * (Beta_A - Beta_B)
  # Wait, standard simpler approach is Neumark or Two-fold (Viewpoint of General):
  # Explained = (X_A - X_B) * Beta_A
  # Unexplained = X_B * (Beta_A - Beta_B)
  
  # Weighted aggregation from fitted values to group means.
  # IMPORTANT: regressions (mod_A, mod_B) are weighted by ~weight, so the
  # group means must also be weighted -- otherwise the decomposition arithmetic
  # is internally inconsistent and can produce >100% explained shares.
  #
  # Three quantities (Neumark two-fold decomposition):
  #   E_A           = weighted mean fitted price for General under General returns
  #   E_B           = weighted mean fitted price for comparison group under own returns
  #   E_B_given_A   = weighted mean fitted price for comparison group IF they had General returns
  #                   (the counterfactual -- same characteristics, different coefficients)
  #
  #   total_gap   = E_A - E_B          (raw gap)
  #   explained   = E_A - E_B_given_A  = (X_A - X_B) * Beta_A  (endowment difference)
  #   unexplained = E_B_given_A - E_B  = X_B * (Beta_A - Beta_B) (coefficient difference / discrimination)

  # E_A: General group, General model
  pred_A <- predict(mod_A)
  ok_A   <- !is.na(pred_A)
  E_A    <- weighted.mean(pred_A[ok_A], w = df_A$weight[ok_A])

  # E_B: Comparison group, own model
  pred_B <- predict(mod_B)
  ok_B   <- !is.na(pred_B)
  E_B    <- weighted.mean(pred_B[ok_B], w = df_B$weight[ok_B])

  # E_B_given_A: Comparison group characteristics, but General model coefficients
  E_B_given_A <- tryCatch({
    pred_BgA <- predict(mod_A, newdata = df_B)
    ok_BgA   <- !is.na(pred_BgA)
    weighted.mean(pred_BgA[ok_BgA], w = df_B$weight[ok_BgA])
  }, error = function(e) { NA_real_ })

  if (is.na(E_B_given_A)) {
    cat("  Prediction failed due to factor mismatch, skipping.\n")
    return(NULL)
  }
  
  total_gap   <- E_A - E_B
  explained   <- E_A - E_B_given_A        # (X_A - X_B)*Beta_A
  unexplained <- E_B_given_A - E_B        # X_B*(Beta_A - Beta_B)
  
  cat(sprintf("  Raw log wage gap (General - %s): %.4f (%.1f%%)\n",
              group_label, total_gap, 100*(exp(total_gap)-1)))
  cat(sprintf("  EXPLAINED   (endowment differences):  %.4f (%.1f%% of gap)\n",
              explained, 100*explained/total_gap))
  cat(sprintf("  UNEXPLAINED (discrimination residual): %.4f (%.1f%% of gap)\n\n",
              unexplained, 100*unexplained/total_gap))

  list(
    group       = group_label,
    total_gap   = total_gap,
    explained   = explained,
    unexplained = unexplained,
    interaction = NA
  )
}

# Baseline (with land control)
oaxaca_sc  <- run_manual_oaxaca("SC",  include_land = TRUE)
oaxaca_st  <- run_manual_oaxaca("ST",  include_land = TRUE)
oaxaca_obc <- run_manual_oaxaca("OBC", include_land = TRUE)

# Sensitivity: EXCLUDING land control (to bound endowment laundering)
cat("\n=== SENSITIVITY TEST: OAXACA DECOMPOSITION WITHOUT LAND CONTROL ===\n\n")
oaxaca_sc_noland  <- run_manual_oaxaca("SC",  include_land = FALSE)
oaxaca_st_noland  <- run_manual_oaxaca("ST",  include_land = FALSE)
oaxaca_obc_noland <- run_manual_oaxaca("OBC", include_land = FALSE)

make_summary_df <- function(sc, st, obc, label) {
  bind_rows(
    lapply(list(sc, st, obc), function(x) {
      if (is.null(x)) return(NULL)
      data.frame(
        Spec            = label,
        Group           = x$group,
        Total_Gap_log   = round(x$total_gap,   4),
        Total_Gap_pct   = round(100*(exp(x$total_gap)-1), 2),
        Explained_log   = round(x$explained,   4),
        Explained_pct   = round(100*x$explained/x$total_gap, 1),
        Unexplained_log = round(x$unexplained, 4),
        Unexplained_pct = round(100*x$unexplained/x$total_gap, 1)
      )
    })
  )
}

oaxaca_summary <- make_summary_df(oaxaca_sc, oaxaca_st, oaxaca_obc, "Baseline (with land)")
oaxaca_summary_noland <- make_summary_df(oaxaca_sc_noland, oaxaca_st_noland, oaxaca_obc_noland, "Sensitivity (no land)")

cat("=== OAXACA DECOMPOSITION SUMMARY (BASELINE) ===\n\n")
print(oaxaca_summary)

cat("\n=== OAXACA DECOMPOSITION SUMMARY (NO LAND SENSITIVITY) ===\n\n")
print(oaxaca_summary_noland)

dir.create("../results", showWarnings = FALSE)
write.csv(bind_rows(oaxaca_summary, oaxaca_summary_noland), "../results/oaxaca_decomposition_summary.csv", row.names = FALSE)
saveRDS(list(
  baseline = list(sc=oaxaca_sc, st=oaxaca_st, obc=oaxaca_obc),
  no_land  = list(sc=oaxaca_sc_noland, st=oaxaca_st_noland, obc=oaxaca_obc_noland)
), "../results/oaxaca_full_results.rds")

cat("✅ Oaxaca baseline and land sensitivity results saved to ../results/\n")
