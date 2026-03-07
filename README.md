# To Enter or To Not Enter: Market Discrimination Against Marginalized Farmers

## Project Overview
This research analyzes the **"Final Mile" gap** in Indian agriculture, shifting the focus from production-side disadvantages (land and credit) to structural disadvantages at the market gate. Using the **NSS 77th Round (2019)**, the study investigates whether Scheduled Caste (SC) and Scheduled Tribe (ST) farmers face distinct mechanisms of discrimination: **Exclusion** from formal markets versus **Extraction** through predatory pricing.

## Research Objectives
1.  **Mechanism Identification**: Distinguish between market access barriers for ST farmers and price penalties for SC farmers.
2.  **Intersectional Analysis**: Test if land ownership mitigates or intensifies caste-based bias.
3.  **Spatial vs. Social**: Determine if price gaps are driven by geographic location or social identity.

## Dataset & Variables
* **Source**: NSS 77th Round, Schedule 33.1 (2019).
* **Sample**: 41,641 sales records.
* **Composition**: General (27.3%), OBC (39.6%), SC (11.0%), and ST (22.1%).
* **Key Metrics**: 
    * **Unit Price**: Value sold divided by quantity[cite: 25].
    * **Market Choice**: Formal (Mandi/Coop) vs. Informal (Private Trader).
    * **Land Categories**: Marginal (<0.5ha), Small (0.5-2ha), Medium (2-5ha), and Large (>5ha).

## Technical Implementation

### Econometric Models
* **Model 1 (Multinomial Market Access)**: A series of Linear Probability Models testing likelihood of accessing Private Traders, Mandis, Cooperatives, and Government Procurement.
* **Model 2 (Price Discrimination & Quantile Regressions)**: A log-linear model using **District Fixed Effects**. Extended with Quantile Regressions (10th, 50th, 90th percentiles) to assess distributional penalties.
* **Model 3 (Adverse Incorporation)**: Interaction models testing extraction mechanisms via Sharecropping (interlocked land-labor-output markets).

### File Structure


```bash
├── 01_setup.R                 # Configuration and package loading
├── 02_dataloading_BULLETPROOF.R  # Robust data loading with error handling
├── 03_cleaning_FINAL_FIXED.R  # Data cleaning and variable construction
├── 04_analysis_ROBUST_FIXED.R # Main econometric analysis
├── 05_visualize_land_heterogeneity.R  # Land size heterogeneity plots
├── 06_analysis_ST_Land_Penalty.R  # ST-specific analysis
├── nss77_robust_results.rds   # Saved analysis results
├── nss77_results_summary.csv  # Summary table of key findings
├── price_gaps_by_caste.png    # Visualization 1
├── market_access_by_caste.png # Visualization 2
└── plot_marginal_penalty.png  # Visualization 3
```

## Key Findings 

### 1. The Market Access Divide
* **SC Farmers**: 10.1 percentage points **less likely** to sell to private traders (p < 0.01) and disproportionately access regulated Mandis. However, they are systemically excluded from premium Government Procurement channels compared to General Caste peers.
* **ST Farmers**: Show different market access patterns, with greater reliance on informal channels (+4.0%), driven by geographic exclusion.

### 2. Price Discrimination Patterns (Quantile Effects)
* **Average (OLS)**: The aggregate OLS price penalty for SC farmers is negligible (-0.7%), but this masks extreme distributional heterogeneity.
* **Exclusion from Premium Markets (90th Percentile)**: SC farmers face a highly significant **-1.4% penalty** at the top of the price distribution, indicating exclusion from the highest-paying market opportunities.
* **Equalization at the Bottom (10th Percentile)**: Distress sales show no caste penalty (+1.7%), pointing to a universal price floor for desperate sellers.

### 3. Mechanisms of Adverse Incorporation
* **The Sharecropper Penalty**: Farmers under lease terms face significant price penalties compared to landowners in the exact same district selling the same crop. This proxy for tied-labor/debt highlights how pre-existing dependencies dictate disadvantageous output prices.

## Methodological Robustness

### Strengths
* **Fixed Effects**: District, Crop, and State fixed effects neutralize spatial unobservables.
* **Clustered Standard Errors**: At Primary Sampling Unit (village) level  
* **Sampling Weights**: NSS population weights applied throughout
* **Advanced Estimators**: Quantile regressions establish what OLS obscures; mechanistic proxies validate structural theories.

### Limitations
* **Cross-Sectional Data**: Cannot establish firm causality over time.
* **Small Marginal Samples**: Imprecise estimates for the absolute most vulnerable intersectional groups.
* **Missing Direct Mechanisms**: Relying on sharecropping as a proxy for tied-labor rather than direct measurement of trader-farmer debt contracts.

## Future Research Directions

### 1. Longitudinal Econometrics (Multi-Year Data)
* **Pseudo-Panel Construction**: Aggregate NSS 70th and 77th rounds at the District-Caste-Land cohort level to track the persistence of discrimination over time.
* **Difference-in-Differences (DiD)**: Use the staggered rollout of e-NAM (electronic markets) to see if digital integration reduces the "intersectional penalty" for marginal SC farmers.

### 2. Capturing Transactional Nuances (Fieldwork)
* **Audit Studies**: Conduct field experiments using identical crop quality to isolate pure caste bias from unobserved quality differences.
* **Interlocked Market Surveys**: Investigate if ST reliance on traders is driven by debt-traps (credit-output linkages) rather than just geographic distance.
* **Bargaining Observations**: Document "soft" barriers at the Mandi, such as wait times, weighing fraud, or arbitrary quality rejections.
