################################################################################
#                                   SPECIMEN                                   
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
anchor <- as.Date("2000-01-01")   # synthetic diagnosis anchor

# Optional: simple sample-type mapping (fallback = 0 when unknown)
sample_type_map <- c(
  "Primary"    = 0L,   # put real concept if known later
  "Metastatic" = 0L,
  "Normal"     = 0L,
  "Primary Tumor" = 0L,
  "Solid Tissue Normal" = 0L
)

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
# ---- CREATE SPECIMEN ----
#   - one SPECIMEN per distinct Sample ID
#   - specimen_date = anchor
#   - specimen_type_concept_id mapped when possible, else 0
#   - keep Sample ID in specimen_source_id and specimen_source_value
#   - include simple provenance in specimen_source_value (type/status)
# ============================================================
specimen <- raw %>%
  distinct(`Patient ID`, `Sample ID`, `Sample Type`, `Somatic Status`) %>%
  left_join(xref, by = "Patient ID") %>%
  arrange(`Sample ID`) %>%
  mutate(
    specimen_id              = row_number(),
    stype_norm               = str_trim(as.character(`Sample Type`)),
    specimen_type_concept_id = coalesce(sample_type_map[stype_norm], 0L),
    specimen_source_value    = ifelse(
      is.na(`Somatic Status`) | `Somatic Status` == "",
      paste0(`Sample ID`, " | ", stype_norm),
      paste0(`Sample ID`, " | ", stype_norm, " | ", `Somatic Status`)
    )
  ) %>%
  transmute(
    specimen_id,
    person_id,
    specimen_concept_id          = 0L,                # unknown; not used here
    specimen_type_concept_id,                         # mapped or 0
    specimen_date                = anchor,
    specimen_datetime            = as.POSIXct(NA),
    quantity                     = NA_real_,
    unit_concept_id              = NA_integer_,
    anatomic_site_concept_id     = NA_integer_,
    disease_status_concept_id    = NA_integer_,
    specimen_source_id           = `Sample ID`,
    specimen_source_value,                            # ID | Type | Somatic Status
    unit_source_value            = NA_character_,
    anatomic_site_source_value   = NA_character_,
    disease_status_source_value  = NA_character_
  )

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(specimen, "./0_data/mapped/SPECIMEN.csv")
