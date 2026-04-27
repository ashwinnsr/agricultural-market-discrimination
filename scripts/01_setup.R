# ==============================================================================
# 01_setup.R - CONFIGURATION AND CODEBOOK
# NSS 77th Round, Schedule 33.1 (Agricultural Households)
# Full agricultural year: Visit 1 (July-Dec 2018) + Visit 2 (Jan-June 2019)
# ==============================================================================

# 1. Load All Required Packages
library(tidyverse)
library(haven)
library(survey)
library(fixest)
library(quantreg)
library(oaxaca)
library(modelsummary)
library(scales)
library(Hmisc)

# 2. Data Path
DATA_PATH <- "C:/Users/ashwin/Documents/New_NSS77/nss77-agricultural-welfare"

# 3. Multiplier Note
# MLT is stored as integer (e.g. 170500). Divide by 100 to get the actual
# multiplier used for population-level expansion. For relative/regression
# purposes, using MLT directly (or MLT/100) gives identical results.
# We divide by 100 for consistency with NSS documentation.
WEIGHT_DIVISOR <- 100

# ==============================================================================
# CODEBOOK - Block 6 (Crop Output Disposal)
# Source: NSS 77th Round Schedule 33.1 Level-06 str() output
# ==============================================================================

# PRIMARY KEY (common across all blocks)
# HHID         : Character, 9-digit unique household ID
# FSU_Slno     : FSU Serial No (village/cluster level, used for clustering SE)
# SSS          : Second-stage stratum
# hh_no        : Household number within FSU
# visitNo      : "1" or "2"
# District     : 2-digit district code
# State        : 2-digit state code
# Sample       : Sub-sample (1 or 2) -- needed for combined weight formula

# BLOCK 6 VARIABLES (Level-06 .sav files)
# b6q1  : Serial number of crop entry
# b6q2  : Crop code (4-digit; e.g. "0101" = paddy, "0106" = wheat)
# b6q3  : Unit code (1=kg, 2=number)
# b6q4  : Area of irrigated land (0.00 acres)
# b6q5  : Quantity produced from irrigated land
# b6q6  : Area of un-irrigated land (0.00 acres)
# b6q7  : Quantity produced from un-irrigated land
# b6q8  : Total quantity produced
# b6q9  : Area of land under pre-harvest sale (acres)
# b6q10 : Major disposal - TO WHOM SOLD (THE AGENCY VARIABLE)
#          1 = Local market / local traders
#          2 = APMC market (Mandi)
#          3 = Input dealers
#          4 = Cooperative
#          5 = Government agencies (FCI etc)
#          6 = Farmer Producer Organisations (FPO)
#          7 = Private processors
#          8 = Contract farming sponsors/companies
#          9 = Others
# b6q11 : Satisfaction with sale outcome
#          1 = Satisfactory
#          2 = Not satisfactory: lower than market price
#          3 = Delayed payments
#          4 = Deductions for loans borrowed
#          5 = Faulty weighing and grading
#          9 = Other cause of dissatisfaction
# b6q12 : Major disposal: quantity sold (kg)
# b6q13 : Major disposal: sale value (Rs.)
# b6q14 : Other disposal: quantity sold
# NSC   : NSC code (sub-sample identifier)
# MLT   : Multiplier (divide by 100 for actual weight)

# BLOCK 6 VARIABLES (Level-07 .sav files -- continuation)
# b6q15 : Other disposal: sale value (Rs.)
# b6q16 : All disposal: total quantity sold
# b6q17 : All disposal: total sale value (Rs.)
# b6q18 : Rate (Rs./unit): col.17/col.16  <-- BETTER PRICE MEASURE
# b6q19 : Value of pre-harvest sale (Rs.)
# b6q20 : Value of harvested produce (Rs.)
# b6q21 : Value of by-products (Rs.)
# b6q22 : Total value (Rs.)

# BLOCK 4 VARIABLES (Level-03 .sav file -- household characteristics)
# B4Q3 / SOCIAL_GROUP : 1=ST, 2=SC, 3=OBC, 9=Others (General)
# B4Q5 / MPCE         : Usual Monthly Consumer Expenditure (Rs.)
# STATE               : State code
# DISTRICT            : District code
# MLT                 : Multiplier

# BLOCK 5 VARIABLES (Level-04 .sav file -- land)
# B5Q3  : Area of land (acres)
# B5Q10 : Terms of lease (3 = sharecropping)

# BLOCK 13 VARIABLES (Level-15 .sav file -- loans)
# b13q2 : Nature of loan (1=hereditary, 2=cash, 3=kind, 4=partly)
# b13q3 : Source (01-13=institutional; 14-20=non-institutional)
#          Institutional: 01=SCB, 02=RRB, 03=Coop society, 04=Coop bank
#          Non-institutional: 14=landlord, 15=agri moneylender, 16=prof moneylender,
#                             17=input supplier, 20=market commission agent/traders
# b13q4 : Purpose (1=capex farm, 2=revex farm, 3=non-farm, 4=housing, ...)
# b13q7 : Amount outstanding (Rs.)

# BLOCK 14 VARIABLES (Level-16 .sav file -- MSP awareness)
# b14q2 : Crop code (links back to Block 6)
# b14q4 : Aware of MSP for this crop (numeric; 1=yes, 2=no, inferred)
# b14q5 : Which agency procures this crop at MSP
# b14q6 : Whether household sold to any MSP agency (9=did not sell at MSP)
# b14q7 : Quantity sold at MSP agency
# b14q8 : Sell rate (Rs.)
# b14q9 : Reason for NOT selling to MSP agency
#          1=procurement agency not available; 2=no local purchaser
#          3=poor quality; 4=crop pre-pledged; 5=better price over MSP; 9=others

# BLOCK 7 VARIABLES (Level-08 .sav file -- input expenses)
# b7q3  : Serial no. of crop (links back to Block 6 b6q1)
# b7q4  : Crop code
# b7q5  : Input source (same codes as b6q10)
# b7q6  : Quality/adequacy (1=good, 2=satisfactory, 3=poor, 4=don't know)
# b7q7  : Paid-out expenses (Rs.)
# b7q8  : Imputed expenses (Rs.)

# ==============================================================================
# CROP CODE TAXONOMY (from actual labels in b6q2)
# ==============================================================================
CROP_TAXONOMY <- tibble(
  crop_code = c(
    "0101","0102","0103","0104","0105","0106","0107","0108","0188",
    "0201","0202","0203","0204","0205","0206","0207","0208","0288",
    "0401","0402","0488",
    "0501","0502","0503","0504","0505","0506","0507","0508","0509",
    "0510","0511","0512","0513","0514","0515","0516","0517","0518","0519","0588",
    "0601","0602","0603","0604","0605","0606","0607","0608","0609",
    "0610","0611","0612","0613","0614","0615","0616","0617","0618",
    "0619","0620","0621","0622","0623","0624","0625","0626","0627","0628","0629","0630","0688",
    "0701","0702","0703","0704","0705","0706","0788",
    "0801","0802","0803","0804","0805","0806","0807","0808","0809","0810",
    "0811","0812","0813","0814","0815","0816","0817","0818","0819","0820","0821","0822","0823","0888",
    "0901",
    "1001","1002","1003","1004","1005","1006","1007","1008","1009","1010","1011","1012","1088",
    "1101","1102","1103","1104","1188",
    "1201","1288","1301","1302","1388",
    "1401","1402","1403","1488",
    "1501","1502","1503","1588",
    "1601","1602","1603","1604","1605","1688",
    "1701","1702","1703","1704","1788",
    "1801","1802","1803","1804","1888",
    "1901","1902","1988","9999"
  ),
  crop_name = c(
    "paddy","jowar","bajra","maize","ragi","wheat","barley","small millets","other cereals",
    "gram","tur(arhar)","urad","moong","masur","horse gram","beans(pulses)","peas(pulses)","other pulses",
    "sugarcane","palmvriah","other sugar crops",
    "pepper(black)","chillies","ginger","turmeric","cardamon(small)","cardamon(large)",
    "betel nuts","garlic","coriander","tamarind","cumin seed","fennel/anise","nutmeg",
    "fenugreek","cloves","cinnamon","cocoa","kacholam","betelvine","other condiments/spices",
    "mangoes","orange/kinu","mosambi","lemon/lime","other citrous","banana","table grapes",
    "wine grapes","apple","pear","peaches","plum","kiwi","chiku","papaya","guava","almond",
    "walnut","cashewnuts","apricot","jackfruit","lichi","pineapple","watermelon","musk melon",
    "bread fruits","ber","bel","mulberry","aonla(amla)","other fruits",
    "potato","tapioca","sweet potato","yam","elephant foot yam","colocasia/arum","other tubers",
    "onion","carrot","radish","beetroot","turnip","tomato","spinach","amaranths","cabbage",
    "other leafy veg","brinjal","peas(veg)","lady's finger","cauliflower","cucumber",
    "bottle gourd","pumpkin","bitter gourd","other gourds","guar beans","beans(green)",
    "drumstick","green chillies","other vegetables",
    "other food crops",
    "groundnut","castorseed","sesamum","rapeseed/mustard","linseed","coconut","sunflower",
    "safflower","soyabean","nigerseed","oil palm","toria","other oilseeds",
    "cotton","jute","mesta","sunhemp","other fibres",
    "indigo","other dyes","opium","tobacco","other drugs",
    "guar","oats","green manures","other fodder",
    "tea","coffee","rubber","other plantation",
    "orchids","rose","gladiolus","carnation","marigold","other flowers",
    "asgandh","isabgol","sena","moosli","other medicinal",
    "lemon grass","mint","menthol","eucalyptus","other aromatic",
    "canes","bamboos","other non-food","not applicable/total"
  ),
  crop_group = c(
    rep("Cereals", 9),
    rep("Pulses", 9),
    rep("Sugar Crops", 3),
    rep("Condiments & Spices", 20),
    rep("Fruits", 31),
    rep("Tubers", 7),
    rep("Vegetables", 24),
    "Other Food Crops",
    rep("Oilseeds", 13),
    rep("Fibres", 5),
    rep("Dyes & Drugs", 5),
    rep("Fodder", 4),
    rep("Plantation", 4),
    rep("Flowers", 6),
    rep("Medicinal Plants", 5),
    rep("Aromatic Plants", 5),
    rep("Other Non-Food", 3),
    "Total/NA"
  ),
  # MSP-eligible crops (main ones announced by CACP)
  msp_eligible = crop_code %in% c(
    "0101","0106",  # paddy, wheat
    "0102","0103","0104","0105","0107",  # coarse cereals
    "0201","0202","0203","0204","0205",  # pulses
    "1001","1004","1003","1007","1009",  # oilseeds: groundnut, mustard, sesamum, sunflower, soyabean
    "0401",  # sugarcane
    "1101","1102"   # cotton, jute
  )
)

cat("Setup complete. Codebook and crop taxonomy loaded.\n")
cat("Crop groups available:", paste(unique(CROP_TAXONOMY$crop_group), collapse=", "), "\n")
