# Authored by David Hippisley-Cox
# project: gold_oxcprd_001b
# analysis plan version: NA
rm(list = ls())
gc()
source("{{STUDY_001B_ROOT}}/gold/rfiles/utils/setup.R")
init_script_logger("ons_death_dedup.r")


# ---------------------------------------------------------------------
# ------------------ notes ------------------
# ---------------------------------------------------------------------
# Purpose:
# Deduplicate ONS death records to exactly one output row per `patid`,
# while preserving a full row-level audit trail and patient-level status.
#
# Inputs:
# - `oxcprd_001b_gold_death_patient.txt` (raw linked ONS death rows)
#
# Outputs:
# - `*_deduplicated.txt`: final one-row-per-patid dataset
# - `*_dedup_log.txt`: row-level keep/remove decisions and reasons
# - `*_dedup_patient_status.txt`: patient-level dedup outcome summary
#
# Algorithm summary:
# 1) Classify duplicate groups (`patid`) into:
#    - `unique`
#    - `clinically_identical_match` (identical non-admin fields)
#    - `missing_vs_present_only` (differences are only NA vs non-NA)
#    - `strict_no_na_duplicate_match` (true conflicting coded values)
# 2) For `clinically_identical_match`, keep the first row and remove the rest.
# 3) For `missing_vs_present_only`, merge rows by taking first non-missing
#    value per field to create one patient-level record.
# 4) For `strict_no_na_duplicate_match`, rank rows lexicographically using
#    this strict hierarchy (first difference wins):
#    - date of death present
#    - underlying cause present
#    - COVID underlying preference (`U071` over `U072`)
#    - avoid ill-defined ICD-10 (`R*`)
#    - avoid `X59.*` unspecified external cause
#    - prefer more specific underlying ICD-10
#    - prefer row with more distinct coding values
#    - prefer higher-priority ICD-10 chapter
#    - prefer richer supplementary coding
#    - deterministic tie-break by original row order
# 5) If a strict group has conflicting non-missing dates of death,
#    remove all rows for that `patid` from the final deduplicated dataset
#    and record exclusion in logs/status.
# 6) Write row-level log, patient-level status summary, and final output.
#
# Notes:
# - Administrative columns (`neo_nate_flag`, `pod_*`) are excluded from
#   duplicate conflict detection.
# - Final invariant: `nrow(dedup_out) == uniqueN(dedup_out$patid)`.

# ---------------------------------------------------------------------
# ------------------ filepaths ------------------
# ---------------------------------------------------------------------
rawdata_dir <- getOption("rawdatadir")
linked_data_dir <- file.path(rawdata_dir, "linked_data")
ons_death_dir <- file.path(linked_data_dir, "death_patient")
base_name <- "oxcprd_001b_gold_death_patient"
ons_death <- file.path(ons_death_dir, paste0(base_name, ".txt"))
ons_death_dedup <- file.path(
  ons_death_dir, paste0(base_name, "_deduplicated.txt")
)
dedup_log_path <- file.path(ons_death_dir, paste0(base_name, "_dedup_log.txt"))
dedup_patient_status_path <- file.path(
  ons_death_dir, paste0(base_name, "_dedup_patient_status.txt")
)

# ---------------------------------------------------------------------
# ------------------ helpers ------------------
# ---------------------------------------------------------------------
clean_chr <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  x
}

icd10_is_specific <- function(code) {
  code <- clean_chr(code)
  n <- nchar(code)
  last <- ifelse(!is.na(code) & n > 0, substr(code, n, n), NA_character_)
  as.integer(!is.na(code) & n >= 4 & !(last %chin% c("8", "9")))
}

icd10_is_ill_defined <- function(code) {
  code <- clean_chr(code)
  as.integer(!is.na(code) & substr(code, 1, 1) == "R")
}

icd10_prefer_covid <- function(code) {
  code <- clean_chr(code)

  pref <- fcase(
    code == "U071", "covid_confirmed",
    code == "U072", "covid_unconfirmed",
    default        = "not_covid"
  )

  factor(
    pref,
    levels = c(
      "covid_confirmed",
      "covid_unconfirmed",
      "not_covid"
    ),
    ordered = TRUE
  )
}

icd10_is_x59_unspecified <- function(code) {
  code <- clean_chr(code)
  as.integer(!is.na(code) & toupper(substr(code, 1, 3)) == "X59")
}

count_distinct_coding_values <- function(DT,
                                         uc_icd10_cols,
                                         uc_icd9_cols,
                                         s_cod_cols,
                                         icd9_orig_cols) {
  n <- nrow(DT)
  out <- integer(n)

  all_cols <- unique(c(
    uc_icd10_cols,
    uc_icd9_cols,
    s_cod_cols,
    icd9_orig_cols
  ))

  all_cols <- all_cols[all_cols %chin% names(DT)]
  if (length(all_cols) == 0L) {
    return(out)
  }

  for (i in seq_len(n)) {
    vals <- unlist(DT[i, ..all_cols], use.names = FALSE)
    vals <- clean_chr(vals)
    vals <- vals[!is.na(vals)]
    out[i] <- uniqueN(vals)
  }

  out
}

icd10_chapter_rank <- function(code) {
  code <- clean_chr(code)
  first <- ifelse(is.na(code), NA_character_, toupper(substr(code, 1, 1)))

  #  abritary ranking of ICD-10 chapters for tie-breaking
  lev <- c(
    "V", "W", "X", "Y",
    "C", "D",
    "I",
    "J",
    "A", "B", "E", "F", "G", "H", "K", "L", "M", "N",
    "O", "P", "Q", "S", "T", "U", "Z",
    "R"
  )

  factor(first, levels = lev, ordered = TRUE)
}

first_non_missing <- function(x) {
  x <- clean_chr(x)
  x <- x[!is.na(x)]
  if (length(x) == 0L) NA_character_ else x[1]
}

sup_stats_one_row <- function(codes, uc_val) {
  codes <- clean_chr(codes)
  codes <- codes[!is.na(codes)]

  if (length(codes) == 0L) {
    return(list(
      n_suppl = 0L,
      n_sup_unique = 0L,
      n_sup_specific = 0L,
      n_sup_non_ill = 0L
    ))
  }

  spec <- icd10_is_specific(codes)
  ill <- icd10_is_ill_defined(codes)

  list(
    n_suppl        = length(codes),
    n_sup_unique   = uniqueN(codes),
    n_sup_specific = sum(spec, na.rm = TRUE),
    n_sup_non_ill  = sum(ill == 0L, na.rm = TRUE)
  )
}

row_first_nonmissing_across_cols <- function(DT, cols) {
  if (length(cols) == 0L) {
    return(rep(NA_character_, nrow(DT)))
  }
  mat <- as.matrix(DT[, ..cols])
  apply(mat, 1, first_non_missing)
}

first_decisive_step <- function(a, b) {
  if (a$has_dod > b$has_dod) {
    return("DoD present")
  }
  if (a$has_uc > b$has_uc) {
    return("underlying present")
  }
  if (as.integer(a$uc_covid) < as.integer(b$uc_covid)) {
    return("COVID U071>U072")
  }
  if (a$uc_ill < b$uc_ill) {
    return("avoid ill-defined/R")
  }
  if (a$uc_x59 < b$uc_x59) {
    return("avoid X59.*")
  }
  if (a$uc_spec > b$uc_spec) {
    return("specific underlying")
  }
  if (a$row_distinct_code_count > b$row_distinct_code_count) {
    return("most distinct coding values")
  }
  if (!is.na(a$uc_chap) && !is.na(b$uc_chap) && a$uc_chap < b$uc_chap) {
    return("preferred chapter")
  }
  if (a$n_suppl > b$n_suppl) {
    return("supplementary richness/quality")
  }
  if (a$n_sup_specific > b$n_sup_specific) {
    return("supplementary richness/quality")
  }
  if (a$n_sup_unique > b$n_sup_unique) {
    return("supplementary richness/quality")
  }
  if (a$n_sup_non_ill > b$n_sup_non_ill) {
    return("supplementary richness/quality")
  }
  "deterministic tie-break"
}

first_removal_reason <- function(best, cur) {
  prefix <- "removed under strict deduplication hierarchy: "
  if (best$has_dod > cur$has_dod) {
    return(paste0(prefix, "missing date of death"))
  }
  if (best$has_uc > cur$has_uc) {
    return(paste0(prefix, "missing underlying cause"))
  }
  if (as.integer(best$uc_covid) < as.integer(cur$uc_covid)) {
    return(paste0(prefix, "COVID-19 underlying cause (prefer U071 over U072)"))
  }
  if (best$uc_ill < cur$uc_ill) {
    return(paste0(prefix, "underlying cause is ill-defined (R-chapter)"))
  }
  if (best$uc_x59 < cur$uc_x59) {
    return(paste0(
      prefix,
      "underlying cause is X59.* (unspecified external cause), ",
      "treated as less specific"
    ))
  }
  if (best$uc_spec > cur$uc_spec) {
    return(paste0(prefix, "underlying cause less specific"))
  }
  if (!is.na(best$row_distinct_code_count) &&
    !is.na(cur$row_distinct_code_count) &&
    best$row_distinct_code_count > cur$row_distinct_code_count) {
    return(paste0(prefix, "fewer distinct coding values than retained record"))
  }
  if (
    !is.na(best$uc_chap) &&
      !is.na(cur$uc_chap) &&
      best$uc_chap < cur$uc_chap
  ) {
    return(paste0(
      prefix,
      "underlying chapter less preferred than retained record"
    ))
  }
  if (best$n_suppl > cur$n_suppl) {
    return(paste0(prefix, "fewer supplementary cause codes"))
  }
  if (best$n_sup_specific > cur$n_sup_specific) {
    return(paste0(prefix, "fewer specific supplementary ICD-10 codes"))
  }
  if (best$n_sup_unique > cur$n_sup_unique) {
    return(paste0(prefix, "fewer unique supplementary cause codes"))
  }
  if (best$n_sup_non_ill > cur$n_sup_non_ill) {
    return(paste0(prefix, "more ill-defined supplementary codes (R-chapter)"))
  }
  paste0(
    prefix,
    "tie with retained record; removed by deterministic ",
    "tie-break (orig_row_index)"
  )
}

# ---------------------------------------------------------------------
# ------------------ run ------------------
# ---------------------------------------------------------------------

dod_col <- "reg_date_of_death"
admin_cols <- c(
  "neo_nate_flag",
  "pod_code",
  "pod_establishment_type",
  "pod_nhs_establishment"
)

# 1) Read and normalize raw ONS death rows.
log_info_msg("Reading: ", ons_death)
DT <- fread(
  ons_death,
  sep = "\t",
  colClasses = "character",
  na.strings = c("", "NA"),
  showProgress = TRUE
)

stopifnot("patid" %chin% names(DT))

for (j in names(DT)) set(DT, j = j, value = clean_chr(DT[[j]]))

orig_cols <- names(DT)

# 2) Classify duplicate patterns at patid level:
#    unique, clinically-identical, strict conflict, or missing-vs-present-only.
dup_patids <- DT[, .N, by = patid][N > 1L, patid]

DT[, match_type := "unique"]
if (length(dup_patids) > 0L) {
  dups <- DT[patid %chin% dup_patids]
  sig_cols <- setdiff(orig_cols, c("patid", admin_cols))
  dups[, row_sig := do.call(
    paste,
    c(lapply(.SD, function(z) fifelse(is.na(z), "<NA>", z)), sep = "||")
  ), .SDcols = sig_cols]

  sig_tbl <- dups[, .(n_distinct_row_sigs = uniqueN(row_sig)), by = patid]
  clinically_identical_patids <- sig_tbl[n_distinct_row_sigs == 1L, patid]

  cols_to_check <- setdiff(orig_cols, c("patid", admin_cols))
  cols_to_check <- cols_to_check[cols_to_check != "match_type"]

  dlong <- melt(
    dups[, c("patid", cols_to_check), with = FALSE],
    id.vars = "patid",
    variable.name = "col",
    value.name = "val",
    variable.factor = FALSE
  )

  strict_patids <- dlong[, .(
    nuniq = uniqueN(val[!is.na(val)])
  ), by = .(patid, col)][
    nuniq > 1L, unique(patid)
  ]

  missing_only_patids <- setdiff(
    dup_patids,
    union(clinically_identical_patids, strict_patids)
  )

  DT[
    patid %chin% clinically_identical_patids,
    match_type := "clinically_identical_match"
  ]
  DT[patid %chin% strict_patids, match_type := "strict_no_na_duplicate_match"]
  DT[patid %chin% missing_only_patids, match_type := "missing_vs_present_only"]

  rm(dups, dlong)
  gc()
}

# 3) Build row-level log for unique + clinically-identical records.
log_up <- DT[match_type %chin% c("unique", "clinically_identical_match")]
log_up[, row_index := seq_len(.N), by = patid]
log_up[, kept_in_final := (
  match_type == "unique"
) | (
  match_type == "clinically_identical_match" & row_index == 1L
)]
log_up[, dedup_reason := fifelse(
  match_type == "unique",
  "kept: unique record (no duplicates for this patid)",
  fifelse(
    row_index == 1L,
    paste0(
      "kept: representative row among duplicates identical across ",
      "non-administrative fields"
    ),
    "removed: identical duplicate row across non-administrative fields"
  )
)]
log_up[, row_index := NULL]

# 4) Build row-level log for missing-vs-present-only records,
#    then create one merged patient record (first non-missing per field).
log_mvp <- DT[match_type == "missing_vs_present_only"]
if (nrow(log_mvp) > 0L) {
  log_mvp[, row_index := seq_len(.N), by = patid]
  log_mvp[, kept_in_final := (row_index == 1L)]
  log_mvp[, dedup_reason := fifelse(
    row_index == 1L,
    paste0(
      "kept: merged record from multiple rows ",
      "(differences only missing vs present)"
    ),
    paste0(
      "removed: merged with other rows for this patid ",
      "(differences only missing vs present; ",
      "patient-level combined record created)"
    )
  )]
  log_mvp[, row_index := NULL]
}

mvp_merged <- if (nrow(log_mvp) > 0L) {
  mvp_src <- DT[match_type == "missing_vs_present_only", ..orig_cols]
  mvp_src[
    ,
    lapply(.SD, first_non_missing),
    by = patid,
    .SDcols = setdiff(orig_cols, "patid")
  ]
} else {
  NULL
}

# 5) Strict deduplication for true conflicting duplicates:
#    rank rows lexicographically by the predefined clinical hierarchy.
strict_dt <- DT[match_type == "strict_no_na_duplicate_match"]
if (nrow(strict_dt) > 0L) {
  uc_icd10_cols <- grep("^s_underlying_cod_icd10", orig_cols, value = TRUE)
  uc_icd9_cols <- grep("^s_underlying_cod_icd9", orig_cols, value = TRUE)
  s_cod_cols <- grep("^s_cod_code_", orig_cols, value = TRUE)
  icd9_orig_cols <- grep("^icd9_orig_mention_", orig_cols, value = TRUE)

  strict_dedup_group <- function(rows) {
    rows <- as.data.table(copy(rows))
    n <- nrow(rows)
    orig_idx <- seq_len(n)

    # DoD handling + conflict exclusion
    dod_parsed <- if (dod_col %chin% names(rows)) {
      parse_hes_ons_date(rows[[dod_col]])
    } else {
      as.IDate(rep(NA, n))
    }
    has_dod <- !is.na(dod_parsed)
    ndod <- uniqueN(dod_parsed[!is.na(dod_parsed)])

    kept <- rep(FALSE, n)
    reason <- rep(NA_character_, n)

    if (ndod > 1L) {
      reason[] <- paste0(
        "removed: conflicting date of death values ",
        "(multiple distinct non-missing dates) for this patid; ",
        "excluded from deduplicated dataset"
      )
      return(list(kept_in_final = kept, dedup_reason = reason))
    }

    # Prefer ICD-10 underlying cols; fallback to ICD-9 underlying cols.
    uc_icd10 <- if (length(uc_icd10_cols) > 0L) {
      row_first_nonmissing_across_cols(rows, uc_icd10_cols)
    } else {
      rep(NA_character_, n)
    }
    uc_val <- uc_icd10
    uc_source <- ifelse(!is.na(uc_val), "icd10", NA_character_)

    if (any(is.na(uc_val)) && length(uc_icd9_cols) > 0L) {
      uc_icd9 <- row_first_nonmissing_across_cols(rows, uc_icd9_cols)
      take9 <- is.na(uc_val) & !is.na(uc_icd9)
      uc_val[take9] <- uc_icd9[take9]
      uc_source[take9] <- "icd9"
    }

    has_uc <- !is.na(uc_val)

    uc_covid <- icd10_prefer_covid(uc_val)
    uc_spec <- icd10_is_specific(uc_val)
    uc_ill <- icd10_is_ill_defined(uc_val)
    uc_x59 <- icd10_is_x59_unspecified(uc_val)
    uc_chap <- icd10_chapter_rank(uc_val)

    n_suppl <- integer(n)
    n_sup_unique <- integer(n)
    n_sup_specific <- integer(n)
    n_sup_non_ill <- integer(n)

    row_distinct_code_count <- count_distinct_coding_values(
      rows,
      uc_icd10_cols = uc_icd10_cols,
      uc_icd9_cols = uc_icd9_cols,
      s_cod_cols = s_cod_cols,
      icd9_orig_cols = icd9_orig_cols
    )

    for (i in seq_len(n)) {
      cols_use <- if (!is.na(uc_source[i]) && uc_source[i] == "icd9") {
        icd9_orig_cols
      } else {
        s_cod_cols
      }
      codes <- if (length(cols_use) > 0L) {
        unlist(rows[i, ..cols_use], use.names = FALSE)
      } else {
        character(0)
      }
      st <- sup_stats_one_row(codes, uc_val[i])

      n_suppl[i] <- st$n_suppl
      n_sup_unique[i] <- st$n_sup_unique
      n_sup_specific[i] <- st$n_sup_specific
      n_sup_non_ill[i] <- st$n_sup_non_ill
    }

    R <- data.table(
      idx = orig_idx,
      has_dod = as.integer(has_dod),
      has_uc = as.integer(has_uc),
      uc_covid = uc_covid,
      uc_spec = uc_spec,
      uc_ill = uc_ill,
      uc_x59 = uc_x59,
      row_distinct_code_count = row_distinct_code_count,
      uc_chap = uc_chap,
      n_suppl = n_suppl,
      n_sup_specific = n_sup_specific,
      n_sup_unique = n_sup_unique,
      n_sup_non_ill = n_sup_non_ill,
      orig_row_index = orig_idx
    )

    # Ranking order is the strict hierarchy (first differing criterion wins).
    setorder(
      R,
      -has_dod,
      -has_uc,
      uc_covid,
      uc_ill,
      uc_x59,
      -uc_spec,
      -row_distinct_code_count,
      uc_chap,
      -n_suppl,
      -n_sup_specific,
      -n_sup_unique,
      -n_sup_non_ill,
      orig_row_index,
      na.last = TRUE
    )

    best_idx <- R$idx[1L]
    kept[best_idx] <- TRUE

    best <- R[1L]
    runner_up <- if (nrow(R) >= 2L) R[2L] else NULL
    decisive_step <- if (!is.null(runner_up)) {
      first_decisive_step(best, runner_up)
    } else {
      "single strict duplicate row after filtering"
    }
    reason[best_idx] <- paste0(
      paste0(
        "kept: best record under strict deduplication hierarchy; ",
        "decisive step = "
      ),
      decisive_step
    )

    for (k in 2:nrow(R)) {
      i <- R$idx[k]
      reason[i] <- first_removal_reason(best, R[k])
    }

    list(kept_in_final = kept, dedup_reason = reason)
  }

  strict_dt[
    ,
    c("kept_in_final", "dedup_reason") := strict_dedup_group(.SD),
    by = patid
  ]
}

# 6) Combine per-branch logs into one full audit log.
logs <- list(log_up)
if (!is.null(log_mvp) && nrow(log_mvp) > 0L) logs <- c(logs, list(log_mvp))
if (nrow(strict_dt) > 0L) logs <- c(logs, list(strict_dt))

dedup_log <- rbindlist(logs, use.names = TRUE, fill = TRUE)
setorder(dedup_log, patid)

log_info_msg("Writing log: ", dedup_log_path)
fwrite(dedup_log, dedup_log_path, sep = "\t")

# 7) Summarize patient-level dedup outcomes.
dedup_patient_status <- dedup_log[, .(
  match_type_any = match_type[1L],
  any_kept = any(kept_in_final),
  all_removed = all(!kept_in_final),
  conflicting_dod = any(grepl(
    "conflicting date of death values",
    dedup_reason,
    fixed = TRUE
  )),
  merged_missing_vs_present = all(match_type == "missing_vs_present_only"),
  n_rows = .N,
  n_rows_kept = sum(kept_in_final)
), by = patid]

dedup_patient_status[, patient_outcome := fcase(
  conflicting_dod, "excluded_conflicting_DoD",
  merged_missing_vs_present, "merged_missing_vs_present_only",
  any_kept & match_type_any == "unique", "unique_kept",
  any_kept & match_type_any == "clinically_identical_match",
  "clinically_identical_kept",
  any_kept & match_type_any == "strict_no_na_duplicate_match", "strict_kept",
  default = "other_removed"
)]

log_info_msg("Writing patient status: ", dedup_patient_status_path)
fwrite(dedup_patient_status, dedup_patient_status_path, sep = "\t")

# 8) Build final deduplicated dataset (one row per patid) and write outputs.
keep_up <- log_up[kept_in_final == TRUE, ..orig_cols]
keep_strict <- if (nrow(strict_dt) > 0L) {
  strict_dt[kept_in_final == TRUE, ..orig_cols]
} else {
  NULL
}

final_list <- list(keep_up)
if (!is.null(mvp_merged) && nrow(mvp_merged) > 0L) {
  final_list <- c(final_list, list(mvp_merged))
}
if (!is.null(keep_strict) && nrow(keep_strict) > 0L) {
  final_list <- c(final_list, list(keep_strict))
}

dedup_out <- rbindlist(final_list, use.names = TRUE, fill = TRUE)
setorder(dedup_out, patid)

stopifnot(nrow(dedup_out) == uniqueN(dedup_out$patid))

log_info_msg(sprintf(
  "[dedup] original rows = %d, deduplicated rows = %d, unique patids = %d",
  nrow(DT), nrow(dedup_out), uniqueN(dedup_out$patid)
))

log_info_msg("Writing deduplicated dataset: ", ons_death_dedup)
fwrite(dedup_out, ons_death_dedup, sep = "\t")

log_info_msg("Done.")
