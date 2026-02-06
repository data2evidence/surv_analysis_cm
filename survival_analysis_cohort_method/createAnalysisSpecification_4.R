library(Strategus)
library(dplyr)
library(CohortMethod)

analysisName <- "surv_analysis_spec_gi_bleed_santan.json"

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

cgModule <- CohortGeneratorModule$new()

# Create the cohort definition shared resource element for the analysis specification
cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(
  cohortDefinitionSet = cohortDefinitionSet
)

# Create the negative control outcome shared resource element for the analysis specification
ncoSharedResource <- cgModule$createNegativeControlOutcomeCohortSharedResourceSpecifications(
  negativeControlOutcomeCohortSet = ncoCohortSet,
  occurrenceType = "all",
  detectOnDescendants = TRUE
)

# Create the module specification
cohortGeneratorModuleSpecifications <- cgModule$createModuleSpecifications(
  generateStats = TRUE
)


cmModule <- CohortMethodModule$new()
negativeControlOutcomes <- lapply(
  X = ncoCohortSet$cohortId,
  FUN = CohortMethod::createOutcome,
  outcomeOfInterest = FALSE,
  trueEffectSize = 1,
  priorOutcomeLookback = 30
)

outcomesOfInterest <- lapply(
  X = 3,
  FUN = CohortMethod::createOutcome,
  outcomeOfInterest = TRUE
)

# outcomes <- append(
#   negativeControlOutcomes,
#   outcomesOfInterest
# )
outcomes <-outcomesOfInterest


tcos1 <- CohortMethod::createTargetComparatorOutcomes(
  targetId = 1,
  comparatorId = 2,
  outcomes = outcomes,
  excludedCovariateConceptIds = c(1118084, 1124300)
)
tcos2 <- CohortMethod::createTargetComparatorOutcomes(
  targetId = 4,
  comparatorId = 5,
  outcomes = outcomes,
  excludedCovariateConceptIds = c(1118084, 1124300)
)

targetComparatorOutcomesList <- list(tcos1)

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
  riskWindowEnd = 99999,
  endAnchor = "cohort end"
)

createPsArgs <- CohortMethod::createCreatePsArgs(
  errorOnHighCorrelation = TRUE,
  stopOnError = TRUE,
  prior = createPrior("laplace", exclude = c(0), useCrossValidation = TRUE),
  control = createControl(noiseLevel = "silent", cvType = "auto", seed = 1, resetCoefficients = TRUE, tolerance = 2e-07, cvRepetitions = 10, startingVariance =0.01),
#   control = Cyclops::createControl(cvRepetitions = 1)
)
matchOnPsArgs <- CohortMethod::createMatchOnPsArgs(maxRatio = 100)
fitOutcomeModelArgs <- CohortMethod::createFitOutcomeModelArgs(modelType = "cox")

computeSharedCovBalArgs <- CohortMethod::createComputeCovariateBalanceArgs()
computeCovBalArgs <- CohortMethod::createComputeCovariateBalanceArgs(
  covariateFilter = FeatureExtraction::getDefaultTable1Specifications()
)

cmAnalysis1 <- CohortMethod::createCmAnalysis(
  analysisId = 1,
  description = "No matching, simple outcome model",
  getDbCohortMethodDataArgs = getDbCmDataArgs,
  createStudyPopArgs = createStudyPopArgs,
  fitOutcomeModelArgs = fitOutcomeModelArgs
)

cmAnalysis2 <- CohortMethod::createCmAnalysis(
  analysisId = 2,
  description = "Matching on ps and covariates, simple outcomeModel",
  getDbCohortMethodDataArgs = getDbCmDataArgs,
  createStudyPopArgs = createStudyPopArgs,
  createPsArgs = createPsArgs,
  matchOnPsArgs = matchOnPsArgs,
  computeSharedCovariateBalanceArgs = computeSharedCovBalArgs,
  computeCovariateBalanceArgs = computeCovBalArgs,
  fitOutcomeModelArgs = fitOutcomeModelArgs
)

cmAnalysis3 <- CohortMethod::createCmAnalysis(
  analysisId = 3,
  description = "No matching, simple outcome model",
  getDbCohortMethodDataArgs = getDbCmDataArgs,
  createStudyPopArgs = createStudyPopArgs,
  fitOutcomeModelArgs = fitOutcomeModelArgs
)

cmAnalysis4 <- CohortMethod::createCmAnalysis(
  analysisId = 4,
  description = "Matching on ps and covariates, simple outcomeModel",
  getDbCohortMethodDataArgs = getDbCmDataArgs,
  createStudyPopArgs = createStudyPopArgs,
  createPsArgs = createPsArgs,
  matchOnPsArgs = matchOnPsArgs,
  computeSharedCovariateBalanceArgs = computeSharedCovBalArgs,
  computeCovariateBalanceArgs = computeCovBalArgs,
  fitOutcomeModelArgs = fitOutcomeModelArgs
)

cmAnalysisList <- list(cmAnalysis2)
# cmAnalysisList <- list(cmAnalysis1, cmAnalysis2)

analysesToExclude <- NULL


cohortMethodModuleSpecifications <- cmModule$createModuleSpecifications(
  cmAnalysisList = cmAnalysisList,
  targetComparatorOutcomesList = targetComparatorOutcomesList,
  analysesToExclude = analysesToExclude
)

analysisSpecifications <- createEmptyAnalysisSpecificiations() %>%
  addSharedResources(cohortDefinitionSharedResource) %>%
  addSharedResources(ncoSharedResource) %>%
  addModuleSpecifications(cohortGeneratorModuleSpecifications) %>%
  addModuleSpecifications(cohortMethodModuleSpecifications)


ParallelLogger::saveSettingsToJson(
  analysisSpecifications,
  file.path("./", analysisName)
)
# print("Analysis specifications saved successfully.")
cat("Analysis specification created and saved to", analysisName, "\n")