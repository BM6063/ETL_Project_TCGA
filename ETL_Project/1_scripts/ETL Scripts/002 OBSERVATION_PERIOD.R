################################################################################
#                               OBSERVATION_PERIOD                             #
################################################################################

# ============================================================
# ---- Clean Environment and Load Libraries ----
# ============================================================
rm(list = ls(all.names = TRUE))     # Remove all objects
gc()                                # Trigger garbage collection

library(dplyr)
library(readr)
library(lubridate)
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
# ---- EXTRACT INPUTS FOR DATES ----
# ============================================================
last_contact_days <- suppressWarnings(as.integer(raw$`Last Communication Contact from Initial Pathologic Diagnosis Date`))
os_months         <- suppressWarnings(as.numeric(raw$`Overall Survival (Months)`))
os_status         <- raw$`Overall Survival Status`

# ============================================================
# ---- CREATE OBSERVATION_PERIOD ----
#      start = anchor
#      end   = max(anchor + last_contact_days,
#                  anchor + OS_months*30.44 if DECEASED)
# ============================================================
observation_period <- raw %>%
  left_join(xref, by = "Patient ID") %>%
  transmute(
    person_id,
    observation_period_start_date = anchor,
    observation_period_end_date   = pmax(
      anchor + ifelse(is.na(last_contact_days), 0L, last_contact_days),
      anchor + ifelse(os_status == "1:DECEASED" & !is.na(os_months), m2d(os_months), 0L)
    ),
    period_type_concept_id = 44814725L
  )

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(observation_period, "./0_data/mapped/OBSERVATION_PERIOD.csv")
