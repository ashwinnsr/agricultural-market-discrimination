# ==============================================================================
# 04_descriptives.R
# Table 1: Weighted Summary Statistics by Social Group
# This is the foundation of any rigorous empirical paper.
# All statistics are weighted by the survey multiplier (MLT/100).
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(tidyverse)
library(Hmisc)

cat("=== GENERATING DESCRIPTIVE STATISTICS (TABLE 1) ===\n")

# ==============================================================================
# HELPER: Weighted mean and SD
# ==============================================================================
wt_mean <- function(x, w) {
  x <- as.numeric(x); w <- as.numeric(w)
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (sum(ok) == 0) return(NA_real_)
  weighted.mean(x[ok], w[ok])
}

wt_sd <- function(x, w) {
  x <- as.numeric(x); w <- as.numeric(w)
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (sum(ok) < 2) return(NA_real_)
  sqrt(Hmisc::wtd.var(x[ok], w[ok], normwt = TRUE))
}

wt_pct <- function(x, w) {
  # Weighted proportion of x==1
  x <- as.numeric(x); w <- as.numeric(w)
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (sum(ok) == 0) return(NA_real_)
  weighted.mean(x[ok], w[ok]) * 100
}

# ==============================================================================
# PANEL A: Key variable means/SDs by social group
# ==============================================================================
cat("\n[A] Panel A: Means and SDs by social group\n")

vars_continuous <- list(
  "Unit Price (Rs./kg)"          = "unit_price",
  "Log Unit Price"               = "log_unit_price",
  "Qty Sold (kg)"                = "qty_sold",
  "MPCE (Rs./month)"             = "mpce",
  "Total Land (acres)"           = "total_land"
)

vars_binary <- list(
  "Sold to APMC (%)"             = "sold_to_apmc",
  "Sold to Local Trader (%)"     = "sold_to_trader",
  "Sold to Government (%)"       = "sold_to_govt",
  "Sold to Cooperative (%)"      = "sold_to_coop",
  "Sold to FPO (%)"              = "sold_to_fpo",
  "Sold Formally (%)"            = "sold_to_formal",
  "Satisfied with Sale (%)"      = "satisfied",
  "Dissatisfied: Low Price (%)"  = "dissatisfied_price",
  "Dissatisfied: Loan Deduc. (%)"= "dissatisfied_loan",
  "Sharecropper (%)"             = "is_sharecropper",
  "Has Any Debt (%)"             = "has_any_loan",
  "Has Informal Lender Debt (%)" = "has_informal_lender",
  "MSP Aware (%)"                = "any_msp_aware",
  "Sold at MSP (%)"              = "any_sold_at_msp"
)

groups <- c("General","OBC","SC","ST")

build_panel <- function(df) {
  results <- list()

  for (vname in names(vars_continuous)) {
    col <- vars_continuous[[vname]]
    if (!col %in% names(df)) next
    row_data <- data.frame(Variable = vname, Type = "Continuous")
    for (g in groups) {
      sub <- df %>% filter(caste_cat == g)
      m  <- wt_mean(sub[[col]], sub$weight)
      sd <- wt_sd(sub[[col]], sub$weight)
      row_data[[paste0(g,"_mean")]] <- round(m, 2)
      row_data[[paste0(g,"_sd")]]   <- round(sd, 2)
    }
    # Full sample
    row_data[["Full_mean"]] <- round(wt_mean(df[[col]], df$weight), 2)
    row_data[["Full_sd"]]   <- round(wt_sd(df[[col]], df$weight), 2)
    results[[vname]] <- row_data
  }

  for (vname in names(vars_binary)) {
    col <- vars_binary[[vname]]
    if (!col %in% names(df)) next
    row_data <- data.frame(Variable = vname, Type = "Binary (%)")
    for (g in groups) {
      sub <- df %>% filter(caste_cat == g)
      p <- wt_pct(sub[[col]], sub$weight)
      row_data[[paste0(g,"_mean")]] <- round(p, 1)
      row_data[[paste0(g,"_sd")]]   <- NA
    }
    row_data[["Full_mean"]] <- round(wt_pct(df[[col]], df$weight), 1)
    row_data[["Full_sd"]]   <- NA
    results[[vname]] <- row_data
  }

  bind_rows(results)
}

table1 <- build_panel(df_final)

# Add N (unweighted count per group)
n_by_group <- df_final %>%
  group_by(caste_cat) %>%
  summarise(n = n(), .groups = "drop")
n_total <- nrow(df_final)

cat("\n=== TABLE 1: DESCRIPTIVE STATISTICS BY SOCIAL GROUP ===\n")
cat(sprintf("%-35s %10s %10s %10s %10s %10s\n",
            "Variable", "General", "OBC", "SC", "ST", "Full"))
cat(strrep("-", 80), "\n")
for (i in seq_len(nrow(table1))) {
  r <- table1[i,]
  cat(sprintf("%-35s %10s %10s %10s %10s %10s\n",
              substr(r$Variable, 1, 35),
              paste0(r$General_mean, if (!is.na(r$General_sd)) paste0(" (", r$General_sd, ")") else ""),
              paste0(r$OBC_mean,     if (!is.na(r$OBC_sd))     paste0(" (", r$OBC_sd,     ")") else ""),
              paste0(r$SC_mean,      if (!is.na(r$SC_sd))      paste0(" (", r$SC_sd,       ")") else ""),
              paste0(r$ST_mean,      if (!is.na(r$ST_sd))      paste0(" (", r$ST_sd,       ")") else ""),
              paste0(r$Full_mean,    if (!is.na(r$Full_sd))    paste0(" (", r$Full_sd,     ")") else "")))
}
cat(strrep("-", 80), "\n")
cat("Observations:", paste(sapply(groups, function(g) {
  paste0(g, "=", n_by_group$n[n_by_group$caste_cat == g])
}), collapse="; "), "; Total=", n_total, "\n")

# ==============================================================================
# PANEL B: Raw mean price gap tests (t-test vs General caste)
# ==============================================================================
cat("\n\n[B] Panel B: Tests of mean price difference vs General caste\n")
cat(sprintf("%-10s %12s %12s %12s %12s\n",
            "Group", "Mean Price", "Gap vs Gen", "t-stat", "p-value"))
cat(strrep("-", 60), "\n")

general_prices <- df_final %>% filter(caste_cat == "General")
for (g in c("OBC","SC","ST")) {
  grp_prices <- df_final %>% filter(caste_cat == g)
  if (nrow(grp_prices) > 30) {
    tt <- tryCatch(
      t.test(grp_prices$unit_price, general_prices$unit_price),
      error = function(e) NULL
    )
    if (!is.null(tt)) {
      gap <- mean(grp_prices$unit_price, na.rm=TRUE) - mean(general_prices$unit_price, na.rm=TRUE)
      cat(sprintf("%-10s %12.2f %12.2f %12.2f %12.4f\n",
                  g,
                  mean(grp_prices$unit_price, na.rm=TRUE),
                  gap,
                  tt$statistic,
                  tt$p.value))
    }
  }
}

# ==============================================================================
# PANEL C: Crop composition by social group (top 10 crops)
# ==============================================================================
cat("\n\n[C] Panel C: Crop composition by social group (weighted share %)\n")

crop_comp <- df_final %>%
  group_by(caste_cat, crop_group) %>%
  summarise(wt_n = sum(weight, na.rm=TRUE), .groups="drop") %>%
  group_by(caste_cat) %>%
  mutate(share_pct = wt_n / sum(wt_n) * 100) %>%
  ungroup() %>%
  pivot_wider(id_cols = crop_group, names_from = caste_cat, values_from = share_pct, values_fill = 0) %>%
  arrange(desc(General))

print(crop_comp %>% mutate(across(where(is.numeric), ~round(., 1))))

# ==============================================================================
# PANEL D: Market channel distribution by social group
# ==============================================================================
cat("\n\n[D] Panel D: Market channel use by social group (weighted %)\n")

channel_cols <- c("sold_to_trader","sold_to_apmc","sold_to_govt",
                  "sold_to_coop","sold_to_fpo","sold_to_formal")
channel_labels <- c("Local Trader","APMC Mandi","Government",
                    "Cooperative","FPO","Formal (all)")

channel_table <- map_dfr(seq_along(channel_cols), function(i) {
  col <- channel_cols[i]
  if (!col %in% names(df_final)) return(NULL)
  df_final %>%
    group_by(caste_cat) %>%
    summarise(pct = wt_pct(.data[[col]], weight), .groups="drop") %>%
    mutate(channel = channel_labels[i])
}) %>%
  pivot_wider(id_cols = channel, names_from = caste_cat, values_from = pct) %>%
  mutate(across(where(is.numeric), ~round(., 1)))

print(channel_table)

# ==============================================================================
# SAVE TABLE 1
# ==============================================================================
dir.create("../results", showWarnings = FALSE)
write_csv(table1, "../results/table1_descriptives_by_group.csv")
write_csv(crop_comp, "../results/table_crop_composition.csv")
write_csv(channel_table, "../results/table_market_channels.csv")
cat("\n✅ Descriptive tables saved to ../results/\n")
