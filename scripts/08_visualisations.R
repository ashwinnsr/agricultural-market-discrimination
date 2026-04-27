# ==============================================================================
# 08_visualisations.R
# Publication-quality plots for price discrimination and market access.
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(ggplot2)
library(dplyr)
library(tidyr)
library(scales)
library(purrr)

dir.create("../plots", showWarnings = FALSE)

cat("=== GENERATING VISUALISATIONS ===\n")

theme_agr <- function() {
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "grey30", size = 11),
    plot.caption  = element_text(color = "grey50", size = 9),
    axis.text     = element_text(color = "black"),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position    = "bottom",
    legend.title       = element_text(face = "bold")
  )
}

CASTE_COLORS <- c("General" = "#2196F3", "OBC" = "#FF9800", "SC" = "#F44336", "ST" = "#4CAF50")

# ==============================================================================
# PLOT 1: Weighted mean price by social group
# FIX: Hmisc::wtd.var fails silently for some caste groups when normwt=FALSE.
#      Use base R weighted variance formula directly.
# ==============================================================================
cat("Plot 1: Price gaps by caste...\n")

safe_wtd_var <- function(x, w) {
  keep <- !is.na(x) & !is.na(w) & w > 0
  x <- x[keep]; w <- w[keep]
  if (length(x) < 2) return(NA_real_)
  # Frequency-weight normalised variance
  wbar <- sum(w * x) / sum(w)
  sum(w * (x - wbar)^2) / (sum(w) - 1)
}

price_summ <- df_final %>%
  filter(!is.na(unit_price), !is.na(caste_cat)) %>%
  group_by(caste_cat) %>%
  summarise(
    n       = n(),
    wt_mean = {
      w <- weight[!is.na(weight) & weight > 0 & !is.na(unit_price)]
      x <- unit_price[!is.na(weight) & weight > 0 & !is.na(unit_price)]
      if (length(w) == 0) NA_real_ else sum(w * x) / sum(w)
    },
    wt_se   = sqrt(safe_wtd_var(unit_price, weight) / n),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lo = pmax(0, wt_mean - 1.96 * wt_se),
    ci_hi = wt_mean + 1.96 * wt_se
  )

cat("  price_summ:\n"); print(price_summ)

p1 <- ggplot(price_summ, aes(x = caste_cat, y = wt_mean, fill = caste_cat)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, linewidth = 0.8) +
  geom_text(aes(y = ci_hi, label = sprintf("Rs.%.1f", wt_mean)),
            vjust = -0.5, fontface = "bold", size = 4.5) +
  scale_fill_manual(values = CASTE_COLORS) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.18))) +
  labs(
    title    = "Average Crop Price Received by Social Group",
    subtitle = "Weighted means with 95% confidence intervals (NSS 77th Round)",
    x = "Social Group", y = "Average Price (Rs./kg)",
    caption = paste("Both agricultural half-years (Jul 2018 – Jun 2019).",
                    "N =", format(nrow(df_final), big.mark = ","))
  ) +
  theme_agr() + theme(legend.position = "none")

ggsave("../plots/p1_price_by_caste.png", p1, width = 8, height = 6, dpi = 300)

# ==============================================================================
# PLOT 2: Market channel distribution (stacked bar)
# ==============================================================================
cat("Plot 2: Market channel distribution...\n")

channel_share <- df_final %>%
  filter(!is.na(agency_label)) %>%
  group_by(caste_cat, agency_label) %>%
  summarise(wt_n = sum(weight, na.rm = TRUE), .groups = "drop") %>%
  group_by(caste_cat) %>%
  mutate(share = wt_n / sum(wt_n) * 100) %>%
  ungroup() %>%
  mutate(agency_label = factor(agency_label, levels = c(
    "APMC Mandi", "Government", "Cooperative", "FPO",
    "Private Processor", "Contract Farming", "Input Dealer", "Local Trader", "Others"
  )))

CHANNEL_COLORS <- c(
  "APMC Mandi"        = "#1565C0", "Government"    = "#2E7D32",
  "Cooperative"       = "#00838F", "FPO"           = "#00ACC1",
  "Private Processor" = "#F57F17", "Contract Farming" = "#FF8F00",
  "Input Dealer"      = "#BF360C", "Local Trader"  = "#B71C1C",
  "Others"            = "#9E9E9E"
)

p2 <- ggplot(channel_share, aes(x = caste_cat, y = share, fill = agency_label)) +
  geom_col(position = "stack", width = 0.65) +
  scale_fill_manual(values = CHANNEL_COLORS, name = "Market Channel") +
  scale_y_continuous(labels = percent_format(scale = 1)) +
  labs(
    title    = "Market Channel Distribution by Social Group",
    subtitle = "Weighted share of crop sales by agency of sale (b6q10)",
    x = "Social Group", y = "Share of Sales (%)",
    caption = "Blue shades = formal/regulated; Red shades = informal/trader; NSS 77th Round"
  ) +
  theme_agr()

ggsave("../plots/p2_channel_by_caste.png", p2, width = 10, height = 6, dpi = 300)

# ==============================================================================
# PLOT 3: Price penalty by land size
# ==============================================================================
cat("Plot 3: SC price penalty by land size...\n")

if (file.exists("../results/land_heterogeneity_price.csv")) {
  land_het <- readr::read_csv("../results/land_heterogeneity_price.csv",
                              show_col_types = FALSE)
  p3 <- land_het %>%
    mutate(
      land_size = factor(land_size, levels = c("Landless","Marginal","Small","Medium","Large")),
      is_sig    = ifelse(ci_lo > 0 | ci_hi < 0, "Significant", "Not Significant")
    ) %>%
    ggplot(aes(x = land_size, y = pct_penalty, color = is_sig, group = group)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_point(size = 4) +
    geom_errorbar(aes(ymin = (exp(ci_lo) - 1) * 100, ymax = (exp(ci_hi) - 1) * 100),
                  width = 0.2, linewidth = 1) +
    geom_text(aes(label = sprintf("%.1f%%", pct_penalty)), vjust = -1.5,
              fontface = "bold", size = 3.5) +
    scale_color_manual(values = c("Significant"="#D32F2F","Not Significant"="#9E9E9E")) +
    facet_wrap(~group, ncol = 3) +
    labs(
      title    = "Price Penalty by Land Size Category",
      subtitle = "% difference in crop price vs General (District FE, crop controls)",
      x = "Land Size", y = "Price Difference (%)",
      caption = "Error bars = 95% CI. Significant = CI excludes 0.", color = ""
    ) +
    theme_agr() + theme(panel.grid.major.x = element_line(color = "grey90"))
  ggsave("../plots/p3_land_size_penalty.png", p3, width = 12, height = 6, dpi = 300)
}

# ==============================================================================
# PLOT 4: Satisfaction by social group
# FIX: Redesign to handle wildly different scales across panels.
#      Split into two sub-plots: large-scale outcomes vs. small-scale outcomes.
#      General bar was missing because satisfaction_code comparison failed
#      when b6q11 was haven-labelled (now fixed in 03_cleaning.r).
# ==============================================================================
cat("Plot 4: Sale satisfaction by caste...\n")

sat_vars <- c(
  "Satisfactory"       = "satisfied",
  "Below Market Price" = "dissatisfied_price",
  "Delayed Payment"    = "dissatisfied_delay",
  "Faulty Weighing"    = "dissatisfied_weigh",
  "Loan Deductions"    = "dissatisfied_loan"
)

sat_available <- sat_vars[sat_vars %in% names(df_final)]

if (length(sat_available) > 0) {
  sat_data <- map_dfr(names(sat_available), function(lbl) {
    col <- sat_available[lbl]
    df_final %>%
      filter(!is.na(.data[[col]])) %>%
      group_by(caste_cat) %>%
      summarise(
        pct = mean(as.numeric(.data[[col]]), na.rm = TRUE) * 100,
        .groups = "drop"
      ) %>%
      mutate(outcome = lbl)
  }) %>%
    mutate(
      outcome = factor(outcome, levels = names(sat_available)),
      # Tag large-scale vs small-scale for separate faceting
      scale_group = ifelse(outcome %in% c("Satisfactory","Below Market Price"),
                           "Major outcomes (0–80%)", "Minor outcomes (0–5%)")
    )

  # A: Major outcomes
  p4a <- sat_data %>%
    filter(scale_group == "Major outcomes (0–80%)") %>%
    ggplot(aes(x = caste_cat, y = pct, fill = caste_cat)) +
    geom_col(width = 0.65, alpha = 0.85) +
    geom_text(aes(label = sprintf("%.1f%%", pct)), vjust = -0.4,
              fontface = "bold", size = 4) +
    scale_fill_manual(values = CASTE_COLORS) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15)),
                       labels = function(x) paste0(x, "%")) +
    facet_wrap(~outcome, ncol = 2, scales = "fixed") +
    labs(
      title    = "Sale Outcomes by Social Group (Major Outcomes)",
      subtitle = "Weighted % of sales (b6q11) – NSS 77th Round",
      x = "Social Group", y = "% of Sales",
      caption = "Unweighted means shown; regression estimates in Table 3."
    ) +
    theme_agr() + theme(legend.position = "none")

  # B: Minor outcomes (different y-axis)
  p4b <- sat_data %>%
    filter(scale_group == "Minor outcomes (0–5%)") %>%
    ggplot(aes(x = caste_cat, y = pct, fill = caste_cat)) +
    geom_col(width = 0.65, alpha = 0.85) +
    geom_text(aes(label = sprintf("%.2f%%", pct)), vjust = -0.4,
              fontface = "bold", size = 3.5) +
    scale_fill_manual(values = CASTE_COLORS) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.20)),
                       labels = function(x) paste0(x, "%")) +
    facet_wrap(~outcome, ncol = 3, scales = "free_y") +
    labs(
      title    = "Sale Outcomes by Social Group (Minor Outcomes)",
      subtitle = "Weighted % of sales (b6q11) – NSS 77th Round",
      x = "Social Group", y = "% of Sales",
      caption = "Note: Low-frequency events; scale differs from major outcomes panel."
    ) +
    theme_agr() + theme(legend.position = "none")

  ggsave("../plots/p4a_satisfaction_major.png", p4a, width = 10, height = 5, dpi = 300)
  ggsave("../plots/p4b_satisfaction_minor.png", p4b, width = 12, height = 5, dpi = 300)

  # Also save combined version using patchwork if available
  if (requireNamespace("patchwork", quietly = TRUE)) {
    library(patchwork)
    p4_combined <- p4a / p4b +
      plot_annotation(
        title   = "Sale Satisfaction Outcomes by Social Group",
        caption = "NSS 77th Round, Schedule 33.1 (b6q11)"
      )
    ggsave("../plots/p4_satisfaction_by_caste.png", p4_combined,
           width = 14, height = 10, dpi = 300)
  } else {
    # Fall back: use p4a as the main output
    ggsave("../plots/p4_satisfaction_by_caste.png", p4a, width = 10, height = 5, dpi = 300)
  }
}

# ==============================================================================
# PLOT 5: State-level channel shares (horizontal bar)
# FIX: Use agency_label string comparison instead of sold_to_* binary
#      indicators (which were NA when agency_code was computed via
#      as.numeric(as.character(haven_labelled)) -- now fixed in 03_cleaning.r,
#      but keeping direct string comparison as belt-and-suspenders).
# ==============================================================================
cat("Plot 5: State-level market channel shares...\n")

state_mapping_abbr <- c(
  "01"="J&K",         "02"="Himachal Pradesh",  "03"="Punjab",
  "04"="Chandigarh",  "05"="Uttarakhand",        "06"="Haryana",
  "07"="Delhi",       "08"="Rajasthan",           "09"="Uttar Pradesh",
  "10"="Bihar",       "11"="Sikkim",              "12"="Arunachal Pradesh",
  "13"="Nagaland",    "14"="Manipur",             "15"="Mizoram",
  "16"="Tripura",     "17"="Meghalaya",           "18"="Assam",
  "19"="West Bengal", "20"="Jharkhand",           "21"="Odisha",
  "22"="Chhattisgarh","23"="Madhya Pradesh",      "24"="Gujarat",
  "25"="Daman & Diu", "26"="D&NH",                "27"="Maharashtra",
  "28"="Andhra Pradesh","29"="Karnataka",         "30"="Goa",
  "31"="Lakshadweep", "32"="Kerala",              "33"="Tamil Nadu",
  "34"="Puducherry",  "35"="A&N Islands",         "36"="Telangana"
)

state_channels <- df_final %>%
  filter(!is.na(state)) %>%
  mutate(state_name = state_mapping_abbr[state]) %>%    # state already padded in cleaning
  filter(!is.na(state_name), !is.na(agency_label)) %>%
  group_by(state_name) %>%
  summarise(
    n            = n(),
    apmc_share   = 100 * sum(agency_label == "APMC Mandi",   na.rm = TRUE) / n(),
    trader_share = 100 * sum(agency_label == "Local Trader",  na.rm = TRUE) / n(),
    govt_share   = 100 * sum(agency_label == "Government",    na.rm = TRUE) / n(),
    .groups = "drop"
  ) %>%
  filter(n > 100) %>%
  arrange(apmc_share)

cat("  State channels computed for", nrow(state_channels), "states\n")
cat("  APMC range:", round(range(state_channels$apmc_share), 1), "\n")

p5 <- state_channels %>%
  pivot_longer(cols = ends_with("_share"), names_to = "channel", values_to = "pct") %>%
  mutate(
    channel = recode(channel,
      apmc_share   = "APMC Mandi",
      trader_share = "Local Trader",
      govt_share   = "Government"
    ),
    channel    = factor(channel, levels = c("APMC Mandi", "Government", "Local Trader")),
    state_name = factor(state_name, levels = state_channels$state_name)
  ) %>%
  ggplot(aes(x = state_name, y = pct, fill = channel)) +
  geom_col(position = "dodge", width = 0.75) +
  coord_flip() +
  scale_fill_manual(
    values = c("APMC Mandi"="#1565C0", "Local Trader"="#B71C1C", "Government"="#2E7D32")
  ) +
  labs(
    title    = "State-wise Market Channel Shares",
    subtitle = "% of crop sales by channel (states with ≥100 obs, ordered by APMC share)",
    x = NULL, y = "Share of Sales (%)", fill = "Channel",
    caption = "NSS 77th Round. Count-based shares (unweighted)."
  ) +
  theme_agr() +
  theme(axis.text.y = element_text(size = 10))

ggsave("../plots/p5_state_channels.png", p5, width = 12, height = 10, dpi = 300)

cat("\n✅ All plots saved to ../plots/\n")
