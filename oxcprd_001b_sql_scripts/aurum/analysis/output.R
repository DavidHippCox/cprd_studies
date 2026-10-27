# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# Shared results-directory rules for models and descriptives.

# Capture this file's directory when sourced, without a machine-specific path.
default_analysis_output_directory <- local({
  files <- Filter(Negate(is.null), lapply(sys.frames(), function(x) x$ofile))
  if (!length(files)) stop("Source output.R before creating analysis settings.")
  script <- tail(files, 1L)[[1L]]
  if (!file.exists(script)) script <- basename(script)
  analysis_dir <- dirname(normalizePath(script, mustWork = TRUE))
  function(analysis = c("models", "descriptives"), output_root = NULL) {
    analysis <- match.arg(analysis)
    if (is.null(output_root)) {
      folder <- if (analysis == "models") "model_results" else "distribution_results"
      output_root <- file.path(analysis_dir, analysis, folder)
    }
    file.path(output_root, format(Sys.time(), "%Y%m%d_%H%M%S"))
  }
})

check_output_directory <- function(output_dir, allow_existing = FALSE) {
  if (!is.character(output_dir) || length(output_dir) != 1L ||
    is.na(output_dir) || !nzchar(output_dir)) {
    stop("Supply one output directory.")
  }
  if (file.exists(output_dir) && !dir.exists(output_dir)) {
    stop("The output path is an existing file.")
  }
  if (!isTRUE(allow_existing) && dir.exists(output_dir) &&
    length(list.files(output_dir, all.files = TRUE, no.. = TRUE))) {
    stop(
      "The results directory is not empty. Choose a new directory, ",
      "or set allow_existing = TRUE to deliberately reuse it."
    )
  }
  invisible(NULL)
}

# Create only missing folders, without revisiting existing network ancestors.
ensure_output_directory <- function(path) {
  if (dir.exists(path)) {
    return(invisible(path))
  }
  parent <- dirname(path)
  if (identical(parent, path) || file.exists(path)) {
    stop("Cannot create results directory: ", path)
  }
  ensure_output_directory(parent)
  dir.create(path, recursive = FALSE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Cannot create results directory: ", path)
  invisible(path)
}

write_run_metadata <- function(output_dir, config, input_source = NULL,
                               run_info = NULL) {
  ensure_output_directory(output_dir)
  dput(config, file = file.path(output_dir, "config_used.R"))
  if (!is.null(input_source)) {
    dput(input_source, file = file.path(output_dir, "input_source.R"))
  }
  writeLines(
    capture.output(utils::sessionInfo()),
    file.path(output_dir, "sessionInfo.txt")
  )
  if (!is.null(run_info)) {
    utils::write.csv(
      as.data.frame(run_info), file.path(output_dir, "run_info.csv"),
      row.names = FALSE
    )
  }
  invisible(output_dir)
}

read_run_config <- function(run_dir) {
  path <- file.path(run_dir, "config_used.R")
  if (!file.exists(path)) {
    stop("Saved config_used.R not found. Supply config explicitly for this run.")
  }
  config <- dget(path)
  if (!is.list(config)) stop("The saved run configuration must be a list.")
  config$output_dir <- run_dir
  config
}

# Keep the primary outcome and its sensitivity analyses in the same folder.
outcome_folder <- function(outcome) {
  sub("_no_prior$", "", outcome)
}

outcome_directory <- function(run_dir, outcome, subdirectory = NULL) {
  path <- file.path(run_dir, outcome_folder(outcome))
  if (!is.null(subdirectory)) path <- file.path(path, subdirectory)
  ensure_output_directory(path)
  path
}

model_key <- function(outcome, comparison, adjustment, method) {
  paste(outcome, sub("_vs_A$", "", comparison), adjustment, method, sep = "__")
}

# Model archives and Cox curves use the same adjustment ID.
cox_curve_key <- function(outcome, comparison, adjustment) {
  model_key(outcome, comparison, adjustment, "cox")
}
