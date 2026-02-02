library(Strategus)
library(dplyr)


analysisName <- "surv_analysis_spec_gi_bleed.json"

# Set time-at-risk
timeAtRisks <- tibble(
  label = c("Kaplan Meier Analysis"),
  riskWindowStart  = c(1),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(0),
  endAnchor = c("cohort end")
)

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


#Target-Comparator pairs
cmTcList <- data.frame(
  targetCohortId = 1,
  targetCohortName = "celecoxib",
  comparatorCohortId = 2,
  comparatorCohortName = "diclofenac"
)
print("\nCheck 1\n")
# cmTcList <- data.frame(
#   targetCohortId = 1,
#   targetCohortName = "cancer with chemotherapy",
#   comparatorCohortId = 2,
#   comparatorCohortName = "cancer with radiotherapy"
# )
# Outcome cohort
outcomeCohortId <- 3
priorOutcomeLookback <- 99999
psMatchMaxRatio <- 1

# Define the outcome
outcomeList <- lapply(seq_len(1), function(i) {
  CohortMethod::createOutcome(
    outcomeId = outcomeCohortId,
    outcomeOfInterest = TRUE,
    trueEffectSize = NA,
    priorOutcomeLookback = priorOutcomeLookback
  )
})
print("\nCheck 2\n")
# Define the T-C-O structure
targetComparatorOutcomesList <- list(
  CohortMethod::createTargetComparatorOutcomes(
    targetId = cmTcList$targetCohortId,
    comparatorId = cmTcList$comparatorCohortId,
    outcomes = outcomeList
  )
)
print("Target-Comparator-Outcomes structure created successfully.")
print("\nCheck \n")

# Setup cohort method module
cmModuleSettingsCreator <- CohortMethodModule$new()

cmAnalysisList <- list(
  CohortMethod::createCmAnalysis(
    analysisId = 1,
    description = "KM analysis with PS Matching",
    getDbCohortMethodDataArgs = CohortMethod::createGetDbCohortMethodDataArgs(
      restrictToCommonPeriod = TRUE,
      studyStartDate = studyStartDate,
      studyEndDate = studyEndDate,
      maxCohortSize = 0,
      covariateSettings = FeatureExtraction::createDefaultCovariateSettings()
    ),
    createStudyPopArgs = CohortMethod::createCreateStudyPopulationArgs(
        firstExposureOnly = FALSE,
        washoutPeriod = 0,
        removeDuplicateSubjects = "keep first",
        censorAtNewRiskWindow = TRUE,
        removeSubjectsWithPriorOutcome = TRUE,
        priorOutcomeLookback = 99999,
        riskWindowStart = timeAtRisks$riskWindowStart,
        startAnchor = timeAtRisks$startAnchor,
        riskWindowEnd = timeAtRisks$riskWindowEnd,
        endAnchor = timeAtRisks$endAnchor,
        minDaysAtRisk = 1,
        maxDaysAtRisk = 99999
    ),
    createPsArgs = CohortMethod::createCreatePsArgs(
      maxCohortSizeForFitting = 250000,
      errorOnHighCorrelation = TRUE,
      stopOnError = FALSE, # Setting to FALSE to allow Strategus complete all CM operations; when we cannot fit a model, the equipoise diagnostic should fail
      estimator = "att",
      prior = Cyclops::createPrior(
        priorType = "laplace", 
        exclude = c(0), 
        useCrossValidation = TRUE
      ),
      control = Cyclops::createControl(
        noiseLevel = "silent", 
        cvType = "auto", 
        seed = 1, 
        resetCoefficients = TRUE, 
        tolerance = 2e-07, 
        cvRepetitions = 1, 
        startingVariance = 0.01
      )
    ),
    matchOnPsArgs = CohortMethod::createMatchOnPsArgs(
      maxRatio = psMatchMaxRatio,
      caliper = 0.2,
      caliperScale = "standardized logit",
      allowReverseMatch = FALSE,
      stratificationColumns = c()
    ),
    computeSharedCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(
      maxCohortSize = 250000,
      covariateFilter = NULL
    ),
    computeCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(
      maxCohortSize = 250000,
      covariateFilter = FeatureExtraction::getDefaultTable1Specifications()
    ),
    fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(
      modelType = "cox",
      stratified = psMatchMaxRatio != 1,
      useCovariates = FALSE,
      inversePtWeighting = FALSE,
      prior = Cyclops::createPrior(
        priorType = "laplace", 
        useCrossValidation = TRUE
      ),
      control = Cyclops::createControl(
        cvType = "auto", 
        seed = 1, 
        resetCoefficients = TRUE,
        startingVariance = 0.01, 
        tolerance = 2e-07, 
        cvRepetitions = 1, 
        noiseLevel = "quiet"
      )
    )
  )
  
# Cohort Generator Module Specifications 
cgModuleSettingsCreator <- CohortGeneratorModule$new()
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
  )
print("Cohort Generator specifications created successfully.")

# Cohort Method Module Specifications
cohortMethodModuleSpecifications <- cmModuleSettingsCreator$createModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList,
  refitPsForEveryOutcome = FALSE,
  refitPsForEveryStudyPopulation = FALSE,  
  cmDiagnosticThresholds = CohortMethod::createCmDiagnosticThresholds()
)
print("Cohort Method analysis specifications created successfully.")

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