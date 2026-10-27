# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# MariaDB input. Set connection details in the working environment.
# Passwords come directly from the encrypted file keyring, never the environment.
database_settings <- function() {
  port <- suppressWarnings(as.numeric(Sys.getenv("OXCPRD_DB_PORT", "3306")))
  list(
    host = Sys.getenv("OXCPRD_DB_HOST", "127.0.0.1"),
    port = as.integer(port),
    dbname = Sys.getenv("OXCPRD_DB_NAME", "aurum_oxcprd_001b"),
    username = Sys.getenv("OXCPRD_DB_USER"),
    view = Sys.getenv("OXCPRD_DB_VIEW", "analysis_model")
  )
}

# Match the existing kb$set(service=..., keyring=...) entry: no username.
database_password <- function(
  backend = keyring::backend_file$new(keyring = "oxcprd_secrets")
) {
  ring <- "oxcprd_secrets"
  # Lock on both retrieval success and error, before authentication proceeds.
  on.exit(backend$keyring_lock(keyring = ring), add = TRUE)
  backend$get(service = "OXCPRD_DB_PASSWORD", keyring = ring)
}

connect_database <- function(settings = database_settings()) {
  if (!nzchar(settings$username)) {
    stop("Set OXCPRD_DB_USER to an account with SELECT access to the model view.")
  }
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = settings$host, port = settings$port,
    dbname = settings$dbname, username = settings$username,
    password = database_password(),
    bigint = "character", reconnect = FALSE
  )
}

# Reused by models and descriptives; select only requested, quoted columns.
read_analysis_database <- function(columns, settings = database_settings()) {
  connection <- connect_database(settings)
  on.exit(DBI::dbDisconnect(connection), add = TRUE)
  quoted_columns <- DBI::dbQuoteIdentifier(connection, unique(columns))
  quoted_view <- DBI::dbQuoteIdentifier(connection, settings$view)
  query <- paste0(
    "SELECT ", paste(quoted_columns, collapse = ", "),
    "\nFROM ", quoted_view
  )
  data <- DBI::dbGetQuery(connection, query)
  if (!nrow(data)) stop("The analysis view returned no rows.")
  attr(data, "input_source") <- list(
    type = "database", database = settings$dbname, view = settings$view, query = query,
    fetched_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    rows = nrow(data)
  )
  message("Read ", nrow(data), " rows from ", settings$dbname, ".", settings$view, ".")
  data
}
