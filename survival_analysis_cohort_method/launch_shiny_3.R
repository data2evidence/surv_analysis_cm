library(DatabaseConnector)
library(dplyr)
library(OhdsiShinyAppBuilder)
library(OhdsiShinyModules)
library(shiny)
library(future)
library(TreatmentPatterns)
library(CohortSurvival)
library(readr)

analysisName_base = "surv_analysis_spec_gi_bleed"
analysisName <- paste0(analysisName_base, ".json")
results_schema_name <- paste0("res_", analysisName_base, "_amit")

# database connection and execution settings
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "amit.sharma"
pw     <- "Tango==1262"
port   <- 5432              # local forwarded port from your SSH tunnel
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

############################ Launch Shiny RS Viewer ############################
connection <- ResultModelManager::ConnectionHandler$new(connectionDetails)
resultsConnectionDetails <- connectionDetails

# ADD OR REMOVE MODULES TAILORED TO YOUR STUDY
config <- initializeModuleConfig() %>%
  addModuleConfig(
    createDefaultAboutConfig()
  )  %>%
  addModuleConfig(
    createDefaultCohortGeneratorConfig()
  ) %>%
  addModuleConfig(
    createDefaultCharacterizationConfig()
  ) %>%
  addModuleConfig(
    createDefaultPredictionConfig()
  ) %>%
  addModuleConfig(
    createDefaultEstimationConfig()
  )

createShinyApp(config = config, connection = connection, resultDatabaseSettings = createDefaultResultDatabaseSettings(schema=results_schema_name))

# OhdsiShinyAppBuilder::viewShiny(
# config = config, 
# connection = connection,  
# resultDatabaseSettings = createDefaultResultDatabaseSettings(schema=results_schema_name)
# )