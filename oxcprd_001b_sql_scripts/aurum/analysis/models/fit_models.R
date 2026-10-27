# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# Model fitting, diagnostics and saved results. Model choices live in model_config.R.
model_progress <- function(...) {
  message("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", ...)
  invisible(NULL)
}

model_formula <- function(covariates, response) {
  stats::reformulate(c("exposure", covariates),
    response = response, env = asNamespace("survival")
  )
}

fit_model <- function(data, covariates, method) {
  if (nlevels(droplevels(data$exposure)) != 2L) {
    stop("Both exposure groups must be present.")
  }
  if (!sum(data$event)) stop("No outcome events in this sample.")

  if (method == "logistic") {
    if (all(data$event == 1)) stop("No outcome-negative patients.")
    fit <- stats::glm(
      model_formula(covariates, "event"),
      data = data,
      family = stats::binomial(), na.action = stats::na.fail,
      singular.ok = FALSE
    )
    if (!fit$converged || fit$boundary) stop("Unstable logistic fit.")
  } else if (method == "fine_gray") {
    # The first status level is censoring; death is a competing event.
    # Estimate censoring weights by exposure; retain patient IDs to group expanded rows.
    expanded <- survival::finegray(
      model_formula(
        c(covariates, "patid", "strata(exposure)"),
        "Surv(time, status)"
      ),
      data = data, etype = "outcome", na.action = stats::na.fail
    )
    fit <- survival::coxph(
      model_formula(covariates, "Surv(fgstart, fgstop, fgstatus)"),
      data = expanded, weights = fgwt, cluster = patid,
      ties = "efron", model = TRUE,
      na.action = stats::na.fail, singular.ok = FALSE
    )
  } else {
    fit <- survival::coxph(
      model_formula(covariates, "Surv(time, event)"),
      data = data, ties = "efron",
      x = TRUE, model = TRUE, na.action = stats::na.fail, singular.ok = FALSE
    )
  }

  # Ordinary model-based inference; Fine-Gray groups its expanded rows by patient.
  covariance <- stats::vcov(fit)
  beta <- stats::coef(fit)
  se <- sqrt(diag(covariance))
  if (any(!is.finite(beta)) || any(!is.finite(se) | se <= 0)) {
    stop("Non-estimable coefficients or standard errors.")
  }
  critical <- stats::qnorm(0.975)
  list(
    fit = fit, covariance = covariance,
    coefficients = data.frame(
      term = names(beta),
      measure = switch(method,
        cox = "HR",
        logistic = "OR",
        fine_gray = "sHR"
      ),
      log_estimate = unname(beta), std_error = unname(se),
      estimate = exp(beta),
      conf_low = exp(beta - critical * se),
      conf_high = exp(beta + critical * se),
      p_value = 2 * stats::pnorm(-abs(beta / se)), row.names = NULL
    )
  )
}

write_model_tables <- function(estimates, diagnostics, ph_tests,
                               missingness, output_dir) {
  tables <- lapply(
    list(
      estimates = estimates, diagnostics = diagnostics,
      ph_tests = ph_tests, missingness = missingness
    ),
    function(rows) do.call(rbind, rows)
  )
  for (name in names(tables)) {
    utils::write.csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")),
      row.names = FALSE, na = ""
    )
  }
  tables
}

# Drop incomplete records once, then use ordinary treatment contrasts with A
# and the first configured covariate level as the reference categories.
complete_case_sample <- function(candidates, variables) {
  complete <- stats::complete.cases(candidates[c("exposure", variables)])
  data <- candidates[complete, , drop = FALSE]
  for (name in c("exposure", variables)) {
    if (is.factor(data[[name]])) {
      data[[name]] <- droplevels(data[[name]])
      if (nlevels(data[[name]]) > 1L) {
        contrasts(data[[name]]) <- stats::contr.treatment(levels(data[[name]]))
      }
    }
  }
  list(data = data, n_excluded = sum(!complete))
}

# How the analysis sample was formed and which model was fit.
model_report <- function(cohort, sample, n_missing, outcome, comparison,
                         adjustment, method, covariates) {
  response <- switch(method,
    logistic = "event",
    fine_gray = "Surv(time, status)",
    cox = "Surv(time, event)"
  )
  data.frame(
    outcome = outcome$id, comparison = paste0(comparison, "_vs_A"),
    adjustment = adjustment, adjustment_label = adjustment_label(adjustment), method = method,
    n_comparison = nrow(cohort$data),
    n_excluded_history = sum(!cohort$data$eligible),
    n_excluded_zero_time = sum(cohort$data$eligible & !cohort$include),
    n_excluded_missing = n_missing,
    n = nrow(sample), n_A = sum(sample$exposure == "A"),
    n_exposed = sum(sample$exposure == comparison),
    events = sum(sample$event),
    events_A = sum(sample$event[sample$exposure == "A"]),
    events_exposed = sum(sample$event[sample$exposure == comparison]),
    competing_deaths = if (outcome$family == "death" || method == "logistic") {
      NA_integer_
    } else {
      sum(sample$status == "death")
    },
    n_with_prior = sum(sample$prior),
    variance_method = if (method == "fine_gray") {
      "Patient-level robust"
    } else {
      "Model-based (independent patients)"
    },
    formula = paste(deparse(model_formula(covariates, response)), collapse = " "),
    log_likelihood = NA_real_, model_df = NA_integer_, AIC = NA_real_,
    fit_file = "", adjusted_curve_file = "",
    status = "ok", notes = "", stringsAsFactors = FALSE
  )
}


fit_and_save_model <- function(sample, covariates, report, output_dir, config,
                               age_centre) {
  started <- proc.time()[["elapsed"]]
  label <- paste(report$outcome, report$comparison, report$adjustment,
    report$method,
    sep = " / "
  )
  meta <- report[c(
    "outcome", "comparison", "adjustment", "adjustment_label", "method",
    "variance_method"
  )]
  key <- model_key(report$outcome, report$comparison, report$adjustment, report$method)
  outcome_dir <- outcome_directory(output_dir, report$outcome)
  notes <- character()
  model_progress("Fitting model: ", label, " (n = ", nrow(sample), ").")
  fitted <- tryCatch(
    withCallingHandlers(
      fit_model(sample, covariates, report$method),
      warning = function(w) {
        notes <<- c(notes, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  unstable <- any(grepl("infinite|did not converge|numerically 0 or 1", notes,
    ignore.case = TRUE
  ))
  if (inherits(fitted, "error") || unstable) {
    report$status <- "failed"
    reason <- if (inherits(fitted, "error")) {
      conditionMessage(fitted)
    } else {
      "Unstable fit; estimates withheld."
    }
    report$notes <- paste(unique(c(notes, reason)), collapse = "; ")
    model_progress(
      "Model complete: ", label, " (status = failed; elapsed = ",
      round(proc.time()[["elapsed"]] - started, 1), " s). ", reason
    )
    return(list(estimates = NULL, diagnostics = report, ph_tests = NULL))
  }

  likelihood <- stats::logLik(fitted$fit)
  report$log_likelihood <- as.numeric(likelihood)
  report$model_df <- attr(likelihood, "df")
  report$AIC <- stats::AIC(fitted$fit)
  fitted$metadata <- report
  fitted$age_centre <- age_centre
  ph_tests <- NULL
  if (report$method == "cox") {
    model_progress("PH test: ", label, ".")
    test <- tryCatch(survival::cox.zph(fitted$fit, terms = TRUE), error = identity)
    if (inherits(test, "error")) {
      notes <- c(notes, paste("PH diagnostic:", conditionMessage(test)))
    } else {
      fitted$ph <- test
      ph_tests <- cbind(meta,
        term = rownames(test$table),
        as.data.frame(test$table), row.names = NULL
      )
      if (config$ph_plots && report$adjustment %in% config$ph_adjustments) {
        model_progress("PH plots: ", label, ".")
        plot_result <- tryCatch(
          save_ph_plots(test, file.path(outcome_dir, paste0(key, "_ph.pdf")),
            fit = fitted$fit, metadata = meta, config = config
          ),
          error = identity
        )
        if (inherits(plot_result, "error")) {
          notes <- c(notes, paste("PH plot:", conditionMessage(plot_result)))
        }
      }
    }
  }
  if (report$method == "cox" && report$outcome %in% adjusted_curve_ids(config) &&
    (report$outcome == "death" || report$adjustment == "fully")) {
    model_progress("Adjusted curves: ", label, ".")
    curve_result <- tryCatch(save_adjusted_curve(fitted, output_dir, config), error = identity)
    if (inherits(curve_result, "error")) {
      notes <- c(notes, paste("Adjusted curve:", conditionMessage(curve_result)))
    } else {
      report$adjusted_curve_file <- curve_result
    }
  }
  if (length(notes)) report$status <- "warning"
  report$notes <- paste(unique(notes), collapse = "; ")
  if (config$save_fits) {
    model_progress("Saving model: ", label, ".")
    report$fit_file <- file.path(outcome_folder(report$outcome), paste0(key, ".rds"))
    fitted$metadata <- report
    fitted$patient_ids <- sample$patid
    saveRDS(fitted, file.path(output_dir, report$fit_file))
  }
  model_progress(
    "Model complete: ", label, " (status = ", report$status,
    "; elapsed = ", round(proc.time()[["elapsed"]] - started, 1), " s)."
  )
  list(
    estimates = cbind(meta, fitted$coefficients),
    diagnostics = report, ph_tests = ph_tests
  )
}


# Read and prepare raw data once; run_models() also accepts a saved prepared cohort.
# Keep output_dir and config first for existing callers.
model_main <- function(
  output_dir = config$output_dir,
  config = model_config(), data = NULL,
  settings = database_settings(), allow_existing = FALSE
) {
  validate_model_config(config)
  check_output_directory(output_dir, allow_existing = allow_existing)
  if (is.null(data)) {
    model_progress("Reading model data from database.")
    data <- read_model_database(config, settings)
  }
  model_progress("Preparing analysis data (", nrow(data), " input rows).")
  input_source <- attr(data, "input_source")
  data <- prepare_data(data, config)
  attr(data, "input_source") <- input_source
  run_models(data, config, output_dir, allow_existing = allow_existing)
}

# Fit from prepare_data() output or readRDS("analysis_data.rds").
# New fits require a fresh results directory unless reuse is explicitly requested.
run_models <- function(
  prepared_data, config, output_dir = config$output_dir, allow_existing = FALSE
) {
  started <- proc.time()[["elapsed"]]
  validate_model_config(config)
  check_output_directory(output_dir, allow_existing = allow_existing)
  config$output_dir <- output_dir
  data <- prepared_data
  age_centre <- attr(data, "age_centre")
  if (length(age_centre) != 1L || !is.finite(age_centre)) {
    stop("Supply prepared data from prepare_data() or a saved analysis_data.rds.")
  }
  outcomes <- outcome_config(config)
  jobs <- model_jobs(config)
  adjustments <- lapply(config$covariates, function(levels) {
    levels[names(levels) %in% config$adjustments]
  })
  # Check each covariate once, before writing a partial results folder.
  families <- unique(vapply(outcomes, function(x) x$family, character(1)))
  require_columns(
    data,
    unique(unlist(adjustments[families], use.names = FALSE))
  )
  validate_post_event_dates(data, model_input_spec(config)$prefixes)
  ensure_output_directory(output_dir)
  model_progress("Results folder: ", normalizePath(output_dir, mustWork = FALSE))
  write_run_metadata(
    output_dir, config,
    input_source = attr(data, "input_source"),
    run_info = data.frame(
      age_centre = age_centre, n_input = nrow(data),
      created = as.character(Sys.time())
    )
  )
  jobs$model_file <- vapply(seq_len(nrow(jobs)), function(i) {
    file.path(outcome_folder(jobs$outcome[i]), paste0(model_key(
      jobs$outcome[i], jobs$comparison[i], jobs$adjustment[i], jobs$method[i]
    ), ".rds"))
  }, character(1))
  jobs$status <- "pending"
  jobs$available <- FALSE
  save_jobs <- function() {
    jobs$available <- file.exists(file.path(output_dir, jobs$model_file))
    utils::write.csv(jobs, file.path(output_dir, "model_jobs.csv"),
      row.names = FALSE, na = ""
    )
  }
  save_jobs()
  if (config$save_input) {
    model_progress("Saving prepared cohort to analysis_data.rds.")
    saveRDS(data, file.path(output_dir, "analysis_data.rds"))
  }
  model_progress("Exporting descriptive survival curves.")
  curve_diagnostics <- export_survival_curves(data, output_dir, config)
  model_progress("Descriptive survival curve exports complete.")

  results <- missingness <- list()
  for (outcome in outcomes) {
    model_progress("Preparing outcome: ", outcome$id, ".")
    endpoint <- make_endpoint(data, outcome)
    family_models <- adjustments[[outcome$family]]
    all_covariates <- unique(unlist(family_models, use.names = FALSE))
    outcome_jobs <- which(jobs$outcome == outcome$id)
    for (comparison in unique(jobs$comparison[outcome_jobs])) {
      cohort <- comparison_data(endpoint, outcome, comparison)
      candidates <- cohort$candidates
      if (length(all_covariates)) {
        missingness[[length(missingness) + 1L]] <- data.frame(
          outcome = outcome$id, comparison = paste0(comparison, "_vs_A"),
          variable = all_covariates, n_candidates = nrow(candidates),
          n_missing = vapply(
            candidates[all_covariates],
            function(x) sum(is.na(x)), integer(1)
          )
        )
      }
      common_sample <- if (config$complete_cases == "common") {
        complete_case_sample(candidates, all_covariates)
      }
      comparison_jobs <- outcome_jobs[jobs$comparison[outcome_jobs] == comparison]
      for (adjustment in unique(jobs$adjustment[comparison_jobs])) {
        covariates <- family_models[[adjustment]]
        selected <- if (config$complete_cases == "common") {
          common_sample
        } else {
          complete_case_sample(candidates, covariates)
        }
        adjustment_jobs <- comparison_jobs[
          jobs$adjustment[comparison_jobs] == adjustment
        ]
        for (job in adjustment_jobs) {
          report <- model_report(
            cohort, selected$data, selected$n_excluded,
            outcome, comparison, adjustment, jobs$method[job], covariates
          )
          result <- fit_and_save_model(
            selected$data, covariates, report, output_dir, config, age_centre
          )
          results[[length(results) + 1L]] <- result
          jobs$status[job] <- result$diagnostics$status
        }
      }
    }
    # Checkpoint tables after each endpoint; models have already been saved.
    model_progress("Saving summary tables after outcome: ", outcome$id, ".")
    outputs <- write_model_tables(
      lapply(results, `[[`, "estimates"), lapply(results, `[[`, "diagnostics"),
      lapply(results, `[[`, "ph_tests"), missingness, output_dir
    )
    save_jobs()
  }
  model_progress(
    nrow(outputs$diagnostics), " model fits attempted; ",
    sum(outputs$diagnostics$status == "failed"),
    " failed. Total elapsed = ", round(proc.time()[["elapsed"]] - started, 1),
    " s. Review diagnostics.csv and PH plots."
  )
  if (!is.null(curve_diagnostics) && any(curve_diagnostics$status != "ok")) {
    model_progress("Some curve exports failed; review curve_diagnostics.csv.")
  }
  invisible(outputs)
}

# Reuse archived PH tests (or calculate a missing test) without refitting models.
export_ph_plots <- function(run_dir, output_dir = run_dir, config = NULL) {
  if (is.null(config)) config <- read_run_config(run_dir)
  validate_model_config(config, check_packages = FALSE)
  if (!isTRUE(config$ph_plots)) {
    return(invisible(NULL))
  }
  jobs <- saved_model_jobs(run_dir, config)
  jobs <- jobs[jobs$method == "cox" &
    jobs$adjustment %in% config$ph_adjustments, , drop = FALSE]
  if (!nrow(jobs)) {
    return(invisible(NULL))
  }
  require_model_packages(c("ggplot2", "ggrastr", "cowplot"))
  ensure_output_directory(output_dir)
  reports <- lapply(seq_len(nrow(jobs)), function(i) {
    job <- jobs[i, , drop = FALSE]
    key <- model_key(job$outcome, job$comparison, job$adjustment, "cox")
    plot_file <- file.path(outcome_folder(job$outcome), paste0(key, "_ph.pdf"))
    result <- tryCatch(
      {
        path <- file.path(run_dir, job$model_file)
        if (!file.exists(path)) stop("Cox model archive not found: ", basename(path))
        saved <- readRDS(path)
        if (!inherits(saved$fit, "coxph") || !identical(saved$metadata$method, "cox")) {
          stop("Supply an archived Cox model.")
        }
        test <- saved$ph
        if (is.null(test)) test <- survival::cox.zph(saved$fit, terms = TRUE)
        outcome_directory(output_dir, job$outcome)
        save_ph_plots(test, file.path(output_dir, plot_file),
          fit = saved$fit, metadata = saved$metadata, config = config
        )
        ""
      },
      error = function(e) conditionMessage(e)
    )
    data.frame(
      outcome = job$outcome, comparison = job$comparison,
      adjustment = job$adjustment, model_file = job$model_file,
      plot_file = plot_file, status = if (nzchar(result)) "failed" else "ok",
      notes = result, stringsAsFactors = FALSE
    )
  })
  reports <- do.call(rbind, reports)
  utils::write.csv(reports, file.path(output_dir, "ph_plot_diagnostics.csv"),
    row.names = FALSE
  )
  model_progress(
    sum(reports$status == "ok"), " PH plots exported; ",
    sum(reports$status == "failed"), " failed. See ph_plot_diagnostics.csv."
  )
  invisible(reports)
}
