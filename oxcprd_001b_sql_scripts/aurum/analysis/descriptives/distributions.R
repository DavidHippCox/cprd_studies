# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# Histograms of age, BMI, GP registration months and pre-index consultation days.
# Source this file, edit distribution_config(), then call distribution_main().
# Locate helpers relative to this script for source() and Rscript.
local({
  files <- Filter(Negate(is.null), lapply(sys.frames(), function(x) x$ofile))
  script <- if (length(files)) {
    tail(files, 1L)[[1L]]
  } else {
    sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
  }
  if (is.na(script)) stop("Cannot locate the analysis script.")
  # source(chdir = TRUE) has already entered the script directory.
  if (!file.exists(script)) script <- basename(script)
  analysis_dir <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
  target <- parent.env(environment())
  source(file.path(analysis_dir, "database.R"), local = target)
  source(file.path(analysis_dir, "output.R"), local = target)
})

distribution_config <- function(output_dir = default_analysis_output_directory("descriptives")) {
  list(
    output_dir = output_dir,
    groups = c("All", "A", "B1", "B2"), # B2 is a subset of B1, not a separate partition.
    variables = list(
      age = list(
        column = "age_at_dementia_index", label = "Age at dementia index",
        xlab = "Age (years)", binwidth = 2, density = TRUE, discrete = FALSE
      ),
      bmi = list(
        column = "bmi_value", label = "Body mass index",
        xlab = "BMI (kg/m^2)", binwidth = 2, density = TRUE, discrete = FALSE
      ),
      gp_months = list(
        column = "gp_registration_months", label = "GP registration duration",
        xlab = "Months", binwidth = 12, density = FALSE, discrete = FALSE
      ),
      consult_days = list(
        column = "n_gp_consult_days_12m_pre_dementia",
        label = "Consultation days in pre-index year",
        xlab = "Distinct consultation days", binwidth = 1,
        density = TRUE, discrete = TRUE
      )
    ),
    density_bw = "nrd0", density_adjust = 1, # R bandwidth rule and multiplier.
    fill = "#77beeb", line = "#0d5381"
  )
}

# Read only the group flags and the four numeric fields.
distribution_columns <- function(config) {
  unique(c(
    "group_ab", "b2_flag",
    vapply(config$variables, function(x) x$column, character(1))
  ))
}

calculate_distributions <- function(data, config = distribution_config()) {
  if (anyNA(data$group_ab) || any(!data$group_ab %in% c("A", "B1")) ||
    anyNA(data$b2_flag) || any(!data$b2_flag %in% 0:1) ||
    any(data$b2_flag == 1 & data$group_ab != "B1")) {
    stop("Expected group_ab A/B1 and a complete B2 flag marking a subset of B1.")
  }
  masks <- list(
    All = rep(TRUE, nrow(data)), A = data$group_ab == "A",
    B1 = data$group_ab == "B1", B2 = data$b2_flag == 1
  )
  masks <- masks[config$groups]
  plots <- lapply(masks, function(x) list())
  summary <- list()
  limits <- list()
  for (name in names(config$variables)) {
    spec <- config$variables[[name]]
    values <- as.numeric(data[[spec$column]])
    observed <- values[is.finite(values)]
    breaks <- NULL
    if (length(observed)) {
      origin <- if (spec$discrete) -spec$binwidth / 2 else 0
      lower <- floor((min(observed) - origin) / spec$binwidth) * spec$binwidth + origin
      upper <- ceiling((max(observed) - origin) / spec$binwidth) * spec$binwidth + origin
      if (upper <= lower) upper <- lower + spec$binwidth
      breaks <- seq(lower, upper, by = spec$binwidth)
    }
    for (group in names(masks)) {
      raw <- values[masks[[group]]]
      x <- raw[is.finite(raw)]
      h <- if (length(x)) {
        graphics::hist(x,
          breaks = breaks, right = FALSE,
          include.lowest = TRUE, plot = FALSE
        )
      } else {
        NULL
      }
      d <- if (spec$density && length(x) > 1L && min(x) < max(x)) {
        stats::density(x,
          bw = config$density_bw, adjust = config$density_adjust,
          from = breaks[1L], to = tail(breaks, 1L)
        )
      } else {
        NULL
      }
      plots[[group]][[name]] <- list(histogram = h, density = d)
      q <- if (length(x)) {
        stats::quantile(x, c(0, .25, .5, .75, 1), names = FALSE)
      } else {
        rep(NA_real_, 5)
      }
      summary[[length(summary) + 1L]] <- data.frame(
        group = group, variable = name, column = spec$column,
        n_total = length(raw), n_observed = length(x), n_missing = sum(is.na(raw)),
        n_nonfinite = sum(!is.na(raw) & !is.finite(raw)),
        mean = if (length(x)) mean(x) else NA_real_,
        sd = if (length(x) > 1L) stats::sd(x) else NA_real_,
        min = q[1L], q25 = q[2L], median = q[3L], q75 = q[4L], max = q[5L]
      )
    }
    heights <- unlist(lapply(plots, function(page) {
      c(page[[name]]$histogram$density, page[[name]]$density$y)
    }))
    limits[[name]] <- list(
      x = if (length(breaks)) range(breaks) else c(0, 1),
      y = c(0, max(c(0, heights)) * 1.08)
    )
  }
  list(
    plots = plots, summary = do.call(rbind, summary), limits = limits,
    config = config, input_source = attr(data, "input_source")
  )
}

# Reusable with readRDS('distributions.rds')
plot_distribution_page <- function(result, group) {
  config <- result$config
  old <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old))
  graphics::par(
    mfrow = c(2, 2), mar = c(4.2, 4.6, 3.5, 1), oma = c(1.6, 0, 3, 0),
    cex.axis = .85, cex.lab = .9, las = 1
  )
  variables <- names(config$variables)
  for (i in seq_along(variables)) {
    name <- variables[i]
    spec <- config$variables[[name]]
    panel <- result$plots[[group]][[name]]
    row <- result$summary[result$summary$group == group & result$summary$variable == name, ]
    label <- paste(strwrap(spec$label, width = 38), collapse = "\n")
    if (is.null(panel$histogram)) {
      graphics::plot.new()
      graphics::title(main = label, cex.main = 1)
      graphics::text(.5, .5, "No observed values")
    } else {
      plot(panel$histogram,
        freq = FALSE, col = config$fill, border = "white",
        main = label, xlab = spec$xlab, ylab = "Density", cex.main = 1,
        xlim = result$limits[[name]]$x, ylim = result$limits[[name]]$y
      )
      if (!is.null(panel$density)) graphics::lines(panel$density, col = config$line, lwd = 2)
    }
    graphics::mtext(sprintf(
      "Observed: %s | Missing: %s | Nonfinite: %s",
      format(row$n_observed, big.mark = ","), format(row$n_missing, big.mark = ","),
      format(row$n_nonfinite, big.mark = ",")
    ), side = 3, line = .35, cex = .75)
    if (i %% 4L == 0L || i == length(variables)) {
      title <- if (group == "All") "All patients (A + B1)" else paste("Group", group)
      n <- result$summary$n_total[result$summary$group == group][1L]
      graphics::mtext(paste0("Distributions: ", title, " | n = ", format(n, big.mark = ",")),
        side = 3, outer = TRUE, line = 1, font = 2, cex = 1.1
      )
      graphics::mtext("Full observed range; shared bins and scales across groups. B2 is a subset of B1.",
        side = 1, outer = TRUE, line = .4, cex = .8
      )
    }
  }
  invisible(result)
}

save_distribution_plots <- function(result, output_dir) {
  ensure_output_directory(output_dir)
  grDevices::pdf(file.path(output_dir, "distributions.pdf"),
    width = 11, height = 8.5,
    compress = TRUE, useDingbats = FALSE
  )
  on.exit(grDevices::dev.off())
  for (group in names(result$plots)) plot_distribution_page(result, group)
  invisible(output_dir)
}

validate_distribution_config <- function(config) {
  if (!length(config$groups) || any(!config$groups %in% c("All", "A", "B1", "B2"))) {
    stop("Choose groups from All, A, B1 and B2.")
  }
  if (!length(config$variables) ||
    any(vapply(config$variables, function(x) x$binwidth <= 0, logical(1)))) {
    stop("Configure at least one variable, with a positive bin width.")
  }
  invisible(config)
}

run_distributions <- function(data, config = distribution_config(),
                              output_dir = config$output_dir,
                              allow_existing = FALSE) {
  validate_distribution_config(config)
  check_output_directory(output_dir, allow_existing)
  absent <- setdiff(distribution_columns(config), names(data))
  if (length(absent)) stop("Missing columns: ", paste(absent, collapse = ", "))
  config$output_dir <- output_dir
  result <- calculate_distributions(data, config)
  write_run_metadata(
    output_dir, config, input_source = attr(data, "input_source"),
    run_info = data.frame(n_input = nrow(data), created = as.character(Sys.time()))
  )
  saveRDS(result, file.path(output_dir, "distributions.rds"))
  utils::write.csv(result$summary,
    file.path(output_dir, "distribution_summary.csv"), row.names = FALSE
  )
  save_distribution_plots(result, output_dir)
  message("Distribution results saved in ", normalizePath(output_dir))
  invisible(result)
}

distribution_main <- function(output_dir = config$output_dir,
                              config = distribution_config(),
                              settings = database_settings(), data = NULL,
                              allow_existing = FALSE) {
  validate_distribution_config(config)
  check_output_directory(output_dir, allow_existing)
  if (is.null(data)) {
    data <- read_analysis_database(distribution_columns(config), settings)
  }
  run_distributions(data, config, output_dir, allow_existing)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 1L) stop("Usage: Rscript distributions.R [NEW_OUTPUT_DIRECTORY]")
  if (length(args)) distribution_main(args[1L]) else distribution_main()
}
