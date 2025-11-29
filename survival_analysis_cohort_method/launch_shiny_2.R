library(shiny)
library(ggplot2)
library(dplyr)
library(DatabaseConnector)
library(survival)
# library(survminer)
library(SqlRender)

# ---- User: provide these ----
connectionDetails <- NULL  # Your DatabaseConnector connectionDetails object
cdmDatabaseSchema <- "cdm_schema"
resultsDatabaseSchema <- "results_schema"
cmTablePrefix <- "cm_"    # CohortMethod table prefix
databaseId <- ""
targetId <- 1
comparatorId <- 2
outcomeId <- 1
analysisId <- 1

# ---- Helper functions ----

getKaplanMeier <- function(connection, resultsDatabaseSchema, cmTablePrefix,
                           targetId, comparatorId, outcomeId, analysisId, databaseId) {
  sql <- "
    SELECT *
    FROM @resultsDatabaseSchema.@cmTablePrefixkaplan_meier_dist
    WHERE target_id = @targetId
      AND comparator_id = @comparatorId
      AND outcome_id = @outcomeId
      AND analysis_id = @analysisId
      AND database_id = '@databaseId'
    ORDER BY time
  "
  renderTranslateQuerySql(connection, sql,
                          resultsDatabaseSchema = resultsDatabaseSchema,
                          cmTablePrefix = cmTablePrefix,
                          targetId = targetId,
                          comparatorId = comparatorId,
                          outcomeId = outcomeId,
                          analysisId = analysisId,
                          databaseId = databaseId,
                          snakeCaseToCamelCase = TRUE)
}

getPropensityScores <- function(connection, resultsDatabaseSchema, cmTablePrefix,
                                targetId, comparatorId, analysisId, databaseId) {
  sql <- "
    SELECT ps_value as score, treatment_id as treatment
    FROM @resultsDatabaseSchema.@cmTablePrefixpropensity_score_dist
    WHERE target_id = @targetId
      AND comparator_id = @comparatorId
      AND analysis_id = @analysisId
      AND database_id = '@databaseId'
  "
  renderTranslateQuerySql(connection, sql,
                          resultsDatabaseSchema = resultsDatabaseSchema,
                          cmTablePrefix = cmTablePrefix,
                          targetId = targetId,
                          comparatorId = comparatorId,
                          analysisId = analysisId,
                          databaseId = databaseId,
                          snakeCaseToCamelCase = TRUE)
}

getCox <- function(connection, resultsDatabaseSchema, cmTablePrefix,
                   targetId, comparatorId, outcomeId, analysisId, databaseId) {
  sql <- "
    SELECT outcome_id, hazard_ratio as hr, hazard_ratio_95_ci_lower as lowerCI,
           hazard_ratio_95_ci_upper as upperCI, p_value as pValue
    FROM @resultsDatabaseSchema.@cmTablePrefixcohort_method_result
    WHERE target_id = @targetId
      AND comparator_id = @comparatorId
      AND outcome_id = @outcomeId
      AND analysis_id = @analysisId
      AND database_id = '@databaseId'
  "
  renderTranslateQuerySql(connection, sql,
                          resultsDatabaseSchema = resultsDatabaseSchema,
                          cmTablePrefix = cmTablePrefix,
                          targetId = targetId,
                          comparatorId = comparatorId,
                          outcomeId = outcomeId,
                          analysisId = analysisId,
                          databaseId = databaseId,
                          snakeCaseToCamelCase = TRUE)
}

# ---- Shiny App ----
ui <- fluidPage(
  titlePanel("OHDSI CohortMethod Visualizations"),
  sidebarLayout(
    sidebarPanel(
      helpText("Kaplan-Meier, Propensity Score, and Cox Hazard Ratio visualizations from database")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Kaplan-Meier", plotOutput("kmPlot")),
        tabPanel("Propensity Score", plotOutput("psPlot")),
        tabPanel("Cox Hazard Ratio", plotOutput("coxPlot"))
      )
    )
  )
)

server <- function(input, output, session) {
  
  conn <- connect(connectionDetails)
  on.exit(disconnect(conn), add = TRUE)
  
  # Kaplan-Meier
  km_data <- reactive({
    getKaplanMeier(conn, resultsDatabaseSchema, cmTablePrefix,
                   targetId, comparatorId, outcomeId, analysisId, databaseId)
  })
  
  output$kmPlot <- renderPlot({
    km <- km_data()
    if (nrow(km) == 0) return(NULL)
    
    km_long <- data.frame(
      time = rep(km$time, 2),
      survival = c(km$targetSurvival, km$comparatorSurvival),
      lower = c(km$targetSurvivalLb, km$comparatorSurvivalLb),
      upper = c(km$targetSurvivalUb, km$comparatorSurvivalUb),
      strata = rep(c("Target", "Comparator"), each = nrow(km))
    )
    
    ggplot(km_long, aes(x=time, y=survival, color=strata)) +
      geom_step(size=1) +
      geom_ribbon(aes(ymin=lower, ymax=upper, fill=strata), alpha=0.2, color=NA) +
      labs(x="Time (days)", y="Survival probability") +
      theme_minimal() +
      scale_color_manual(values=c("red","blue")) +
      scale_fill_manual(values=c("red","blue"))
  })
  
  # Propensity Score
  ps_data <- reactive({
    getPropensityScores(conn, resultsDatabaseSchema, cmTablePrefix,
                        targetId, comparatorId, analysisId, databaseId)
  })
  
  output$psPlot <- renderPlot({
    ps <- ps_data()
    if (nrow(ps) == 0) return(NULL)
    ggplot(ps, aes(x=score, fill=factor(treatment))) +
      geom_density(alpha=0.5) +
      labs(x="Propensity Score", y="Density", fill="Cohort") +
      scale_fill_manual(values=c("blue","red"), labels=c("Comparator","Target")) +
      theme_minimal()
  })
  
  # Cox Hazard Ratios
  cox_data <- reactive({
    getCox(conn, resultsDatabaseSchema, cmTablePrefix,
           targetId, comparatorId, outcomeId, analysisId, databaseId)
  })
  
  output$coxPlot <- renderPlot({
    cox <- cox_data()
    if (nrow(cox) == 0) return(NULL)
    ggplot(cox, aes(x=factor(outcomeId), y=hr)) +
      geom_point(size=3) +
      geom_errorbar(aes(ymin=lowerCI, ymax=upperCI), width=0.2) +
      geom_hline(yintercept=1, linetype="dashed", color="grey") +
      labs(y="Hazard Ratio (95% CI)", x="Outcome") +
      theme_minimal()
  })
  
}

shinyApp(ui, server)