################################################################################
#                              QC LEVEL 1–2 (R)                                #
#        Structural keys, row counts, date logic, basic plausibility           #
################################################################################

# ============================================================
# ---- Clean Environment and Load Libraries ----
# ============================================================
rm(list = ls(all.names = TRUE)); gc()
library(DBI); library(RPostgres); library(dplyr)

# ============================================================
# ---- CONNECT ----
# ============================================================
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "tcga_omop", host = "localhost",
  user = "postgres", password = "12345", port = 5432
)

# ============================================================
# ---- ROW COUNTS ----
# ============================================================
tbls <- c("person","observation_period","condition_occurrence",
          "specimen","measurement","observation","death")
counts <- sapply(tbls, \(t) dbGetQuery(con, paste0("SELECT COUNT(*) n FROM ", t))$n)
print(counts)

# ============================================================
# ---- REFERENTIAL: person_id present in PERSON ----
# ============================================================
check_fk <- function(t) dbGetQuery(con, paste0("
  SELECT COUNT(*) AS missing
  FROM ", t, " x
  LEFT JOIN person p ON p.person_id = x.person_id
  WHERE p.person_id IS NULL;"))
fk_miss <- sapply(setdiff(tbls, "person"), check_fk)
print(fk_miss)

# ============================================================
# ---- OBSERVATION_PERIOD LOGIC ----
# ============================================================
dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN observation_period_end_date < observation_period_start_date THEN 1 ELSE 0 END) AS bad_range,
    MIN(observation_period_start_date) AS min_start,
    MAX(observation_period_end_date)   AS max_end
  FROM observation_period;")

# exactly one OP per person?
dbGetQuery(con, "
  SELECT COUNT(*) AS persons_with_multiple
  FROM (
    SELECT person_id, COUNT(*) c
    FROM observation_period
    GROUP BY person_id
    HAVING COUNT(*)<>1
  ) z;")

# ============================================================
# ---- AGE / DURATION PLAUSIBILITY ----
# ============================================================
# Age 0–120? (derived rule, since birth is pseudo)
dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN obs.value_as_number < 0 OR obs.value_as_number > 120 THEN 1 ELSE 0 END) AS out_of_range
  FROM observation obs
  WHERE obs.observation_source_value = 'Diagnosis Age';")

# No negative months/days
dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN value_as_number < 0 THEN 1 ELSE 0 END) AS negatives
  FROM observation
  WHERE observation_source_value IN ('Disease Free (Months)',
                                     'Overall Survival (Months)',
                                     'Disease-specific Survival (Months)',
                                     'Last contact (days since diagnosis)',
                                     'Last alive (days since diagnosis)');")

# ============================================================
# ---- DEATH CONSISTENCY ----
# ============================================================
# death_date within observation_period
dbGetQuery(con, "
  SELECT SUM(CASE WHEN d.death_date < op.observation_period_start_date
                   OR d.death_date > op.observation_period_end_date
              THEN 1 ELSE 0 END) AS deaths_outside_period
  FROM death d
  JOIN observation_period op USING(person_id);")

# persons marked deceased but no DEATH row?
dbGetQuery(con, "
  SELECT COUNT(*) AS living_flagged_deceased_missing_death
  FROM observation o
  WHERE o.observation_source_value = 'Overall Survival (Months)'
    AND o.value_as_string = '1:DECEASED'
    AND NOT EXISTS (SELECT 1 FROM death d WHERE d.person_id = o.person_id);
")

# ============================================================
# ---- DISCONNECT ----
# ============================================================
dbDisconnect(con)
