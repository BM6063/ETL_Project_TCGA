################################################################################
#                                     DEATH                                    
################################################################################

# ============================================================
# ---- Clean Environment and Load Libraries ----
# ============================================================
rm(list = ls(all.names = TRUE))     # Remove all objects
gc()                                # Trigger garbage collection

library(dplyr)
library(readr)
library(lubridate)
library(stringr)

# ============================================================
# ---- LOAD DATA / CONFIG ----
# ============================================================
infile <- "./0_data/raw/coadread_tcga_pan_can_atlas_2018_clinical_data.tsv"
anchor <- as.Date("2000-01-01")                     # synthetic diagnosis anchor
m2d    <- function(m) as.integer(round(as.numeric(m) * 30.44))  # months → days

# ============================================================
# ---- READ TCGA CLINICAL DATA ----
# ============================================================
raw <- read_tsv(infile, show_col_types = FALSE)

# ============================================================
# ---- BUILD SURROGATE KEY (Patient ID -> person_id) ----
# ============================================================
xref <- raw %>%
  distinct(`Patient ID`) %>%
  arrange(`Patient ID`) %>%
  mutate(person_id = row_number())

# ============================================================
# ---- PREP OFFSETS / FLAGS ----
#   - Include a DEATH row if either:
#       * Overall Survival Status == "1:DECEASED"
#       * Disease-specific Survival status == "1:DEAD WITH TUMOR"
#   - death_date = anchor + min(os_days, dss_days) when both present
# ============================================================
os_months  <- suppressWarnings(as.numeric(raw$`Overall Survival (Months)`))
os_status  <- raw$`Overall Survival Status`

dss_months <- suppressWarnings(as.numeric(raw$`Months of disease-specific survival`))
dss_status <- raw$`Disease-specific Survival status`

os_days    <- m2d(os_months)
dss_days   <- m2d(dss_months)

is_dead_os  <- !is.na(os_status)  & os_status  == "1:DECEASED"
is_dead_dss <- !is.na(dss_status) & dss_status == "1:DEAD WITH TUMOR"

# ============================================================
# ---- CREATE DEATH ----
#   - Prefer the earliest available derived death date
#   - cause_source_value set only when disease-specific death indicated
#   - leave cause_concept_id NULL (map later if desired)
# ============================================================
death <- raw %>%
  left_join(xref, by = "Patient ID") %>%
  mutate(
    # candidates for days offset
    os_days_eff  = ifelse(is_dead_os  & !is.na(os_days),  os_days,  NA_integer_),
    dss_days_eff = ifelse(is_dead_dss & !is.na(dss_days), dss_days, NA_integer_),
    
    # choose earliest non-NA offset
    death_offset_days = pmin(os_days_eff, dss_days_eff, na.rm = TRUE),
    death_offset_days = ifelse(is.infinite(death_offset_days), NA, death_offset_days),
    
    # final inclusion flag (must have at least one death flag AND at least one offset)
    include_row = (is_dead_os | is_dead_dss) & !is.na(death_offset_days),
    
    # cause text if disease-specific death
    cause_source_value = ifelse(is_dead_dss, "Disease-specific death (DEAD WITH TUMOR)", NA_character_)
  ) %>%
  filter(include_row) %>%
  transmute(
    person_id,
    death_date               = anchor + death_offset_days,
    death_datetime           = as.POSIXct(NA),
    death_type_concept_id    = 32817L,          # placeholder; refine if needed
    cause_concept_id         = NA_integer_,     # map later if desired
    cause_source_value,
    cause_source_concept_id  = NA_integer_
  )

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(death, "./0_data/mapped/DEATH.csv")
