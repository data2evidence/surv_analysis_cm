# fetch_table_names.R
# Install DatabaseConnector if needed:
# install.packages("remotes")
# remotes::install_github("ohdsi/DatabaseConnector")

library(DatabaseConnector)

# ---- CONFIGURE ----
# dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
# server <- "127.0.0.1/alpdev_pg"  # for PostgreSQL, can be "localhost/DBNAME"
# user   <- "postgres"
# pw     <- "Toor1234"
# port   <- 41192              # local forwarded port from your SSH tunnel
# pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"

dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "study_results_pg_admin_user"
# pw     <- "Toor1234"
pw     <- "dpQo1Cq0eIXXemiHCglrcOyXHoOoiS"
port   <- 41192              # local forwarded port from your SSH tunnel
pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"


# Create connection details
connectionDetails <- createConnectionDetails(
  dbms = dbms,
  server = server,
  user = user,
  password = pw,
  port = port,
  pathToDriver = pathToDriver
)

results_schema_name <- "results_survival_analysis_specification_cancer_amit_2"
conn <- connect(connectionDetails)
sql <- paste0("CREATE SCHEMA IF NOT EXISTS ", results_schema_name, ";")
executeSql(conn, sql)
disconnect(conn)


# ---- CONNECT ----
conn <- connect(connectionDetails)
on.exit({
  # ensure disconnect even if script errors
  tryCatch(disconnect(conn), error = function(e) NULL)
})

# ---- RUN A SIMPLE QUERY: list table names (exclude system schemas) ----
sql <- '
SELECT COUNT(*) AS count
FROM "cdm_5pct_9a0f90a32250497d9483c981ef1e1e70".person;
'

tables_df <- querySql(conn, sql)

# Print results
print(tables_df)

# ---- CLOSE ----
disconnect(conn)
message('Done.')