# Complete Results Guide: Model-by-Model

> This document explains every model in your NSS 77 analysis in plain language, with accurate significance levels, effect sizes, and honest assessments of what each result does and does not establish. Read through this before making any village selection.

---

## Section 0: What You're Measuring

**The outcome variable** is the **log unit price** (Rs. per kg) each farmer received for a crop sale.

**The reference group** is **General Caste** farmers. All caste coefficients mean: *"relative to an otherwise identical General Caste farmer."*

**Significance conventions used here** (corrected from pipeline labels):

| Symbol | Meaning |
|--------|---------|
| *** | p < 0.01 (very strong evidence) |
| ** | p < 0.05 (strong evidence) |
| * | p < 0.10 (weak/suggestive evidence) |
| (ns) | p ≥ 0.10 (not significant — do not report as a finding) |

---

## Section 1: Raw Descriptive Gaps (No Controls)

**Before any regression**, from `table1_descriptives_by_group.csv`:

| Group | Mean Price (Rs./kg) | Mean Log Price | Land (acres) | Informal Debt (%) | Formal Sales (%) |
|-------|---------------------|----------------|-------------|-------------------|------------------|
| General | 30.84 | 2.95 | 3.75 | 19.5% | 18.3% |
| OBC | 31.20 | 3.02 | 3.42 | 26.2% | 18.9% |
| SC | 26.55 | 2.96 | 2.21 | 31.9% | 13.4% |
| ST | 29.66 | 3.11 | 3.01 | 31.7% | 10.8% |

**What to notice:**
- SC farmers have the **lowest raw Rs./kg price** (26.55 vs 30.84 for General) — a gap of Rs. 4.3/kg.
- But ST farmers have a **higher log price** (3.11 vs 2.95) in raw terms, even though their Rs./kg is lower — this is because ST farmers concentrate in **high-value-per-kg crops** (spices, horticulture, forest produce), not staples.
- SC farmers are **most excluded from formal markets** (13.4% vs 18.3% General) and have the **highest informal debt exposure** (31.9%).
- Dissatisfied with price (low price complaint): SC = 39.2%, General = 29.5% — a 10 percentage point gap — the **largest subjective satisfaction gap** in the dataset.

> These raw gaps are **not controlled for anything** — land, crop type, location. The regressions below untangle what is driving them.

---

## Section 2: OLS Price Regressions — M1 to M6

All models: Outcome = `log_unit_price`. Controls added progressively. Standard errors clustered by village (FSU).

### M1 — Baseline (Crop Fixed Effects only)

**Controls:** Crop type FE, survey wave only.

| Caste | Coefficient | % Effect | Significance |
|-------|-------------|----------|-------------|
| SC | −0.034 | −3.4% | ** |
| ST | ~−0.080 | ~−7.7% | ** |
| OBC | ~+0.025 | ~+2.5% | * to ** |

Within any given crop, SC farmers receive ~3.4% less. ST farmers ~7.7% less. OBC farmers receive a small *premium*. This model doesn't account for wealth, land, or local market conditions — those are major confounders.

---

### M2 — Adding Wealth and Land Controls

**Controls:** Crop FE, wave, quantity sold, MPCE, total land.

| Caste | Coefficient | % Effect | Significance |
|-------|-------------|----------|-------------|
| SC | −0.020 | −2.0% | ** |
| ST | ~−0.040 | ~−3.9% | ** |
| OBC | ~+0.025 | ~+2.5% | * to ** |

Once SC farmers' lower land ownership and wealth are accounted for, the SC gap halves (−3.4% → −2.0%). The gap does not disappear — it shrinks. This shows that **some of the raw gap is class-mediated (land/wealth), but not all of it**.

---

### M3 — Adding District Fixed Effects ← Preferred Specification

**Controls:** Crop FE, **district FE**, wave, quantity, MPCE, land.

District FE absorbs local market conditions — mandi proximity, infrastructure, dominant crop prices. This is the most conservative, defensible estimate of the *within-district* caste price gap.

| Caste | Coefficient | % Effect | Significance |
|-------|-------------|----------|-------------|
| SC | −0.022 | **−2.2%** | ** |
| ST | near-zero or ns | — | (ns once district FE added) |
| OBC | ~+0.020 | ~+2.0% | * |

The SC gap **survives district controls** — it is not explained by SC farmers simply living in worse-market areas. ST gap largely disappears when district FE is added (their disadvantage is geographic/crop-mix, not within-district). OBC premium persists.

---

### M4 — State Fixed Effects

**Controls:** Crop FE, **state FE** (less granular than district), wave, quantity, MPCE, land.

| Caste | Coefficient | % Effect | Significance |
|-------|-------------|----------|-------------|
| SC | −0.014 | −1.4% | * (marginal) |
| ST | large negative | absorbed | absorbed by state FE |
| OBC | **+0.0002** | **≈0%** | **(ns)** |

This is the **only model where OBC ≈ 0**. State FE absorbs the geographic clustering of OBC-dominant high-value agricultural regions (Punjab, Maharashtra, western UP). **Do not use M4 alone to characterise OBC outcomes** — it is misleading to single out this specification.

---

### M5 — District FE, No Quantity Control

Dropping quantity sold (which may be endogenous to price) gives an upper-bound estimate. SC penalty: −2.0% (**) — stable, confirming the penalty is not a quantity artefact.

### M6 — Categorical Land Class FE

Replacing continuous log-land with discrete land size bins: SC penalty ~−2.1% (**) — stable.

---

### Summary Across M1–M6

| Finding | Verdict |
|---------|---------|
| SC ~2% within-district price penalty | ✅ Consistent and significant (p<0.05) across M2, M3, M5, M6 |
| Class (land/wealth) explains ~half the raw SC gap | ✅ Confirmed |
| OBC premium of ~2–4% in most specifications | ✅ Consistent, often significant |
| OBC absorbed to zero under state FE (M4) | ✅ Confirmed — geography artifact, not the "true" OBC story |
| ST penalty absorbed by district FE | ✅ Confirmed — geography/crop-mix driven |

---

## Section 3: M7 — Caste × Land Class Interaction (UNRELIABLE)

**Purpose:** Tests whether the SC penalty concentrates among small/marginal farmers vs larger ones.

> [!CAUTION]
> **This model is flagged as unreliable in the pipeline code itself.** SC large-landholding farmers number only **7 households nationally** in the sample. These 7 households dominate the Large cell and produce a nonsensical −55% penalty. The pipeline comment explicitly says: *"DO NOT report these as robust findings."*

What the land-stratified results *do* show (Section 8 below) is that the penalty is small and non-significant in every land class where SC has adequate observations (Marginal, Small, Semi-Medium). **The caste×class interaction cannot be answered at national survey resolution.** This is precisely why PARI census data is needed.

---

## Section 4: Oaxaca-Blinder Decomposition

Decomposes the raw price gap into: **Explained** (endowment differences: land, crop mix, wealth) and **Unexplained** (the "discrimination residual" — gap not explained by observables).

### Results (Baseline with land control):

| Group | Raw Gap | Explained | Unexplained |
|-------|---------|-----------|-------------|
| SC | **−0.97%** | 69.4% | 30.6% (= −0.30%) |
| ST | **−14.8%** | 118.5% | **−18.5% (positive! = +2.97%)** |
| OBC | **−6.7%** | 59.7% | 40.3% (= −2.8%) |

**SC:** The raw gap is tiny (−0.97%). Of that, ~69% is explained by lower land/wealth/different crop mix. The unexplained residual is only −0.30 percentage points of a 0.97% gap — extremely small.

**ST:** The raw gap is large (−14.8%) but **more than 100% is explained by characteristics**. This means if ST farmers had the same land/crop/location as General farmers, they would receive *higher* prices. The unexplained component is +2.97% (favourable for ST). This is the concentration-reversal finding.

**OBC:** Raw gap of −6.7% is larger than SC in raw terms — but it is driven by endowment differences (crop mix, scale). The unexplained residual (−2.8%) is modest.

### Critical fragility test (dropping land control):

| Group | Explained | Unexplained |
|-------|-----------|-------------|
| SC | **469% of gap** | **−369% of gap** |

The SC Oaxaca decomposition is **structurally fragile** — including or excluding land swings the unexplained share by 800 percentage points. The raw gap (−0.97%) is too small to decompose reliably. **Do not use Oaxaca to claim how much SC discrimination "exists."**

---

## Section 5: Market Channel Access (LPMs — Script 07)

Linear probability models: Does caste predict *which channel* a farmer uses?

| Channel | SC vs General | ST vs General |
|---------|--------------|--------------|
| Local Trader | **+4–5 pp more likely** | **+7 pp more likely** |
| APMC Mandi | **−3 pp less likely** | −2 pp less likely |
| Government | similar | **−2 pp less likely** |
| Cooperative/FPO | **−1 pp less likely** | −0.5 pp less likely |

SC and ST farmers are systematically **pushed toward local traders and excluded from formal channels**. The formal channel exclusion gap: SC = 13.4%, General = 18.3% — a 4.9 percentage point difference.

> ✅ **This is one of the most robust findings in the analysis.** Systematic exclusion from formal markets is a structural disadvantage independent of any within-channel price penalty.

---

## Section 6: Within-Channel Price Penalties (The Core Puzzle — Corrected p-values)

For farmers who already use a specific channel, does caste predict the price within that channel?

> [!WARNING]
> **Corrected from all previous drafts.** Both the trader and government SC penalties have p > 0.05. They are significant only at the 10% level.

| Channel | Group | Effect | p-value | n | Verdict |
|---------|-------|--------|---------|---|---------|
| APMC Mandi | SC | −2.86% | 0.226 | 2,950 | **(ns)** |
| APMC Mandi | ST | −2.36% | 0.351 | 2,950 | **(ns)** |
| APMC Mandi | OBC | −3.44% | 0.050 | 2,950 | *(borderline) |
| **Local Trader** | **SC** | **−2.0%** | **0.065** | 56,218 | ***(p<0.10 only)*** |
| Local Trader | ST | −2.1% | 0.135 | 56,218 | **(ns)** |
| Local Trader | OBC | +1.1% | 0.192 | 56,218 | **(ns)** |
| **Government** | **SC** | **−3.76%** | **0.071** | 2,391 | ***(p<0.10 only; small n)*** |
| Government | ST | −3.59% | 0.196 | 2,391 | **(ns)** |
| Government | OBC | +0.34% | 0.861 | 2,391 | **(ns)** |
| **Cooperative/FPO** | **SC** | **+6.65%** | **0.013** | 1,370 | ✅ **(p<0.05)** |
| **Cooperative/FPO** | **ST** | **+10.8%** | **0.005** | 1,370 | ✅ **(p<0.01)** |
| **Cooperative/FPO** | **OBC** | **+5.26%** | **0.008** | 1,370 | ✅ **(p<0.01)** |

### The most important takeaway from this table:

**The cooperative/FPO channel is the strongest, clearest caste-price relationship in the entire analysis** — and it runs in the *opposite* direction from what the word "discrimination" implies. SC, ST, and OBC farmers all receive a significant *premium* of 5–11% inside cooperatives relative to General caste farmers. This likely reflects membership-based pricing rules, government-mandated procurement norms, or cooperative governance structures that reduce trader power.

The motivating research question therefore becomes not just "why is there a penalty in trader markets?" but: **"What institutional feature of cooperative markets produces better outcomes for marginalised groups — and why are SC/ST farmers largely excluded from accessing it?"**

---

## Section 7: ST Concentration Diagnostic (The Reversal)

**In ST-concentrated districts** (top 50% of ST observations):
- ST mean log price: **3.20**

**In other districts:**
- ST mean log price: **3.08**

ST farmers in their own demographic strongholds receive *higher* prices. This directly contradicts the idea that "being a minority in the market puts you at a disadvantage." Possible explanations (none confirmed):
- High-density ST areas may have community-level marketing institutions
- Statutory land protections (Tripura Tribal District Council, Schedule V/VI areas) may insulate markets
- Crop-mix effect: ST-concentrated areas may grow specific high-value traditional varieties (bamboo products, tribal horticulture)

**This is an open empirical puzzle — not a mechanism already identified by the NSS data.**

---

## Section 8: Land Heterogeneity Results

Separate regressions by land class (same M3 controls: crop FE, district FE):

| Land Class | SC Penalty | p-value (approx) | n | Reliable? |
|------------|-----------|------------------|---|-----------|
| Marginal (<2.5 ac) | −1.1% | >0.10 (ns) | 34,274 | ✅ Yes |
| Small (2.5–5 ac) | −1.6% | >0.10 (ns) | 23,345 | ✅ Yes |
| Semi-Medium (5–10 ac) | −0.8% | >0.10 (ns) | 13,244 | ✅ Yes |
| Medium (10–25 ac) | +8.4% | (ns) | 3,174 | ⚠️ Sparse SC |
| Large (>25 ac) | −55.4% | (ns) | 447 | ❌ SC n=7, absurd |

Within the land classes where SC has enough observations, the penalty is 0.8–1.6% and **not statistically significant**. The caste×class interaction cannot be estimated reliably at national scale. PARI village data — which covers every household — is the only way to cross-tabulate SC × tenurial class properly.

---

## Section 9: Quantile Regressions

SC coefficients at different points in the price distribution (cluster-bootstrap SEs):

| Quantile | SC Coefficient | Interpretation |
|----------|----------------|----------------|
| 10th (distress) | **+0.017** (positive) | SC not more exposed to distress-sale collapses |
| 50th (median) | −0.006 | Small negative, near zero |
| 90th (premium) | −0.015 | Small negative at premium sales |

SC farmers are **not disproportionately concentrated in the left tail** of the price distribution relative to General caste once crop and location are controlled. The average ~2% penalty appears distributed across the price distribution rather than concentrated in distress-sale episodes.

---

## Section 10: Mechanisms (Script 09)

### MSP Awareness
- SC farmers: **30.5%** aware of MSP vs **40.3%** General — a 10pp gap
- Significant after state FE and controls: SC systematically less informed
- Of those *aware*, SC still less likely to sell at MSP (7.1% vs 9.5% General)
- ✅ **Information asymmetry is a real and significant mechanism**

### Informal Debt
- SC: **31.9%** have informal lender debt vs **19.5%** General — 12pp gap
- After controls, SC remains significantly more likely to have moneylender/trader debt
- Credit-output interlocking is plausible: farmers who owe money to their buyer may face tied-sale prices
- ✅ **Informal debt exposure gap is significant and robust**

### Mediation (Channel as Mediator)
- ~30–40% of the total SC price gap is statistically mediated by formal channel exclusion
- ~60–70% is a "direct" within-channel component (unexplained by channel alone)
- ⚠️ Descriptive decomposition only — not a causal claim

---

## Section 11: Complete Significance Summary

| Claim | Verdict |
|-------|---------|
| SC farmers receive lower raw prices (Rs. 4.3/kg gap) | ✅ Established |
| ~2% SC within-district price penalty (M3 preferred) | ✅ Established (p<0.05) |
| SC formally excluded from APMC and cooperatives | ✅ Established |
| SC less MSP-aware after controls | ✅ Established |
| SC more informally indebted after controls | ✅ Established |
| SC/ST premium inside cooperatives (+7–11%) | ✅ Established (p<0.05 / p<0.01) |
| SC within-trader penalty (−2.0%) | ⚠️ Suggestive only (p=0.065) |
| SC within-government penalty (−3.8%) | ⚠️ Suggestive only (p=0.071; n=2,391) |
| SC within-APMC penalty | ❌ Not significant (p=0.23) |
| Caste × land class interaction | ❌ Cannot establish at national scale (SC n=7 at Large) |
| ST penalty driven by geography/crop-mix | ✅ Penalty absorbed by district FE |
| ST concentration-reversal | ✅ Higher prices in ST-dense districts — mechanism unknown |
| OBC premium of ~2–4% in most specs | ✅ Established across M1–M3, M5–M6 |
| OBC premium absorbed under state FE (M4) | ✅ Confirmed — likely geographic clustering artifact |
| Oaxaca SC unexplained = discrimination | ❌ Fragile — gap too small, swing of 800pp across specs |

---

## Section 12: Mapping Results to Village Selection

Now that you have clear results, here is how they map to PARI site requirements:

### Puzzle A — SC exclusion + informal debt + trader price gap
**What data you need:**  Complete household census with seller-level transaction data, debt source records (moneylender vs landlord vs bank), tenurial position.
**The PARI tool:** Blocks 5.1–5.3 (tenancy), Block 16 (labour obligation), Block 25 (indebtedness by source), Block 6B (marketing costs + transport).
**Best sites:** UP villages (Harevli, Mahatwar) — absentee landlordism, documented SC household majority under upper-caste land ownership, 2006–2023 resurvey panel.
**The question it answers:** Among SC households, does the ~2% within-trader penalty concentrate among landless sharecroppers tied to landlord-credit, or is it uniform across all SC households including marginal owner-cultivators?

### Puzzle B — ST concentration-reversal + statutory protection
**What data you need:** Villages inside and outside a statutory protected area (tribal council or Schedule V/VI zone) so you can compare with and without the institutional protection active.
**The PARI tool:** Census of all households; land records; channel documentation.
**Best sites:** Tripura PARI rounds — two villages inside Tripura Tribal Autonomous District Council + Muhuripur outside as benchmark.
**The question it answers:** Does statutory land security (rather than demographic majority/minority status alone) insulate tribal farmers from within-channel price suppression?

### Puzzle C — Why does the cooperative premium exist and why are SC/ST excluded from it?
**What data you need:** A village with an active cooperative or FPO where you can trace membership decisions and pricing rules.
**Bonus:** This could be incorporated into either UP or Tripura sites if a cooperative structure is documented there.
**The question it answers:** What institutional feature of cooperative markets equalises or reverses the caste price gap — and what prevents SC/ST farmers from accessing it?

> **Recommended sequence:** Lock in Puzzles A and B as the two main PARI investigations (UP for SC×class mechanisms; Tripura for ST concentration-reversal). Treat Puzzle C as a secondary diagnostic within whichever site has cooperative data. Then finalise village selection based on which specific PARI rounds contain the required Block-level data coverage.
