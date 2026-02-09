# integration of Table 1 creation with result viewer shiny app 
# v2 - when shiny is just loading table 1 from results db and not creating them

library(CohortMethod)
library(DatabaseConnector)
library(FeatureExtraction)
library(dplyr)
library(OhdsiShinyAppBuilder)
library(readr)
library(shiny)
library(stringr)
library(tidyr)
library(tibble)

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

######### function to reformat and display table 1 ##############
format_table1 <- function(tb) {
  blank_row <- tibble(
    Characteristic = "",
    Count = "",
    `% (n = 1,800)` = ""
  )

  is_blank_row <- function(row_tbl) {
    if (!is.data.frame(row_tbl) || nrow(row_tbl) == 0) {
      return(FALSE)
    }
    vals <- unlist(row_tbl[1, ], use.names = FALSE)
    all(trimws(vals) == "")
  }

  append_partition <- function(out_list) {
    if (length(out_list) == 0 || !is_blank_row(out_list[[length(out_list)]])) {
      out_list <- append(out_list, list(blank_row))
    }
    out_list
  }

  partition_before_headers <- c(
    "Medical history: General",
    "Medical history: Cardiovascular disease",
    "Charlson comorbidity index",
    "CHADS2Vasc"
  )
  partition_after_numeric <- c(
    "Charlson comorbidity index",
    "CHADS2Vasc"
  )

  out <- list()
  i <- 1
  n <- nrow(tb)

  while (i <= n) {
    row <- tb[i, ]
    trimmed_char <- str_trim(ifelse(is.na(row$Characteristic), "", row$Characteristic))
    trimmed_count <- str_trim(ifelse(is.na(row$Count), "", row$Count))
    trimmed_percent <- str_trim(ifelse(is.na(row$`% (n = 1,800)`), "", row$`% (n = 1,800)`))

    if (trimmed_char %in% partition_before_headers) {
      out <- append_partition(out)
    }

    if (trimmed_char == "Characteristic" && trimmed_percent == "Value") {
      out <- append_partition(out)
    }

    # --- Detect numeric block header ---
    # A numeric block starts when a row has a name (non-empty), Count empty, Value empty,
    # and the next row is "Mean"
    if (
      trimmed_char != "" &&
      trimmed_count == "" &&
      trimmed_percent == "" &&
      i + 1 <= n &&
      str_trim(tb$Characteristic[i + 1]) == "Mean"
    ) {
      stats_labels <- c(
        "Mean",
        "Std. deviation",
        "Minimum",
        "25th percentile",
        "Median",
        "75th percentile",
        "Maximum"
      )

      # Add a blank row before the numeric block to visually separate
      out <- append_partition(out)
      out <- append(out, list(row))

      # Extract consecutive numeric stats rows for this characteristic
      stats_idx <- integer()
      j <- i + 1
      while (j <= n) {
        next_label <- str_trim(ifelse(is.na(tb$Characteristic[j]), "", tb$Characteristic[j]))
        if (next_label %in% stats_labels) {
          stats_idx <- c(stats_idx, j)
          j <- j + 1
        } else {
          break
        }
      }

      stats <- tibble()
      if (length(stats_idx) > 0) {
        stats <- tb[stats_idx, , drop = FALSE] %>%
          mutate(stat = str_trim(Characteristic)) %>%
          filter(stat %in% stats_labels)
      }

      # Extract values
      mean_val <- stats$`% (n = 1,800)`[stats$stat == "Mean"]
      sd_val   <- stats$`% (n = 1,800)`[stats$stat == "Std. deviation"]
      min_val  <- stats$`% (n = 1,800)`[stats$stat == "Minimum"]
      max_val  <- stats$`% (n = 1,800)`[stats$stat == "Maximum"]
      perc_25 <- stats$`% (n = 1,800)`[stats$stat == "25th percentile"]
      perc_med <- stats$`% (n = 1,800)`[stats$stat == "Median"]
      perc_75 <- stats$`% (n = 1,800)`[stats$stat == "75th percentile"]

      # Add formatted numeric rows
      mean_sd_row <- tibble(
        Characteristic = "    Mean (SD)",
        Count = "",
        `% (n = 1,800)` = paste0(mean_val, " (", sd_val, ")")
      )
      min_max_row <- tibble(
        Characteristic = "    Min, Max",
        Count = "",
        `% (n = 1,800)` = paste0("[", min_val, ", ", max_val, "]")
      )
      perc_row <- tibble(
        Characteristic = "    Percentiles [25th, Median, 75th]",
        Count = "",
        `% (n = 1,800)` = paste0("[", perc_25, ", ", perc_med, ", ", perc_75, "]")
      )

      out <- append(out, list(mean_sd_row, min_max_row, perc_row))

      if (trimmed_char %in% partition_after_numeric) {
        out <- append_partition(out)
      }

      # Skip the original numeric rows (header + stats block)
      next_row_index <- if (length(stats_idx) > 0) max(stats_idx) + 1 else (i + 1)
      i <- next_row_index
      next
    }

    # --- Otherwise just append row as-is ---
    out <- append(out, list(row))
    i <- i + 1
  }

  bind_rows(out)
}

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
      sql <- paste0("SELECT table1_json FROM ", results_schema_name, ".tb1_results WHERE cohort_id = '", cohort_id, "';")
      conn <- connectionHandler$getConnection()
      res <- DatabaseConnector::querySql(conn, sql)
      if (nrow(res) == 0) {
        cat("No Table 1 output found for cohort ID:", cohort_id, "\n")
        return (NULL)
      }
      json_str <- res$table1_json[1]
      table1 <- ParallelLogger::convertJsonToSettings(json_str)
      print(class(table1))
      print(table1, n=Inf)
      table1 <- format_table1(table1)
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