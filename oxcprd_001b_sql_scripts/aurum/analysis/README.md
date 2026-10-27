# OXCPRD_001B Aurum analyses

The analysis code has two workflows: descriptive distributions and outcome
models. Shared database and output helpers live in this directory; statistical
definitions remain beside the relevant workflow.

## Setup

Install the packages listed in [models/README.md](models/README.md) or
[descriptives/README.md](descriptives/README.md). Models without plots need
`survival`; database reads additionally need `DBI`, `RMariaDB` and `keyring`.

Set database connection values in your local R environment:

```text
OXCPRD_DB_HOST=127.0.0.1
OXCPRD_DB_PORT=3306
OXCPRD_DB_NAME=aurum_oxcprd_001b
OXCPRD_DB_VIEW=analysis_model
OXCPRD_DB_USER=your_readonly_username
```

Keep private settings in a Git-ignored `.Renviron` or a protected user
environment file. Store the database password in the file keyring described in
[Database connection](models/README.md#database-connection).

## Run the analyses

```r
source("oxcprd_001b_sql_scripts/aurum/analysis/models/survival.R")
config <- model_config()
results <- model_main(config = config)

source("oxcprd_001b_sql_scripts/aurum/analysis/descriptives/distributions.R")
descriptive_config <- distribution_config()
distributions <- distribution_main(config = descriptive_config)
```

The entry scripts also support `Rscript`. Existing script names remain valid.
Default results locations remain `models/model_results/<timestamp>` and
`descriptives/distribution_results/<timestamp>`. Both are Git-ignored.

Set `config$output_dir` at runtime to choose another location. New runs reject
nonempty output directories. `allow_existing = TRUE` deliberately permits reuse
and can retain files from earlier selections; prefer a new directory for a new
analysis. Saved-plot exporters can overwrite plots in a completed run.

## Reuse data and saved fits

The model stages can be called separately:

```r
raw_data <- read_model_database(config)
prepared <- prepare_data(raw_data, config)
results <- run_models(prepared, config)
```

Both main functions accept raw input data without connecting to MariaDB:
`model_main(config = config, data = raw_data)` and
`distribution_main(config = descriptive_config, data = raw_data)`.
`run_distributions(data, config)` calculates and exports descriptives directly.

To fit a new selection using a saved prepared cohort:

```r
# run_dir identifies a completed local results directory.
saved_config <- read_run_config(run_dir)
saved_config$output_dir <- default_analysis_output_directory("models")
prepared <- readRDS(file.path(run_dir, "analysis_data.rds"))
results <- run_models(prepared, saved_config)
```


To regenerate model plots without querying the database or refitting:

```r
export_adjusted_curves(run_dir)
export_ph_plots(run_dir)
```

These exporters load `config_used.R` by default and use `model_jobs.csv` to
identify jobs belonging to that run. 

Both workflows save `config_used.R`, `input_source.R` when available,
`run_info.csv` and `sessionInfo.txt`. Model runs additionally save a job manifest
with relative model filenames, fit status and archive availability.
