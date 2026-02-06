library(Strategus)
library(dplyr)
library(CohortMethod)

analysisName <- "surv_analysis_spec_gi_bleed.json"

# Load cohort definitions
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  # settingsFileName = "./cancer_cohorts/Cohorts.csv",
  # jsonFolder = "./cancer_cohorts/cohorts",
  # sqlFolder = "./cancer_cohorts/sql/sql_server"
  
  settingsFileName = "./gibleed_cohorts/Cohorts.csv",
  jsonFolder = "./gibleed_cohorts/cohorts",
  sqlFolder = "./gibleed_cohorts/sql/sql_server"
  
  # settingsFileName = "./atlas_cohorts/Cohorts.csv",
  # jsonFolder = "./atlas_cohorts/cohorts",
  # sqlFolder = "./atlas_cohorts/sql/sql_server"
)
print("Cohort definitions loaded successfully.")
tarCohortId <- 1
compCohortId <- 2
outCohortId <- 3

ncoCohortSet <- tibble::tibble(
  cohortId = c(10037, 10038, 10039, 10040, 10041, 10042, 10043, 10044, 10046, 10047, 10048, 10049),
  cohortName = c(
    "Concussion with loss of consciousness",
    "Child attention deficit disorder",
    "Urinary tract infection caused by Escherichia coli",
    "Anemia",
    "Coronary arteriosclerosis",
    "Cardiac arrest",
    "Atrial fibrillation",
    "Alzheimer's disease",
    "Viral sinusitis",
    "Myocardial infarction",
    "Acute bacterial sinusitis",
    "Polyp of colon"
  ),
  outcomeConceptId = c(375671, 440086, 4116491, 
                         439777, 317576, 321042, 
                         313217, 378419, 40481087, 
                         4329847, 4294548, 4285898)
)

cgModuleSettingsCreator <- CohortGeneratorModule$new()
# Create the negative control outcome shared resource element for the analysis specification
ncoSharedResource <-  cgModuleSettingsCreator$createNegativeControlOutcomeCohortSharedResourceSpecifications(
  negativeControlOutcomeCohortSet = ncoCohortSet,
  occurrenceType = "all",
  detectOnDescendants = TRUE
)

negativeControlOutcomes <- lapply(
  X = ncoCohortSet$cohortId,
  FUN = CohortMethod::createOutcome,
  outcomeOfInterest = FALSE,
  trueEffectSize = 1,
  priorOutcomeLookback = 30
)

# priorOutcomeLookback <- 30
studyStartDate <- "19000101"
studyEndDate <- "20251231"

# Target-Comparator pairs
cmTcList <- data.frame(
  targetCohortId = tarCohortId,
  targetCohortName = "Celecoxib Users",
  comparatorCohortId = compCohortId,
  comparatorCohortName = "Diclofenac Users"
)

# Outcome cohort
outcomeCohortId <- outCohortId

# Set time-at-risk
timeAtRisks <- tibble(
  label = c("KM Analysis"),
  riskWindowStart  = c(0),
  startAnchor = c("cohort start"),
  riskWindowEnd  = c(99999),
  endAnchor = c("cohort end")
)

# Define the outcome
outcomeOfInterest <- lapply(seq_len(1), function(i) {
  CohortMethod::createOutcome(
    outcomeId = outcomeCohortId,
    outcomeOfInterest = TRUE,
    # trueEffectSize = NA,
    # priorOutcomeLookback = priorOutcomeLookback
  )
})

outcomes <- append(
  negativeControlOutcomes,
  outcomeOfInterest
)

# Define the T-C-O structure
targetComparatorOutcomesList <- list(
  CohortMethod::createTargetComparatorOutcomes(
    targetId = cmTcList$targetCohortId,
    comparatorId = cmTcList$comparatorCohortId,
    outcomes = outcomes,
    excludedCovariateConceptIds = c(1118084, 1124300)
  )
)

# aceI <- c(1335471,1340128,1341927,1363749,1308216,1310756,1373225,
#           1331235,1334456,1342439)
# thz <- c(1395058,974166,978555,907013)

covarSettings <- FeatureExtraction::createDefaultCovariateSettings(addDescendantsToExclude = TRUE)

getDbCmDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
  washoutPeriod = 183,
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = "remove all",
  maxCohortSize = 100000,
  covariateSettings = covarSettings
)

createStudyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(
  minDaysAtRisk = 1,
  riskWindowStart = 0,
  startAnchor = "cohort start",
  riskWindowEnd = 30,
  endAnchor = "cohort end"
)

# Setup cohort method module
cmAnalysisList <- list(
  CohortMethod::createCmAnalysis(
    analysisId = 1,
    description = "KM analysis with PS Matching",
    
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgs,
  	# createPsArgs = CohortMethod::createCreatePsArgs(
    #   errorOnHighCorrelation = TRUE,
    #   stopOnError = TRUE,
    #   prior = createPrior("laplace", exclude = c(0), useCrossValidation = TRUE),
    #   control = createControl(noiseLevel = "silent", cvType = "auto", seed = 1,
    #     resetCoefficients = TRUE, tolerance = 2e-07, cvRepetitions = 10, startingVariance =0.01),
    #   estimator = "ate"
    # ),
    # matchOnPsArgs = CohortMethod::createMatchOnPsArgs(
    #   maxRatio = 100
    # ),
    # computeSharedCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(
    #   # maxCohortSize = 250000,
    #   # covariateFilter = NULL
    # ),
    # computeCovariateBalanceArgs = CohortMethod::createComputeCovariateBalanceArgs(
    #   # maxCohortSize = 250000,
    #   # covariateFilter = FeatureExtraction::getDefaultTable1Specifications()
    # ),
    fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(
      modelType = "cox"
    )
  )
)

# Cohort Generator Module Specifications
cohortDefinitionShared <- cgModuleSettingsCreator$createCohortSharedResourceSpecifications(cohortDefinitionSet)
cohortGeneratorModuleSpecifications <- cgModuleSettingsCreator$createModuleSpecifications(
  generateStats = TRUE
)
print("Cohort Generator specifications created successfully.")


# Cohort Method Module Specifications
cmModuleSettingsCreator <- CohortMethodModule$new()
cohortMethodModuleSpecifications <- cmModuleSettingsCreator$createModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList,
  # refitPsForEveryOutcome = FALSE,
  # refitPsForEveryStudyPopulation = FALSE,  
  # cmDiagnosticThresholds = CohortMethod::createCmDiagnosticThresholds()
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