# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2

cox_curve_components <- function(fit, times) {
  if (!fit$method %in% c("efron", "breslow")) stop("Use Efron or Breslow ties.")
  if (!is.null(fit$weights) && any(fit$weights != 1)) {
    stop("These standardised intervals require an unweighted Cox model.")
  }
  x <- sweep(fit$x, 2, fit$means, "-")
  baseline <- survival::coxsurv.fit(
    ctype = if (fit$method == "efron") 2 else 1, stype = 2, se.fit = FALSE,
    varmat = stats::vcov(fit), cluster = NULL, y = fit$y, x = x,
    wt = rep(1, nrow(x)), risk = exp(drop(x %*% stats::coef(fit))),
    position = NULL, strata = NULL, oldid = NULL,
    y2 = NULL, x2 = matrix(0, 1, ncol(x)), risk2 = 1,
    strata2 = NULL, id2 = NULL, unlist = FALSE
  )[[1L]]
  at <- findInterval(times, baseline$time) + 1L
  derivative <- matrix(apply(baseline$xbar, 2, cumsum), ncol = ncol(x))
  list(
    hazard = c(0, baseline$cumhaz)[at],
    variance = c(0, cumsum(baseline$varhaz))[at],
    derivative = rbind(0, derivative)[at, , drop = FALSE]
  )
}

# Log-log limits stay within [0, 1], as for the descriptive KM curves.
curve_confidence_limits <- function(estimate, std_error, level = 0.95) {
  lower <- upper <- estimate
  inside <- estimate > 0 & estimate < 1
  log_hazard <- log(-log(estimate[inside]))
  transformed_se <- std_error[inside] / abs(estimate[inside] * log(estimate[inside]))
  width <- stats::qnorm((1 + level) / 2) * transformed_se
  lower[inside] <- exp(-exp(log_hazard + width))
  upper[inside] <- exp(-exp(log_hazard - width))
  data.frame(conf_low = lower, conf_high = upper)
}

# Marginal delta intervals conditional on the observed standardisation covariates.
# Include baseline and coefficient uncertainty jointly.
standardised_cox_estimates <- function(fit, data, times, level = 0.95) {
  components <- cox_curve_components(fit, times)
  covariance <- stats::vcov(fit)
  groups <- fit$xlevels$exposure
  estimates <- lapply(groups, function(group) {
    data$exposure <- factor(rep(group, nrow(data)), levels = groups)
    x <- sweep(stats::model.matrix(fit, data = data), 2, fit$means, "-")
    risk <- exp(drop(x %*% stats::coef(fit)))
    values <- lapply(seq_along(times), function(k) {
      survival <- exp(-components$hazard[k] * risk)
      risk_survival <- risk * survival
      average_risk <- mean(risk_survival)
      gradient <- components$hazard[k] * drop(crossprod(x, risk_survival)) / length(risk) -
        average_risk * components$derivative[k, ]
      variance <- average_risk^2 * components$variance[k] +
        drop(crossprod(gradient, covariance %*% gradient))
      c(estimate = mean(survival), std_error = sqrt(variance))
    })
    values <- as.data.frame(do.call(rbind, values))
    data.frame(
      group = group, time_days = times, time_years = times / 365.25,
      values, curve_confidence_limits(values$estimate, values$std_error, level),
      row.names = NULL
    )
  })
  do.call(rbind, estimates)
}

# Marginal standardised survival from a saved Cox model at any adjustment level.
# Average the individual survival predictions, rather than their risk scores.
adjusted_survival_curve <- function(saved, config = model_config()) {
  fit <- saved$fit
  meta <- saved$metadata
  if (!inherits(fit, "coxph") || !identical(meta$method, "cox")) {
    stop("Supply an archived Cox model (not logistic or Fine-Gray).")
  }
  if (!is.null(fit$naive.var)) {
    stop("These intervals require a fresh Cox fit without clustering/robust variance.")
  }
  if (is.null(fit$model) || is.null(fit$x) || attr(fit$y, "type") != "right" ||
    !is.null(fit$strata) || !is.null(fit$offset)) {
    stop("These curves require a saved, unstratified right-censored Cox model without offsets.")
  }
  # Older archives called an exposure + age_c model "unadjusted".
  # Correct its local metadata without changing the saved model file.
  if (meta$adjustment == "unadjusted" &&
    setequal(attr(stats::terms(fit), "term.labels"), c("exposure", "age_c"))) {
    meta$adjustment <- "age_adjusted"
    meta$adjustment_label <- adjustment_label("age_adjusted")
  }
  data <- fit$model
  groups <- fit$xlevels$exposure
  if (length(groups) != 2L) stop("The model must compare A with B1 or B2.")
  # The archived fit supplies its contrasts when predicting new data.
  for (name in names(data)) {
    if (is.factor(data[[name]])) attr(data[[name]], "contrasts") <- NULL
  }
  observed <- data.frame(time = fit$y[, "time"], exposure = data$exposure)
  # Stop at the shorter of the two groups' observed follow-up ranges.
  maximum <- min(tapply(observed$time, observed$exposure, max))
  requested <- sort(unique(config$curve_times_years * 365.25))
  requested <- requested[requested <= maximum]
  times <- sort(unique(c(
    seq(0, maximum, length.out = config$adjusted_curve_points),
    requested
  )))

  level <- config$curve_conf_level
  estimates <- standardised_cox_estimates(fit, data, times, level)
  ticks <- pretty(c(0, max(maximum / 365.25, 1 / 365.25)), n = 5)
  ticks <- ticks[ticks >= 0 & ticks * 365.25 <= maximum]
  mortality <- meta$outcome == "death"
  list(
    method = "adjusted_cox", outcome = meta$outcome,
    comparison = sub("_vs_A$", "", meta$comparison), adjustment = meta$adjustment,
    adjustment_label = adjustment_label(meta$adjustment),
    formula = paste(deparse(stats::formula(fit)), collapse = " "),
    estimand = if (mortality) {
      "All-cause survival"
    } else {
      "Net event-free survival (death censored)"
    },
    sample = paste("complete-case cohort used for the Cox model:", adjustment_label(meta$adjustment)),
    standardisation = paste(
      "Average individual survival predictions with exposure set",
      "to each group over the same combined model cohort."
    ),
    n_standardised = nrow(data), confidence_intervals = TRUE,
    confidence_level = level,
    confidence_method = paste(
      "Model-based delta method, including baseline and coefficient covariance;",
      "fixed observed standardisation covariates; log-log limits"
    ),
    estimates = estimates,
    timepoints = estimates[estimates$time_days %in% requested, , drop = FALSE],
    risk_table = curve_risk_table(observed, ticks),
    maximum_years = maximum / 365.25, metadata = meta, age_centre = saved$age_centre,
    plot_settings = config$plot_settings["curve_colours"]
  )
}

save_adjusted_curve <- function(saved, output_dir, config = model_config()) {
  meta <- saved$metadata
  directory <- outcome_directory(output_dir, meta$outcome, "adjusted_curves")
  curve <- adjusted_survival_curve(saved, config)
  key <- cox_curve_key(curve$outcome, curve$comparison, curve$adjustment)
  save_curve_files(curve, file.path(directory, key))
  file.path(outcome_folder(meta$outcome), "adjusted_curves", paste0(key, ".rds"))
}


# The saved manifest limits exports to jobs belonging to the original run.
# Older runs fall back to their saved configuration; explicit overrides still apply.
saved_model_jobs <- function(run_dir, config) {
  configured <- model_jobs(config)
  manifest <- file.path(run_dir, "model_jobs.csv")
  jobs <- if (file.exists(manifest)) {
    utils::read.csv(manifest, stringsAsFactors = FALSE)
  } else {
    configured
  }
  columns <- c("outcome", "comparison", "adjustment", "method")
  if (!all(columns %in% names(jobs))) {
    stop("model_jobs.csv must contain outcome, comparison, adjustment and method.")
  }
  key <- function(rows) {
    paste(rows$outcome, sub("_vs_A$", "", rows$comparison),
      rows$adjustment, rows$method,
      sep = "__"
    )
  }
  jobs <- jobs[key(jobs) %in% key(configured), , drop = FALSE]
  if (!"model_file" %in% names(jobs)) {
    jobs$model_file <- vapply(seq_len(nrow(jobs)), function(i) {
      file.path(outcome_folder(jobs$outcome[i]), paste0(model_key(
        jobs$outcome[i], jobs$comparison[i], jobs$adjustment[i], jobs$method[i]
      ), ".rds"))
    }, character(1))
  }
  jobs
}

export_adjusted_curves <- function(
  run_dir,
  output_dir = run_dir, config = NULL
) {
  if (is.null(config)) config <- read_run_config(run_dir)
  validate_model_config(config, check_packages = FALSE)
  curve_ids <- adjusted_curve_ids(config)
  if (!length(curve_ids)) {
    return(invisible(NULL))
  }
  jobs <- saved_model_jobs(run_dir, config)
  jobs <- jobs[jobs$method == "cox" & jobs$outcome %in% curve_ids &
    (jobs$outcome == "death" | jobs$adjustment == "fully"), , drop = FALSE]
  if (!nrow(jobs)) {
    return(invisible(NULL))
  }
  require_model_packages(c("survminer", "ggplot2", "cowplot"))
  ensure_output_directory(output_dir)
  reports <- lapply(seq_len(nrow(jobs)), function(i) {
    model_file <- jobs$model_file[i]
    path <- file.path(run_dir, model_file)
    message(
      "Cox curve: ", jobs$outcome[i], " (", jobs$comparison[i], " vs A; ",
      adjustment_label(jobs$adjustment[i]), ")"
    )
    curve_key <- cox_curve_key(jobs$outcome[i], jobs$comparison[i], jobs$adjustment[i])
    curve_file <- file.path(outcome_folder(jobs$outcome[i]), "adjusted_curves", paste0(curve_key, ".rds"))
    result <- tryCatch(
      {
        if (!file.exists(path)) stop("Cox model archive not found: ", basename(path))
        saved <- readRDS(path)
        if (jobs$adjustment[i] == "unadjusted" &&
          !identical(attr(stats::terms(saved$fit), "term.labels"), "exposure")) {
          stop(
            "This historical 'unadjusted' archive includes covariates. ",
            "Use save_adjusted_curve(saved, output_dir, config) to export it with its correct label."
          )
        }
        save_adjusted_curve(saved, output_dir, config)
        ""
      },
      error = function(e) conditionMessage(e)
    )
    data.frame(
      outcome = jobs$outcome[i], comparison = jobs$comparison[i],
      adjustment = jobs$adjustment[i], adjustment_label = adjustment_label(jobs$adjustment[i]),
      model_file = model_file, curve_file = curve_file,
      status = if (nzchar(result)) "failed" else "ok",
      notes = result
    )
  })
  reports <- do.call(rbind, reports)
  utils::write.csv(reports, file.path(output_dir, "adjusted_curve_diagnostics.csv"),
    row.names = FALSE
  )
  message(
    sum(reports$status == "ok"), " adjusted curves exported; ",
    sum(reports$status == "failed"), " failed. See adjusted_curve_diagnostics.csv."
  )
  invisible(reports)
}
