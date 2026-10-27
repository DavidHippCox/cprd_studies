# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2
# survival supplies the PH tests and smooths; ggplot2/ggrastr/cowplot render them.
# https://stat.ethz.ch/R-manual/R-devel/library/survival/html/plot.cox.zph.html

ph_p_label <- function(p) {
  if (is.finite(p)) trimws(format.pval(p, digits = 2, eps = 0.001)) else "NA"
}

ph_plot_context <- function(metadata) {
  if (is.null(metadata)) {
    return("Cox proportional-hazards diagnostics")
  }
  label <- if (is.null(metadata$adjustment_label)) {
    adjustment_label(metadata$adjustment)
  } else {
    metadata$adjustment_label
  }
  paste(gsub("_", " ", metadata$outcome), gsub("_", " ", metadata$comparison),
    label,
    sep = " | "
  )
}

# Retain transformed spacing; map day labels using the saved event times.
ph_time_scale <- function(one) {
  if (one$transform == "log") {
    return(ggplot2::scale_x_log10())
  }
  if (one$transform == "identity") {
    return(ggplot2::scale_x_continuous())
  }
  ticks <- pretty(range(one$time), n = 5)
  positions <- stats::approx(one$time, one$x, xout = ticks, ties = mean)$y
  keep <- is.finite(positions)
  ggplot2::scale_x_continuous(breaks = positions[keep], labels = ticks[keep])
}

# Both views use the same full-range axes. All finite residuals are retained.
ph_plot_panel <- function(one, fit, term, label, residuals, settings) {
  coefficient <- fit$assign[[term]]
  multiple <- length(coefficient) > 1L
  reference <- if (multiple) 1 else unname(stats::coef(fit)[coefficient])
  smooth <- graphics::plot(one, plot = FALSE)
  if (is.null(smooth)) stop("Cannot draw PH smooth for term: ", term)
  lines <- data.frame(
    time = smooth$x, estimate = smooth$y[, 1L],
    upper = smooth$y[, 2L], lower = smooth$y[, 3L]
  )
  points <- data.frame(
    time = if (one$transform == "log") exp(one$x) else one$x,
    residual = one$y[, 1L]
  )
  points <- points[is.finite(points$time) & is.finite(points$residual), , drop = FALSE]
  p <- one$table[1L, "p"]
  flagged <- is.finite(p) && p < settings$ph_alpha
  colour <- settings$ph_colours[[if (flagged) "flagged" else "ok"]]
  status <- if (!is.finite(p)) {
    "PH test unavailable"
  } else if (flagged) {
    "Evidence of non-PH"
  } else {
    "No evidence of non-PH"
  }
  figure <- ggplot2::ggplot() +
    ph_time_scale(one) +
    ggplot2::coord_cartesian(
      xlim = range(points$time, lines$time, finite = TRUE),
      ylim = range(reference, points$residual, smooth$y, finite = TRUE)
    ) +
    ggplot2::labs(
      title = paste(strwrap(label, width = 40), collapse = "\n"),
      subtitle = paste0(status, " | PH p: ", ph_p_label(p)),
      x = switch(one$transform,
        km = "Days since dementia index\n(KM-transformed spacing)",
        identity = "Days since dementia index",
        log = "Days since dementia index (log scale)",
        paste("Days since dementia index\n(", one$transform, "-transformed spacing)", sep = "")
      ),
      y = if (multiple) {
        "Multiplier of fitted term effect"
      } else {
        "Time-varying coefficient (log hazard ratio)"
      }
    ) +
    ggplot2::theme_classic(base_size = 10) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = 11, face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = colour),
      plot.margin = ggplot2::margin(8, 12, 8, 8)
    )
  if (residuals) {
    figure + ggrastr::rasterise(
      ggplot2::geom_point(
        data = points, ggplot2::aes(x = time, y = residual),
        colour = "#73818C", alpha = 0.6, size = 0.6, stroke = 0
      ),
      dpi = settings$ph_residual_dpi, dev = "ragg"
    )
  } else {
    figure +
      ggplot2::geom_line(
        data = lines, ggplot2::aes(x = time, y = estimate),
        colour = colour, linewidth = 0.8
      ) +
      ggplot2::geom_line(
        data = lines, ggplot2::aes(x = time, y = upper),
        colour = "#90A4AE", linetype = "dotted"
      ) +
      ggplot2::geom_line(
        data = lines, ggplot2::aes(x = time, y = lower),
        colour = "#90A4AE", linetype = "dotted"
      ) +
      ggplot2::geom_hline(yintercept = reference, colour = "gray40", linetype = "dashed")
  }
}

# Labels, screening threshold and raster resolution remain in model_config.R.
save_ph_plot <- function(test, path, fit, metadata = NULL, residuals = FALSE,
                         config = model_config()) {
  labels <- config$covariate_labels
  groups <- levels(fit$model$exposure)
  labels["exposure"] <- paste("Exposure:", groups[2L], "versus", groups[1L])
  terms <- colnames(test$y)
  global <- if ("GLOBAL" %in% rownames(test$table)) {
    paste("Global PH p:", ph_p_label(test$table["GLOBAL", "p"]))
  } else {
    "Global PH test unavailable"
  }
  view <- if (residuals) "Scaled Schoenfeld residuals only" else "Schoenfeld smooth curves only"
  key <- if (residuals) {
    "Grey raster dots: all finite event residuals | no fitted or reference lines"
  } else {
    "Coloured line: smooth | dotted grey: +/-2 SE | dashed grey: constant-effect reference"
  }
  heading <- cowplot::ggdraw() + cowplot::draw_label(
    paste(ph_plot_context(metadata), paste(view, global, sep = " | "), sep = "\n"),
    size = 10, fontface = "bold"
  )
  footer <- cowplot::ggdraw() + cowplot::draw_label(paste(
    key, paste0(
      "Matched axes in both PDFs; full residual range. PH screening threshold: ",
      config$plot_settings$ph_alpha, "."
    ),
    sep = "\n"
  ), size = 8)
  grDevices::pdf(path,
    width = 11, height = 6.3, pointsize = 11,
    onefile = TRUE, compress = TRUE, useDingbats = FALSE
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  for (start in seq.int(1L, length(terms), by = 2L)) {
    indices <- seq.int(start, min(start + 1L, length(terms)))
    panels <- lapply(indices, function(i) {
      term <- terms[i]
      label <- if (term %in% names(labels)) labels[[term]] else gsub("_", " ", term)
      ph_plot_panel(test[i], fit, term, label, residuals, config$plot_settings)
    })
    if (length(panels) == 1L) panels[[2L]] <- cowplot::ggdraw()
    page <- cowplot::plot_grid(
      heading, cowplot::plot_grid(plotlist = panels, ncol = 2), footer,
      ncol = 1, rel_heights = c(0.13, 1, 0.13)
    )
    print(page)
  }
  invisible(path)
}

# Export the matched pair from a newly fitted or archived model.
save_ph_plots <- function(test, path, fit, metadata = NULL, config = model_config()) {
  if (!grepl("\\.pdf$", path, ignore.case = TRUE)) stop("Supply a .pdf path.")
  paths <- c(
    curves = path,
    residuals = sub("\\.pdf$", "_residuals.pdf", path, ignore.case = TRUE)
  )
  for (view in names(paths)) {
    save_ph_plot(test, paths[[view]],
      fit = fit, metadata = metadata,
      residuals = view == "residuals", config = config
    )
  }
  invisible(paths)
}
