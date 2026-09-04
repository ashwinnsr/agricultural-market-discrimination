# ==============================================================================
# 09_mechanisms.R
# Explores mechanisms of market discrimination: "The Double Squeeze"
# Includes:
#   1. MSP Awareness (Information Asymmetry)
#   2. Loans / Indebtedness (Distress Sales)
#   3. Input Costs (The first squeeze)
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(fixest)
library(modelsummary)
library(ggplot2)
library(dplyr)

cat("=== MECHANISMS ANALYSIS: THE DOUBLE SQUEEZE ===\n\n")

df_mech <- df_final %>%
  mutate(
    crop_x_dist = paste(crop_code, district, sep="_"),
    visit_fac   = factor(visit),
    log_debt    = log(pmax(total_debt, 0.01, na.rm=TRUE)),
    log_input_exp = log(pmax(total_paid_input_exp, 0.01, na.rm=TRUE))
  ) %>%
  filter(!is.na(caste_cat), !is.na(weight))

# ==============================================================================
# 1. MSP AWARENESS (Information Asymmetry)
# Does social group predict whether a farmer is even aware of the Minimum Support
# Price for their crops?
# ==============================================================================
cat("\n--- 1. MSP Awareness ---\n")

if ("any_msp_aware" %in% names(df_mech)) {
  m_msp_aware <- feols(
    any_msp_aware ~ caste_cat + log_total_land + log_mpce + visit_fac | state,
    data = df_mech %>% distinct(hhid, .keep_all = TRUE), # household level
    weights = ~weight,
    cluster = ~fsu_id
  )

  m_msp_sold <- feols(
    any_sold_at_msp ~ caste_cat + log_total_land + log_mpce + visit_fac | state,
    data = df_mech %>% distinct(hhid, .keep_all=TRUE) %>% filter(any_msp_aware == 1),
    weights = ~weight,
    cluster = ~fsu_id
  )

  cat("Probability of being MSp Aware (Household Level):\n")
  print(coeftable(m_msp_aware))
  
  cat("\nConditional on Awareness, probability of actually selling at MSP:\n")
  print(coeftable(m_msp_sold))
}

# ==============================================================================
# 2. INDEBTEDNESS AND DISTRESS SELLING (The Interlinked Market)
# Do informal loans force farmers to sell at lower prices or specifically to traders?
# ==============================================================================
cat("\n\n--- 2. Indebtedness & Tie-in Sales ---\n")

if ("has_informal_lender" %in% names(df_mech)) {
  # Are marginalized castes more likely to have informal loans?
  m_informal_debt <- feols(
    has_informal_lender ~ caste_cat + log_total_land + log_mpce + visit_fac | state,
    data = df_mech %>% distinct(hhid, .keep_all = TRUE),
    weights = ~weight,
    cluster = ~fsu_id
  )
  
  cat("Probability of having Debt from Moneylender/Traders (Household Level):\n")
  print(coeftable(m_informal_debt))

  # Does having informal debt lower the price received? (Testing tie-in effect)
  m_debt_price <- feols(
    log_unit_price ~ caste_cat + has_informal_lender + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
    data = df_mech,
    weights = ~weight,
    cluster = ~fsu_id
  )
  
  cat("\nImpact of Informal Lender Debt on Crop Price Received:\n")
  print(coeftable(m_debt_price)[c("has_informal_lender", "caste_catSC", "caste_catST", "caste_catOBC"), ])
}

# ==============================================================================
# 3. INPUT COSTS (The First Squeeze)
# Do marginalized castes pay more for inputs (conditional on crop/geography)?
# ==============================================================================

cat("\n\n--- 3. Input Costs (Paid-out expenses) ---\n")

if ("log_input_exp" %in% names(df_mech) && any(!is.na(df_mech$log_input_exp))) {
  
  # DIAGNOSTIC: check ST subsample within total_paid_input_exp > 0 restriction
  input_subsmpl <- df_mech %>%
    group_by(caste_cat) %>%
    summarise(
      n_total = n(),
      n_paid = sum(total_paid_input_exp > 0, na.rm = TRUE),
      pct_zero_or_na = mean(total_paid_input_exp == 0 | is.na(total_paid_input_exp), na.rm = TRUE) * 100,
      median_paid_exp = median(total_paid_input_exp[total_paid_input_exp > 0], na.rm = TRUE),
      .groups = "drop"
    )
  cat("\n[DIAGNOSTIC] Input cost subsample properties:\n")
  print(input_subsmpl)

  # Regress log paid input expenses on social group (restricted to >0)
  m_input_cost <- feols(
    log_input_exp ~ caste_cat + log_total_land + log_mpce + visit_fac | crop_code + district,
    data = subset(df_mech, total_paid_input_exp > 0),
    weights = ~weight,
    cluster = ~fsu_id
  )
  
  cat("\nDifference in Input Expenses Paid (Log) - District FE & Crop Control (total_paid_input_exp > 0):\n")
  print(coeftable(m_input_cost))

  # Robustness: IHS (no zero exclusion — avoids composition/selection bias)
  m_input_cost_ihs <- feols(
    log(total_paid_input_exp + sqrt(total_paid_input_exp^2 + 1)) ~ caste_cat + log_total_land + log_mpce + visit_fac | crop_code + district,
    data    = df_mech %>% mutate(total_paid_input_exp = replace_na(total_paid_input_exp, 0)),
    weights = ~weight,
    cluster = ~fsu_id
  )
  cat("\nDifference in Input Expenses Paid (IHS, all observations including zero):\n")
  print(coeftable(m_input_cost_ihs)[c("caste_catSC","caste_catST","caste_catOBC"),])
  
  # Institutional vs Informal Input sourcing
  if ("pct_institutional_input" %in% names(df_mech)) {
     m_input_source <- feols(
       pct_institutional_input ~ caste_cat + log_total_land + log_mpce + visit_fac | district,
       data = df_mech %>% distinct(hhid, visit, .keep_all = TRUE),
       weights = ~weight,
       cluster = ~fsu_id
    )
    cat("\nDifference in % of Inputs from Institutional Sources:\n")
    print(coeftable(m_input_source))
  }
}

# ==============================================================================
# 4. BARON-KENNY MEDIATION FOR H2 (Channel Access)
# Descriptive decomposition of total price gap into direct and channel-mediated components.
# NOTE: Interpreted as a descriptive accounting decomposition, not a causal mediation
# estimate, as the mediator (formal channel) and outcome (price) share unmeasured confounders.
# ==============================================================================
cat("\n\n--- 4. Mediation Analysis (Baron-Kenny Descriptive Decomposition) ---\n")

m_direct <- tryCatch(
  feols(
    log_unit_price ~ caste_cat + sold_to_formal + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
    data = df_mech,
    weights = ~weight,
    cluster = ~fsu_id
  ),
  error = function(e) NULL
)

# Re-estimate matching total effect model (matching sample exactly)
m_total <- tryCatch(
  feols(
    log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
    data = df_mech %>% filter(!is.na(sold_to_formal)),
    weights = ~weight,
    cluster = ~fsu_id
  ),
  error = function(e) NULL
)

if (!is.null(m_direct) && !is.null(m_total)) {
  cat("=== BARON-KENNY MEDIATION: Channel Access (sold_to_formal) as Mediator ===\n")
  for (grp in c("SC","ST","OBC")) {
    key <- paste0("caste_cat", grp)
    if (key %in% names(coef(m_total)) && key %in% names(coef(m_direct))) {
      total_eff  <- coef(m_total)[key]
      direct_eff <- coef(m_direct)[key]
      indirect   <- total_eff - direct_eff
      pct_med    <- 100 * indirect / total_eff
      cat(sprintf("  %-3s Caste: Total Effect = %+.4f | Direct Effect = %+.4f | Indirect = %+.4f (%5.1f%% mediated)\n",
                  grp, total_eff, direct_eff, indirect, pct_med))
    }
  }
  cat("=========================================================================\n")
}

# ==============================================================================
# SAVE RESULTS
# ==============================================================================
dir.create("../results", showWarnings = FALSE)
saveRDS(list(
  msp_aware=if(exists("m_msp_aware")) m_msp_aware else NULL,
  msp_sold=if(exists("m_msp_sold")) m_msp_sold else NULL,
  informal_debt=if(exists("m_informal_debt")) m_informal_debt else NULL,
  debt_price=if(exists("m_debt_price")) m_debt_price else NULL,
  input_cost=if(exists("m_input_cost")) m_input_cost else NULL,
  input_cost_ihs=if(exists("m_input_cost_ihs")) m_input_cost_ihs else NULL,
  input_source=if(exists("m_input_source")) m_input_source else NULL,
  mediation_total=if(exists("m_total")) m_total else NULL,
  mediation_direct=if(exists("m_direct")) m_direct else NULL
), "../results/mechanisms_results.rds")

cat("\n✅ Mechanisms analysis results saved to ../results/mechanisms_results.rds\n")
