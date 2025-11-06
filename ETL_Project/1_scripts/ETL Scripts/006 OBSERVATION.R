################################################################################
#                                  OBSERVATION                                  #
################################################################################

# ============================================================
# ---- Clean Environment and Load Libraries ----
# ============================================================
rm(list = ls(all.names = TRUE)); gc()

library(dplyr)
library(readr)
library(lubridate)
library(stringr)

# ============================================================
# ---- LOAD DATA / CONFIG ----
# ============================================================
infile <- "./0_data/raw/coadread_tcga_pan_can_atlas_2018_clinical_data.tsv"
anchor <- as.Date("2000-01-01")                      # synthetic diagnosis anchor
m2d    <- function(m) as.integer(round(as.numeric(m) * 30.44))  # months → days
yes_id <- 4188539L
no_id  <- 4188540L

num_or_na <- function(x) suppressWarnings(as.numeric(x))
int_or_na <- function(x) suppressWarnings(as.integer(x))

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
# ---- PREP COMMON OFFSETS (NUMERIC) ----
# ============================================================
last_contact_days <- int_or_na(raw$`Last Communication Contact from Initial Pathologic Diagnosis Date`)
last_alive_days   <- int_or_na(raw$`Last Alive Less Initial Pathologic Diagnosis Date Calculated Day Value`)
df_months         <- num_or_na(raw$`Disease Free (Months)`)
os_months         <- num_or_na(raw$`Overall Survival (Months)`)
dss_months        <- num_or_na(raw$`Months of disease-specific survival`)

# Handy coercer to ensure Date type
to_date <- function(d) as.Date(d, origin = "1970-01-01")

# ============================================================
# ---- BUILD OBSERVATION ROWS (one block per source concept) ----
# ============================================================
obs_list <- list()

# 0) Diagnosis Age (numeric at anchor)
obs_list[[length(obs_list)+1]] <- raw %>%
  left_join(xref, by = "Patient ID") %>%
  transmute(
    person_id,
    observation_concept_id = 0L,                     # can replace with 43054920 later
    observation_date       = anchor,
    observation_datetime   = as.POSIXct(NA),
    value_as_number        = int_or_na(`Diagnosis Age`),
    value_as_string        = NA_character_,
    value_as_concept_id    = NA_integer_,
    qualifier_concept_id   = NA_integer_,
    unit_concept_id        = NA_integer_,
    provider_id            = NA_integer_,
    visit_occurrence_id    = NA_integer_,
    visit_detail_id        = NA_integer_,
    observation_source_value = "Diagnosis Age",
    observation_source_concept_id = NA_integer_,
    unit_source_value      = NA_character_,
    qualifier_source_value = NA_character_,
    value_source_value     = NA_character_
  ) %>% filter(!is.na(value_as_number))

# 1) AJCC Stage Group (string at anchor)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = anchor,
    observation_datetime   = as.POSIXct(NA),
    value_as_string        = `Neoplasm Disease Stage American Joint Committee on Cancer Code`,
    value_as_number        = NA_real_,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "AJCC Stage Group"
  ) %>% filter(!is.na(value_as_string) & value_as_string != "")

# 2) AJCC T / N / M (strings at anchor)
make_ajcc_block <- function(col, label){
  raw %>% left_join(xref, by = "Patient ID") %>%
    transmute(
      person_id,
      observation_concept_id = 0L,
      observation_date       = anchor,
      observation_datetime   = as.POSIXct(NA),
      value_as_string        = .data[[col]],
      value_as_number        = NA_real_,
      value_as_concept_id    = NA_integer_,
      observation_source_value = label
    ) %>% filter(!is.na(value_as_string) & value_as_string != "")
}
obs_list[[length(obs_list)+1]] <- make_ajcc_block("American Joint Committee on Cancer Tumor Stage Code","AJCC T")
obs_list[[length(obs_list)+1]] <- make_ajcc_block("Neoplasm Disease Lymph Node Stage American Joint Committee on Cancer Code","AJCC N")
obs_list[[length(obs_list)+1]] <- make_ajcc_block("American Joint Committee on Cancer Metastasis Stage Code","AJCC M")

# 3) AJCC Version (string at anchor)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = anchor,
    observation_datetime   = as.POSIXct(NA),
    value_as_string        = `American Joint Committee on Cancer Publication Version Type`,
    value_as_number        = NA_real_,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "AJCC Version"
  ) %>% filter(!is.na(value_as_string) & value_as_string != "")

# 4) Person Neoplasm Cancer Status (WITH TUMOR? Yes/No; date = last contact if available)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(
    status_txt  = `Person Neoplasm Cancer Status`,
    lc_days_eff = coalesce(last_contact_days, 0L),
    obs_date    = anchor + lc_days_eff,
    val_concept = case_when(
      str_to_upper(status_txt) == "WITH TUMOR"  ~ yes_id,
      str_to_upper(status_txt) == "TUMOR FREE" ~ no_id,
      TRUE ~ NA_integer_
    )
  ) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = obs_date,                      # already Date
    observation_datetime   = as.POSIXct(NA),
    value_as_concept_id    = val_concept,
    value_as_string        = status_txt,
    value_as_number        = NA_real_,
    observation_source_value = "Neoplasm Cancer Status"
  ) %>% filter(!is.na(value_as_concept_id) | (!is.na(value_as_string) & value_as_string != ""))

# 5) Last contact (days) → date = anchor + days; also store days
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(dnum = coalesce(last_contact_days, NA_integer_),
         od   = ifelse(is.na(dnum), NA, as.numeric(anchor) + dnum)) %>%   # numeric to control NA
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = to_date(od),
    observation_datetime   = as.POSIXct(NA),
    value_as_number        = dnum,
    value_as_string        = NA_character_,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "Last contact (days since diagnosis)"
  ) %>% filter(!is.na(value_as_number))

# 6) Last alive (days)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(dnum = coalesce(last_alive_days, NA_integer_),
         od   = ifelse(is.na(dnum), NA, as.numeric(anchor) + dnum)) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = to_date(od),
    observation_datetime   = as.POSIXct(NA),
    value_as_number        = dnum,
    value_as_string        = NA_character_,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "Last alive (days since diagnosis)"
  ) %>% filter(!is.na(value_as_number))

# 7) Disease Free (months) → numeric + pseudo-date
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(dnum = ifelse(is.na(df_months), NA, m2d(df_months)),
         od   = ifelse(is.na(dnum), NA, as.numeric(anchor) + dnum)) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = to_date(od),
    observation_datetime   = as.POSIXct(NA),
    value_as_number        = df_months,
    value_as_string        = NA_character_,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "Disease Free (Months)"
  ) %>% filter(!is.na(value_as_number))

# 8) Disease Free Status (“0:DiseaseFree”/“1:…”) → Yes/No on DISEASE-FREE?
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(
    dfs_txt    = `Disease Free Status`,
    val_concept = case_when(
      str_detect(dfs_txt %||% "", "^0") ~ yes_id,   # Disease-free? Yes
      str_detect(dfs_txt %||% "", "^1") ~ no_id,    # Not DF? No
      TRUE ~ NA_integer_
    )
  ) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = anchor,
    observation_datetime   = as.POSIXct(NA),
    value_as_concept_id    = val_concept,
    value_as_string        = dfs_txt,
    value_as_number        = NA_real_,
    observation_source_value = "Disease Free Status"
  ) %>% filter(!is.na(value_as_concept_id) | (!is.na(value_as_string) & value_as_string != ""))

# 9) Overall Survival (months)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(dnum = ifelse(is.na(os_months), NA, m2d(os_months)),
         od   = ifelse(is.na(dnum), NA, as.numeric(anchor) + dnum)) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = to_date(od),
    observation_datetime   = as.POSIXct(NA),
    value_as_number        = os_months,
    value_as_string        = `Overall Survival Status`,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "Overall Survival (Months)"
  ) %>% filter(!is.na(value_as_number) | (!is.na(value_as_string) & value_as_string != ""))

# 10) Disease-specific Survival (months)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(dnum = ifelse(is.na(dss_months), NA, m2d(dss_months)),
         od   = ifelse(is.na(dnum), NA, as.numeric(anchor) + dnum)) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = to_date(od),
    observation_datetime   = as.POSIXct(NA),
    value_as_number        = dss_months,
    value_as_string        = `Disease-specific Survival status`,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "Disease-specific Survival (Months)"
  ) %>% filter(!is.na(value_as_number) | (!is.na(value_as_string) & value_as_string != ""))

# 11) Somatic Status, Subtype, Tissue Source Site/Code, Oncotree, Acronym, Detailed, Genetic Ancestry
label_block <- function(col, label){
  raw %>% left_join(xref, by = "Patient ID") %>%
    transmute(
      person_id,
      observation_concept_id = 0L,
      observation_date       = anchor,
      observation_datetime   = as.POSIXct(NA),
      value_as_string        = .data[[col]],
      value_as_number        = NA_real_,
      value_as_concept_id    = NA_integer_,
      observation_source_value = label
    ) %>% filter(!is.na(value_as_string) & value_as_string != "")
}
obs_list[[length(obs_list)+1]] <- label_block("Somatic Status","Somatic Status")
obs_list[[length(obs_list)+1]] <- label_block("Subtype","Subtype")
obs_list[[length(obs_list)+1]] <- label_block("Tissue Source Site","Tissue Source Site")
obs_list[[length(obs_list)+1]] <- label_block("Tissue Source Site Code","Tissue Source Site Code")
obs_list[[length(obs_list)+1]] <- label_block("Oncotree Code","Oncotree Code")
obs_list[[length(obs_list)+1]] <- label_block("TCGA PanCanAtlas Cancer Type Acronym","Cancer Type Acronym")
obs_list[[length(obs_list)+1]] <- label_block("Cancer Type Detailed","Cancer Type Detailed")
obs_list[[length(obs_list)+1]] <- label_block("Genetic Ancestry Label","Genetic Ancestry Label")

# 12) Yes/No flags: In PanCan Pathway Analysis, Informed consent verified, New Neoplasm Event...
yn_block <- function(col, label){
  raw %>% left_join(xref, by = "Patient ID") %>%
    mutate(
      txt = .data[[col]],
      val = case_when(
        str_to_upper(txt) == "YES" ~ yes_id,
        str_to_upper(txt) == "NO"  ~ no_id,
        TRUE ~ NA_integer_
      )
    ) %>%
    transmute(
      person_id,
      observation_concept_id = 0L,
      observation_date       = anchor,
      observation_datetime   = as.POSIXct(NA),
      value_as_concept_id    = val,
      value_as_string        = txt,
      value_as_number        = NA_real_,
      observation_source_value = label
    ) %>% filter(!is.na(value_as_concept_id) | (!is.na(value_as_string) & value_as_string != ""))
}
obs_list[[length(obs_list)+1]] <- yn_block("In PanCan Pathway Analysis","In PanCan Pathway Analysis")
obs_list[[length(obs_list)+1]] <- yn_block("Informed consent verified","Informed consent verified")
obs_list[[length(obs_list)+1]] <- yn_block("New Neoplasm Event Post Initial Therapy Indicator","New Neoplasm Event Post Initial Therapy Indicator")

# 13) Form completion date (metadata date as-is; robust parse)
obs_list[[length(obs_list)+1]] <- raw %>% left_join(xref, by = "Patient ID") %>%
  mutate(form_date = suppressWarnings(as.Date(`Form completion date`,
                                              tryFormats = c("%m/%d/%y","%m/%d/%Y","%Y-%m-%d")))) %>%
  transmute(
    person_id,
    observation_concept_id = 0L,
    observation_date       = form_date,                # already Date
    observation_datetime   = as.POSIXct(NA),
    value_as_string        = NA_character_,
    value_as_number        = NA_real_,
    value_as_concept_id    = NA_integer_,
    observation_source_value = "Form completion date"
  ) %>% filter(!is.na(observation_date))

# ============================================================
# ---- CONCATENATE & ID ASSIGNMENT (ensure Date type) ----
# ============================================================
# Guarantee all blocks have Date type for observation_date
for (i in seq_along(obs_list)) {
  if (!inherits(obs_list[[i]]$observation_date, "Date")) {
    obs_list[[i]]$observation_date <- to_date(obs_list[[i]]$observation_date)
  }
}

observation <- bind_rows(obs_list) %>%
  mutate(observation_id = row_number()) %>%
  select(observation_id, everything())

# ============================================================
# ---- WRITE OUTPUT ----
# ============================================================
write_csv(observation, "./0_data/mapped/OBSERVATION.csv")
