library(DatabaseConnector)
library(dplyr)
library(OhdsiShinyAppBuilder)
library(OhdsiShinyModules)

# resultsDatabaseSchema <- "surv_analysis_spec_cancer_amit_100pct_2"
resultsDatabaseSchema <- "res_surv_analysis_spec_cancer_amit_100pct_2"

# launch the shiny app
# database connection and execution settings
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
# user   <- "postgres"
# pw     <- "Toor1234"
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


OhdsiShinyAppBuilder::viewShiny(
config = config, 
connection = connection,  
resultDatabaseSettings = createDefaultResultDatabaseSettings(schema=resultsDatabaseSchema)
)

# print("Shiny Config:")
# print(shinyConfig)
#print("Results Connection Details:")
#print(resultsConnectionDetails)

# Test database connection before starting
# tryCatch({
#   conn <- DatabaseConnector::connect(resultsConnectionDetails)
#   cat("Database connection successful\n")
#   DatabaseConnector::disconnect(conn)
# }, error = function(e) {
#   cat("Database connection failed:", e$message, "\n")
# })

# now create the shiny app based on the config file and view the results
# based on the connection 
# print("Creating Shiny app...")
# app <- OhdsiShinyAppBuilder::createShinyApp(
#   config = shinyConfig, 
#   connection = resultsConnectionDetails,
#   # resultDatabaseSettings = createDefaultResultDatabaseSettings(schema = resultsDatabaseSchema)
# )
# print("App creation result:")
# # print(app)

# print("Running Shiny app...")
# shiny::runApp(
#   app, 
#   host = "0.0.0.0", 
#   port = 3838,
#   launch.browser = FALSE
# )