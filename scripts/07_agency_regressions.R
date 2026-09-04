# ==============================================================================
# 07_agency_regressions.R
# H2: MARKET CHANNEL ACCESS ANALYSIS
# Tests whether social group predicts which market channel a farmer sells through.
# Uses correct agency variable: b6q10
#   1=Local trader, 2=APMC, 3=Input dealer, 4=Cooperative,
#   5=Government, 6=FPO, 7=Private processor, 8=Contract farming
#
# Also analyses:
#   - Satisfaction with sale outcomes (b6q11)
#   - Channel-conditional price analysis (price premium/penalty within APMC)
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(fixest)
library(modelsummary)

cat("=== H2: MARKET CHANNEL ACCESS ANALYSIS ===\n")

df_reg <- df_final %>%
  mutate(
    visit_fac    = factor(visit),
    crop_x_dist  = paste(crop_code, district, sep="_")
  ) %>%
  filter(!is.na(caste_cat), !is.na(agency_code), !is.na(weight))

cat("Agency regression sample:", nrow(df_reg), "\n")
cat("Agency distribution:\n")
print(table(df_reg$agency_label, useNA="ifany"))

# ==============================================================================
# MODELS: LPM for each market channel
# Reference: General caste
# Controls: Land, MPCE, Crop FE, District FE, visit
# ==============================================================================

agency_models <- list()

base_controls <- "caste_cat + log_total_land + log_mpce + visit_fac | crop_code + district"

cat("\n--- Trader (Local/Informal) ---\n")
agency_models$trader <- feols(
  as.formula(paste("sold_to_trader ~", base_controls)),
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

cat("--- APMC Mandi ---\n")
agency_models$apmc <- feols(
  as.formula(paste("sold_to_apmc ~", base_controls)),
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

cat("--- Government Procurement ---\n")
agency_models$govt <- feols(
  as.formula(paste("sold_to_govt ~", base_controls)),
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

cat("--- Cooperative / FPO ---\n")
agency_models$coop <- feols(
  as.formula(paste("sold_to_coop ~", base_controls)),
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

agency_models$fpo <- feols(
  as.formula(paste("sold_to_fpo ~", base_controls)),
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

cat("--- Formal channels (all combined) ---\n")
agency_models$formal <- feols(
  as.formula(paste("sold_to_formal ~", base_controls)),
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

# Print table
cat("\n=== MARKET CHANNEL ACCESS TABLE (LPM) ===\n")
cat("(Coefficients = percentage point change relative to General caste)\n\n")
print(etable(
  agency_models,
  keep    = "caste_cat",
  fitstat = c("n","r2"),
  headers = c("Trader","APMC","Govt","Coop","FPO","Formal"),
  digits  = 4,
  se.below = TRUE
))

# ==============================================================================
# SATISFACTION WITH SALE OUTCOME (b6q11)
# This is an entirely NEW analysis using the variable that was previously
# MISIDENTIFIED as the agency variable.
# Tests: Are marginalised farmers more likely to be dissatisfied with prices,
#        face loan deductions, or faulty weighing?
# ==============================================================================
cat("\n\n=== SATISFACTION WITH SALE OUTCOME ANALYSIS ===\n")

satisfaction_models <- list()

if ("satisfied" %in% names(df_reg)) {
  cat("--- Overall satisfaction ---\n")
  satisfaction_models$satisfied <- feols(
    as.formula(paste("satisfied ~", base_controls)),
    data = df_reg, weights = ~weight, cluster = ~fsu_id
  )

  cat("--- Dissatisfied: price lower than market ---\n")
  satisfaction_models$dis_price <- feols(
    as.formula(paste("dissatisfied_price ~", base_controls)),
    data = df_reg, weights = ~weight, cluster = ~fsu_id
  )

  cat("--- Dissatisfied: loan deductions ---\n")
  satisfaction_models$dis_loan <- feols(
    as.formula(paste("dissatisfied_loan ~", base_controls)),
    data = df_reg, weights = ~weight, cluster = ~fsu_id
  )

  cat("--- Dissatisfied: faulty weighing/grading ---\n")
  satisfaction_models$dis_weigh <- feols(
    as.formula(paste("dissatisfied_weigh ~", base_controls)),
    data = df_reg, weights = ~weight, cluster = ~fsu_id
  )

  cat("--- Dissatisfied: delayed payments ---\n")
  satisfaction_models$dis_delay <- feols(
    as.formula(paste("dissatisfied_delay ~", base_controls)),
    data = df_reg, weights = ~weight, cluster = ~fsu_id
  )

  print(etable(
    satisfaction_models,
    keep    = "caste_cat",
    fitstat = c("n","r2"),
    headers = c("Satisfied","LowPrice","LoanDeduc","BadWeigh","DelayPay"),
    digits  = 4,
    se.below = TRUE
  ))
}

# ==============================================================================
# CONDITIONAL ANALYSIS: Price within APMC
# Tests: Even conditional on selling at APMC, do marginalised farmers face
#        a price penalty? (Intra-channel discrimination)
# ==============================================================================
cat("\n\n=== CONDITIONAL ANALYSIS: Price Penalty WITHIN Each Channel ===\n")

channels_to_test <- list(
  "APMC Mandi"       = "sold_to_apmc",
  "Local Trader"     = "sold_to_trader",
  "Government"       = "sold_to_govt",
  "Cooperative/FPO"  = "sold_to_coop"
)

within_channel_results <- data.frame()

for (ch_label in names(channels_to_test)) {
  ch_col <- channels_to_test[[ch_label]]
  
  df_ch_all <- df_reg %>% filter(.data[[ch_col]] == 1)
  df_ch_res <- df_reg %>% filter(.data[[ch_col]] == 1, qty_all == qty_major)
  
  for (subset_type in c("Single-Channel Only", "Unrestricted")) {
    df_ch <- if (subset_type == "Single-Channel Only") df_ch_res else df_ch_all
    
    if (nrow(df_ch) < 200) {
      cat(sprintf("  %s (%s): too few obs (%d), skipping\n", ch_label, subset_type, nrow(df_ch)))
      next
    }
    m_ch <- tryCatch(
      feols(
        log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
        data    = df_ch,
        weights = ~weight,
        cluster = ~fsu_id
      ),
      error = function(e) NULL
    )
    if (!is.null(m_ch)) {
      for (grp in c("SC","ST","OBC")) {
        key <- paste0("caste_cat", grp)
        if (key %in% names(coef(m_ch))) {
          est <- coef(m_ch)[key]
          se  <- se(m_ch)[key]
          pval <- fixest::pvalue(m_ch)[key]
          within_channel_results <- rbind(within_channel_results, data.frame(
            channel     = ch_label,
            sample_type = subset_type,
            group       = grp,
            estimate    = round(est, 4),
            se          = round(se, 4),
            pct_penalty = round((exp(est)-1)*100, 2),
            p_value     = round(pval, 4),
            n_obs       = nrow(df_ch)
          ))
          sig <- ifelse(pval < 0.01, "***", ifelse(pval < 0.05, "**", ifelse(pval < 0.10, "*", "")))
          cat(sprintf("  %-18s (%-19s) | %-4s: %.3f (%.1f%%) %s  (n=%d)\n",
                      ch_label, subset_type, grp, est, (exp(est)-1)*100, sig, nrow(df_ch)))
        }
      }
    }
  }
}

cat("\n  Note: Estimates within channel remove selection into channel;\n")
cat("  a penalty within APMC means caste discrimination inside the formal market.\n")

# ==============================================================================
# SAVE
# ==============================================================================
dir.create("../results", showWarnings = FALSE)
saveRDS(list(agency=agency_models, satisfaction=satisfaction_models),
        "../results/agency_regression_results.rds")
write_csv(within_channel_results, "../results/within_channel_price_penalty.csv")

cat("\n✅ Agency and satisfaction regression results saved.\n")