# ==============================================================================
# 08_state_wise_agency.R
# Generating State-wise Distribution of Agency Shares (especially Govt Procurement)
# ==============================================================================

# Ensure df_final exists
if (!exists("df_final")) stop("Error: df_final not found. Please run the setup and cleaning scripts.")

library(dplyr)
library(ggplot2)

# Install missing packages for mapping if necessary
if (!requireNamespace("sf", quietly = TRUE)) install.packages("sf", repos = "http://cran.us.r-project.org")
if (!requireNamespace("geodata", quietly = TRUE)) install.packages("geodata", repos = "http://cran.us.r-project.org")

library(sf)
library(geodata)

cat("=== GENERATING STATE-WISE AGENCY DISTRIBUTION MAP ===\n")

# Map NSS state codes to names
# NSS 77th Round State Codes
state_mapping <- c(
    "01" = "Jammu and Kashmir", "02" = "Himachal Pradesh", "03" = "Punjab", "04" = "Chandigarh",
    "05" = "Uttarakhand", "06" = "Haryana", "07" = "Delhi", "08" = "Rajasthan", "09" = "Uttar Pradesh",
    "10" = "Bihar", "11" = "Sikkim", "12" = "Arunachal Pradesh", "13" = "Nagaland", "14" = "Manipur",
    "15" = "Mizoram", "16" = "Tripura", "17" = "Meghalaya", "18" = "Assam", "19" = "West Bengal",
    "20" = "Jharkhand", "21" = "Odisha", "22" = "Chhattisgarh", "23" = "Madhya Pradesh", "24" = "Gujarat",
    "25" = "Daman and Diu", "26" = "Dadra and Nagar Haveli", "27" = "Maharashtra", "28" = "Andhra Pradesh",
    "29" = "Karnataka", "30" = "Goa", "31" = "Lakshadweep", "32" = "Kerala", "33" = "Tamil Nadu",
    "34" = "Puducherry", "35" = "Andaman and Nicobar Islands", "36" = "Telangana"
)

# Calculate state-wise shares
state_shares <- df_final %>%
    mutate(State_Name = state_mapping[state]) %>%
    filter(!is.na(State_Name)) %>%
    group_by(State_Name) %>%
    summarise(
        Total_Sales = n(),
        Govt_Share = mean(sold_to_govt, na.rm = TRUE) * 100,
        Mandi_Share = mean(sold_to_mandi, na.rm = TRUE) * 100,
        Trader_Share = mean(sold_to_trader, na.rm = TRUE) * 100,
        Coop_Share = mean(sold_to_coop, na.rm = TRUE) * 100
    ) %>%
    filter(Total_Sales > 50) # Only include states with sufficient data

cat("State-wise Government Procurement Shares:\n")
print(state_shares %>% select(State_Name, Govt_Share) %>% arrange(desc(Govt_Share)))

# Try to get India shapefile using geodata
cat("\nDownloading/Loading India shapefile...\n")
india_map <- tryCatch(
    {
        ind_gadm <- geodata::gadm(country = "IND", level = 1, path = tempdir())
        st_as_sf(ind_gadm)
    },
    error = function(e) {
        cat("Could not load shapefile:", e$message, "\n")
        NULL
    }
)

if (!is.null(india_map)) {
    # Clean up names to match (GADM often has slightly different names)
    state_shares$Join_Name <- tolower(gsub(" and | & ", " ", state_shares$State_Name))
    india_map$Join_Name <- tolower(gsub(" and | & ", " ", india_map$NAME_1))

    # Standardize tricky names
    india_map$Join_Name[india_map$Join_Name == "jammu and kashmir"] <- "jammu kashmir"
    india_map$Join_Name[india_map$Join_Name == "nct of delhi"] <- "delhi"
    india_map$Join_Name[grepl("odisha", india_map$Join_Name)] <- "odisha"

    # Merge data
    map_data <- india_map %>% left_join(state_shares, by = "Join_Name")

    # Plot Government Share
    p_map_govt <- ggplot(data = map_data) +
        geom_sf(aes(fill = Govt_Share), color = "gray20", linewidth = 0.4) +
        scale_fill_viridis_c(
            option = "magma", direction = -1, name = "Govt Share (%)",
            na.value = "grey90", limits = c(0, max(map_data$Govt_Share, na.rm = T))
        ) +
        labs(
            title = "Government Procurement Share by State",
            subtitle = "Percentage of crop sales to Government/FCI",
            caption = "Grey lines indicate states with insufficient NSS data."
        ) +
        theme_void() +
        theme(
            plot.title = element_text(face = "bold", size = 20, hjust = 0.5),
            plot.subtitle = element_text(size = 14, hjust = 0.5),
            legend.position = "right",
            legend.title = element_text(size = 14, face = "bold"),
            legend.text = element_text(size = 12)
        )

    ggsave("../plots/map_govt_share.png", p_map_govt, width = 10, height = 10, dpi = 300, create.dir = TRUE)
    cat("✅ Map saved as '../plots/map_govt_share.png'\n")

    # Plot Trader Share (Informal)
    p_map_trader <- ggplot(data = map_data) +
        geom_sf(aes(fill = Trader_Share), color = "gray20", linewidth = 0.4) +
        scale_fill_viridis_c(option = "mako", direction = -1, name = "Trader Share (%)", na.value = "grey90") +
        labs(
            title = "Private Trader Share by State",
            subtitle = "Percentage of crop sales to Informal Private Traders"
        ) +
        theme_void() +
        theme(
            plot.title = element_text(face = "bold", size = 20, hjust = 0.5),
            plot.subtitle = element_text(size = 14, hjust = 0.5),
            legend.position = "right",
            legend.title = element_text(size = 14, face = "bold"),
            legend.text = element_text(size = 12)
        )
    ggsave("../plots/map_trader_share.png", p_map_trader, width = 10, height = 10, dpi = 300, create.dir = TRUE)
    cat("✅ Map saved as '../plots/map_trader_share.png'\n")
} else {
    cat("\nFalling back to bar chart since shapefile could not be loaded.\n")
    p_bar <- ggplot(state_shares, aes(x = reorder(State_Name, Govt_Share), y = Govt_Share, fill = Govt_Share)) +
        geom_col() +
        coord_flip() +
        theme_minimal() +
        labs(title = "Govt Procurement by State", x = "", y = "Share (%)") +
        scale_fill_viridis_c(option = "magma", direction = -1)
    ggsave("../plots/bar_govt_share.png", p_bar, width = 8, height = 10, dpi = 300, create.dir = TRUE)
    cat("✅ Bar chart saved as '../plots/bar_govt_share.png'\n")
}
