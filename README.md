# Caste Inequities, Market Access, and Price Discrimination in Indian Agriculture

## Overview
This repository contains the complete end-to-end quantitative analysis pipeline investigating price formation, market channel selection, and caste-based economic disparities among Indian agricultural households. 

Using unit-level data from the **NSS 77th Round (Schedule 33.1: Land and Livestock Holdings of Agricultural Households, 2019)**, the project evaluates whether Scheduled Caste (SC) and Scheduled Tribe (ST) farmers face systematic price penalties at the market gate, and whether these disparities stem from **Exclusion** (lack of access to formal channels) or **Extraction / Squeezed Inclusion** (price penalties within market channels regardless of landholdings and location).

---

## Key Empirical Findings

1. **Baseline Price Penalty**:
   - SC farmers face a statistically significant **−1.1% to −1.3% baseline price penalty** relative to General/Forward caste farmers ($p < 0.01$) after controlling for high-dimensional District $\times$ Crop Fixed Effects, landholding size, irrigation, and transaction timing.
   - ST farmers face a state-level price deficit driven primarily by spatial concentration and remote geographic location.

2. **Oaxaca-Blinder Price Decomposition**:
   - Total raw price gap between SC and General caste farmers is **2.52 log points**.
   - **69.4% of the gap is EXPLAINED** by structural endowments (smaller land holdings, lower irrigation access, crop mix, and channel selection).
   - **30.6% of the gap (−0.77 log points) remains UNEXPLAINED**, representing direct within-market price discrimination and localized bargaining penalties.

3. **Distributional Impact (Quantile Regressions)**:
   - Price penalties are concentrated at the lower and median ends of the price distribution: **−1.3% at Q10**, **−1.1% at Q50 (median)**, and **−0.8% at Q90**.

4. **Market Access & "Squeezed Inclusion"**:
   - SC farmers are **2.2 percentage points more likely** to sell produce at APMC Mandis ($p < 0.01$) and **3.2 percentage points less likely** to rely on informal Local Traders relative to General caste farmers.
   - Despite participating in regulated Mandis at higher rates, SC farmers do not capture higher prices or state procurement quotas (FCI/Cooperatives), reflecting a state of "squeezed inclusion".

5. **Within-Channel Price Discrimination**:
   - Controlling for channel choice, SC farmers face a **−1.1% price penalty** even within informal Local Trader transactions ($p < 0.01$), proving that market channel selection alone does not eliminate caste-based price disparities.

---

## Directory Structure

```bash
code/
├── India Shape/                         # Shapefiles for spatial mapping (india_st.shp, india_ds.shp)
├── plots/                               # Publication-ready visualizations (PNG format, 300 DPI)
│   ├── map_govt_share.png               # State-wise Government procurement share
│   ├── map_mandi_share.png              # State-wise APMC Mandi share
│   ├── map_trader_share.png             # State-wise Local Trader share
│   ├── p1_price_by_caste.png            # Log price distribution density by social group
│   ├── p2_channel_by_caste.png          # Market channel selection shares by social group
│   ├── p3_land_size_penalty.png         # SC price penalty across land holding size classes
│   ├── p4_satisfaction_by_caste.png     # Price satisfaction rates by social group
│   ├── p4a_satisfaction_major.png       # Price satisfaction for major crops
│   ├── p4b_satisfaction_minor.png       # Price satisfaction for minor crops
│   └── p5_state_channels.png            # State-level breakdown of agency selection
├── results/                             # Statistical output tables and model objects
│   ├── agency_regression_results.rds    # Fitted LPM model objects for channel choice
│   ├── land_heterogeneity_price.csv     # Regression coefficients across land classes
│   ├── mechanisms_results.rds           # Fitted mechanism model objects
│   ├── mh_hh_income.rds                 # Household income summary objects
│   ├── nss77_quantile_summary.csv       # Quantile regression estimates (Q10, Q50, Q90)
│   ├── nss77_results_summary.csv        # Main OLS price regression summary (M1–M6)
│   ├── nss77_robust_results.rds         # Main price regression fit objects
│   ├── oaxaca_decomposition_summary.csv # Oaxaca decomposition output
│   ├── oaxaca_full_results.rds          # Oaxaca decomposition fit object
│   ├── price_regression_results.rds     # Complete price model objects
│   ├── table1_descriptives_by_group.csv # Descriptive statistics (Table 1)
│   ├── table_crop_composition.csv       # Crop selection by social group
│   ├── table_market_channels.csv        # Market channel breakdown
│   └── within_channel_price_penalty.csv # Within-channel price penalty estimates
├── scripts/                             # R pipeline analysis scripts
│   ├── 00_run_all.R                     # Master orchestrator script
│   ├── 01_setup.R                       # Packages, paths, weight constants & crop codebook
│   ├── 02_dataloading_FINAL.r           # Data ingestion for Visit 1 & Visit 2 (Blocks 4, 5, 6, 13, 14)
│   ├── 03_cleaning.r                    # Price derivation, 1%/99% symmetric trimming & panel ID creation
│   ├── 04_descriptives.r                # Descriptive statistics, crop composition & Table 1 summary
│   ├── 05_price_regressions.R           # OLS price regressions (M1-M6), Quantile regressions & M7 land interactions
│   ├── 06_oaxaca.R                      # Oaxaca-Blinder two-fold gap decomposition (SC vs. General)
│   ├── 07_agency_regressions.R          # Linear Probability Models (LPM) for agency selection
│   ├── 08_visualisations.R              # Plots generator for distributions, channel choices & penalties
│   ├── 09_mechanisms.R                  # Within-channel price regressions & mechanism tests
│   ├── 10_state_maps.R                  # Geospatial choropleth map generator
│   └── run_pipeline.bat                 # Windows batch execution script
├── .gitignore                           # Git ignore rules for data and large binaries
└── README.md                            # Pipeline documentation
```

---

## Pipeline Execution

### Prerequisites
- **R**: Version 4.0 or higher
- **Required Packages**:
  ```r
  install.packages(c("tidyverse", "haven", "survey", "fixest", 
                     "quantreg", "oaxaca", "modelsummary", 
                     "scales", "Hmisc", "sf", "geodata"))
  ```

### Running the Full Analysis
To execute the complete analysis pipeline from raw data to plots and results:

1. Open R or RStudio in the project root directory.
2. Run the master orchestrator script:
   ```r
   source("code/scripts/00_run_all.R")
   ```
   *Alternatively, on Windows, run `code/scripts/run_pipeline.bat` from command prompt.*

---

## Methodological Summary

- **Sampling & Weights**: Analysis applies NSS household multipliers (`MLT / 100`) adjusted across combined Visit 1 and Visit 2 survey waves.
- **Outlier Handling**: Prices are computed as total sale value divided by quantity sold ($\text{INR/kg}$) and trimmed symmetrically at 1st and 99th percentiles within state-crop cells.
- **Fixed Effects & Clustering**: Regressions include high-dimensional District $\times$ Crop Fixed Effects (`District^Crop`) to control for local soil, weather, infrastructure, and crop-specific market conditions. Standard errors are clustered at the Primary Sampling Unit / FSU level (`FSU_Slno`).
- **Land Categorization**: Operational land holdings are categorized into Marginal ($< 0.5\text{ ha}$), Small ($0.5\text{--}2\text{ ha}$), Medium ($2\text{--}5\text{ ha}$), and Large ($> 5\text{ ha}$).
