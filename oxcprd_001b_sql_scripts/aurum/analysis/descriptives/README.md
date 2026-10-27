# CPRD Aurum descriptive analyses
### Analysis plan version: v2

Histograms and summary statistics for age at dementia index, body mass
index, GP registration duration and consultation days in the year before
dementia, using `aurum_oxcprd_001b.analysis_model`.

## Setup

Install the required R packages:

```r
install.packages(c("DBI", "RMariaDB", "keyring"))
```

Use the [shared setup guide](../README.md#setup)
for the analysis view and password keyring.

## Running the analysis

These examples use repository-relative paths. Helpers resolve relative to the entry script:

```r
source("oxcprd_001b_sql_scripts/aurum/analysis/descriptives/distributions.R")
config <- distribution_config()
result <- distribution_main(config = config)
```

Results are saved in a timestamped directory under
`descriptives/distribution_results`. Set `config$output_dir` to choose
another location.

## Variables and groups

| Variable | Database field | Histogram bin width |
|---|---|---|
| Age at dementia index | `age_at_dementia_index` | 2 years |
| Body mass index | `bmi_value` | 2 kg/m^2 |
| GP registration duration | `gp_registration_months` | 12 months |
| Consultation days in the pre-index year | `n_gp_consult_days_12m_pre_dementia` | 1 day |

Plots are produced for the whole cohort (A+B1), A, B1 and B2. B2 is a
subset of B1. Histograms use density scaling, with common bins and axes
across groups. Age, BMI and consultation days include density overlays.
Each variable uses its available finite observations; summaries report
missing and nonfinite values separately.

Settings are defined in `distribution_config()`. For example:

```r
config$groups <- c("A", "B1", "B2")
config$variables$age$binwidth <- 5
config$variables$bmi$density <- FALSE
config$density_adjust <- 1.5
```

Select variables by editing `config$variables`, where each entry specifies
the database field, labels, bin width and density settings.

## Outputs

| File | Contents |
|---|---|
| `distributions.pdf` | Four plots per page, one page per group |
| `distribution_summary.csv` | Counts, missingness, mean, SD, quartiles and range |
| `distributions.rds` | Calculated histograms, densities, summaries and settings |
| `config_used.R` | Analysis settings |

To redraw saved plots:

```r
cached <- readRDS(file.path(config$output_dir, "distributions.rds"))
plot_distribution_page(cached, "All")
save_distribution_plots(cached, file.path(config$output_dir, "replotted"))
```

Changes to bin width or density bandwidth require a new analysis run.

## Shared workflow

See [the analysis guide](../README.md) for shared setup, portable paths and run
metadata. Helpers resolve relative to this script rather than the working
directory.

To analyse data already in R without a database connection, use
`distribution_main(config = config, data = data)` or
`run_distributions(data, config)`. New runs reject nonempty results directories;
`allow_existing = TRUE` deliberately permits reuse. Standalone
`save_distribution_plots()` remains available for replotting saved results.

Each run also saves `input_source.R` when available, `run_info.csv` and
`sessionInfo.txt`, alongside the existing distribution outputs.
