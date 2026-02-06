# script to store Eunomia data in the specified schema in the target database
library(DatabaseConnector)
library(Eunomia)

# database connection and execution settings
dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
server <- "127.0.0.1/eunomia_dataset"  # for PostgreSQL, can be "localhost/DBNAME"
user   <- "amit.sharma"
pw     <- "Tango==1262"
port   <- 5432              # local forwarded port from your SSH tunnel
pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"

# Create connection details
# connectionDetails <- createConnectionDetails(
#   dbms = dbms,
#   server = server,
#   user = user,
#   password = pw,
#   port = port,
#   pathToDriver = pathToDriver
# )

Eunomia::extractLoadData(
  from = "/Users/amit.sharma/Downloads/GiBleed_5.3.zip",
  to = "/Users/amit.sharma/Downloads/GiBleed_5.3.sqlite",
)