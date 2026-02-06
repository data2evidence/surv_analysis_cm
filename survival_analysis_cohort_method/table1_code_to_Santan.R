library(FeatureExtraction)

source_db_connection_details <- NULL # connection details object to the source database
cohorts_list <- c(1,2) # depending on the cohorts in the notebook
cohort_table <- "cohort"
cdm_database_schema_name <- "main"
cohort_database_schema_name <- "main"

# fetch covariate data for cohorts in the list
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()
covData <- getDbCovariateData(
  connectionDetails = source_db_connection_details,
  tempEmulationSchema = NULL,
  cdmDatabaseSchema = cdm_database_schema_name,
  cdmVersion = "5",
  cohortTable = cohort_table,
  cohortDatabaseSchema = cohort_database_schema_name,
  cohortTableIsTemp = FALSE,
  cohortIds = cohorts_list,
  rowIdField = "subject_id",
  covariateSettings = covariateSettings,
  aggregated = TRUE
)
# create Table 1 for cohorts in the list
for (cohort_id in cohorts_list){
    # create table for each cohort
    table1 <- createTable1(
        covariateData1 = covData1,
        cohortId1 = as.integer(cohort_id),
        specifications = getDefaultTable1Specifications(),
        output = "one column",
        showCounts = TRUE,
        showPercent = TRUE,
        percentDigits = 1,
        valueDigits = 1,
        stdDiffDigits = 2
    )
    # dump table 1 as a json file
    file_path = paste0("./", "tb1_", cohort_id, ".json")
    ParallelLogger::saveSettingsToJson(
        table1,
        file.path(file_path)
    )
    # code to push this json file to db here
    
}
