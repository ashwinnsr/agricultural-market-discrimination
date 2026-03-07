# ==============================================================================
# 05_visualize_land_heterogeneity.R
# Visualizing the "Marginal Penalty" - The specific disadvantage of poor SC farmers
# ==============================================================================

library(fixest)
library(ggplot2)
library(dplyr)
library(scales) # For percentage formatting

# Ensure df_final exists
if(!exists("df_final")) stop("Error: df_final not found. Run 03_cleaning.R first.")

cat("=== GENERATING LAND SIZE HETEROGENEITY PLOT ===\n")

# ------------------------------------------------------------------------------
# STEP 1: RUN REGRESSIONS BY LAND SIZE
# ------------------------------------------------------------------------------

# Define the land categories
land_categories <- c("Marginal", "Small", "Medium", "Large")
results_df <- data.frame()

for (size in land_categories) {
  # Filter data for this land size
  df_subset <- df_final %>% filter(land_size == size)
  
  # Skip if too few observations
  if(nrow(df_subset) < 100) next
  
  # Run the model: Log Price ~ Caste + Controls + District FE
  # We use District FE because that's your "Robust" standard
  model <- feols(log_unit_price ~ caste_cat + log_qty_sold + log_mpce | crop_code_char + district, 
                 data = df_subset, 
                 weights = ~weight,
                 cluster = ~fsu_id) # Cluster at village level
  
  # Extract SC coefficient
  coef_val <- coef(model)["caste_catSC"]
  se_val   <- se(model)["caste_catSC"]
  
  # Calculate 95% Confidence Intervals
  ci_lower <- coef_val - 1.96 * se_val
  ci_upper <- coef_val + 1.96 * se_val
  
  # Store results
  temp_df <- data.frame(
    land_size = size,
    coefficient = coef_val,
    se = se_val,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    # Convert log points to percentage terms: (e^beta - 1) * 100
    pct_penalty = (exp(coef_val) - 1) * 100,
    pct_lower = (exp(ci_lower) - 1) * 100,
    pct_upper = (exp(ci_upper) - 1) * 100,
    n_obs = nobs(model)
  )
  
  results_df <- rbind(results_df, temp_df)
}

# ------------------------------------------------------------------------------
# STEP 2: PREPARE PLOT DATA
# ------------------------------------------------------------------------------

# Determine significance for coloring
results_df <- results_df %>%
  mutate(
    is_significant = ifelse(pct_upper < 0 | pct_lower > 0, "Significant", "Not Significant"),
    land_size = factor(land_size, levels = c("Marginal", "Small", "Medium", "Large")),
    label_text = sprintf("%.1f%%", pct_penalty)
  )

print(results_df)

# ------------------------------------------------------------------------------
# STEP 3: CREATE THE PLOT
# ------------------------------------------------------------------------------

p_heterogeneity <- ggplot(results_df, aes(x = land_size, y = pct_penalty)) +
  
  # Add reference line at 0 (No discrimination)
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40", size = 1) +
  
  # Add error bars (Confidence Intervals)
  geom_errorbar(aes(ymin = pct_lower, ymax = pct_upper, color = is_significant), 
                width = 0.15, size = 1, alpha = 0.8) +
  
  # Add points (The Estimates)
  geom_point(aes(color = is_significant), size = 5) +
  
  # Add value labels
  geom_text(aes(label = label_text, color = is_significant), 
            vjust = -1.5, fontface = "bold", size = 4) +
  
  # Custom Colors: Red for significant penalty, Gray for insignificant
  scale_color_manual(values = c("Significant" = "#D9534F", "Not Significant" = "gray70")) +
  
  # Labels and Titles
  labs(
    title = "The 'Marginal' Penalty: Price Discrimination by Land Size",
    subtitle = "Percentage difference in crop prices for SC farmers vs. General Caste (same district)",
    y = "Price Difference (%)",
    x = "Farmer Land Category",
    caption = "Note: Estimates control for crop type, quantity sold, wealth, and District Fixed Effects.\nError bars represent 95% Confidence Intervals. 'Marginal' farmers own < 0.5 hectares."
  ) +
  
  # Theme Styling
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(color = "gray30", size = 12),
    legend.position = "none", # Hide legend since colors are self-explanatory
    axis.text = element_text(color = "black"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank() # Remove vertical grid lines for cleaner look
  )

# ------------------------------------------------------------------------------
# STEP 4: DISPLAY AND SAVE
# ------------------------------------------------------------------------------

print(p_heterogeneity)

ggsave("plot_marginal_penalty.png", plot = p_heterogeneity, width = 10, height = 6, dpi = 300)

cat("✅ Plot saved as 'plot_marginal_penalty.png'\n")