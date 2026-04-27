# ==============================================================================
# 10_state_maps.R
# State-wise choropleth maps of market channel shares.
#
# FIXES applied:
# 1. agency_code was NA for haven-labelled b6q10 -- root fix in 03_cleaning.r.
#    This script also uses agency_label string comparison as belt-and-suspenders.
# 2. GADM alias lookup now uses raw GADM NAME_1 as the key (before any
#    normalisation), fixing Jammu & Kashmir, Delhi, Odisha etc.
# 3. Non-participating states (A&N, Chandigarh, D&NH, Lakshadweep) are
#    correctly grey -- per NSS 77th Round design document.
# ==============================================================================

if (!exists("df_final")) stop("Run 03_cleaning.r first.")

library(dplyr)
library(ggplot2)
library(stringr)
library(tidyr)

if (!requireNamespace("sf",      quietly=TRUE)) install.packages("sf",      repos="http://cran.us.r-project.org")
if (!requireNamespace("geodata", quietly=TRUE)) install.packages("geodata", repos="http://cran.us.r-project.org")

library(sf)
library(geodata)

cat("=== GENERATING STATE-WISE AGENCY DISTRIBUTION MAP ===\n")

# NSS state codes → full names (should closely match GADM NAME_1 after aliasing)
state_mapping <- c(
    "01"="Jammu & Kashmir",       "02"="Himachal Pradesh",
    "03"="Punjab",                 "04"="Chandigarh",
    "05"="Uttarakhand",            "06"="Haryana",
    "07"="Delhi",                  "08"="Rajasthan",
    "09"="Uttar Pradesh",          "10"="Bihar",
    "11"="Sikkim",                 "12"="Arunachal Pradesh",
    "13"="Nagaland",               "14"="Manipur",
    "15"="Mizoram",                "16"="Tripura",
    "17"="Meghalaya",              "18"="Assam",
    "19"="West Bengal",            "20"="Jharkhand",
    "21"="Odisha",                 "22"="Chhattisgarh",
    "23"="Madhya Pradesh",         "24"="Gujarat",
    "25"="Daman & Diu",            "26"="Dadra & Nagar Haveli",
    "27"="Maharashtra",            "28"="Andhra Pradesh",
    "29"="Karnataka",              "30"="Goa",
    "31"="Lakshadweep",            "32"="Kerala",
    "33"="Tamil Nadu",             "34"="Puducherry",
    "35"="Andaman & Nicobar",      "36"="Telangana"
)

# --- Build state-level shares using agency_label (string comparison)
# This avoids dependence on sold_to_* binary indicators
state_shares <- df_final %>%
    filter(!is.na(state), !is.na(agency_label)) %>%
    mutate(State_Name = state_mapping[state]) %>%   # state already padded in 03_cleaning.r
    filter(!is.na(State_Name)) %>%
    group_by(State_Name) %>%
    summarise(
        Total_Sales  = n(),
        Govt_Share   = 100 * sum(agency_label == "Government",  na.rm=TRUE) / n(),
        Mandi_Share  = 100 * sum(agency_label == "APMC Mandi",  na.rm=TRUE) / n(),
        Trader_Share = 100 * sum(agency_label == "Local Trader", na.rm=TRUE) / n(),
        Coop_Share   = 100 * sum(agency_label == "Cooperative",  na.rm=TRUE) / n(),
        .groups = "drop"
    ) %>%
    filter(Total_Sales > 100)

cat("State-wise data (", nrow(state_shares), "states with >100 obs):\n")
print(state_shares %>% select(State_Name, Total_Sales, Govt_Share, Mandi_Share, Trader_Share) %>%
          arrange(desc(Mandi_Share)), n = 36)

# --- Load shapefile ---
cat("\nLoading local official India shapefile...\n")
india_map <- tryCatch({
    # The shapefile is located outside the 'code' directory in 'India Shape'
    shp <- st_read("../../India Shape/india_st.shp", quiet=TRUE)
    
    # Identify the state name column dynamically (e.g. STATE, ST_NM, NAME_1, statename)
    col_names <- names(shp)
    state_col <- col_names[grepl("(?i)state|st_nm|name_1", col_names)][1]
    
    if (is.na(state_col)) {
        stop(paste("Could not identify state name column. Found columns:", paste(col_names, collapse=", ")))
    }
    
    # Rename it to NAME_1 so the downstream logic works seamlessly
    shp <- shp %>% rename(NAME_1 = !!sym(state_col))
    shp
}, error = function(e) {
    cat("Could not load shapefile:", e$message, "\n"); NULL
})

# Normalise string for fuzzy joining: lowercase, collapse whitespace
normalise_name <- function(x) {
    tolower(str_replace_all(x, "\\s+", " ") %>% str_trim())
}

if (!is.null(india_map)) {

    # Aliases: KEY = purely normalized (lowercase) shapefile string, VALUE = purely normalized NSS name
    shape_to_nss <- c(
        "jammu and kashmir"           = "jammu & kashmir",
        "nct of delhi"                = "delhi",
        "orissa"                      = "odisha",
        "uttaranchal"                 = "uttarakhand",
        "dadra and nagar haveli"      = "dadra & nagar haveli",
        "dadra and nagar haveli and daman and diu" = "dadra & nagar haveli",
        "daman and diu"               = "daman & diu",
        "andaman and nicobar"         = "andaman & nicobar",
        "andaman and nicobar islands" = "andaman & nicobar",
        "pondicherry"                 = "puducherry"
    )

    india_map <- india_map %>%
        mutate(
            raw_norm = normalise_name(NAME_1),
            nss_name = case_when(
                raw_norm %in% names(shape_to_nss) ~ shape_to_nss[raw_norm],
                TRUE                              ~ raw_norm
            ),
            join_key = nss_name
        )

    # For NSS: normalise State_Name directly
    state_shares <- state_shares %>%
        mutate(join_key = normalise_name(State_Name))

    # Diagnostic
    unmatched_gadm <- india_map %>%
        filter(!join_key %in% state_shares$join_key) %>%
        select(NAME_1, nss_name, join_key) %>%
        as.data.frame()
    cat("\nGADM states not in NSS data (expected to be grey):\n")
    print(unmatched_gadm)

    matched_states <- sum(india_map$join_key %in% state_shares$join_key)
    cat("States with NSS data:", matched_states, "of", nrow(india_map), "GADM polygons\n\n")

    map_data <- india_map %>% left_join(state_shares, by="join_key")

    # Custom theme for maps
    theme_map <- function() {
        theme_void() +
        theme(
            plot.title    = element_text(face="bold", size=18, hjust=0.5),
            plot.subtitle = element_text(size=12, hjust=0.5, color="grey30"),
            plot.caption  = element_text(size=9, color="grey50"),
            legend.position = "right",
            legend.title  = element_text(face="bold", size=11),
            plot.margin   = margin(10, 20, 10, 20)
        )
    }

    dir.create("../plots", showWarnings=FALSE)

    # --- MAP 1: Government Procurement Share ---
    p_map_govt <- ggplot(data=map_data) +
        geom_sf(aes(fill=Govt_Share), color="white", linewidth=0.3) +
        scale_fill_viridis_c(
            option="magma", direction=-1,
            name="Govt\nShare (%)",
            na.value="grey85",
            labels=function(x) paste0(round(x,1),"%")
        ) +
        labs(
            title    = "Government Procurement Share by State",
            subtitle = "% of crop sales to Government / FCI (NSS 77th Round)",
            caption  = paste("Grey = states with <100 obs or not participating in NSS 77th Round",
                             "(A&N, Chandigarh, D&NH, Lakshadweep).")
        ) +
        theme_map()

    ggsave("../plots/map_govt_share.png", p_map_govt, width=11, height=10, dpi=300)
    cat("✅ Saved: map_govt_share.png\n")

    # --- MAP 2: Private Trader Share ---
    p_map_trader <- ggplot(data=map_data) +
        geom_sf(aes(fill=Trader_Share), color="white", linewidth=0.3) +
        scale_fill_viridis_c(
            option="mako", direction=-1,
            name="Trader\nShare (%)",
            na.value="grey85",
            labels=function(x) paste0(round(x,1),"%")
        ) +
        labs(
            title    = "Private Trader Share by State",
            subtitle = "% of crop sales to Informal Private Traders (NSS 77th Round)",
            caption  = paste("Grey = states with <100 obs or not participating in NSS 77th Round.")
        ) +
        theme_map()

    ggsave("../plots/map_trader_share.png", p_map_trader, width=11, height=10, dpi=300)
    cat("✅ Saved: map_trader_share.png\n")

    # --- MAP 3: APMC Mandi Share ---
    p_map_mandi <- ggplot(data=map_data) +
        geom_sf(aes(fill=Mandi_Share), color="white", linewidth=0.3) +
        scale_fill_viridis_c(
            option="viridis", direction=-1,
            name="APMC\nShare (%)",
            na.value="grey85",
            labels=function(x) paste0(round(x,1),"%")
        ) +
        labs(
            title    = "APMC Mandi Share by State",
            subtitle = "% of crop sales to Regulated APMC Markets (NSS 77th Round)",
            caption  = paste("Grey = states with <100 obs or not participating in NSS 77th Round.")
        ) +
        theme_map()

    ggsave("../plots/map_mandi_share.png", p_map_mandi, width=11, height=10, dpi=300)
    cat("✅ Saved: map_mandi_share.png\n")

} else {
    # Fallback: bar chart if shapefile unavailable
    cat("\nFalling back to bar chart (shapefile unavailable).\n")
    fallback <- state_shares %>%
        arrange(Mandi_Share) %>%
        mutate(State_Name = factor(State_Name, levels=State_Name)) %>%
        pivot_longer(c(Govt_Share, Mandi_Share, Trader_Share),
                     names_to="channel", values_to="pct") %>%
        mutate(channel = recode(channel,
            Govt_Share="Government", Mandi_Share="APMC Mandi", Trader_Share="Local Trader")) %>%
        ggplot(aes(x=State_Name, y=pct, fill=channel)) +
        geom_col(position="dodge") + coord_flip() +
        scale_fill_manual(
            values=c("APMC Mandi"="#1565C0","Government"="#2E7D32","Local Trader"="#B71C1C")
        ) +
        labs(title="Market Channel Shares by State", x=NULL, y="Share (%)", fill="Channel") +
        theme_minimal(base_size=12)
    dir.create("../plots", showWarnings=FALSE)
    ggsave("../plots/map_fallback_bar.png", fallback, width=12, height=10, dpi=300)
}
