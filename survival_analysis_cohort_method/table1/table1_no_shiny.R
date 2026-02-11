library(DatabaseConnector)
library(FeatureExtraction)
################### Using Cohort Method to create Table 1 ####################
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "amit.sharma"
pw     <- "Tango==1262"
port   <- 5432              # local forwarded port from your SSH tunnel
pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"

#Create connection details
connectionDetails <- createConnectionDetails(
  dbms = dbms,
  server = server,
  user = user,
  password = pw,
  port = port,
  pathToDriver = pathToDriver
)
cdm_schema_name <- "main"
cohort_table = "cohort_tbl"

connectionDetails_source <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  server = "/Users/amit.sharma/Documents/GiBleed_5.3.sqlite"
)
# default covariate settings
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()

cohort_1 <- 1
cohort_2 <- 2
# get covariate data for first cohort
covData1 <- getDbCovariateData(
  connectionDetails = connectionDetails_source,
  tempEmulationSchema = NULL,
  cdmDatabaseSchema = "main",
  cdmVersion = "5",
  cohortTable = cohort_table,
  cohortDatabaseSchema = "main",
  cohortTableIsTemp = FALSE,
  cohortIds = c(cohort_1),
  rowIdField = "subject_id",
  covariateSettings = covariateSettings,
  aggregated = TRUE
)
print("Covariate data for target cohort (cohortId 1) loaded successfully.")
print(covData1)
# Pull covariate names as a vector
# covariate_names <- covData1$covariateRef %>% dplyr::pull(covariateName)
# print(covariate_names)
# cat("Number of covariates:", length(covariate_names), "\n")

# Or to see the full table in R:
covariate_table <- covData1$covariateRef %>% collect()
head(covariate_table)

# get covariate data for second cohort
covData2 <- getDbCovariateData(
  connectionDetails = connectionDetails_source,
  tempEmulationSchema = NULL,
  cdmDatabaseSchema = "main",
  cdmVersion = "5",
  cohortTable = cohort_table,
  cohortDatabaseSchema = "main",
  cohortTableIsTemp = FALSE,
  cohortIds = c(cohort_2),
  rowIdField = "subject_id",
  covariateSettings = covariateSettings,
  aggregated = TRUE
)

# create Table 1
table1 <- createTable1(
  covariateData1 = covData1,
#   covariateData2 = covData2,
  cohortId1 = cohort_1,
#   cohortId2 = cohort_2,
  specifications = getDefaultTable1Specifications(),
  output = "one column",
  showCounts = TRUE,
  showPercent = TRUE,
  percentDigits = 1,
  valueDigits = 1,
  stdDiffDigits = 2
)
cat("\n############## Table 1 ###################\n")
print(table1)

print(typeof(table1))

ParallelLogger::saveSettingsToJson(
  table1,
  file.path("./table1_output.json")
)

table1_2 <- ParallelLogger::loadSettingsFromJson(
  file.path("./table1_output.json")
)

print(typeof(table1_2))
print(table1_2)


