library(DatabaseConnector)

analysisName_base = "surv_analysis_spec_cancer"
analysisName <- paste0(analysisName_base, ".json")
results_schema_name <- paste0("res_", analysisName_base, "_amit_100pct")

outputLocation <- file.path(getwd(), "results")
databaseName <- "Eunomia" # Only used as a folder name for results from the study
minCellCount <- 5
cohortTableName <- "cohort_tbl"

cat("Uploading results to the database...\n")
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "study_results_pg_admin_user"
pw     <- "dpQo1Cq0eIXXemiHCglrcOyXHoOoiS"
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

# Connect to db and create schema if not exists
conn <- connect(connectionDetails)
sql_1 <- paste0("DROP SCHEMA IF EXISTS ", results_schema_name, " CASCADE;")
executeSql(conn, sql_1)
sql_2 <- paste0("CREATE SCHEMA IF NOT EXISTS ", results_schema_name, ";")
executeSql(conn, sql_2)
disconnect(conn)

fileName <- file.path(paste0("./", analysisName))
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = fileName
)
cat("Analysis specifications loaded from", fileName, "\n")

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