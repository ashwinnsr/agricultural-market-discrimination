# ODD Protocol: Agent-Based Model of Caste Dynamics in Indian Agricultural Markets

## Overview, Design concepts, and Details (Grimm et al., 2006; 2010; 2020)

---

## 1. PURPOSE

This model investigates how caste-based social stratification shapes agricultural market outcomes in India through the interplay of four mechanisms:

1. **Market channel segmentation** — Differential access to formal (APMC, government, cooperative) vs informal (local trader) selling channels
2. **Within-channel price discrimination** — Caste-based price penalties even within the same market channel
3. **Debt-driven distress selling** — Informal debt forcing farmers into disadvantageous trader-tied sales
4. **Information asymmetry** — Differential awareness of Minimum Support Prices (MSP)

The model formalises the "double squeeze" / adverse incorporation hypothesis: marginalised caste groups (SC/ST) are simultaneously squeezed on the input side (higher costs, exploitative credit) and output side (lower prices, trader dependence), creating reinforcing feedback loops that reproduce agrarian inequality.

**Key research questions:**
1. Under what conditions does the debt–distress–low price cycle converge vs diverge?
2. Which policy intervention (MSP awareness, formal credit, FPO expansion) most effectively reduces caste price gaps?
3. What is the residual caste penalty after removing information asymmetry entirely?

---

## 2. ENTITIES, STATE VARIABLES, AND SCALES

### 2.1 Entities

| Entity | Count | Description |
|--------|-------|-------------|
| **FarmerAgent** | 5,000 | Agricultural households |
| **BuyerAgent** | 300 (6 channels × 50 districts) | Stylised market channels |
| **Districts** | 50 | Spatial units (no explicit grid) |

### 2.2 FarmerAgent State Variables

| Variable | Type | Source | Description |
|----------|------|--------|-------------|
| `caste` | Categorical | NSS Block 4 | Social group: General, OBC, SC, ST |
| `land` | Continuous (acres) | NSS Block 5 | Operational landholding |
| `mpce` | Continuous (₹) | NSS Block 4 | Wealth proxy |
| `crop` | Categorical | NSS Block 6 | Primary crop grown this season |
| `debt_amount` | Continuous (₹) | NSS Block 13 | Outstanding loans |
| `has_informal_debt` | Boolean | NSS Block 13 | Indebted to moneylender/trader |
| `msp_aware` | Boolean | NSS Block 14 | Aware of MSP for grown crop |
| `channel_chosen` | Categorical | NSS Block 6 (b6q10) | Market channel used for sale |
| `price_received` | Continuous (₹/q) | NSS Block 6 (b6q18) | Unit price received |
| `net_income` | Continuous (₹) | Computed | Revenue - costs - debt service |

### 2.3 Scales

- **Temporal**: Each time step = one agricultural season (Kharif or Rabi). Default: 20 seasons (10 years).
- **Spatial**: 50 stylised districts. No explicit spatial topology.
- **Population**: 5,000 farmers (scalable). Caste proportions match NSS 77th Round.

---

## 3. PROCESS OVERVIEW AND SCHEDULING

Each season, all FarmerAgents execute the following steps **simultaneously** (synchronous update):

```
1. CHOOSE CROP       — Select crop from caste-specific distribution
2. PRODUCE           — Calculate yield = base_yield × land × weather_shock
3. INCUR INPUT COSTS — Pay for inputs (caste premium applies)
4. CHOOSE CHANNEL    — Select market channel f(caste, land, debt, MSP_aware)
5. RECEIVE PRICE     — Price = base × channel_mult × (1 + caste_penalty) × noise
6. UPDATE FINANCES   — Net income → update wealth, debt dynamics
```

Data is collected after all agents complete their steps.

---

## 4. DESIGN CONCEPTS

### 4.1 Basic Principles

The model operationalises three theoretical frameworks:
- **Adverse Incorporation** (du Toit, 2004; Harriss-White, 2003): Marginalised groups are incorporated into markets on systematically disadvantageous terms
- **Interlinked Markets** (Bardhan, 1980; Basu, 1986): Credit and output markets are linked, creating tied sales
- **Cumulative Disadvantage** (Merton, 1968): Small per-transaction penalties compound over time into large wealth gaps

### 4.2 Emergence

The following macro-patterns emerge from micro-level interactions:
- Aggregate caste price gaps (validated against Oaxaca-Blinder decomposition)
- Income inequality (Gini coefficient evolution)
- Debt trap dynamics (feedback between debt, distress sales, and wealth)
- Market concentration (trader dominance among specific caste groups)

### 4.3 Adaptation

Farmers adapt indirectly through:
- **Wealth-mediated channel access**: As MPCE changes, channel choice probabilities shift
- **Debt spiral**: Negative income → increased debt → higher probability of trader lock-in
- **No strategic learning**: Agents do not optimise or learn from past outcomes (bounded rationality assumption consistent with the adverse incorporation framework — structural constraints dominate individual agency)

### 4.4 Objectives

Farmers do not have explicit utility functions. Their behaviour is probabilistic, calibrated from observed revealed preferences in the NSS data.

### 4.5 Sensing

Farmers "know" their own:
- Caste, land, wealth, debt status
- MSP awareness (stochastic)
- Local crop prices (via channel-specific price determination)

Farmers do **not** know:
- Other farmers' prices or strategies
- Aggregate market conditions
- Optimal channel choice

### 4.6 Interaction

- **Direct interaction**: None between farmers (no social networks)
- **Indirect interaction**: Through market channels (aggregate demand affects nothing in this version — channels have unlimited capacity)
- **Future extension**: Farmer-farmer information exchange, trader-farmer bargaining

### 4.7 Stochasticity

| Process | Stochastic Element | Distribution |
|---------|-------------------|--------------|
| Land initialisation | Draw from caste-specific distribution | Log-normal |
| Wealth initialisation | Draw from caste-specific distribution | Truncated normal |
| Crop choice | Probabilistic selection | Multinomial |
| Yield | Weather shock | Normal(1.0, 0.25) |
| Channel choice | Probabilistic selection | Adjusted multinomial |
| Price | Market noise | Normal(1.0, CV_crop) |
| Debt default | Probability of falling into informal debt | Bernoulli |

### 4.8 Observation

Model-level data collected each season:
- Mean prices by caste (price gap computation)
- Mean income by caste
- Channel distribution by caste
- Debt rates by caste
- Gini coefficient of income
- Distress sale rates

Agent-level data collected for final season.

---

## 5. INITIALISATION

1. **Population**: 5,000 farmers allocated to castes per NSS proportions (General: 18%, OBC: 45%, SC: 15%, ST: 22%)
2. **Land**: Drawn from caste-specific log-normal distributions (see `config.py`)
3. **Wealth**: Drawn from caste-specific truncated normal distributions
4. **Debt**: Initialised from caste-specific probabilities (Block 13)
5. **MSP awareness**: Initialised from caste-specific probabilities (Block 14)
6. **Location**: Randomly assigned to one of 50 districts
7. **Buyers**: 6 channel types × 50 districts = 300 buyer agents

---

## 6. INPUT DATA

The model does not use external time-varying input data. All parameters are calibrated from the NSSO 77th Round cross-section (2018–19).

---

## 7. SUBMODELS

### 7.1 Channel Choice

Channel selection probability for farmer *i* of caste *c* with land *l*, debt status *d*, and MSP awareness *m*:

```
P(channel_j | c, l, d, m) ∝ base_prob(c, j) 
                              + land_effect(j) × l
                              + debt_lock_in(d, j)
                              + msp_boost(m, j, crop)
                              + fpo_scenario(c, j)
```

Normalised to sum to 1 across channels.

### 7.2 Price Determination

Price for farmer *i* selling crop *k* through channel *j*:

```
price_i = base_price(k) × price_shock(k) 
          × channel_mult(j) 
          × exp(within_channel_penalty(j, c))
          × exp(distress_discount(d, j))
          × quantity_discount(qty)
```

### 7.3 Wealth Update

```
net_income = revenue - input_costs - debt_service
mpce_new = 0.7 × mpce_old + 0.3 × max(500, income_per_capita_monthly)
```

### 7.4 Debt Dynamics

If net_income < 0:
  - debt increases by 50% of the deficit
  - 10% probability of shifting to informal debt

If net_income > 0:
  - 20% of net income used for debt repayment
  - Debt cleared → informal debt flag reset

---

## 8. CALIBRATION AND VALIDATION

### 8.1 Calibration Sources

All parameters derived from NSSO 77th Round analysis pipeline:
- `04_descriptives.r` → Initial distributions
- `05_price_regressions.R` → Caste price penalties
- `06_oaxaca.R` → Explained/unexplained gap shares
- `07_agency_regressions.R` → Channel choice probabilities
- `09_mechanisms.R` → MSP awareness, debt, input cost parameters

### 8.2 Validation Targets (Pattern-Oriented Modelling)

| Pattern | Empirical Target | ABM Should Reproduce |
|---------|-----------------|---------------------|
| SC-General price gap | ~5-8% | ✓ Within range |
| ST-General price gap | ~7-10% | ✓ Within range |
| SC trader dependence | ~50-55% | ✓ Within range |
| General APMC access | ~25-30% | ✓ Within range |
| Oaxaca unexplained share | >50% of gap | Emergent (not hard-coded) |
| Larger penalty at Q10 vs Q90 | Confirmed in quantile regressions | Emergent |

---

## 9. LIMITATIONS AND CAVEATS

1. **No panel validation**: Temporal dynamics are generated, not empirically validated
2. **No network structure**: Agent interactions are market-mediated only
3. **No strategic learning**: Agents do not adapt strategies based on experience
4. **No supply-side dynamics**: Buyer agents are passive
5. **No spatial topology**: Districts are labels, not a connected landscape
6. **Cross-sectional calibration**: All behavioural parameters from a single survey round

---

## References

- Grimm, V. et al. (2006). A standard protocol for describing individual-based and agent-based models. *Ecological Modelling*, 198(1-2), 115-126.
- Grimm, V. et al. (2010). The ODD protocol: A review and first update. *Ecological Modelling*, 221(23), 2760-2768.
- Grimm, V. et al. (2020). The ODD protocol for describing agent-based and other simulation models: A second update. *JASSS*, 23(2), 7.
- Harriss-White, B. (2003). *India Working: Essays on Society and Economy*. Cambridge University Press.
- Bardhan, P.K. (1980). Interlocking factor markets and agrarian development. *Oxford Economic Papers*, 32(1), 82-98.
- du Toit, A. (2004). Social exclusion discourse and chronic poverty. *Development and Change*, 35(5), 987-1010.
