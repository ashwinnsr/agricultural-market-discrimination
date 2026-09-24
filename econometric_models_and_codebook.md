# Econometric Models & Variable Construction Codebook

**Project:** Market Access in Rural India: An Investigation of Agricultural Output Pricing  
**Author:** Ashwin  
**Data Sources:** National Sample Survey (NSS) 77th Round (Schedule 33.1, 2019–20) & PARI Village Surveys  
**Code Repository:** `agricultural-market-discrimination`  

---

## 1. Data Preparation & Variable Construction

All analytical variables are constructed from NSS 77 Schedule 33.1 (Visit 1 and Visit 2 merged using 8-digit household panel IDs).

### 1.1 Identifiers & Data Cleaning Code (`03_cleaning.r`)

```r
# Data cleaning, outlier trimming, and variable derivation
library(dplyr)
library(haven)
library(stringr)

# Filtering valid sales transactions (excluding summary rows b6q1 == "9" and code "9999")
df_price <- df_raw %>%
  filter(as.character(b6q1) != "9", crop_code != "9999") %>%
  filter(!is.na(unit_price) & unit_price > 0) %>%
  filter(!is.na(qty_sold) & qty_sold > 0)

# Symmetric 1%-99% two-stage outlier trimming by crop code
df_trimmed <- df_price %>%
  group_by(crop_code) %>%
  filter(
    unit_price >= quantile(unit_price, 0.01, na.rm = TRUE),
    unit_price <= quantile(unit_price, 0.99, na.rm = TRUE)
  ) %>%
  ungroup()
```

---

### 1.2 Outcome Variable: Unit Price

* **Primary Outcome:** Log Unit Price ($\log(\text{unit\_price})$), where unit price is measured in Rs./kg.
* **Derivation:** Rate from all disposals (`b6q18`), with fallback to major disposal value (`b6q13`) divided by major disposal quantity (`b6q12`).

```r
df_cats <- df_trimmed %>%
  mutate(
    # Preferred rate from all disposals (b6q18), fallback to major disposal
    unit_price = case_when(
      !is.na(rate_all) & rate_all > 0                       ~ rate_all,
      !is.na(qty_major) & qty_major > 0 & !is.na(val_major) ~ val_major / qty_major,
      TRUE                                                  ~ NA_real_
    ),
    log_unit_price = log(unit_price),
    
    # Transaction scale control
    qty_sold     = case_when(
      !is.na(qty_all) & qty_all > 0   ~ qty_all,
      !is.na(qty_major) & qty_major > 0 ~ qty_major,
      TRUE                             ~ NA_real_
    ),
    log_qty_sold = log(qty_sold)
  )
```

---

### 1.3 Social Group Categories (`caste_cat`)

Derived from NSS Block 4 `social_group` item (1 = ST, 2 = SC, 3 = OBC, 9/Others = General).

```r
df_cats <- df_cats %>%
  mutate(
    caste_cat = case_when(
      social_group == 1 ~ "ST",
      social_group == 2 ~ "SC",
      social_group == 3 ~ "OBC",
      TRUE              ~ "General"
    ),
    caste_cat = factor(caste_cat, levels = c("General", "OBC", "SC", "ST"))
  )
```

---

### 1.4 Class & Wealth Proxies

#### A. Continuous Land & Consumption Wealth
```r
df_cats <- df_cats %>%
  mutate(
    log_total_land = log(pmax(total_land, 0.01, na.rm = TRUE)), # Land possessed in acres
    log_mpce       = log(pmax(mpce, 1, na.rm = TRUE))          # Monthly per capita expenditure (Rs.)
  )
```

#### B. Discrete Landholding Size Classes (`land_class_simple`)
Converted from land possessed in acres to hectares ($1 \text{ acre} = 0.405 \text{ ha}$).

```r
df_cats <- df_cats %>%
  mutate(
    land_possessed_acres = total_land,
    land_possessed_ha    = total_land * 0.405,

    # Official NSS 7-bin tabulation plan
    land_class_official = factor(
      case_when(
        is.na(land_possessed_ha) | land_possessed_ha < 0.005  ~ "< 0.01 ha",
        land_possessed_ha >= 0.005 & land_possessed_ha < 0.405 ~ "0.01-0.40 ha",
        land_possessed_ha >= 0.405 & land_possessed_ha < 1.005 ~ "0.41-1.00 ha",
        land_possessed_ha >= 1.005 & land_possessed_ha < 2.005 ~ "1.01-2.00 ha",
        land_possessed_ha >= 2.005 & land_possessed_ha < 4.005 ~ "2.01-4.00 ha",
        land_possessed_ha >= 4.005 & land_possessed_ha < 10.005~ "4.01-10.00 ha",
        land_possessed_ha >= 10.005                            ~ "10.00+ ha",
        TRUE                                                   ~ NA_character_
      ),
      levels = c("< 0.01 ha", "0.01-0.40 ha", "0.41-1.00 ha", "1.01-2.00 ha", "2.01-4.00 ha", "4.01-10.00 ha", "10.00+ ha")
    ),

    # Simplified 5-bin literature class (used for interaction M7 & land heterogeneity)
    # Zero-land sales (n=2) are merged into Marginal to prevent rank deficiency.
    land_class_simple = factor(
      case_when(
        is.na(land_possessed_ha)                             ~ NA_character_,
        land_possessed_ha >= 0 & land_possessed_ha < 1.0    ~ "Marginal",
        land_possessed_ha >= 1.0 & land_possessed_ha < 2.0  ~ "Small",
        land_possessed_ha >= 2.0 & land_possessed_ha < 4.0  ~ "Semi-Medium",
        land_possessed_ha >= 4.0 & land_possessed_ha < 10.0 ~ "Medium",
        land_possessed_ha >= 10.0                           ~ "Large",
        TRUE                                                 ~ NA_character_
      ),
      levels = c("Marginal", "Small", "Semi-Medium", "Medium", "Large")
    )
  )
```

---

### 1.5 Market Channels / Agency (`agency_code`)

Extracted from Block 6 Item 10 (`b6q10`).

```r
df_cats <- df_cats %>%
  mutate(
    agency_code  = as.numeric(haven::zap_labels(b6q10)),
    agency_label = case_when(
      agency_code == 1 ~ "Local Trader",
      agency_code == 2 ~ "APMC Mandi",
      agency_code == 3 ~ "Input Dealer",
      agency_code == 4 ~ "Cooperative",
      agency_code == 5 ~ "Government",
      agency_code == 6 ~ "FPO",
      agency_code == 7 ~ "Private Processor",
      agency_code == 8 ~ "Contract Farming",
      agency_code == 9 ~ "Others",
      TRUE             ~ NA_character_
    ),
    sold_to_trader   = as.integer(agency_code == 1),
    sold_to_apmc     = as.integer(agency_code == 2),
    sold_to_coop     = as.integer(agency_code == 4),
    sold_to_govt     = as.integer(agency_code == 5),
    sold_to_fpo      = as.integer(agency_code == 6),
    sold_to_formal   = as.integer(agency_code %in% c(2, 4, 5, 6, 7, 8)),
    sold_to_informal = as.integer(agency_code %in% c(1, 3, 9))
  )
```

---

### 1.6 Marketing Satisfaction (`satisfaction_code`)

Extracted from Block 6 Item 11 (`b6q11`).

```r
df_cats <- df_cats %>%
  mutate(
    satisfaction_code  = as.character(as.numeric(haven::zap_labels(b6q11))),
    satisfied          = as.integer(satisfaction_code == "1"),
    dissatisfied_price = as.integer(satisfaction_code == "2"), # Lower than market price
    dissatisfied_delay = as.integer(satisfaction_code == "3"), # Delayed payment
    dissatisfied_loan  = as.integer(satisfaction_code == "4"), # Loan deductions
    dissatisfied_weigh = as.integer(satisfaction_code == "5")  # Faulty weighing/grading
  )
```

---

### 1.7 Double Squeeze Mechanism Variables

```r
df_mech <- df_final %>%
  mutate(
    # 1. MSP Awareness & Participation (Block 14)
    msp_aware   = as.integer(b14q4 == 1),
    sold_at_msp = as.integer(b14q6 == 1),

    # 2. Credit Exposure (Block 13)
    has_informal_lender = as.integer(informal_debt_amount > 0),
    log_debt            = log(pmax(total_debt, 0.01, na.rm = TRUE)),

    # 3. Paid-out Input Expenses (Block 7)
    total_paid_input_exp = as.numeric(total_paid_input_exp),
    log_input_exp        = log(pmax(total_paid_input_exp, 0.01, na.rm = TRUE)),
    ihs_input_exp        = asinh(total_paid_input_exp) # Inverse hyperbolic sine
  )
```

---

## 2. OLS Price Discrimination Models (`05_price_regressions.R`)

Dependent Variable: $\log(\text{unit\_price}_{icst})$  
Reference Group: **General Caste**  
Standard Errors: Clustered at Primary Sampling Unit (FSU) level (`fsu_id`)

```r
library(fixest)
```

### 2.1 Model Specifications M1 to M7

#### Model M1: Baseline (Crop Fixed Effects)
$$\log(\text{unit\_price}_{icst}) = \alpha + \beta_1 \text{SC}_i + \beta_2 \text{ST}_i + \beta_3 \text{OBC}_i + \text{visit}_t + \gamma_c + \varepsilon_{icst}$$

```r
m1_base <- feols(
  log_unit_price ~ caste_cat + visit_fac | crop_code,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

#### Model M2: + Controls (Quantity, Wealth, Continuous Land)
$$\log(\text{unit\_price}_{icst}) = \alpha + \boldsymbol{\beta} \text{Caste}_i + \theta_1 \log(\text{qty}) + \theta_2 \log(\text{MPCE}) + \theta_3 \log(\text{land}) + \text{visit}_t + \gamma_c + \varepsilon_{icst}$$

```r
m2_controls <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

#### Model M3: Preferred Specification (+ District FE)
$$\log(\text{unit\_price}_{icst}) = \alpha + \boldsymbol{\beta} \text{Caste}_i + \theta_1 \log(\text{qty}) + \theta_2 \log(\text{MPCE}) + \theta_3 \log(\text{land}) + \text{visit}_t + \gamma_c + \delta_d + \varepsilon_{icst}$$

```r
m3_district <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

#### Model M4: State FE (Sensitivity Test)
```r
m4_state <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + state,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

#### Model M5: District FE, No Quantity Control
```r
m5_no_qty <- feols(
  log_unit_price ~ caste_cat + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

#### Model M6: Categorical Land Class FE
```r
m6_landclass <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + visit_fac | crop_code + district + land_class_simple,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

#### Model M7: Caste $\times$ Land Class Interaction Model
$$\log(\text{unit\_price}_{icst}) = \alpha + \boldsymbol{\beta} (\text{Caste}_i \times \text{LandClass}_i) + \theta_1 \log(\text{qty}) + \theta_2 \log(\text{MPCE}) + \text{visit}_t + \gamma_c + \delta_d + \varepsilon_{icst}$$

```r
m7_caste_x_land <- feols(
  log_unit_price ~ caste_cat * land_class_simple + log_qty_sold + log_mpce + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

# Mandatory Cell-Size Diagnostic Code
cell_sizes <- df_reg %>%
  filter(!is.na(land_class_simple)) %>%
  group_by(caste_cat, land_class_simple) %>%
  summarise(n = n(), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = land_class_simple, values_from = n, values_fill = 0)
# Result: SC x Large landholding cell has only n=7 observations nationally
```

---

### 2.2 Land Stratified Sub-group Regressions

Estimates Model M3 independently within each land size stratum:

```r
land_het_results <- data.frame()
for (sz in c("Marginal", "Small", "Semi-Medium", "Medium", "Large")) {
  df_sz <- df_reg %>% filter(land_class_simple == sz)
  m <- feols(
    log_unit_price ~ caste_cat + log_qty_sold + log_mpce + visit_fac | crop_code + district,
    data = df_sz, weights = ~weight, cluster = ~fsu_id
  )
}
```

---

### 2.3 Quantile Regressions (`quantreg`)

Evaluates caste effects across the log unit price distribution ($\tau \in \{0.10, 0.50, 0.90\}$):

```r
library(quantreg)

# Demeaned residuals from fixed effects
m_fe <- feols(log_unit_price ~ 1 | crop_code + district, data = df_reg)
df_reg$price_resid <- residuals(m_fe)

# Quantile regression at tau = 0.1, 0.5, 0.9 with cluster-bootstrap SEs
for (tau_val in c(0.1, 0.5, 0.9)) {
  qr_mod <- rq(
    price_resid ~ caste_cat + log_qty_sold + log_mpce + log_total_land,
    tau = tau_val, data = df_reg, weights = weight
  )
  # Cluster bootstrap standard errors (B = 100)
}
```

---

## 3. Blinder-Oaxaca Price Decomposition (`06_oaxaca.R`)

### 3.1 Two-Fold Neumark Formulation (Reference Group = General Caste)
Decomposes the raw log price gap ($\Delta \bar{Y} = \bar{Y}_G - \bar{Y}_B$) into:
* **Explained Share (Endowments):** $(\bar{\mathbf{X}}_G - \bar{\mathbf{X}}_B) \hat{\boldsymbol{\beta}}_G$
* **Unexplained Share (Discrimination Residual):** $\bar{\mathbf{X}}_B (\hat{\boldsymbol{\beta}}_G - \hat{\boldsymbol{\beta}}_B)$

### 3.2 R Implementation Code

```r
run_manual_oaxaca <- function(group_label, include_land = TRUE) {
  formula_rhs <- if (include_land) {
    "~ log_qty_sold + log_mpce + log_total_land + factor(crop_group)"
  } else {
    "~ log_qty_sold + log_mpce + factor(crop_group)"
  }
  
  df_pair <- df_final %>%
    filter(caste_cat %in% c("General", group_label)) %>%
    filter(is.finite(log_unit_price), is.finite(log_qty_sold), is.finite(log_mpce), weight > 0)
  
  df_A <- df_pair %>% filter(caste_cat == "General")
  df_B <- df_pair %>% filter(caste_cat == group_label)
  
  form  <- as.formula(paste("log_unit_price", formula_rhs))
  mod_A <- feols(form, data = df_A, weights = ~weight)
  mod_B <- feols(form, data = df_B, weights = ~weight)
  
  pred_A   <- predict(mod_A)
  pred_B   <- predict(mod_B)
  pred_BgA <- predict(mod_A, newdata = df_B) # Counterfactual
  
  E_A         <- weighted.mean(pred_A, w = df_A$weight)
  E_B         <- weighted.mean(pred_B, w = df_B$weight)
  E_B_given_A <- weighted.mean(pred_BgA, w = df_B$weight)
  
  total_gap   <- E_A - E_B
  explained   <- E_A - E_B_given_A
  unexplained <- E_B_given_A - E_B
  
  return(data.frame(total_gap, explained, unexplained))
}
```

---

## 4. Market Channel Access & Satisfaction Models (`07_agency_regressions.R`)

### 4.1 Market Channel Access Linear Probability Models (LPMs)

Outcome: $Y_{icst} \in \{\text{sold\_to\_trader}, \text{sold\_to\_apmc}, \text{sold\_to\_govt}, \text{sold\_to\_coop}, \text{sold\_to\_fpo}, \text{sold\_to\_formal}\}$

$$\text{Pr}(\text{Channel}_{icst} = 1) = \alpha + \boldsymbol{\beta} \text{Caste}_i + \theta_1 \log(\text{qty}) + \theta_2 \log(\text{MPCE}) + \theta_3 \log(\text{land}) + \gamma_c + \delta_d + \varepsilon_{icst}$$

```r
lpm_formal <- feols(
  sold_to_formal ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

---

### 4.2 Marketing Outcome Satisfaction LPMs

Outcomes: $\text{satisfied}, \text{dissatisfied\_price}, \text{dissatisfied\_delay}, \text{dissatisfied\_loan}, \text{dissatisfied\_weigh}$

```r
lpm_satisfied <- feols(
  satisfied ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

lpm_dis_price <- feols(
  dissatisfied_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

---

### 4.3 Intra-Channel Conditional Price Penalties

Estimates price penalty *within* specific market channels (sub-sampled to single-channel households to eliminate selection risks):

```r
# Local Trader Channel Only
df_trader <- df_reg %>% filter(agency_code == 1)
m_trader  <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_trader, weights = ~weight, cluster = ~fsu_id
)

# APMC Mandi Channel Only
df_apmc <- df_reg %>% filter(agency_code == 2)
m_apmc  <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_apmc, weights = ~weight, cluster = ~fsu_id
)

# Government Procurement Only
df_govt <- df_reg %>% filter(agency_code == 5)
m_govt  <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_govt, weights = ~weight, cluster = ~fsu_id
)

# Cooperative / FPO Only
df_coop <- df_reg %>% filter(agency_code %in% c(4, 6))
m_coop  <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_coop, weights = ~weight, cluster = ~fsu_id
)
```

---

## 5. Mechanism Models — "The Double Squeeze" (`09_mechanisms.R`)

### 5.1 Information Asymmetry: MSP Awareness & Selling

```r
# Household-level MSP Awareness LPM
m_msp_aware <- feols(
  msp_aware ~ caste_cat + log_total_land + log_mpce + visit_fac | state,
  data = df_hh, weights = ~weight, cluster = ~fsu_id
)

# Conditional on Awareness, Probability of Selling at MSP
df_aware <- df_hh %>% filter(msp_aware == 1)
m_msp_sale <- feols(
  sold_at_msp ~ caste_cat + log_total_land + log_mpce + visit_fac | state,
  data = df_aware, weights = ~weight, cluster = ~fsu_id
)
```

---

### 5.2 Credit Exposure & Tied Sales

```r
# Probability of Debt from Moneylenders / Local Traders
m_informal_debt <- feols(
  has_informal_lender ~ caste_cat + log_total_land + log_mpce + visit_fac | state,
  data = df_hh, weights = ~weight, cluster = ~fsu_id
)

# Price Impact of Informal Lender Debt
m_price_debt <- feols(
  log_unit_price ~ has_informal_lender + caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

---

### 5.3 Production Squeeze: Paid-Out Input Expenses

```r
# Log Paid-Out Input Expenses (Positive Expense Subsample)
df_inputs <- df_reg %>% filter(total_paid_input_exp > 0)
m_input_log <- feols(
  log_input_exp ~ caste_cat + log_total_land + log_mpce + visit_fac | crop_code + district,
  data = df_inputs, weights = ~weight, cluster = ~fsu_id
)

# Inverse Hyperbolic Sine (IHS) Transformation (Full Sample Including Zero Expenses)
m_input_ihs <- feols(
  ihs_input_exp ~ caste_cat + log_total_land + log_mpce + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)
```

---

### 5.4 Baron-Kenny Mediation Analysis (Channel Access as Mediator)

Quantifies the share of the total caste log price penalty mediated by formal market channel selection:

```r
# Step 1: Total Effect (Caste -> Price)
m_total <- feols(
  log_unit_price ~ caste_cat + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

# Step 2: Direct Effect (Caste -> Price + Formal Channel Mediator)
m_direct <- feols(
  log_unit_price ~ caste_cat + sold_to_formal + log_qty_sold + log_mpce + log_total_land + visit_fac | crop_code + district,
  data = df_reg, weights = ~weight, cluster = ~fsu_id
)

# Mediation Calculations
total_sc  <- coef(m_total)["caste_catSC"]
direct_sc <- coef(m_direct)["caste_catSC"]
indirect_sc <- total_sc - direct_sc
pct_mediated_sc <- (indirect_sc / total_sc) * 100
```
