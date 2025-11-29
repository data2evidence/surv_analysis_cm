library(Strategus)
library(dplyr)

studyStartDate <- "19000101"
studyEndDate <- "20251231"
analysisName <- "surv_analysis_spec_cancer.json"

# Load cohort definitions
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "./cancer_cohorts/Cohorts.csv",
  jsonFolder = "./cancer_cohorts/cohorts",
  sqlFolder = "./cancer_cohorts/sql/sql_server"
  # settingsFileName = "./gibleed_cohorts/Cohorts.csv",
  # jsonFolder = "./gibleed_cohorts/cohorts",
  # sqlFolder = "./gibleed_cohorts/sql/sql_server"
)
print("Cohort definitions loaded successfully.")

# Cohort Generator
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
  )
print("Cohort Generator specifications created successfully.")

# Target-Comparator pairs
# cmTcList <- data.frame(
#   targetCohortId = 1,
#   targetCohortName = "celecoxib",
#   comparatorCohortId = 2,
#   comparatorCohortName = "diclofenac"
# )
cmTcList <- data.frame(
  targetCohortId = 1,
  targetCohortName = "cancer with chemotherapy",
  comparatorCohortId = 2,
  comparatorCohortName = "cancer with radiotherapy"
)
# Outcome cohort
outcomeCohortId <- 3

# Set time-at-risk
timeAtRisks <- tibble(
  label = c("Kaplan-Meier Analysis"),
  riskWindowStart = 0,
  startAnchor = "cohort start",
  riskWindowEnd = 3650,
  endAnchor = "cohort end"
)

# Define the outcome
outcomeList <- lapply(seq_len(1), function(i) {
  CohortMethod::createOutcome(
    outcomeId = outcomeCohortId,
    outcomeOfInterest = TRUE
  )
})

# Define the T-C-O structure
targetComparatorOutcomesList <- list(
  CohortMethod::createTargetComparatorOutcomes(
    targetId = cmTcList$targetCohortId,
    comparatorId = cmTcList$comparatorCohortId,
    outcomes = outcomeList
  )
)
print("Target-Comparator-Outcomes structure created successfully.")

# Setup cohort method module
cmModuleSettingsCreator <- CohortMethodModule$new()

cmAnalysisList <- list(
  CohortMethod::createCmAnalysis(
    analysisId = 1,
    description = "KM analysis with PS Matching",
    getDbCohortMethodDataArgs = CohortMethod::createGetDbCohortMethodDataArgs(
      studyStartDate = studyStartDate,
      studyEndDate = studyEndDate,
      covariateSettings = FeatureExtraction::createDefaultCovariateSettings()
    ),
    createStudyPopArgs = CohortMethod::createCreateStudyPopulationArgs(
        riskWindowStart = timeAtRisks$riskWindowStart,
        startAnchor = timeAtRisks$startAnchor,
        riskWindowEnd = timeAtRisks$riskWindowEnd,
        endAnchor = timeAtRisks$endAnchor,
        minDaysAtRisk = 0
    ),
    createPsArgs = CohortMethod::createCreatePsArgs(),
    matchOnPsArgs = CohortMethod::createMatchOnPsArgs(),
    computeCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(),
    fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(
      modelType = "cox",
      useCovariates = TRUE,
      stratified = TRUE
    ),
  ),
  CohortMethod::createCmAnalysis(
    analysisId = 2,
    description = "KM analysis with No PS Matching",
    getDbCohortMethodDataArgs = CohortMethod::createGetDbCohortMethodDataArgs(
      studyStartDate = studyStartDate,
      studyEndDate = studyEndDate,
      covariateSettings = FeatureExtraction::createDefaultCovariateSettings()
    ),
    createStudyPopArgs = CohortMethod::createCreateStudyPopulationArgs(
        riskWindowStart = timeAtRisks$riskWindowStart,
        startAnchor = timeAtRisks$startAnchor,
        riskWindowEnd = timeAtRisks$riskWindowEnd,
        endAnchor = timeAtRisks$endAnchor,
        minDaysAtRisk = 0
    ),
    computeCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(),
    fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(
      modelType = "cox",
      useCovariates = TRUE
    ),
  )
)
print("Cohort Method analysis specifications created successfully.")
cohortMethodModuleSpecifications <- cmModuleSettingsCreator$createModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList
)


# Final Analysis Spec
analysisSpecifications <- createEmptyAnalysisSpecificiations() |>
  addSharedResources(cohortDefinitionShared) |>
  addModuleSpecifications(cohortGeneratorModuleSpecifications) |>
  addModuleSpecifications(cohortMethodModuleSpecifications)

ParallelLogger::saveSettingsToJson(
  analysisSpecifications,
  file.path("./", analysisName)
)
# print("Analysis specifications saved successfully.")
cat("Analysis specification created and saved to", analysisName, "\n")