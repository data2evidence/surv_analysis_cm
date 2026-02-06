# integration of Table 1 creation with result viewer shiny app 
# v2 - when shiny is just loading table 1 from results db and not creating them

library(CohortMethod)
library(DatabaseConnector)
library(FeatureExtraction)
library(dplyr)
library(OhdsiShinyAppBuilder)
library(readr)
library(shiny)

#################### Database connection details ####################
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "amit.sharma"
pw     <- "Tango==1262"
port   <- 5432              # local forwarded port from your SSH tunnel
pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"

# global variables
results_schema_name <- "res_surv_analysis_spec_gi_bleed_santan_amit"
#Create connection details
connectionDetails <- createConnectionDetails(
  dbms = dbms,
  server = server,
  user = user,
  password = pw,
  port = port,
  pathToDriver = pathToDriver
)

############### load shiny app to view results ###############
connection <- ResultModelManager::ConnectionHandler$new(connectionDetails)


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
        conn <- connection$getConnection()
        sql <- paste0("SELECT DISTINCT cohort_id FROM ", results_schema_name, ".tb1_results;")
        res <- DatabaseConnector::querySql(conn, sql)
        cat("Cohort IDs loaded from the database:\n")
        print(res$cohort_id)
        return (res$cohort_id)
    })

    observeEvent(cohort_choices(), {
      choices <- cohort_choices()
        updateSelectInput(session, "cohort1", choices = choices, selected = choices[1])
        updateTextInput(session, "cohort1", value = choices[1])
    })

    table1_data <- reactive({
      req(input$cohort1)
      cohort_id <- input$cohort1
      sql <- paste0("SELECT table1_json FROM ", results_schema_name, ".tb1_results WHERE cohort_id = ", cohort_id, " ;")
      conn <- connectionHandler$getConnection()
      res <- DatabaseConnector::querySql(conn, sql)
      if (nrow(res) == 0) {
        cat("No Table 1 output found for cohort ID:", cohort_id, "\n")
        return (NULL)
      }
      json_str <- res$table1_json[1]
      table1 <- ParallelLogger::convertJsonToSettings(json_str)
      print(class(table1))
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