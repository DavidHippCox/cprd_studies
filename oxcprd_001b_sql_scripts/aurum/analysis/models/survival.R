# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# Source this file first, then:
# config <- model_config()
# results <- model_main(config = config)
# Rscript oxcprd_001b_sql_scripts/aurum/analysis/models/survival.R [NEW_OUTPUT_DIRECTORY]

# Load survival methods
library(survival)

# Locate analysis directory
script <- if (sys.nframe() > 0L) {
  sys.frame(1)$ofile
} else {
  sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
}

analysis_dir <- dirname(dirname(normalizePath(script)))

# Load helpers
source(file.path(analysis_dir, "database.R"))
source(file.path(analysis_dir, "output.R"))

helpers <- c(
  "model_config.R",
  "prepare_model_data.R",
  "survival_curves.R",
  "adjusted_curves.R",
  "ph_plots.R",
  "fit_models.R"
)

for (helper in helpers) {
  source(file.path(analysis_dir, "models", helper))
}

# Run only when executed via Rscript
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  model_main(if (length(args)) args[1] else NULL)
}
