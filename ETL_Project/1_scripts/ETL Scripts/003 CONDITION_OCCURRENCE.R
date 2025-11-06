################################################################################
#                          CONDITION_OCCURRENCE                                 #
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
# ---- CREATE CONDITION_OCCURRENCE ----
#  - one primary cancer row per person
#  - start_date = anchor
#  - concept_id = 0 (map to SNOMED later using ICD-10 / ICD-O-3)
#  - source_value = Tumor Type (keep raw label)
# ============================================================
condition_occurrence <- raw %>%
  left_join(xref, by = "Patient ID") %>%
  transmute(
    condition_occurrence_id     = row_number(),
    person_id,
    condition_concept_id        = 0L,                   # placeholder; map later
    condition_start_date        = anchor,
    condition_start_datetime    = as.POSIXct(NA),
    condition_end_date          = as.Date(NA),
    condition_end_datetime      = as.POSIXct(NA),
    condition_type_concept_id   = 32817L,               # derived from registry/source
    condition_status_concept_id = NA_integer_,
    stop_reason                 = NA_character_,
    provider_id                 = NA_integer_,
    visit_occurrence_id         = NA_integer_,
    visit_detail_id             = NA_integer_,
    condition_source_value      = `Tumor Type`,         # e.g., "Colon Adenocarcinoma"
    condition_source_concept_id = NA_integer_,
    condition_status_source_value = NA_character_
  )

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(condition_occurrence, "./0_data/mapped/CONDITION_OCCURRENCE.csv")
