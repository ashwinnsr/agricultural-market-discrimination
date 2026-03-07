# ==============================================================================
# 07_mechanisms_analysis.R
# Testing the "Adverse Incorporation" Hypothesis
# ==============================================================================

# Ensure df_final exists
if (!exists("df_final")) stop("Error: df_final not found. Run 03_cleaning.R first.")

library(fixest)
library(ggplot2)
library(dplyr)

cat("=== ANALYZING MECHANISMS OF TIE-IN SALES & MARKET CHOICE ===\n")

# NOTE: In NSS Schedule 33.1, Block 6 Item 16 usually contains "Reason for sale to agency"
# 1 = Better price
# 2 = Lack of transport
# 3 = Need for pre-agreed loan/cash
# 4 = Delayed payment by others
# 5 = Others
# Let's check if this exists in our raw data, otherwise we use proxies.

# For now, let's create proxy mechanisms if the exact column 'b6q16' or similar isn't ready.
# Usually, adverse incorporation is seen when farmers sell locally to private traders heavily.
# Let's assess if the *distance* penalty is what drives STs, and the *debt* penalty drives SCs.

# 1. Exploring Reasons for Selling to Local Private Traders
# We use reason_sale which is now included in df_final from Step 02/03
df_mechanisms <- df_final %>%
    mutate(
        crop_code_char = as.character(crop_code),
        reason_transport = ifelse(reason_sale == 2, 1, 0),
        reason_credit = ifelse(reason_sale == 3, 1, 0)
    )

# Also ensure df_final has crop_code_char for the other models
df_final <- df_final %>% mutate(crop_code_char = as.character(crop_code))

cat("\n--- Probit Model: Probability of citing 'Lack of Transport' as reason for sale ---\n")
if (sum(df_mechanisms$reason_transport, na.rm = TRUE) > 10) {
    m_trans <- feols(reason_transport ~ caste_cat + log_mpce + total_land | crop_code_char + district,
        data = df_mechanisms, cluster = ~fsu_id
    )
    print(summary(m_trans))
} else {
    cat("⚠️ Insufficient observations for 'Lack of Transport' analysis.\n")
}

cat("\n--- Probit Model: Probability of citing 'Need for Credit/Cash' as reason for sale ---\n")
if (sum(df_mechanisms$reason_credit, na.rm = TRUE) > 10) {
    m_cred <- feols(reason_credit ~ caste_cat + log_mpce + total_land | crop_code_char + district,
        data = df_mechanisms, cluster = ~fsu_id
    )
    print(summary(m_cred))
} else {
    cat("⚠️ Insufficient observations for 'Need for Credit/Cash' analysis.\n")
}

# ------------------------------------------------------------------------------
# PROXY ANALYSIS: Interlocking Land markets and Product markets
# ------------------------------------------------------------------------------
# If you are a sharecropper (lease_terms == 3), do you face a higher price penalty?
cat("\n2. The Sharecropper Penalty (Tied Labor/Land proxy)\n")

# is_sharecropper was created in 02_dataloading_FINAL.r
m_sharecrop <- feols(
    log_unit_price ~ caste_cat + log_qty_sold + log_mpce + total_land + is_sharecropper |
        crop_code_char + district,
    data = df_final,
    weights = ~weight,
    cluster = ~fsu_id
)

cat("Effect of being a sharecropper on price received:\n")
sc_effect <- coef(m_sharecrop)["is_sharecropper"]
cat(sprintf("   %.1f%% penalty for sharecroppers compared to owners in same district\n", (exp(sc_effect) - 1) * 100))

# Does being SC/ST compound the sharecropper penalty?
m_sharecrop_interact <- feols(
    log_unit_price ~ caste_cat * is_sharecropper + log_qty_sold + log_mpce + total_land |
        crop_code_char + district,
    data = df_final,
    weights = ~weight,
    cluster = ~fsu_id
)

cat("\nInteraction Effects (Caste * Sharecropper):\n")
print(coeftable(m_sharecrop_interact)[grep("is_sharecropper", rownames(coeftable(m_sharecrop_interact))), ])

cat("\n✅ Mechanism Analysis Complete.\n")
