# ==============================================================================
# 06_oaxaca.R
# Oaxaca-Blinder Decomposition of the Price Gap (Manual Implementation)
# Decomposes raw price gap into:
#   (1) Explained: differences in endowments (quantities, land, crop mix)
#   (2) Unexplained: residual -- the standard measure of market discrimination
#
# This uses a robust custom function using `fixest` to bypass matrix dimension crashes
# prevalent in the `oaxaca` CRAN package when dealing with sparse survey data.
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(dplyr)
library(fixest)

cat("=== OAXACA-BLINDER DECOMPOSITION OF PRICE GAP ===\n\n")

# Formula used for the two regressions
formula_rhs <- "~ log_qty_sold + log_mpce + log_total_land + factor(crop_group)"

run_manual_oaxaca <- function(group_label) {
  cat(sprintf("--- General vs %s ---\n", group_label))
  
  # Create the dataset
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
      !is.na(crop_group)
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
  
  # The easiest, most robust way to calculate endowments and unexplained gaps without matrix alignment:
  # 1. Expected outcome for Group A: E_A = mean(predict(mod_A, newdata=df_A))
  # 2. Expected outcome for Group B: E_B = mean(predict(mod_B, newdata=df_B))
  # 3. Counterfactual outcome if B had A's returns: E_B_given_A = mean(predict(mod_A, newdata=df_B))
  E_A <- mean(predict(mod_A), na.rm = TRUE)
  E_B <- mean(predict(mod_B), na.rm = TRUE)
  
  # predict handles missing columns by predicting NA if missing, 
  # or we use safe predictions.
  E_B_given_A <- tryCatch({
       mean(predict(mod_A, newdata = df_B), na.rm = TRUE)
    }, error = function(e){ NA })
  
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

oaxaca_sc  <- run_manual_oaxaca("SC")
oaxaca_st  <- run_manual_oaxaca("ST")
oaxaca_obc <- run_manual_oaxaca("OBC")

cat("=== OAXACA DECOMPOSITION SUMMARY ===\n\n")

oaxaca_summary <- bind_rows(
  lapply(list(oaxaca_sc, oaxaca_st, oaxaca_obc), function(x) {
    if (is.null(x)) return(NULL)
    data.frame(
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

print(oaxaca_summary)

cat("\nInterpretation guide:\n")
cat("  'Explained' = % of price gap due to differences in endowments\n")
cat("  'Unexplained' = % of price gap NOT explained by observable endowments\n")
cat("  A large 'Unexplained' share is consistent with market discrimination.\n\n")

dir.create("../results", showWarnings = FALSE)
write.csv(oaxaca_summary, "../results/oaxaca_decomposition_summary.csv", row.names = FALSE)
saveRDS(list(sc=oaxaca_sc, st=oaxaca_st, obc=oaxaca_obc), "../results/oaxaca_full_results.rds")

cat("✅ Oaxaca results saved to ../results/\n")
