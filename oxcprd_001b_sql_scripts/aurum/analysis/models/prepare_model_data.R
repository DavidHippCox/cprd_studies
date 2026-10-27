# Authored by David Hippisley-Cox
# project: aurum_oxcprd_001b
# analysis plan version: v2

require_columns <- function(data, columns) {
  absent <- setdiff(columns, names(data))
  if (length(absent)) stop("Missing columns: ", paste(absent, collapse = ", "))
}

coded_factor <- function(x, levels, labels = levels, name) {
  if (any(!is.na(x) & !as.character(x) %in% as.character(levels))) {
    stop("Unexpected category in ", name)
  }
  value <- factor(x, levels = levels, labels = labels, ordered = FALSE)
  # Explicit treatment contrasts avoid session-wide polynomial contrasts.
  contrasts(value) <- stats::contr.treatment(base::levels(value))
  value
}

# One input specification keeps database selection and validation aligned.
model_input_spec <- function(config) {
  prefixes <- unique(unlist(config$prefixes, use.names = FALSE))
  date_flags <- config$baseline_dates
  dates <- c(
    "dementia_index_date", "earliest_4", "merged_death",
    unname(date_flags),
    paste0(prefixes, "_pre_dem_eventdate"),
    paste0(prefixes, "_post_dem_eventdate")
  )
  numbers <- c("b2_flag", "age_at_dementia_index", unname(config$numeric_fields))
  columns <- c(
    "patid", "group_ab", "gender", "ethnic_6",
    "imd_2019_quintile", "smoking_status", dates, numbers, config$extra_columns
  )
  list(
    columns = unique(columns), dates = unique(dates), numbers = unique(numbers),
    prefixes = prefixes, date_flags = date_flags
  )
}

# Shared connector
read_model_database <- function(config = model_config(), settings = database_settings()) {
  read_analysis_database(model_input_spec(config)$columns, settings)
}

prepare_data <- function(data, config) {
  spec <- model_input_spec(config)
  require_columns(data, spec$columns)
  prefixes <- spec$prefixes
  date_flags <- spec$date_flags
  dates <- spec$dates
  numbers <- spec$numbers
  if (anyDuplicated(data$patid)) stop("Expected one row per patid.")
  if (anyNA(data$group_ab) ||
    any(!data$group_ab %in% c("A", "B1"))) {
    stop("Expected group_ab A or B1; B2 is identified by b2_flag.")
  }
  data[dates] <- lapply(data[dates], as.Date)
  data[numbers] <- lapply(data[numbers], as.numeric)
  if (anyNA(data$b2_flag) || any(!data$b2_flag %in% 0:1)) {
    stop("b2_flag must be a complete 0/1 flag.")
  }
  if (any(data$b2_flag == 1 & data$group_ab != "B1")) {
    stop("B2 must be a subset of B1.")
  }
  index <- data$dementia_index_date
  end <- data$earliest_4
  death <- data$merged_death
  if (anyNA(index) || anyNA(end) || any(end < index) ||
    any(death < index, na.rm = TRUE) ||
    any(end > death, na.rm = TRUE)) {
    stop("Invalid index, death or follow-up dates; check earliest_4.")
  }
  age_mean <- if (is.null(config$age_centre)) {
    mean(data$age_at_dementia_index, na.rm = TRUE)
  } else {
    config$age_centre
  }
  if (!is.finite(age_mean)) stop("No observed ages.")
  data$age_c <- data$age_at_dementia_index - age_mean
  data$sex <- coded_factor(
    data$gender, c(1, 2),
    c("Male", "Female"), "gender"
  )
  data$ethnicity <- coded_factor(
    data$ethnic_6, c(4, 1, 2, 3, 5, 6),
    c("White", "Asian", "Black", "Mixed", "Other", "Unknown"), "ethnic_6"
  )
  data$imd <- coded_factor(data$imd_2019_quintile, 1:5,
    name = "imd_2019_quintile"
  )
  data$smoking <- coded_factor(
    data$smoking_status, c("non-smoker", "current-smoker", "ex-smoker"),
    name = "smoking_status"
  )
  years <- format(index, "%Y")
  data$index_year <- factor(years, levels = sort(unique(years)))
  if (nlevels(data$index_year) > 1L) {
    contrasts(data$index_year) <- stats::contr.treatment(levels(data$index_year))
  }
  for (name in names(config$numeric_fields)) {
    data[[name]] <- data[[config$numeric_fields[[name]]]]
  }
  for (name in names(date_flags)) {
    data[[name]] <- as.integer(!is.na(data[[date_flags[[name]]]]))
  }
  data$followup <- as.numeric(end - index)
  data$death_event <- as.integer(!is.na(death) & death <= end)
  attr(data, "age_centre") <- age_mean
  data
}

make_endpoint <- function(data, outcome) {
  data$prior <- FALSE
  data$eligible <- TRUE

  if (outcome$family == "death") {
    data$time <- data$followup
    data$event <- data$death_event
  } else {
    # Composites use any prior history and the earliest post-index event.
    pre <- data[paste0(outcome$prefixes, "_pre_dem_eventdate")]
    post <- do.call(pmin, c(
      data[paste0(outcome$prefixes, "_post_dem_eventdate")],
      na.rm = TRUE
    ))

    data$prior <- rowSums(!is.na(pre)) > 0L
    data$eligible <- !outcome$exclude_prior | !data$prior

    data$event <- as.integer(!is.na(post))
    data$time <- ifelse(
      data$event == 1,
      as.numeric(post - data$dementia_index_date),
      data$followup
    )
  }

  # An outcome recorded on the death date takes precedence over death.
  data$status <- factor(
    ifelse(data$event == 1, "outcome",
      ifelse(data$death_event == 1, "death", "censor")
    ),
    levels = c("censor", "outcome", "death")
  )

  data
}
# Shared sample selection for models and descriptive survival curves.
comparison_data <- function(endpoint, outcome, comparison) {
  keep <- endpoint$group_ab == "A" |
    (endpoint$group_ab == "B1" &
      (comparison == "B1" | endpoint$b2_flag == 1))
  subset <- endpoint[keep, , drop = FALSE]
  subset$exposure <- factor(
    ifelse(subset$group_ab == "A", "A", comparison),
    levels = c("A", comparison)
  )
  contrasts(subset$exposure) <- stats::contr.treatment(c("A", comparison))
  risk <- subset$eligible
  # Keep genuine index-day deaths, and exclude zero-time censoring.
  if (outcome$method == "cox") {
    risk <- risk & (subset$time > 0 |
      (outcome$family == "death" & subset$event == 1))
  }
  list(
    data = subset, include = risk,
    candidates = subset[risk, , drop = FALSE]
  )
}
