# ==============================================================================
# 01_setup.R - CONFIGURATION (FIXED FOR UPLOADED FILES)
# ==============================================================================

# 1. Load Packages
library(tidyverse)
library(haven)
library(survey)
library(lmtest)
library(sandwich)
library(fixest)

# 2. Set Data Path
DATA_PATH <- "C:/Users/ashwin/Documents/New_NSS77/nss77-agricultural-welfare"

# 3. Key Identifiers (Found in your file headers)
# We use these to merge households across blocks
VARS_KEYS <- c("FSU_SLNO", "SSS", "HH_NO", "VISITNO")

# 4. Variable Mappings

# --- Block 4: Demographics (Household Level) ---
# NOTE: Social Group is in Block 4 (B4Q3), not Block 3!
VAR_SOCIAL_GROUP <- "B4Q3" # Social Group (1=ST, 2=SC, 3=OBC, 9=Others)
VAR_MPCE <- "B4Q5" # Usual Monthly Consumer Expenditure
VAR_DISTRICT <- "B4Q1" # District Code (in Block 4)
VAR_WEIGHT <- "MLT" # Multiplier (Weight)

# --- Block 6: Sales of Crops (The Core of "Double Squeeze") ---
# Based on Standard 77th Round Schedule 33.1
VAR_CROP_CODE <- "B6Q2" # Crop Code
VAR_QTY_SOLD <- "B6Q12" # Quantity Sold (Kg)
VAR_VAL_SOLD <- "B6Q13" # Value of Sale (Rs)
VAR_AGENCY <- "B6Q15" # Agency of Sale (1=Mandi, 5=Trader)
VAR_REASON_SALE <- "B6Q16" # Reason for sale to agency

# --- Block 5: Land & Tenancy ---
VAR_LAND_AREA <- "B5Q3" # Area of land
VAR_LEASE_TERMS <- "B5Q10" # Terms of lease (Sharecropping vs Fixed)

cat("Setup loaded. Variable names aligned with 'B#Q#' format.\n")
