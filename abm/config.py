# ==============================================================================
# config.py
# ABM Parameters Calibrated from NSSO 77th Round (2018-19)
#
# Sources:
#   - Descriptive statistics (04_descriptives.r — Table 1)
#   - Price regressions (05_price_regressions.R — M3 district FE model)
#   - Agency LPMs (07_agency_regressions.R)
#   - Oaxaca-Blinder decomposition (06_oaxaca.R)
#   - Mechanisms analysis (09_mechanisms.R)
#
# All values are calibrated from empirical patterns in the NSS 77th Round.
# Where exact coefficients are unavailable, conservative estimates from
# published literature on caste and Indian agricultural markets are used.
# ==============================================================================

import numpy as np

# ==========================================================================
# 1. POPULATION COMPOSITION
#    Source: NSS 77th Round weighted sample proportions
# ==========================================================================
CASTE_DISTRIBUTION = {
    "General": 0.18,
    "OBC":     0.45,
    "SC":      0.15,
    "ST":      0.22,
}

# ==========================================================================
# 2. LAND ENDOWMENTS (acres)
#    Source: Table 1 descriptives — weighted mean total_land by caste
#    Distribution: Log-normal with caste-specific parameters
# ==========================================================================
LAND_PARAMS = {
    #            (mean_acres,  sd_acres,  prob_landless)
    "General": (4.20, 5.50, 0.03),
    "OBC":     (3.10, 4.20, 0.05),
    "SC":      (1.80, 2.50, 0.12),
    "ST":      (2.60, 3.80, 0.08),
}

# ==========================================================================
# 3. WEALTH (MPCE — Monthly Per Capita Consumer Expenditure, Rs.)
#    Source: NSS 77th Round Block 4
# ==========================================================================
MPCE_PARAMS = {
    #            (mean,   sd)
    "General": (2800, 1800),
    "OBC":     (2200, 1400),
    "SC":      (1700, 1100),
    "ST":      (1400,  900),
}

# ==========================================================================
# 4. CROP PORTFOLIO
#    Source: Panel C — crop composition by social group
#    Probabilities of growing each crop group
# ==========================================================================
CROP_GROUPS = ["Cereals", "Pulses", "Oilseeds", "Cotton", "Sugarcane",
               "Vegetables", "Fruits", "Spices", "Other"]

CROP_DISTRIBUTION = {
    "General": [0.30, 0.10, 0.12, 0.10, 0.10, 0.10, 0.05, 0.05, 0.08],
    "OBC":     [0.35, 0.12, 0.11, 0.09, 0.08, 0.09, 0.04, 0.04, 0.08],
    "SC":      [0.42, 0.14, 0.10, 0.06, 0.06, 0.08, 0.03, 0.03, 0.08],
    "ST":      [0.45, 0.13, 0.09, 0.04, 0.04, 0.07, 0.03, 0.06, 0.09],
}

# Base prices by crop group (Rs./quintal, median from NSS data)
CROP_BASE_PRICES = {
    "Cereals":    1750,
    "Pulses":     4200,
    "Oilseeds":   3800,
    "Cotton":     5100,
    "Sugarcane":   280,    # per quintal (sold by weight to mills)
    "Vegetables": 1500,
    "Fruits":     2800,
    "Spices":     8500,
    "Other":      2000,
}

# Price volatility (CV) by crop group
CROP_PRICE_VOLATILITY = {
    "Cereals":    0.20,
    "Pulses":     0.35,
    "Oilseeds":   0.30,
    "Cotton":     0.25,
    "Sugarcane":  0.10,
    "Vegetables": 0.45,
    "Fruits":     0.40,
    "Spices":     0.50,
    "Other":      0.35,
}

# MSP-eligible crops
MSP_ELIGIBLE_CROPS = ["Cereals", "Pulses", "Oilseeds", "Cotton"]

# ==========================================================================
# 5. MARKET CHANNEL CHOICE PROBABILITIES
#    Source: Agency LPM coefficients (07_agency_regressions.R)
#    Format: probability of choosing each channel, by caste
#    Channels: LocalTrader, APMC, Government, Cooperative, FPO, Other
# ==========================================================================
CHANNEL_NAMES = ["LocalTrader", "APMC", "Government", "Cooperative", "FPO", "Other"]

# Baseline probabilities (General caste, median endowments)
CHANNEL_BASE_PROBS = {
    "General": [0.38, 0.28, 0.08, 0.10, 0.04, 0.12],
    "OBC":     [0.42, 0.25, 0.07, 0.09, 0.03, 0.14],
    "SC":      [0.52, 0.19, 0.05, 0.07, 0.02, 0.15],
    "ST":      [0.55, 0.15, 0.04, 0.06, 0.02, 0.18],
}

# Marginal effects of land on channel choice (per acre)
# Positive = more land increases probability of using this channel
LAND_CHANNEL_EFFECTS = {
    "LocalTrader":  -0.015,   # larger farmers less likely to sell to trader
    "APMC":          0.012,   # larger farmers more likely to access APMC
    "Government":    0.004,
    "Cooperative":   0.005,
    "FPO":           0.002,
    "Other":        -0.008,
}

# ==========================================================================
# 6. PRICE PENALTIES (CASTE DISCRIMINATION)
#    Source: Price regressions M3 (district FE) — log-point penalties
#    These are the "unexplained" component from Oaxaca decomposition
# ==========================================================================

# Within-channel caste price penalty (log points)
# Negative = lower price relative to General caste
CASTE_PRICE_PENALTY = {
    "General":  0.000,
    "OBC":     -0.025,   # ~2.5% lower price
    "SC":      -0.065,   # ~6.3% lower price
    "ST":      -0.080,   # ~7.7% lower price
}

# Channel-specific price multipliers (relative to local trader = 1.0)
CHANNEL_PRICE_MULTIPLIER = {
    "LocalTrader":  1.00,
    "APMC":         1.08,    # ~8% premium at mandi
    "Government":   1.12,    # MSP is typically above market
    "Cooperative":  1.05,
    "FPO":          1.06,
    "Other":        0.95,    # residual/distress
}

# Within-channel discrimination (even in APMC, SC/ST face penalties)
# Source: Within-channel analysis in 07_agency_regressions.R
WITHIN_CHANNEL_PENALTY = {
    "LocalTrader": {"General": 0.0, "OBC": -0.02, "SC": -0.08, "ST": -0.10},
    "APMC":        {"General": 0.0, "OBC": -0.01, "SC": -0.04, "ST": -0.05},
    "Government":  {"General": 0.0, "OBC":  0.00, "SC": -0.01, "ST": -0.02},
    "Cooperative": {"General": 0.0, "OBC": -0.01, "SC": -0.03, "ST": -0.03},
    "FPO":         {"General": 0.0, "OBC":  0.00, "SC": -0.02, "ST": -0.02},
    "Other":       {"General": 0.0, "OBC": -0.03, "SC": -0.09, "ST": -0.11},
}

# ==========================================================================
# 7. CREDIT MARKET PARAMETERS
#    Source: Block 13 loan data
# ==========================================================================
DEBT_PROBABILITY = {
    # (prob_any_loan, prob_informal_lender, mean_debt_if_indebted)
    "General": (0.50, 0.15, 120000),
    "OBC":     (0.52, 0.20, 95000),
    "SC":      (0.55, 0.30, 65000),
    "ST":      (0.48, 0.35, 55000),
}

# Interest rates
FORMAL_INTEREST_RATE   = 0.07    # ~7% p.a. (institutional)
INFORMAL_INTEREST_RATE = 0.24    # ~24% p.a. (moneylender/trader)

# Distress sale discount: additional price penalty when selling under debt pressure
DISTRESS_SALE_DISCOUNT = -0.05   # 5% lower price when forced to sell to repay

# ==========================================================================
# 8. MSP AWARENESS (Information Asymmetry)
#    Source: Mechanisms analysis (09_mechanisms.R) — MSP awareness LPM
# ==========================================================================
MSP_AWARENESS_PROB = {
    "General": 0.65,
    "OBC":     0.55,
    "SC":      0.42,
    "ST":      0.33,
}

# Probability of actually selling at MSP conditional on awareness
MSP_SELLING_PROB_IF_AWARE = {
    "General": 0.30,
    "OBC":     0.25,
    "SC":      0.18,
    "ST":      0.15,
}

# ==========================================================================
# 9. INPUT COSTS
#    Source: Block 7 input expenses, mechanisms analysis
# ==========================================================================
INPUT_COST_PARAMS = {
    # (mean_input_cost_per_acre, sd)
    "General": (8500, 4000),
    "OBC":     (7200, 3500),
    "SC":      (6000, 3000),
    "ST":      (4800, 2500),
}

# Input cost premium for SC/ST (paying more for same inputs)
# From mechanisms: institutional input source share is lower for SC/ST
INPUT_COST_PREMIUM = {
    "General":  0.00,
    "OBC":      0.02,   # 2% more per unit of input
    "SC":       0.06,   # 6% more — fewer institutional sources
    "ST":       0.08,   # 8% more
}

# ==========================================================================
# 10. SIMULATION PARAMETERS
# ==========================================================================
NUM_FARMERS        = 5000
NUM_SEASONS        = 20        # Kharif + Rabi = 1 year, 20 seasons = 10 years
NUM_DISTRICTS      = 50        # Stylised districts
RANDOM_SEED        = 77        # NSS 77th round ;)

# Yield parameters (quintals per acre, by crop group)
YIELD_PER_ACRE = {
    "Cereals":    18,
    "Pulses":      8,
    "Oilseeds":   10,
    "Cotton":     12,
    "Sugarcane":  650,
    "Vegetables":  80,
    "Fruits":      50,
    "Spices":       6,
    "Other":       15,
}

# Subsistence retention (fraction of production consumed, not sold)
SUBSISTENCE_FRACTION = {
    "Cereals":    0.35,
    "Pulses":     0.20,
    "Oilseeds":   0.10,
    "Cotton":     0.00,
    "Sugarcane":  0.00,
    "Vegetables": 0.15,
    "Fruits":     0.10,
    "Spices":     0.05,
    "Other":      0.15,
}

# ==========================================================================
# 11. POLICY COUNTERFACTUAL SCENARIOS
# ==========================================================================
SCENARIOS = {
    "baseline": {
        "name": "Baseline (Status Quo)",
        "msp_awareness_boost":    0.0,
        "formal_credit_boost":    0.0,
        "fpo_penetration_boost":  0.0,
        "discrimination_factor":  1.0,    # 1.0 = full discrimination
    },
    "universal_msp": {
        "name": "Universal MSP Awareness",
        "msp_awareness_boost":    1.0,    # all farmers become MSP-aware
        "formal_credit_boost":    0.0,
        "fpo_penetration_boost":  0.0,
        "discrimination_factor":  1.0,
    },
    "formal_credit": {
        "name": "Universal Formal Credit Access",
        "msp_awareness_boost":    0.0,
        "formal_credit_boost":    1.0,    # all debt becomes institutional
        "fpo_penetration_boost":  0.0,
        "discrimination_factor":  1.0,
    },
    "fpo_expansion": {
        "name": "FPO Expansion for SC/ST",
        "msp_awareness_boost":    0.0,
        "formal_credit_boost":    0.0,
        "fpo_penetration_boost":  0.20,   # +20pp FPO access for SC/ST
        "discrimination_factor":  1.0,
    },
    "no_discrimination": {
        "name": "Zero Caste Discrimination (Theoretical)",
        "msp_awareness_boost":    0.0,
        "formal_credit_boost":    0.0,
        "fpo_penetration_boost":  0.0,
        "discrimination_factor":  0.0,    # remove all caste penalties
    },
    "combined_intervention": {
        "name": "Combined: MSP + Credit + FPO",
        "msp_awareness_boost":    1.0,
        "formal_credit_boost":    1.0,
        "fpo_penetration_boost":  0.20,
        "discrimination_factor":  1.0,
    },
}
