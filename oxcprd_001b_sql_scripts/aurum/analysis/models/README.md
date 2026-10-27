# CPRD Aurum outcome analyses
### Analysis plan version: v2

R scripts for analysing mortality, neuropsychiatric outcomes, medication
use and care-home records in the OXCPRD_001b dementia cohort, following
analysis plan v2.

## Requirements

The scripts use the MariaDB view `aurum_oxcprd_001b.analysis_model`, produced
by the [cohort preparation scripts](../../README.md).

Install the required R packages:

```r
install.packages(c(
  "DBI", "RMariaDB", "keyring", "survival",
  "ggsurvfit", "survminer", "ggplot2", "ggrastr", "cowplot"
))
```

## Database connection

Set the connection details in `.Renviron`, using the
[example settings](../README.md#setup). The database account needs
`SELECT` access to the analysis view. Restart R after changing the settings.

Store the database password in a [file keyring](https://keyring.r-lib.org/reference/backend_file.html).
For the initial setup:

```r
kb <- keyring::backend_file$new()
kb$keyring_create("oxcprd_secrets")
kb$set(service = "OXCPRD_DB_PASSWORD", keyring = "oxcprd_secrets")
```

The prompts request a keyring master password and the database password.
Analysis runs use the keyring master password to unlock the stored entry.

## Running the analysis

These examples use repository-relative paths. Helpers resolve relative to the entry script:

```r
source("oxcprd_001b_sql_scripts/aurum/analysis/models/survival.R")
config <- model_config()
results <- model_main(config = config)
```

Results are saved in a timestamped directory under `models/model_results`.
To choose a results directory, set `config$output_dir` before running.

## Analyses

Models compare B1 with A and B2 with A separately, with A as the reference.
B2 is a subset of B1.

| Outcome | Model | Effect estimate |
|---|---|---|
| All-cause mortality | Cox proportional hazards | Hazard ratio |
| Neuropsychiatric outcomes | Cause-specific Cox | Hazard ratio |
| Medication use | Cause-specific Cox | Hazard ratio |
| Care-home record during follow-up | Logistic regression | Odds ratio |

Neuropsychiatric outcomes include psychosis, delirium, affective symptoms
and challenging behaviour. Medication outcomes include antipsychotics,
antidepressants, their combined category, and anxiolytics/hypnotics.
Each family also has an `*_any` composite outcome.

Follow-up starts at the dementia index date and ends at the first outcome
or the follow-up limit in `earliest_4`.

Nonfatal Cox analyses censor at death. An outcome recorded on the death
date counts as an outcome. Composite outcomes use the earliest date across
their component fields. Primary analyses retain patients with prior records,
including records on the index date; `_no_prior` sensitivity analyses exclude
prior history of the relevant outcome. Index-day deaths remain valid in
mortality models; zero-time censoring is excluded from Cox samples.

Adjustment levels are unadjusted, age adjusted, minimally adjusted,
moderately adjusted and fully adjusted, where defined for each outcome
family. The covariates are listed in [model_config.R](model_config.R).
Age is centred at the cohort mean; IMD quintile and dementia calendar year
are categorical. By default, adjustment levels use a common complete-case
sample within each outcome and comparison. Cox and logistic models use
model-based standard errors.

## Configuration

Edit `model_config.R` or change the settings before calling `model_main()`:

```r
config <- model_config()
config$outcomes <- c("death", "psychosis", "care_home")
config$comparisons <- "B1"
config$adjustments <- c("minimally", "fully")
config$include_sensitivity <- FALSE
```

| Setting | Default |
|---|---|
| `outcomes` | `NULL`: all outcomes, including configured sensitivities |
| `comparisons` | `c("B1", "B2")` |
| `adjustments` | All available adjustment levels |
| `complete_cases` | `"common"`; use `"per_model"` for separate samples |
| `include_sensitivity` | `TRUE`: include `_no_prior` analyses |
| `curve_outcomes` | `"death"`: mortality Kaplan-Meier curves |
| `adjusted_curve_outcomes` | `NULL`: all selected Cox outcomes |
| `curve_times_years` | `c(0, 1, 3, 5, 10)` |
| `curve_conf_level` | `0.95` |
| `ph_adjustments` | `"fully"` |

Set a curve selection to `character()` to omit those plots. Optional
fully adjusted Fine-Gray sensitivity models can be enabled with
`config$fine_gray <- TRUE`.

## Survival curves and diagnostics

Mortality plots include unadjusted Kaplan-Meier curves and standardised
Cox curves at each selected adjustment level. Nonfatal outcomes use
fully adjusted Cox curves from the corresponding model cohort; include
`"fully"` in `config$adjustments` to produce these plots.

Standardised curves average individual survival predictions over the same
model cohort with exposure set to each comparison group. Nonfatal curves
show net event-free survival with deaths censored. Curves include 95%
pointwise confidence intervals and observed numbers at risk.

Proportional hazards are assessed using `cox.zph()`. Fully adjusted Cox
models have paired PDFs showing Schoenfeld smooths and scaled residuals.
Review these alongside the model diagnostics and missingness tables.

## Outputs

Each outcome has a results directory containing its fitted models and
plots. Sensitivity analyses share the corresponding primary outcome's
directory. Filenames identify the outcome, comparison, adjustment and
method, for example `psychosis__B1__fully__cox.rds`.

| Output | Contents |
|---|---|
| `estimates.csv` | Effect estimates, standard errors, 95% confidence intervals and p-values |
| `diagnostics.csv` | Sample sizes, events, model information and fitting or export errors |
| `missingness.csv` | Missing covariate counts |
| `model_jobs.csv` | Model catalogue, relative archive paths, status and availability |
| `ph_tests.csv` | Term-level and global proportional hazards tests |
| `OUTCOME/*_ph.pdf`, `OUTCOME/*_ph_residuals.pdf` | Proportional hazards plots |
| `OUTCOME/*.rds` | Fitted models, coefficients, patient IDs and metadata |
| `death/curves/` | Kaplan-Meier PDFs, RDS objects and CSV summaries |
| `OUTCOME/adjusted_curves/` | Cox survival PDFs, RDS objects and CSV summaries |
| `analysis_data.rds` | Prepared analysis cohort |
| `config_used.R`, `input_source.R`, `run_info.csv`, `sessionInfo.txt` | Run settings, data source and software versions |

## Using saved results

Set `run_dir` to a completed results directory:

```r
run_dir <- config$output_dir
saved <- readRDS(file.path(run_dir, "death", "death__B1__fully__cox.rds"))
saved$coefficients
saved$metadata

export_adjusted_curves(run_dir)
export_ph_plots(run_dir)
```

`export_adjusted_curves()` regenerates curves from the saved models and
writes an `adjusted_curve_diagnostics.csv` report. Individual curve RDS
files can be displayed with `plot_saved_curve()`.

## Scripts

| Script | Purpose |
|---|---|
| `survival.R` | Run the analysis |
| `model_config.R` | Outcomes, covariates and analysis settings |
| `prepare_model_data.R` | Covariates, endpoints and comparison samples |
| `fit_models.R` | Model fitting and results tables |
| `survival_curves.R` | Mortality Kaplan-Meier curves and shared plot exports |
| `adjusted_curves.R` | Standardised Cox survival curves |
| `ph_plots.R` | Proportional hazards plots |

## Reusing data and regenerating plots

See [the shared workflow guide](../README.md#reuse-data-and-saved-fits) for
`model_main(data = ...)`, `run_models(prepared_data, config)` and independent
plot exports. Reuse prepared cohorts only when their transformations remain
appropriate.

`export_adjusted_curves(run_dir)` and `export_ph_plots(run_dir)` load the
run's saved configuration by default. Their `config` argument accepts explicit
overrides. A saved `model_jobs.csv` limits exports to that run's model catalogue;
older runs fall back to saved settings.

New analysis runs reject nonempty output directories. Set
`allow_existing = TRUE` only for deliberate reuse, which can retain stale files.
Saved-plot exporters can overwrite plots without refitting.
