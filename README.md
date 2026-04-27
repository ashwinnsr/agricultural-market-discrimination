# The Double Squeeze: Market Access and Price Discrimination in Indian Agriculture

## Project Overview
This research analyzes the **"Final Mile" gap** in Indian agriculture, shifting the focus from production-side disadvantages (land and credit) to structural disadvantages at the market gate. Using the **NSS 77th Round (2019)**, the study investigates whether Scheduled Caste (SC) and Scheduled Tribe (ST) farmers face distinct mechanisms of discrimination: **Exclusion** from formal markets versus **Extraction** through predatory pricing.

## Research Objectives
1.  **Mechanism Identification**: Distinguish between market access barriers for ST farmers and price penalties for SC farmers.
2.  **Intersectional Analysis**: Test if land ownership mitigates or intensifies caste-based bias.
3.  **Spatial vs. Social**: Determine if price gaps are driven by geographic location or social identity.

## Dataset & Variables
* **Source**: NSS 77th Round, Schedule 33.1 (2019).
* **Sample**: 74,565 sales records (final analytical dataset).
* **Key Metrics**: 
    * **Unit Price**: Value sold divided by quantity.
    * **Market Choice**: Formal (Mandi/Coop/Govt) vs. Informal (Private Trader).
    * **Land Categories**: Marginal (<0.5ha), Small (0.5-2ha), Medium (2-5ha), and Large (>5ha).
    * **Demographics**: General (20,722), OBC (30,335), SC (8,343), ST (15,165).

## Technical Implementation

### Econometric Models
* **Model 1 (Agency Choice)**: Linear Probability Models testing likelihood of accessing Private Traders, Mandis, Cooperatives, and Government Procurement.
* **Model 2 (Price Discrimination & Quantile Regressions)**: A log-linear model using **District Fixed Effects**. Extended with Quantile Regressions (10th, 50th, 90th percentiles using the Frisch-Newton method) to assess distributional penalties.
* **Model 3 (Adverse Incorporation)**: Interaction models testing extraction mechanisms via Sharecropping (interlocked land-labor-output markets).

### Pipeline Execution
The entire analysis is automated via a master script.
**Run instruction:** `source("00_run_all.R")` (Runtime: ~0.3 minutes).

### File Structure
```bash
├── scripts/
│   ├── 00_run_all.R                 # Master script to run full pipeline
│   ├── 01_new_setup.r               # Environment and package loading
│   ├── 02_dataloading_FINAL.r       # NSS 77th Round data ingestion
│   ├── 03_cleaning.r                # Standardized cleaning and price calculation
│   ├── 04_updated_new_analysis.r    # Main fixed-effects and quantile regressions
│   ├── 05_visualisation_new.r       # Land size heterogeneity plots
│   ├── 06_analysis_ST_Land_Penalty.r # ST-specific land interaction analysis
│   ├── 07_mechanisms_analysis.r     # Tied land-labor (Sharecropper) proxies
│   └── 08_state_wise_agency.R       # Geospatial mapping of procurement
├── plots/
│   ├── price_gaps_by_caste.png      # Weighted average price distribution
│   ├── market_access_by_caste_expanded.png  # Agency choice by social group
│   ├── plot_marginal_penalty.png    # SC Price penalty across land sizes
│   ├── st_land_penalty_plot.png     # ST-specific price extraction effects
│   ├── map_govt_share.png           # Geospatial: Govt Procurement
│   └── map_trader_share.png         # Geospatial: Private Trader Dominance
└── README.md
```

## Key Findings 

### 1. Divergent Market Access
* **SC Shift**: SC farmers are **10.5 percentage points less likely** to sell to private traders (p < 0.01). They show a significant retreat from informal markets into formal regulated Mandis.
* **The State Void**: Despite entering formal spaces, SC farmers do not capture higher rates of Government Procurement (FCI) or Cooperatives, leaving them in a state of "squeezed" inclusion.

### 2. The Glass Ceiling of Price Returns (Quantile Effects)
* **Distress Sales (10th Pct)**: Small positive coefficient (+0.8%). In distress, the market collapses for everyone equally.
* **Premium Sales (90th Pct)**: SC farmers face a consistent **-0.8% price penalty**, though less pronounced than the median (-1.9%).
* **Baseline Displacement**: The robust District FE model shows a consistent **-1.9% log point** displacement for SC farmers.
* **ST Penalty**: ST farmers face a significant **-4.6% price penalty** at the state level (p < 0.01), reflecting severe geographic exclusion.

### 3. Mechanisms of Adverse Incorporation
* **The Informality Trap**: High reliance on private traders (80%+) for SC and ST farmers.
* **Indebtedness**: SC households are **6.6 percentage points more likely** to hold debt from moneylenders, a key driver of tied sales.
* **Cooperative Success**: SC and ST farmers in cooperatives receive **7.3% and 10.7% higher prices** respectively, highlighting cooperatives as a critical intervention.

## Methodological Robustness
* **Spatial Controls**: High-dimensional Fixed Effects (District, Crop, State) neutralize geographic unobservables.
* **Inference**: Standard errors clustered at FSU (village) level.
* **Diagnostic Accuracy**: Pipeline uses the Frisch-Newton interior point method for robust quantile estimation on large samples.
