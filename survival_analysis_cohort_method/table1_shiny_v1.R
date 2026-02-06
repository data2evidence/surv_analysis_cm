# integration of Table 1 creation with result viewer shiny app 
# v1 - when shiny has code for fetching and creating table 1

library(CohortMethod)
library(DatabaseConnector)
library(FeatureExtraction)
library(dplyr)
library(OhdsiShinyAppBuilder)
library(readr)
library(shiny)

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

# Connect to db and create schema if not exists
results_schema_name <- "res_surv_analysis_spec_gi_bleed_santan_amit"

############### Using Feature Extraction to create Table 1 ################
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
  cohortId1 = cohort_1,
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


############### load shiny app to view results ###############
connection <- ResultModelManager::ConnectionHandler$new(connectionDetails)
connection_source <- ResultModelManager::ConnectionHandler$new(connectionDetails_source)


# -------------- Table 1 Visualization Module (Shiny) --------------
table1ModuleUI <- function(id) {
  ns <- NS(id)
  fluidPage(
    fluidRow(
      column(12, div(style = "text-align:left;",
        h4("Select Cohort ID:"),
        div(style = "display:inline-block; min-width:200px;", selectInput(ns("cohort1"), label = NULL, choices = NULL))
      ))
    ),
    br(),
    fluidRow(
      column(12,
        div(
          style = "max-width: 70%; width: 100%; border: 2px solid #b3b3b3; border-radius: 10px; padding: 2vw 2vw 2vw 2vw; margin-bottom: 2vw; box-sizing: border-box; text-align:left;",
          h4("Table 1 for Cohorts", style = "text-align:left; font-size:1.5vw; margin-bottom:1vw;"),
          div(style = "overflow-x:auto; text-align:left; width:100%;",
            tableOutput(ns("table1out")),
            tags$style(HTML(paste0("#", ns("table1out"), " table, #", ns("table1out"), " th, #", ns("table1out"), " td { text-align: center !important; }")))
          )
        )
      )
    )
  )
}

table1ModuleServer <- function(id, connectionHandler, resultDatabaseSettings, cohortTable = "cohort_tbl", cdmSchema = "main") {
  moduleServer(id, function(input, output, session) {
    # Get unique cohort IDs from the cohort table

    cohort_choices <- reactive({
        conn <- connection_source$getConnection()
        sql <- paste0("SELECT DISTINCT cohort_definition_id FROM ", cohortTable)
        res <- DatabaseConnector::querySql(conn, sql)
        cat("Cohort IDs loaded from the database:\n")
        print(res$cohort_definition_id)
        return (res$cohort_definition_id)
    })

    observeEvent(cohort_choices(), {
      choices <- cohort_choices()
        updateSelectInput(session, "cohort1", choices = choices, selected = choices[1])
        updateTextInput(session, "cohort1", value = choices[1])
    })

    table1_data <- reactive({
      req(input$cohort1)
      covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()
      covData1 <- FeatureExtraction::getDbCovariateData(
        connectionDetails = NULL,
        connection = connection_source$getConnection(),
        tempEmulationSchema = NULL,
        cdmDatabaseSchema = cdmSchema,
        cdmVersion = "5",
        cohortTable = cohortTable,
        cohortDatabaseSchema = cdmSchema,
        cohortTableIsTemp = FALSE,
        cohortIds = as.integer(input$cohort1),
        rowIdField = "subject_id",
        covariateSettings = covariateSettings,
        aggregated = TRUE
      )
      table1 <- FeatureExtraction::createTable1(
        covariateData1 = covData1,
        cohortId1 = as.integer(input$cohort1),
        specifications = FeatureExtraction::getDefaultTable1Specifications(),
        output = "one column",
        showCounts = TRUE,
        showPercent = TRUE,
        percentDigits = 1,
        valueDigits = 1,
        stdDiffDigits = 2
      )
      return (table1)
    })

    output$table1out <- renderTable({
      tbl <- table1_data()
      if (is.data.frame(tbl)) {
        tbl
      } else {
        data.frame(Message = "No Table 1 output.")
      }
    }, striped = TRUE, bordered = TRUE, hover = TRUE, spacing = 'm', align = 'c')
  })
}

# -------------- Shiny App Initialization --------------
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
  ) %>%
  addModuleConfig(
    createModuleConfig(
      moduleId = 'table1',
      tabName = "Table1",
      shinyModulePackage = NULL,
      shinyModulePackageVersion = NULL,
      moduleUiFunction = table1ModuleUI,
      moduleServerFunction = table1ModuleServer,
      moduleInfoBoxFile = function(){},
      moduleIcon = "info",
      installSource = "CRAN",
      gitHubRepo = NULL
    )
  )

createShinyApp(
  config = config, 
  connection = connection, 
  resultDatabaseSettings = createDefaultResultDatabaseSettings(schema=results_schema_name)
  )