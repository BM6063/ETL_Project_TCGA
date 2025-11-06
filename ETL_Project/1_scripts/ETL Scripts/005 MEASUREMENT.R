################################################################################
#                                  MEASUREMENT                                 #
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
anchor <- as.Date("2000-01-01")   # synthetic diagnosis anchor

# Helper to coerce numeric safely
num_or_na <- function(x) suppressWarnings(as.numeric(x))

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
# ---- CREATE MEASUREMENT ----
#   - one row per numeric score
#   - measurement_date = anchor
#   - unitless except weight (kg = 9529)
# ============================================================
measure_cols <- c(
  "Aneuploidy Score",
  "Buffa Hypoxia Score",
  "Ragnum Hypoxia Score",
  "Winter Hypoxia Score",
  "Fraction Genome Altered",
  "MSI MANTIS Score",
  "MSIsensor Score",
  "Mutation Count",
  "TMB (nonsynonymous)",
  "Patient Weight"
)

unit_ids <- c(NA, NA, NA, NA, NA, NA, NA, NA, NA, 9529L)  # 9529 = kilogram

measurement <- list()

for (i in seq_along(measure_cols)) {
  col <- measure_cols[i]
  unit <- unit_ids[i]
  
  tmp <- raw %>%
    select(`Patient ID`, all_of(col)) %>%
    left_join(xref, by = "Patient ID") %>%
    transmute(
      person_id,
      measurement_concept_id   = 0L,
      measurement_date         = anchor,
      measurement_datetime     = as.POSIXct(NA),
      value_as_number          = num_or_na(.data[[col]]),
      value_as_concept_id      = NA_integer_,
      unit_concept_id          = unit,
      range_low                = NA_real_,
      range_high               = NA_real_,
      provider_id              = NA_integer_,
      visit_occurrence_id      = NA_integer_,
      visit_detail_id          = NA_integer_,
      measurement_source_value = col,
      measurement_source_concept_id = NA_integer_,
      unit_source_value        = NA_character_,
      unit_source_concept_id   = NA_integer_,
      value_source_value       = NA_character_,
      measurement_event_id     = NA_integer_,
      meas_event_field_concept_id = NA_integer_
    ) %>%
    filter(!is.na(value_as_number))
  
  measurement[[length(measurement) + 1]] <- tmp
}

measurement <- bind_rows(measurement) %>%
  mutate(measurement_id = row_number()) %>%
  select(measurement_id, everything())

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(measurement, "./0_data/mapped/MEASUREMENT.csv")
