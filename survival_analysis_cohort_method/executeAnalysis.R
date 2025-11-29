library(DatabaseConnector)

analysisName_base = "surv_analysis_spec_cancer"
analysisName <- paste0(analysisName_base, ".json")
results_schema_name <- paste0("res_", analysisName_base, "_amit_100pct_2")


# database connection and execution settings
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/alp_demo_analytics"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "postgres_tenant_admin_user"
# pw     <- "Toor1234"
pw     <- "g3H5yGTpc6dAChaqkRWxr4"
port   <- 41192              # local forwarded port from your SSH tunnel
pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"

# Create connection details
connectionDetails <- createConnectionDetails(
  dbms = dbms,
  server = server,
  user = user,
  password = pw,
  port = port,
  pathToDriver = pathToDriver
)


## =========== START OF INPUTS ==========
# cdmDatabaseSchema <- "cdm_5pct_9a0f90a32250497d9483c981ef1e1e70"
cdmDatabaseSchema <- "cdmsynpuf100pct"
workDatabaseSchema <- cdmDatabaseSchema

outputLocation <- file.path(getwd(), "results")
databaseName <- "Eunomia" # Only used as a folder name for results from the study
minCellCount <- 5
cohortTableName <- "cohort_tbl"

# connectionDetails <- Eunomia::getEunomiaConnectionDetails()

# clean results folder
# results_folder <- file.path(outputLocation)
cat("Trying to delete previousfolders:", outputLocation, "\n")
# Remove everything inside the folder
if (dir.exists(outputLocation)) {
  unlink(outputLocation, recursive = TRUE, force = TRUE)
}
if (!dir.exists(file.path(outputLocation, databaseName))) {
  dir.create(file.path(outputLocation, databaseName), recursive = T)
}
# Recreate the empty folder (optional, if Strategus expects it to exist)
dir.create(outputLocation, showWarnings = FALSE, recursive = TRUE)

# You can use this snippet to test your connection
# conn <- DatabaseConnector::connect(connectionDetails)
# DatabaseConnector::disconnect(conn)
## =========== END OF INPUTS ==========

fileName <- file.path(paste0("./", analysisName))
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = fileName
)
cat("Analysis specifications loaded from", fileName, "\n")
# print(CohortGenerator::getCohortTableNames(cohortTable = cohortTableName))

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  tempEmulationSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, databaseName, "strategusWork"),
  resultsFolder = file.path(outputLocation, databaseName, "strategusOutput"),
  minCellCount = minCellCount
)

ParallelLogger::saveSettingsToJson(
 object = executionSettings,
 fileName = file.path(outputLocation, databaseName, "executionSettings.json")
)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
cat("Execution complete\n")


cat("Uploading results to the database...\n")
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "study_results_pg_admin_user"
pw     <- "dpQo1Cq0eIXXemiHCglrcOyXHoOoiS"
# Create connection details
connectionDetails <- createConnectionDetails(
  dbms = dbms,
  server = server,
  user = user,
  password = pw,
  port = port,
  pathToDriver = pathToDriver
)
# Connect to db and create schema if not exists
conn <- connect(connectionDetails)
sql_1 <- paste0("DROP SCHEMA IF EXISTS ", results_schema_name, " CASCADE;")
executeSql(conn, sql_1)
sql_2 <- paste0("CREATE SCHEMA IF NOT EXISTS ", results_schema_name, ";")
executeSql(conn, sql_2)
disconnect(conn)

# upload results to another database
resultsDataModelSettings <- Strategus::createResultsDataModelSettings(
  resultsDatabaseSchema = results_schema_name,
  resultsFolder = file.path(outputLocation, databaseName, "strategusOutput")
)
Strategus::createResultDataModel(
  analysisSpecifications = analysisSpecifications,
  resultsDataModelSettings = resultsDataModelSettings,
  resultsConnectionDetails = connectionDetails
)

Strategus::uploadResults(
  analysisSpecifications = analysisSpecifications,
  resultsDataModelSettings = resultsDataModelSettings,
  resultsConnectionDetails = connectionDetails
)
cat("Results uploaded to the database successfully\n")