################################################################################
#                     LOAD OMOP CSVs INTO POSTGRESQL (PUBLIC)                  #
################################################################################

# ============================================================
# ---- Clean Environment and Load Libraries ----
# ============================================================
rm(list = ls(all.names = TRUE)); gc()

library(DBI)
library(RPostgres)
library(readr)
library(dplyr)

# ============================================================
# ---- CONNECTION DETAILS ----
# ============================================================
con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "tcga_omop",     # database created in pgAdmin
  host     = "localhost",
  user     = "postgres",
  password = "12345", # <-- change
  port     = 5432
)

# Path with mapped CSVs
mp <- "./0_data/mapped/"

# ============================================================
# ---- WRITE TABLES (OVERWRITE EACH TIME) ----
# ============================================================

# PERSON
person <- read_csv(paste0(mp, "PERSON.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "person"), person, overwrite = TRUE)

# OBSERVATION_PERIOD
observation_period <- read_csv(paste0(mp, "OBSERVATION_PERIOD.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "observation_period"), observation_period, overwrite = TRUE)

# CONDITION_OCCURRENCE
condition_occurrence <- read_csv(paste0(mp, "CONDITION_OCCURRENCE.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "condition_occurrence"), condition_occurrence, overwrite = TRUE)

# SPECIMEN
specimen <- read_csv(paste0(mp, "SPECIMEN.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "specimen"), specimen, overwrite = TRUE)

# MEASUREMENT
measurement <- read_csv(paste0(mp, "MEASUREMENT.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "measurement"), measurement, overwrite = TRUE)

# OBSERVATION
observation <- read_csv(paste0(mp, "OBSERVATION.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "observation"), observation, overwrite = TRUE)

# DEATH
death <- read_csv(paste0(mp, "DEATH.csv"), show_col_types = FALSE)
dbWriteTable(con, Id(schema = "public", table = "death"), death, overwrite = TRUE)

# ============================================================
# ---- QUICK VERIFY (ROW COUNTS) ----
# ============================================================
counts <- sapply(
  c("person","observation_period","condition_occurrence","specimen","measurement","observation","death"),
  function(t) dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM public.", t))$n
)
print(counts)

# ============================================================
# ---- (OPTIONAL) BASIC INDEXES FOR SPEED ----
# ============================================================
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_person_id_obsperiod  ON public.observation_period (person_id)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_person_id_condition ON public.condition_occurrence (person_id)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_person_id_specimen  ON public.specimen (person_id)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_person_id_measure  ON public.measurement (person_id)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_person_id_observ    ON public.observation (person_id)")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_person_id_death     ON public.death (person_id)")

# ============================================================
# ---- DISCONNECT ----
# ============================================================
dbDisconnect(con)
