library(FeatureExtraction)
library(tibble)

# get connection details for Eunomia GiBleed database from utils
source("../utils/utils.R")
connectionDetails <- getEunomiaConnectionDetails()

default_table_specs <- getDefaultTable1Specifications()
print(default_table_specs)

# custom table specs
table_specs <- tibble(
    label = c(
        "Age",
        "Gender: female",
        "Gender: male",
        "Race",
        "Ethnicity"
    ),
    analysisId = c(
        3, 1, 4, 5
    ),
    covariateIds = c(
        NA,
        "8532001",
        NA,
        NA
    )
)
print(table_specs)