# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# Edit this file for routine changes to the analysis.
model_config <- function(output_dir = default_analysis_output_directory("models")) {
  minimally <- c("age_c", "sex", "ethnicity", "imd", "smoking")
  healthcare_use <- c("consult_days", "gp_months", "index_year")
  moderately <- c(minimally, "tbi", healthcare_use)
  list(
    # A fresh results folder under the model directory.
    output_dir = output_dir,
    analysis_plan = "v2",
    comparisons = c("B1", "B2"), # Separate comparisons, with A as reference.
    outcomes = NULL, # NULL = all; or c("death", "psychosis", "care_home").
    include_sensitivity = TRUE, # Also fit the *_no_prior endpoints.
    adjustments = c("unadjusted", "age_adjusted", "minimally", "moderately", "fully"),
    complete_cases = "common", # Same sample across selected levels; or "per_model".
    age_centre = NULL, # NULL = cohort mean; or a fixed age, e.g. 75.
    fine_gray = FALSE, # Optional fully adjusted competing-risk analysis.

    # Save reusable model objects and the prepared cohort.
    save_fits = TRUE,
    save_input = TRUE,
    ph_plots = TRUE,
    ph_adjustments = "fully", # Which Cox adjustment levels get paired PDFs.
    curve_outcomes = "death", # Descriptive Kaplan-Meier curves for mortality only.
    curve_times_years = c(0, 1, 3, 5, 10),
    # NULL = all selected Cox outcomes; character() skips Cox curves.
    # Nonfatal curves use the fully adjusted fit and its complete-case cohort.
    # Mortality retains curves at each selected adjustment level.
    adjusted_curve_outcomes = NULL,
    adjusted_curve_points = 301L, # Plot grid; requested time points are also exact.
    curve_conf_level = 0.95, # Pointwise confidence level for all curve types.
    plot_settings = list(
      ph_alpha = 0.05, ph_residual_dpi = 150,
      ph_colours = c(ok = "#1565C0", flagged = "#C62828"),
      curve_colours = c("#24628A", "#BA4A35")
    ),

    # Covariates entered in each model, in addition to exposure.
    covariates = list(
      death = list(
        unadjusted = character(),
        age_adjusted = "age_c",
        minimally = minimally,
        moderately = moderately,
        fully = c(moderately, "bmi", "type2_diabetes", "ihd")
      ),
      neuropsychiatric = list(
        unadjusted = character(),
        age_adjusted = "age_c",
        minimally = minimally,
        moderately = moderately,
        fully = c(moderately, "smi", "dep_anx")
      ),
      medication = list(
        unadjusted = character(),
        age_adjusted = "age_c",
        minimally = minimally,
        fully = moderately
      ),
      care_home = list(
        unadjusted = character(),
        age_adjusted = "age_c",
        minimally = minimally,
        # Care-home models omit TBI and do not add a moderate tier.
        fully = c(minimally, healthcare_use)
      )
    ),
    prefixes = list(
      neuropsychiatric = c("psychosis", "delirium", "affective", "challenging"),
      medication = c(
        "antipsychotics", "antidepressants",
        "antipsychotics_antidepressants", "anxiety_and_hypnotics"
      ),
      care_home = "care_home"
    ),

    # SQL fields --> binary varaibles.
    baseline_dates = c(
      tbi = "confounder_tbi_eventdate", smi = "confounder_smi_eventdate",
      dep_anx = "confounder_dep_anx_eventdate",
      type2_diabetes = "type2_diabetes_eventdate", ihd = "ihd_eventdate"
    ),
    numeric_fields = c(
      bmi = "bmi_value",
      consult_days = "n_gp_consult_days_12m_pre_dementia",
      gp_months = "gp_registration_months"
    ),
    extra_columns = character(), # Other SQL fields for custom coding in prepare_data().
    covariate_labels = c(
      age_c = "Age at dementia index (centred, years)",
      sex = "Sex (female versus male)",
      ethnicity = "Ethnicity (overall categorical term)",
      imd = "Deprivation: IMD quintile (overall term)",
      smoking = "Smoking status (overall categorical term)",
      tbi = "Prior traumatic brain injury (yes versus no)",
      consult_days = "GP consultation days in preceding 12 months",
      gp_months = "GP registration duration (months)",
      index_year = "Dementia calendar year (overall term)",
      bmi = "Body mass index (kg/m^2)",
      type2_diabetes = "Baseline type 2 diabetes (yes versus no)",
      ihd = "Baseline ischaemic heart disease (yes versus no)",
      smi = "Baseline severe mental illness (yes versus no)",
      dep_anx = "Baseline depression/anxiety (yes versus no)"
    )
  )
}

adjustment_label <- function(adjustment) {
  labels <- c(
    unadjusted = "Unadjusted", age_adjusted = "Age adjusted",
    minimally = "Minimally adjusted",
    moderately = "Moderately adjusted", fully = "Fully adjusted"
  )
  if (adjustment %in% names(labels)) labels[[adjustment]] else gsub("_", " ", adjustment)
}

# Turn the outcome dictionaries into model jobs. Primary analyses keep prior
# events; *_no_prior sensitivity analyses exclude that outcome's history.
outcome_config <- function(config, selected = TRUE) {
  rows <- list()
  add <- function(id, family, prefixes, prior = FALSE) {
    rows[[length(rows) + 1L]] <<- list(
      id = id, family = family, prefixes = prefixes,
      exclude_prior = prior,
      method = if (family == "care_home") "logistic" else "cox"
    )
  }
  add("death", "death", character())
  for (family in c("neuropsychiatric", "medication")) {
    add(paste0(family, "_any"), family, config$prefixes[[family]])
    if (config$include_sensitivity) {
      add(paste0(family, "_any_no_prior"), family, config$prefixes[[family]], TRUE)
    }
    for (prefix in config$prefixes[[family]]) {
      add(prefix, family, prefix)
      if (config$include_sensitivity) add(paste0(prefix, "_no_prior"), family, prefix, TRUE)
    }
  }
  add("care_home", "care_home", config$prefixes$care_home)
  if (config$include_sensitivity) {
    add("care_home_no_prior", "care_home", config$prefixes$care_home, TRUE)
  }
  if (selected && !is.null(config$outcomes)) {
    rows <- Filter(function(x) x$id %in% config$outcomes, rows)
  }
  rows
}

# One ordered catalogue shared by fitting and saved-run exports.
model_jobs <- function(config) {
  empty <- data.frame(
    outcome = character(), comparison = character(),
    adjustment = character(), method = character(),
    stringsAsFactors = FALSE
  )
  rows <- list()
  for (outcome in outcome_config(config)) {
    levels <- names(config$covariates[[outcome$family]])
    levels <- levels[levels %in% config$adjustments]
    for (comparison in unique(config$comparisons)) {
      for (adjustment in levels) {
        methods <- outcome$method
        if (config$fine_gray && adjustment == "fully" &&
          outcome$method == "cox" && outcome$family != "death") {
          methods <- c(methods, "fine_gray")
        }
        rows[[length(rows) + 1L]] <- data.frame(
          outcome = outcome$id, comparison = comparison,
          adjustment = adjustment, method = methods,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows)) do.call(rbind, rows) else empty
}
# Share curve selection between new fits and saved-model exports.
adjusted_curve_ids <- function(config) {
  outcomes <- Filter(function(x) x$method == "cox", outcome_config(config))
  ids <- vapply(outcomes, function(x) x$id, character(1))
  if (is.null(config$adjusted_curve_outcomes)) {
    ids
  } else {
    intersect(ids, config$adjusted_curve_outcomes)
  }
}

cox_curve_adjustments <- function(outcome, config) {
  levels <- intersect(config$adjustments, names(config$covariates[[outcome$family]]))
  if (outcome$family == "death") levels else intersect(levels, "fully")
}

# Validate user choices once, before querying or fitting. Data-quality checks
# live in prepare_model_data.R; fitting errors are reported per model.
validate_model_config <- function(config, check_packages = TRUE) {
  catalogue <- outcome_config(config, selected = FALSE)
  ids <- vapply(catalogue, function(x) x$id, character(1))
  if (length(setdiff(config$outcomes, ids))) stop("Unknown outcome in config$outcomes.")
  selected <- outcome_config(config)
  if (!length(selected)) stop("Select at least one outcome.")
  if (!length(config$comparisons) || any(!config$comparisons %in% c("B1", "B2"))) {
    stop("comparisons must contain B1 and/or B2.")
  }
  if (!config$complete_cases %in% c("common", "per_model")) {
    stop("complete_cases must be common or per_model.")
  }
  for (family in unique(vapply(selected, function(x) x$family, character(1)))) {
    if (!any(names(config$covariates[[family]]) %in% config$adjustments)) {
      stop("No selected adjustment level for ", family, ".")
    }
  }
  known_levels <- unique(unlist(lapply(config$covariates, names)))
  if (any(!c(config$adjustments, config$ph_adjustments) %in% known_levels)) {
    stop("Unknown adjustment level in configuration.")
  }
  curve_ids <- ids[vapply(catalogue, function(x) x$method == "cox", logical(1))]
  if (length(setdiff(config$adjusted_curve_outcomes, curve_ids))) {
    stop("Unknown survival curve outcome.")
  }
  if (length(setdiff(config$curve_outcomes, "death"))) {
    stop("Descriptive curves support death only. Use adjusted_curve_outcomes for nonfatal survival curves.")
  }
  if (length(config$adjusted_curve_points) != 1L ||
    !is.finite(config$adjusted_curve_points) || config$adjusted_curve_points < 2 ||
    config$adjusted_curve_points != as.integer(config$adjusted_curve_points)) {
    stop("adjusted_curve_points must be an integer of at least 2.")
  }
  if (any(!is.finite(config$curve_times_years) | config$curve_times_years < 0)) {
    stop("Curve times must be finite, nonnegative years.")
  }
  if (!is.null(config$age_centre) &&
    (length(config$age_centre) != 1L || !is.finite(config$age_centre))) {
    stop("age_centre must be NULL or one finite age.")
  }
  if (length(config$curve_conf_level) != 1L || !is.finite(config$curve_conf_level) ||
    config$curve_conf_level <= 0 || config$curve_conf_level >= 1) {
    stop("curve_conf_level must be between 0 and 1.")
  }
  plots <- config$plot_settings
  if (!is.finite(plots$ph_alpha) || plots$ph_alpha <= 0 || plots$ph_alpha >= 1 ||
    plots$ph_residual_dpi <= 0) {
    stop("Use PH alpha between 0 and 1 and positive plot resolutions.")
  }
  # Fail before database extraction when a selected plotting package is missing.
  if (isTRUE(check_packages)) {
    packages <- character()
    if (length(config$curve_outcomes)) packages <- c(packages, "ggsurvfit")
    if (length(adjusted_curve_ids(config))) {
      packages <- c(packages, "survminer", "ggplot2", "cowplot")
    }
    if (isTRUE(config$ph_plots)) packages <- c(packages, "ggplot2", "ggrastr", "cowplot")
    require_model_packages(packages)
  }
  invisible(config)
}

# Saved-run exports check only the packages used by that export.
require_model_packages <- function(packages) {
  packages <- unique(packages)
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop(
      "Install the plotting packages first: install.packages(c(",
      paste(sprintf('"%s"', missing), collapse = ", "), "))"
    )
  }
  invisible(NULL)
}
