# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# Mortality Kaplan-Meier curves and shared survival-curve exports.

# Count directly from patient follow-up times, including those still at risk at t.
# summary.survfit() may approximate the count at a requested time between observations.
curve_at_risk <- function(data, groups, times_days) {
  counts <- numeric(length(times_days))
  for (group in unique(groups)) {
    rows <- groups == group
    observed <- sort(data$time[data$exposure == group])
    counts[rows] <- length(observed) -
      findInterval(times_days[rows], observed, left.open = TRUE)
  }
  counts
}

curve_risk_table <- function(data, times_years) {
  table <- expand.grid(
    time_years = times_years,
    group = levels(droplevels(data$exposure)), stringsAsFactors = FALSE
  )
  table$n_at_risk <- curve_at_risk(data, table$group, table$time_years * 365.25)
  table[c("group", "time_years", "n_at_risk")]
}

curve_estimates <- function(fit, data, times_years = NULL) {
  values <- if (is.null(times_years)) {
    summary(fit, censored = TRUE, data.frame = TRUE)
  } else {
    # Never extend estimates beyond a group's observed follow-up.
    summary(fit, times = times_years * 365.25, extend = FALSE, data.frame = TRUE)
  }
  values$state <- "alive"
  groups <- sub("^exposure=", "", as.character(values$strata))
  optional <- function(name) {
    if (name %in% names(values)) values[[name]] else rep(NA_real_, nrow(values))
  }
  data.frame(
    group = groups, state = values$state,
    time_days = values$time, time_years = values$time / 365.25,
    estimate = values$surv,
    conf_low = optional("lower"), conf_high = optional("upper"),
    std_error = optional("std.err"),
    n_at_risk = curve_at_risk(data, groups, values$time)
  )
}

fit_endpoint_curve <- function(data, outcome, comparison, config) {
  if (nlevels(droplevels(data$exposure)) != 2L) {
    stop("Both exposure groups are required for a comparison curve.")
  }
  if (outcome$family != "death") {
    stop("Descriptive curves support mortality only; use a fully adjusted Cox model for nonfatal outcomes.")
  }
  level <- config$curve_conf_level
  formula <- model_formula(character(), "Surv(time, event)")
  fit <- ggsurvfit::survfit2(
    formula,
    data = data,
    se.fit = TRUE, conf.type = "log-log",
    conf.int = level, influence = FALSE, na.action = stats::na.fail
  )
  maximum <- max(data$time) / 365.25
  ticks <- pretty(c(0, max(maximum, 1 / 365.25)), n = 5)
  ticks <- ticks[ticks >= 0 & ticks <= maximum]
  times <- sort(unique(c(0, config$curve_times_years)))
  quantiles <- stats::quantile(fit, probs = 0.5, scale = 365.25)
  medians <- data.frame(
    group = sub("^exposure=", "", rownames(quantiles$quantile)),
    median_years = as.vector(quantiles$quantile),
    conf_low = as.vector(quantiles$lower),
    conf_high = as.vector(quantiles$upper)
  )
  list(
    fit = fit, method = "km",
    formula = paste(deparse(formula), collapse = " "),
    outcome = outcome$id, comparison = comparison,
    sample = "all eligible patients before covariate complete-case exclusions",
    confidence_intervals = TRUE, confidence_level = level,
    confidence_method = "Greenwood variance; log-log limits",
    patient_ids = data$patid,
    estimates = curve_estimates(fit, data),
    timepoints = curve_estimates(fit, data, times),
    risk_table = curve_risk_table(data, ticks),
    median_survival = medians, maximum_years = maximum,
    plot_settings = config$plot_settings["curve_colours"]
  )
}


# Plot package estimates directly; CSV/RDS tables retain the common export schema.
# Descriptive fits store days; compact adjusted tables supply years directly.
plot_saved_curve <- function(curve) {
  if (!curve$method %in% c("km", "adjusted_cox")) {
    stop("Supply a mortality KM or Cox survival curve.")
  }
  adjusted <- curve$method == "adjusted_cox"
  net <- adjusted && curve$outcome != "death"
  colours <- curve$plot_settings$curve_colours
  ticks <- unique(curve$risk_table$time_years)
  ticks_days <- ticks * 365.25
  maximum_days <- max(curve$maximum_years * 365.25, 1)
  level <- if (is.null(curve$confidence_level)) 0.95 else curve$confidence_level
  prefix <- if (adjusted) {
    label <- if (is.null(curve$adjustment_label)) {
      adjustment_label(curve$adjustment)
    } else {
      curve$adjustment_label
    }
    paste0("Cox (", tolower(label), "):")
  } else {
    "Kaplan-Meier (unadjusted):"
  }
  title <- paste(strwrap(paste(prefix, gsub("_", " ", curve$outcome)), 60),
    collapse = "\n"
  )
  subtitle <- paste(curve$comparison, "vs A;", if (adjusted) {
    "standardised to this model's cohort"
  } else {
    "all eligible patients"
  })
  legend_title <- if (curve$confidence_intervals) {
    paste0(format(100 * level), "% pointwise CIs")
  } else {
    "Exposure"
  }
  ylab <- if (net) {
    "Net event-free survival probability"
  } else {
    "Survival probability"
  }
  xlab <- "Years since dementia index"

  if (adjusted) {
    # Plot the compact exported tables; no patient-level prediction object needed.
    rows <- curve$estimates
    groups <- unique(as.character(rows$group))
    x_scale <- ggplot2::scale_x_continuous(
      breaks = ticks, limits = c(0, maximum_days / 365.25),
      expand = ggplot2::expansion(mult = c(0.05, 0.03))
    )
    plot_data <- data.frame(
      time = rows$time_years, surv = rows$estimate,
      strata = factor(rows$group, levels = groups),
      lower = rows$conf_low, upper = rows$conf_high, n.censor = 0
    )


    figure <- survminer::ggsurvplot_df(
      plot_data,
      color = "strata", palette = colours,
      conf.int = curve$confidence_intervals, conf.int.style = "ribbon",
      conf.int.alpha = 0.16, censor = FALSE, xscale = 1,
      xlim = c(0, maximum_days / 365.25), ylim = c(0, 1),
      title = title, xlab = NULL, ylab = ylab,
      legend = "bottom", legend.title = legend_title, legend.labs = groups,
      ggtheme = ggplot2::theme_classic(base_size = 11)
    )

    figure <- suppressMessages(figure + x_scale) +
      ggplot2::labs(
        subtitle = subtitle,
        caption = if (net) "Deaths censored; model cohort" else NULL
      )
    risk <- ggplot2::ggplot(
      curve$risk_table,
      ggplot2::aes(x = time_years, y = group, label = n_at_risk)
    ) +
      ggplot2::geom_text(size = 3.5) +
      x_scale +
      ggplot2::scale_y_discrete(limits = rev(groups)) +
      ggplot2::labs(x = xlab, y = NULL, title = "Observed number at risk (model cohort)") +
      ggplot2::theme_classic(base_size = 11) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 10),
        axis.line.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank()
      )
    figure <- cowplot::plot_grid(figure, risk,
      ncol = 1,
      rel_heights = c(4, 1.2), align = "v", axis = "lr"
    )
  } else {
    figure <- ggsurvfit::ggsurvfit(curve$fit, linewidth = 0.9)
    if (curve$confidence_intervals) {
      figure <- figure + ggsurvfit::add_confidence_interval(alpha = 0.16)
    }
    figure <- figure +
      ggsurvfit::add_risktable(
        times = ticks_days, risktable_stats = "n.risk",
        stats_label = list(n.risk = "Number at risk")
      ) +
      ggsurvfit::scale_ggsurvfit(
        x_scales = list(
          breaks = ticks_days, labels = ticks, limits = c(0, maximum_days),
          expand = c(0.03, 0)
        ),
        y_scales = list(limits = c(0, 1), labels = ggplot2::waiver())
      ) +
      ggplot2::scale_colour_manual(values = colours, name = legend_title) +
      ggplot2::scale_fill_manual(values = colours, name = legend_title) +
      ggplot2::labs(title = title, subtitle = subtitle, x = xlab, y = ylab) +
      ggplot2::theme(legend.position = "bottom")
  }
  print(figure)
  invisible(curve)
}

save_curve_pdf <- function(curve, path) {
  grDevices::pdf(path, width = 8, height = 6.5, compress = TRUE, useDingbats = FALSE)
  on.exit(grDevices::dev.off())
  plot_saved_curve(curve)
  invisible(path)
}

save_curve_files <- function(curve, prefix) {
  saveRDS(curve, paste0(prefix, ".rds"))
  for (name in c("estimates", "timepoints", "risk_table", "median_survival")) {
    if (!is.null(curve[[name]])) {
      utils::write.csv(curve[[name]], paste0(prefix, "_", name, ".csv"),
        row.names = FALSE, na = ""
      )
    }
  }
  save_curve_pdf(curve, paste0(prefix, ".pdf"))
  invisible(curve)
}

# Supply prepared analysis_data.rds to add/recreate curves without regression fits.
export_survival_curves <- function(data, output_dir, config = model_config()) {
  if (!length(config$curve_outcomes)) {
    return(invisible(NULL))
  }
  if (length(setdiff(config$curve_outcomes, "death"))) {
    stop("Descriptive curves support death only. Use adjusted_curve_outcomes for nonfatal survival curves.")
  }
  outcomes <- Filter(
    function(x) x$id %in% config$curve_outcomes && x$family == "death",
    outcome_config(config, selected = FALSE)
  )
  reports <- list()
  for (outcome in outcomes) {
    curve_dir <- outcome_directory(output_dir, outcome$id, "curves")
    endpoint <- make_endpoint(data, outcome)
    for (comparison in config$comparisons) {
      candidates <- comparison_data(endpoint, outcome, comparison)$candidates
      method <- "km"
      key <- paste(outcome$id, comparison, "unadjusted", method, sep = "__")
      result <- tryCatch(
        {
          curve <- fit_endpoint_curve(candidates, outcome, comparison, config)
          save_curve_files(curve, file.path(curve_dir, key))
          ""
        },
        error = function(e) conditionMessage(e)
      )
      reports[[length(reports) + 1L]] <- data.frame(
        outcome = outcome$id, comparison = paste0(comparison, "_vs_A"),
        method = method, n = nrow(candidates),
        status = if (nzchar(result)) "failed" else "ok", notes = result
      )
    }
  }
  report <- do.call(rbind, reports)
  utils::write.csv(report, file.path(output_dir, "curve_diagnostics.csv"),
    row.names = FALSE
  )
  invisible(report)
}
