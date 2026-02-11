# contains code for utility functions used across the project

# get connection details for Eunomia GiBleed database
getEunomiaConnectionDetails <- function() {
    #################### Database connection details ####################
    dbms   <- "postgresql"        # dbms type (postgresql, sqlserver, oracle, ... )
    server <- "127.0.0.1/study_results"  # for PostgreSQL, can be "localhost/DBNAME"
    user   <- "amit.sharma"
    pw     <- "Tango==1262"
    port   <- 5432              # local forwarded port from your SSH tunnel
    pathToDriver <- "/Users/amit.sharma/Documents/Projects"  # e.g., "/path/to/your/jdbc/driver"

    #Create connection details
    connectionDetails <- createConnectionDetails(
        dbms = dbms,
        server = server,
        user = user,
        password = pw,
        port = port,
        pathToDriver = pathToDriver
    )
    return(connectionDetails)
}