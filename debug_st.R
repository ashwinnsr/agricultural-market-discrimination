source("scripts/01_new_setup.r")
source("scripts/02_dataloading_FINAL.r")
source("scripts/03_cleaning.r")

df_final$crop_code_char <- as.character(df_final$crop_code)
df_final$land_size <- cut(df_final$total_land, breaks = c(0, 0.5, 2, 5, Inf), labels = c("Marginal", "Small", "Medium", "Large"), include.lowest = TRUE)

df_sub <- subset(df_final, land_size == "Marginal" & caste_cat %in% c("ST", "General"))
library(fixest)
m <- feols(log_unit_price ~ caste_cat + log_qty_sold + log_mpce | crop_code_char + district, data = df_sub, weights = ~weight)
print(summary(m))

cat("Top Prices by ST Marginal:\n")
st_marg <- df_sub[df_sub$caste_cat == "ST", ]
st_marg <- st_marg[order(-st_marg$unit_price), ]
print(head(st_marg[, c("crop_code_char", "state", "unit_price", "qty_sold", "weight", "district")], 20))
