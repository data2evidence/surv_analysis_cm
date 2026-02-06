library(jsonlite)
library(DatabaseConnector)

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

connection <- connect(connectionDetails)

# Prepare values
study_id <- 123
cohort_id <- 456
json_str <- '{
  "Characteristic": ["Age group", "   30 -  34", "   35 -  39", "   40 -  44", "   45 -  49", "Gender: female", "Medical history: General", "  Osteoarthritis", "  Rheumatoid arthritis", "  Ulcerative colitis", "Medical history: Cardiovascular disease", "  Coronary arteriosclerosis", "", "Characteristic", "Charlson comorbidity index", "    Mean", "    Std. deviation", "    Minimum", "    25th percentile", "    Median", "    75th percentile", "    Maximum", "CHADS2Vasc", "    Mean", "    Std. deviation", "    Minimum", "    25th percentile", "    Median", "    75th percentile", "    Maximum"],
  "Count": ["", "  206", "  862", "  660", "   72", "  906", "", "1,800", "    1", "   56", "", "    3", "", "", "", "  ", "  ", "  ", "  ", "  ", "  ", "  ", "", "  ", "  ", "  ", "  ", "  ", "  ", "  "],
  "% (n = 1,800)": ["", " 11.4", " 47.9", " 36.7", "  4.0", " 50.3", "", "100.0", "  0.1", "  3.1", "", "  0.2", "", "Value", "", "0.6", "0.4", "0.0", "0.0", "1.0", "1.0", "2.0", "", "0.5", "0.5", "0.0", "0.0", "1.0", "1.0", "1.0"],
  "attr_class": ["tbl_df", "tbl", "data.frame"],
  "attr_row.names": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
}'


print(typeof(json_str))
schema_name <- "res_surv_analysis_spec_gi_bleed_santan_amit"

for (i in 1:5) {
    study_id <- i
    cohort_id <- i * 10
    dataset_id <- i * 20
    tb_content <- json_str
   
    sql <- "INSERT INTO res_surv_analysis_spec_gi_bleed_santan_amit.tb1_results 
    (study_id, cohort_id, dataset_id, table1_json) VALUES 
    (@study_id, @cohort_id, @dataset_id, @table1_json);"

    DatabaseConnector::renderTranslateExecuteSql(
        connection = connection,
        sql = sql,
        study_id = study_id,
        cohort_id = cohort_id,
        dataset_id = dataset_id,
        table1_json = tb_content
    )
}