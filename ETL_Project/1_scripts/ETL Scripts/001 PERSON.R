################################################################################
#                                   PERSON                                     
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
# ---- LOAD DATA -
# ============================================================
infile <- "./0_data/raw/coadread_tcga_pan_can_atlas_2018_clinical_data.tsv"
anchor <- as.Date("2000-01-01")   # synthetic diagnosis anchor

# Concept maps (standard OMOP concept_ids)
gender_map <- c("Male" = 8507L, "Female" = 8532L, "M" = 8507L, "F" = 8532L)
race_map   <- c("White" = 8527L,
                "Black or African American" = 8516L,
                "Asian" = 8515L)
eth_map    <- c("Not Hispanic Or Latino" = 38003564L,
                "Hispanic Or Latino"    = 38003563L)

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
# ---- CREATE PERSON ----
#   - person_id: surrogate key
#   - year_of_birth = year(anchor) - Diagnosis Age
#   - gender/race/ethnicity mapped to standard concepts; unknown -> 0
#   - keep source strings in *_source_value
# ============================================================
person <- raw %>%
  left_join(xref, by = "Patient ID") %>%
  distinct(person_id, .keep_all = TRUE) %>%
  transmute(
    person_id,
    gender_concept_id        = coalesce(gender_map[Sex], 0L),
    year_of_birth            = as.integer(year(anchor) - suppressWarnings(as.numeric(`Diagnosis Age`))),
    month_of_birth           = NA_integer_,
    day_of_birth             = NA_integer_,
    birth_datetime           = as.POSIXct(NA),
    race_concept_id          = coalesce(race_map[`Race Category`], 0L),
    ethnicity_concept_id     = coalesce(eth_map[`Ethnicity Category`], 0L),
    location_id              = NA_integer_,
    provider_id              = NA_integer_,
    care_site_id             = NA_integer_,
    person_source_value      = `Patient ID`,
    gender_source_value      = Sex,
    gender_source_concept_id = NA_integer_,
    race_source_value        = `Race Category`,
    race_source_concept_id   = NA_integer_,
    ethnicity_source_value   = `Ethnicity Category`,
    ethnicity_source_concept_id = NA_integer_
  )

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(person, "./0_data/mapped/PERSON.csv")
