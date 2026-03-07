# ==============================================================================
# 07_analysis_ST_Land_Penalty.R
# Analyzing the "Geography Trap" for Adivasi (ST) Farmers by Land Size
# ==============================================================================

# Ensure df_final exists
if(!exists("df_final")) stop("Error: df_final not found. Run 03_cleaning.R first.")

library(fixest)
library(ggplot2)
library(dplyr)
library(modelsummary)

cat("=== ANALYZING ST FARMER PRICE PENALTY BY LAND SIZE ===\n")

# ==============================================================================
# STEP 1: CALCULATE PRICE GAP FOR STs BY LAND SIZE
# ==============================================================================

# We define the categories
land_categories <- c("Marginal", "Small", "Medium", "Large")

# Initialize results dataframe
results_st <- data.frame(
  Category = character(),
  Estimate = numeric(),
  ConfLow = numeric(),
  ConfHigh = numeric(),
  P_Value = numeric(),
  stringsAsFactors = FALSE
)

cat("\nRunning regressions for each land category (ST vs General)...\n")

for (cat in land_categories) {
  
  # 1. Subset data: Only this land size, Only ST and General (exclude SC/OBC)
  df_subset <- df_final %>% 
    filter(land_size == cat) %>%
    filter(caste_cat %in% c("General", "ST"))
  
  # 2. Run Fixed Effects Model (Controlling for District & Crop)
  # This isolates the "Social" penalty from the "Spatial" penalty
  if(nrow(df_subset) > 100) {
    model <- feols(log_unit_price ~ caste_cat + log_qty_sold + log_mpce | crop_code_char + district, 
                   data = df_subset, 
                   weights = ~weight,
                   cluster = ~fsu_id)
    
    # 3. Extract Coefficient for ST
    coef_summary <- summary(model)$coeftable
    
    if("caste_catST" %in% rownames(coef_summary)) {
      est <- coef_summary["caste_catST", "Estimate"]
      se  <- coef_summary["caste_catST", "Std. Error"]
      p   <- coef_summary["caste_catST", "Pr(>|t|)"]
      
      # Convert log points to percentage: (exp(beta) - 1) * 100
      est_pct <- (exp(est) - 1) * 100
      low_pct <- (exp(est - 1.96 * se) - 1) * 100
      high_pct <- (exp(est + 1.96 * se) - 1) * 100
      
      results_st <- rbind(results_st, data.frame(
        Category = cat,
        Estimate = est_pct,
        ConfLow = low_pct,
        ConfHigh = high_pct,
        P_Value = p
      ))
    }
  }
}

# Fix factor ordering for the plot
results_st$Category <- factor(results_st$Category, levels = c("Marginal", "Small", "Medium", "Large"))

print(results_st)

# ==============================================================================
# STEP 2: GENERATE THE GRAPH
# ==============================================================================

cat("\nGenerating ST Penalty Plot...\n")

# Create color logic: Red if significant, Grey if not
results_st$Significance <- ifelse(results_st$P_Value < 0.05, "Significant Penalty", "Not Significant")

p_st <- ggplot(results_st, aes(x = Category, y = Estimate)) +
  
  # 1. Add Reference Line at 0 (No discrimination)
  geom_hline(yintercept = 0, linetype = "dashed", color = "#555555", linewidth = 1) +
  
  # 2. Add Error Bars (Confidence Intervals)
  geom_errorbar(aes(ymin = ConfLow, ymax = ConfHigh, color = Significance), 
                width = 0.15, linewidth = 1, alpha = 0.6) +
  
  # 3. Add Points
  geom_point(aes(color = Significance), size = 5) +
  
  # 4. Add Labels
  geom_text(aes(label = sprintf("%.1f%%", Estimate)), 
            vjust = -1.5, fontface = "bold", color = "#444444") +
  
  # 5. Custom Colors (Red for Penalty, Grey for Noise)
  scale_color_manual(values = c("Significant Penalty" = "#D9534F", "Not Significant" = "#AAAAAA")) +
  
  # 6. Titles and Theme
  labs(
    title = "The 'Geography Trap': ST Price Penalty by Land Size",
    subtitle = "Percentage difference in crop prices for ST farmers vs. General Caste (same district)",
    x = "Farmer Land Category",
    y = "Price Difference (%)",
    caption = "Note: Estimates control for crop, qty, wealth, and District FE.\nUnlike SCs, even 'Landed' ST farmers face significant price penalties."
  ) +
  
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    axis.text = element_text(size = 12),
    axis.title = element_text(size = 13, face = "bold"),
    legend.position = "none",
    panel.grid.major.x = element_blank()
  ) +
  
  # 7. Fix Y-axis scale (match previous graphs for consistency)
  coord_cartesian(ylim = c(-15, 5))

print(p_st)

# Save the plot
ggsave("st_land_penalty_plot.png", plot = p_st, width = 8, height = 6, dpi = 300)

cat("✅ Plot saved as 'st_land_penalty_plot.png'\n")

# ==============================================================================
# STEP 3: FORMAL COMPARISON (SC vs ST Land Effect)
# ==============================================================================

cat("\n--- Comparison: Does Land Help STs as much as SCs? ---\n")

# We run a simplified interaction model to print the coefficient for "Landed" STs vs "Landed" SCs
df_landed_check <- df_final %>%
  mutate(is_landed = ifelse(total_land > 0.5, 1, 0))

# Model for SC
cat("\n[SC Model] Effect of being Landed (>0.5ha) on Price:\n")
m_sc <- feols(log_unit_price ~ is_landed + log_qty_sold | crop_code_char + district, 
              data = subset(df_landed_check, caste_cat == "SC"),
              weights = ~weight)
print(coef(m_sc)["is_landed"])

# Model for ST
cat("\n[ST Model] Effect of being Landed (>0.5ha) on Price:\n")
m_st <- feols(log_unit_price ~ is_landed + log_qty_sold | crop_code_char + district, 
              data = subset(df_landed_check, caste_cat == "ST"),
              weights = ~weight)
print(coef(m_st)["is_landed"])

cat("\nInterpretation: If ST coefficient is smaller/insignificant, land helps them less.\n")