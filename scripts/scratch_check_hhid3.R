library(haven)
library(dplyr)

DATA_PATH <- "C:/Users/ashwin/Documents/New_NSS77/nss77-agricultural-welfare"
f1 <- file.path(DATA_PATH, "Visit 1 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav")
f2 <- file.path(DATA_PATH, "Visit 2 Level - 06 (Block 6) output of crops produced during the period July - December 2018.sav")

d1 <- read_sav(f1)
names(d1) <- toupper(names(d1))
d2 <- read_sav(f2)
names(d2) <- toupper(names(d2))

mh1 <- d1 %>% filter(as.character(STATE) == "27") %>% select(HHID) %>% distinct() %>% mutate(panel_id = substr(HHID, 1, 8))
mh2 <- d2 %>% filter(as.character(STATE) == "27") %>% select(HHID) %>% distinct() %>% mutate(panel_id = substr(HHID, 1, 8))

joined <- inner_join(mh1, mh2, by="panel_id")

cat("Unique HH in V1 (MH):", nrow(mh1), "\n")
cat("Unique HH in V2 (MH):", nrow(mh2), "\n")
cat("Matched on panel_id (first 8 digits of HHID):", nrow(joined), "\n")
