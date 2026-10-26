-- Authored by David Hippisley-Cox
-- project: gold_oxcprd_001b
-- analysis plan version: NA
-- post_dementia_outcomes_mariadb_pipeline_v1.sql
-- MariaDB 12.3.2 rewrite of:
--   extract_outcomes.R
--   join_desc_outcomes.R
--   outcome_window.R
--
-- The pipeline is deliberately set based. A stored procedure is not needed
-- for these six fixed outcomes and would require less transparent dynamic SQL.
--
-- Main outputs:
--   outcome_log_events
--   preproc_outcome_events
--   outcome_eligibility_log
--   outcome_records_removed_ineligible
--   preproc_outcome_eligible_events
--   outcome_pre_window_exclusions
--   outcome_window_selected
--   preproc_outcome_features_long
--   feat_alcohol_related_psychiatric
--   feat_care_home
--   feat_depression_anxiety
--   feat_drug_related_psychiatric
--   feat_medication
--   feat_neuropsychiatric
--
-- Required codelist tables:
--   alcohol_related_psychiatric_codes_GOLD
--   care_home_codes_GOLD
--   depression_anxiety_codes_GOLD
--   drug_related_psychiatric_codes_GOLD
--   medication_codes_GOLD
--   neuropsychiatric_codes_GOLD
--
-- Required cohort columns:
--   preproc_base (
--       patid, yob, tod, merged_death,
--       latest_4, earliest_4, dementia_eventdate
--   )
--
-- Recommended source indexes, created once outside this pipeline:
--   pc_clinical (medcode, eventdate, patid)
--   pc_test (medcode, eventdate, patid)
--   pc_referral (medcode, eventdate, patid)
--   pc_therapy (prodcode, eventdate, patid)
--   preproc_base (patid)
--
-- Window definitions reproduce outcome_window.R exactly:
--   pre_3y_1y : [-1095, -365) days from dementia
--   pre_1y_0y : [ -365,     0) days from dementia
--   post_dem   : [    0,  +Inf) days from dementia
--
-- As in create_outcome_window.R, a pre-window event removes all window events
-- for that patient/outcome prefix. Otherwise, only the earliest event across
-- all three windows is selected. Ties are resolved deterministically by
-- source rank, code, and description because SQL source rows have no file-row
-- order equivalent to the R input order.

/* -------------------------------------------------------------------------
   1. Session-scoped unified codelists and configured outcome prefixes
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_post_dementia_codes;
CREATE TEMPORARY TABLE tmp_post_dementia_codes (
    feature VARCHAR(64) NOT NULL,
    outcome_prefix VARCHAR(64) NULL,
    medcode INT UNSIGNED NULL,
    prodcode BIGINT UNSIGNED NULL,
    description TEXT NULL,
    drugtypes VARCHAR(255) NULL,
    nsp_subtype VARCHAR(255) NULL,
    alcohol_detoxification VARCHAR(255) NULL
) ENGINE=InnoDB;

INSERT INTO tmp_post_dementia_codes (
    feature,
    outcome_prefix,
    medcode,
    description
)
SELECT
    'alcohol_related_psychiatric',
    'alcohol_related_psychiatric',
    medcode,
    description
FROM alcohol_related_psychiatric_codes_GOLD
WHERE medcode IS NOT NULL;

INSERT INTO tmp_post_dementia_codes (
    feature,
    outcome_prefix,
    medcode,
    description
)
SELECT
    'care_home',
    'care_home',
    medcode,
    description
FROM care_home_codes_GOLD
WHERE medcode IS NOT NULL;

INSERT INTO tmp_post_dementia_codes (
    feature,
    outcome_prefix,
    medcode,
    description
)
SELECT
    'depression_anxiety',
    'depression_anxiety',
    medcode,
    description
FROM depression_anxiety_codes_GOLD
WHERE medcode IS NOT NULL;

INSERT INTO tmp_post_dementia_codes (
    feature,
    outcome_prefix,
    medcode,
    description
)
SELECT
    'drug_related_psychiatric',
    'drug_related_psychiatric',
    medcode,
    description
FROM drug_related_psychiatric_codes_GOLD
WHERE medcode IS NOT NULL;

INSERT INTO tmp_post_dementia_codes (
    feature,
    outcome_prefix,
    prodcode,
    description,
    drugtypes,
    alcohol_detoxification
)
SELECT
    'medication',
    drugtypes,
    prodcode,
    description,
    drugtypes,
    CAST(alcohol_detoxification AS CHAR)
FROM medication_codes_GOLD
WHERE prodcode IS NOT NULL;

INSERT INTO tmp_post_dementia_codes (
    feature,
    outcome_prefix,
    medcode,
    description,
    nsp_subtype
)
SELECT
    'neuropsychiatric',
    nsp_subtype,
    medcode,
    description,
    nsp_subtype
FROM neuropsychiatric_codes_GOLD
WHERE medcode IS NOT NULL;

ALTER TABLE tmp_post_dementia_codes
    ADD INDEX idx_tmp_outcome_medcode (medcode, feature),
    ADD INDEX idx_tmp_outcome_prodcode (prodcode, feature);

DROP TEMPORARY TABLE IF EXISTS tmp_outcome_prefixes;
CREATE TEMPORARY TABLE tmp_outcome_prefixes (
    feature VARCHAR(64) NOT NULL,
    outcome_prefix VARCHAR(64) NOT NULL,
    PRIMARY KEY (outcome_prefix)
) ENGINE=InnoDB;

INSERT INTO tmp_outcome_prefixes (
    feature,
    outcome_prefix
)
VALUES
    ('alcohol_related_psychiatric', 'alcohol_related_psychiatric'),
    ('care_home', 'care_home'),
    ('depression_anxiety', 'depression_anxiety'),
    ('drug_related_psychiatric', 'drug_related_psychiatric'),
    ('medication', 'antipsychotics'),
    ('medication', 'antidepressants'),
    ('medication', 'antipsychotics_antidepressants'),
    ('medication', 'anxiety_and_hypnotics'),
    ('neuropsychiatric', 'psychosis'),
    ('neuropsychiatric', 'delirium'),
    ('neuropsychiatric', 'affective'),
    ('neuropsychiatric', 'challenging');

/* -------------------------------------------------------------------------
   2. Extract, describe, and apply lifetime/time-in-practice filtering
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS outcome_log_events;

CREATE TABLE outcome_log_events
ENGINE=InnoDB
AS
SELECT
    e.feature,
    e.outcome_prefix,
    e.source_table,
    e.source_dataset,
    e.source_rank,
    e.patid,
    e.eventdate,
    e.medcode,
    e.prodcode,
    e.enttype,
    e.adid,
    e.description,
    e.drugtypes,
    e.nsp_subtype,
    e.alcohol_detoxification,
    cb.yob,
    cb.tod,
    cb.merged_death,
    CASE
        WHEN e.eventdate > cb.yob
         AND (cb.tod IS NULL OR e.eventdate <= cb.tod)
         AND (
                cb.merged_death IS NULL
                OR e.eventdate <= cb.merged_death
             )
            THEN 1
        ELSE 0
    END AS keep_flag
FROM (
    SELECT
        cd.feature,
        cd.outcome_prefix,
        'clinical' AS source_table,
        'cprd' AS source_dataset,
        1 AS source_rank,
        c.patid,
        c.eventdate,
        c.medcode,
        CAST(NULL AS UNSIGNED) AS prodcode,
        c.enttype,
        c.adid,
        cd.description,
        cd.drugtypes,
        cd.nsp_subtype,
        cd.alcohol_detoxification
    FROM tmp_post_dementia_codes AS cd
    INNER JOIN pc_clinical AS c
        ON c.medcode = cd.medcode
    WHERE cd.medcode IS NOT NULL

    UNION ALL

    SELECT
        cd.feature,
        cd.outcome_prefix,
        'referral' AS source_table,
        'cprd' AS source_dataset,
        2 AS source_rank,
        r.patid,
        r.eventdate,
        r.medcode,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cd.description,
        cd.drugtypes,
        cd.nsp_subtype,
        cd.alcohol_detoxification
    FROM tmp_post_dementia_codes AS cd
    INNER JOIN pc_referral AS r
        ON r.medcode = cd.medcode
    WHERE cd.medcode IS NOT NULL

    UNION ALL

    SELECT
        cd.feature,
        cd.outcome_prefix,
        'test' AS source_table,
        'cprd' AS source_dataset,
        3 AS source_rank,
        t.patid,
        t.eventdate,
        t.medcode,
        CAST(NULL AS UNSIGNED) AS prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cd.description,
        cd.drugtypes,
        cd.nsp_subtype,
        cd.alcohol_detoxification
    FROM tmp_post_dementia_codes AS cd
    INNER JOIN pc_test AS t
        ON t.medcode = cd.medcode
    WHERE cd.medcode IS NOT NULL

    UNION ALL

    SELECT
        cd.feature,
        cd.outcome_prefix,
        'therapy' AS source_table,
        'cprd' AS source_dataset,
        1 AS source_rank,
        th.patid,
        th.eventdate,
        CAST(NULL AS UNSIGNED) AS medcode,
        th.prodcode,
        CAST(NULL AS UNSIGNED) AS enttype,
        CAST(NULL AS UNSIGNED) AS adid,
        cd.description,
        cd.drugtypes,
        cd.nsp_subtype,
        cd.alcohol_detoxification
    FROM tmp_post_dementia_codes AS cd
    INNER JOIN pc_therapy AS th
        ON th.prodcode = cd.prodcode
    WHERE cd.prodcode IS NOT NULL
) AS e
INNER JOIN preproc_base AS cb
    ON cb.patid = e.patid
WHERE e.eventdate IS NOT NULL;

DROP TABLE IF EXISTS preproc_outcome_events;

CREATE TABLE preproc_outcome_events
ENGINE=InnoDB
AS
SELECT
    feature,
    outcome_prefix,
    source_table,
    source_dataset,
    source_rank,
    patid,
    eventdate,
    medcode,
    prodcode,
    enttype,
    adid,
    description,
    drugtypes,
    nsp_subtype,
    alcohol_detoxification
FROM outcome_log_events
WHERE keep_flag = 1;

ALTER TABLE preproc_outcome_events
    ADD INDEX idx_outcome_prefix_patid_date (
        outcome_prefix,
        patid,
        eventdate
    ),
    ADD INDEX idx_outcome_feature_source (feature, source_table),
    ADD INDEX idx_outcome_medcode (medcode),
    ADD INDEX idx_outcome_prodcode (prodcode);

/* -------------------------------------------------------------------------
   3. Eligibility relative to latest_4 and earliest_4
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_outcome_group_eligibility;

CREATE TEMPORARY TABLE tmp_outcome_group_eligibility
ENGINE=InnoDB
AS
SELECT
    e.patid,
    e.outcome_prefix,
    CASE
        WHEN MAX(cb.latest_4 IS NULL) = 1 THEN NULL
        ELSE MAX(
            CASE WHEN e.eventdate < cb.latest_4 THEN 1 ELSE 0 END
        )
    END AS has_early_cprd
FROM preproc_outcome_events AS e
INNER JOIN preproc_base AS cb
    ON cb.patid = e.patid
GROUP BY
    e.patid,
    e.outcome_prefix;

ALTER TABLE tmp_outcome_group_eligibility
    ADD INDEX idx_tmp_outcome_eligibility_prefix_patid (
        outcome_prefix,
        patid
    );

DROP TABLE IF EXISTS outcome_eligibility_log;

CREATE TABLE outcome_eligibility_log
ENGINE=InnoDB
AS
SELECT
    e.feature,
    e.outcome_prefix,
    e.source_table,
    e.source_dataset,
    e.source_rank,
    e.patid,
    e.eventdate,
    e.medcode,
    e.prodcode,
    e.enttype,
    e.adid,
    e.description,
    e.drugtypes,
    e.nsp_subtype,
    e.alcohol_detoxification,
    cb.latest_4,
    cb.earliest_4,
    cb.dementia_eventdate,
    g.has_early_cprd,
    CASE
        WHEN g.has_early_cprd = 1 THEN 0
        WHEN g.has_early_cprd = 0
         AND e.eventdate <= cb.earliest_4
            THEN 1
        WHEN g.has_early_cprd = 0
         AND cb.earliest_4 IS NOT NULL
         AND e.eventdate > cb.earliest_4
            THEN 0
        ELSE NULL
    END AS eligible
FROM preproc_outcome_events AS e
INNER JOIN preproc_base AS cb
    ON cb.patid = e.patid
INNER JOIN tmp_outcome_group_eligibility AS g
    ON g.patid = e.patid
   AND g.outcome_prefix <=> e.outcome_prefix;

ALTER TABLE outcome_eligibility_log
    ADD INDEX idx_outcome_eligibility_filter (
        eligible,
        outcome_prefix,
        patid,
        eventdate
    );

DROP TABLE IF EXISTS outcome_records_removed_ineligible;

CREATE TABLE outcome_records_removed_ineligible
ENGINE=InnoDB
AS
SELECT
    feature,
    outcome_prefix,
    patid,
    eventdate,
    description,
    drugtypes,
    nsp_subtype,
    alcohol_detoxification,
    has_early_cprd
FROM outcome_eligibility_log
WHERE eligible = 0;

DROP TABLE IF EXISTS preproc_outcome_eligible_events;

CREATE TABLE preproc_outcome_eligible_events
ENGINE=InnoDB
AS
SELECT
    feature,
    outcome_prefix,
    source_table,
    source_rank,
    patid,
    eventdate,
    medcode,
    prodcode,
    description,
    drugtypes,
    nsp_subtype,
    alcohol_detoxification,
    dementia_eventdate
FROM outcome_eligibility_log
WHERE eligible = 1;

ALTER TABLE preproc_outcome_eligible_events
    ADD INDEX idx_eligible_prefix_patid_date (
        outcome_prefix,
        patid,
        eventdate
    );

/* -------------------------------------------------------------------------
   4. Earliest pre-window exclusions and earliest selected window events
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS outcome_pre_window_exclusions;

CREATE TABLE outcome_pre_window_exclusions
ENGINE=InnoDB
AS
SELECT
    ranked.feature,
    ranked.outcome_prefix,
    ranked.patid,
    ranked.dementia_eventdate,
    ranked.eventdate,
    ranked.description
FROM (
    SELECT
        e.*,
        ROW_NUMBER() OVER (
            PARTITION BY e.outcome_prefix, e.patid
            ORDER BY
                e.eventdate,
                e.source_rank,
                COALESCE(e.medcode, 0),
                COALESCE(e.prodcode, 0),
                e.description
        ) AS event_rank
    FROM preproc_outcome_eligible_events AS e
    WHERE e.dementia_eventdate IS NOT NULL
      AND e.eventdate < DATE_SUB(
            e.dementia_eventdate,
            INTERVAL 1095 DAY
          )
) AS ranked
WHERE ranked.event_rank = 1;

ALTER TABLE outcome_pre_window_exclusions
    ADD INDEX idx_pre_window_exclusion_prefix_patid (
        outcome_prefix,
        patid
    );

DROP TABLE IF EXISTS outcome_window_selected;

CREATE TABLE outcome_window_selected
ENGINE=InnoDB
AS
SELECT
    ranked.feature,
    ranked.outcome_prefix,
    ranked.patid,
    ranked.dementia_eventdate,
    ranked.eventdate,
    ranked.description,
    CASE
        WHEN ranked.eventdate < DATE_SUB(
                ranked.dementia_eventdate,
                INTERVAL 365 DAY
             )
            THEN 'pre_3y_1y'
        WHEN ranked.eventdate < ranked.dementia_eventdate
            THEN 'pre_1y_0y'
        ELSE 'post_dem'
    END AS window_bin
FROM (
    SELECT
        e.*,
        ROW_NUMBER() OVER (
            PARTITION BY e.outcome_prefix, e.patid
            ORDER BY
                e.eventdate,
                e.source_rank,
                COALESCE(e.medcode, 0),
                COALESCE(e.prodcode, 0),
                e.description
        ) AS event_rank
    FROM preproc_outcome_eligible_events AS e
    LEFT JOIN outcome_pre_window_exclusions AS x
        ON x.patid = e.patid
       AND x.outcome_prefix <=> e.outcome_prefix
    WHERE x.patid IS NULL
      AND e.dementia_eventdate IS NOT NULL
      AND e.eventdate >= DATE_SUB(
            e.dementia_eventdate,
            INTERVAL 1095 DAY
          )
) AS ranked
WHERE ranked.event_rank = 1;

ALTER TABLE outcome_window_selected
    ADD INDEX idx_window_selected_prefix_patid (
        outcome_prefix,
        patid
    );

/* -------------------------------------------------------------------------
   5. Normalized patient-level outcome features
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS preproc_outcome_features_long;

CREATE TABLE preproc_outcome_features_long
ENGINE=InnoDB
AS
SELECT
    cb.patid,
    cb.dementia_eventdate,
    p.feature,
    p.outcome_prefix,
    x.eventdate AS excluded_pre_window_eventdate,
    x.description AS excluded_pre_window_description,
    CASE
        WHEN s.window_bin = 'pre_3y_1y' THEN s.eventdate
        ELSE NULL
    END AS pre_3y_1y_eventdate,
    CASE
        WHEN s.window_bin = 'pre_3y_1y' THEN s.description
        ELSE NULL
    END AS pre_3y_1y_description,
    CASE
        WHEN s.window_bin = 'pre_1y_0y' THEN s.eventdate
        ELSE NULL
    END AS pre_1y_0y_eventdate,
    CASE
        WHEN s.window_bin = 'pre_1y_0y' THEN s.description
        ELSE NULL
    END AS pre_1y_0y_description,
    CASE
        WHEN s.window_bin = 'post_dem' THEN s.eventdate
        ELSE NULL
    END AS post_dem_eventdate,
    CASE
        WHEN s.window_bin = 'post_dem' THEN s.description
        ELSE NULL
    END AS post_dem_description
FROM preproc_base AS cb
CROSS JOIN tmp_outcome_prefixes AS p
LEFT JOIN outcome_pre_window_exclusions AS x
    ON x.patid = cb.patid
   AND x.outcome_prefix = p.outcome_prefix
LEFT JOIN outcome_window_selected AS s
    ON s.patid = cb.patid
   AND s.outcome_prefix = p.outcome_prefix
WHERE cb.patid IS NOT NULL
  AND cb.dementia_eventdate IS NOT NULL;

ALTER TABLE preproc_outcome_features_long
    ADD UNIQUE INDEX idx_outcome_features_prefix_patid (
        outcome_prefix,
        patid
    );

/* -------------------------------------------------------------------------
   6. R-compatible simple feature tables
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS feat_alcohol_related_psychiatric;

CREATE TABLE feat_alcohol_related_psychiatric
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    excluded_pre_window_eventdate
        AS alcohol_related_psychiatric_excluded_pre_window_eventdate,
    excluded_pre_window_description
        AS alcohol_related_psychiatric_excluded_pre_window_description,
    pre_3y_1y_eventdate
        AS alcohol_related_psychiatric_pre_3y_1y_eventdate,
    pre_3y_1y_description
        AS alcohol_related_psychiatric_pre_3y_1y_description,
    pre_1y_0y_eventdate
        AS alcohol_related_psychiatric_pre_1y_0y_eventdate,
    pre_1y_0y_description
        AS alcohol_related_psychiatric_pre_1y_0y_description,
    post_dem_eventdate
        AS alcohol_related_psychiatric_post_dem_eventdate,
    post_dem_description
        AS alcohol_related_psychiatric_post_dem_description
FROM preproc_outcome_features_long
WHERE outcome_prefix = 'alcohol_related_psychiatric';

ALTER TABLE feat_alcohol_related_psychiatric
    ADD UNIQUE INDEX idx_feat_alcohol_related_psychiatric_patid (patid);

DROP TABLE IF EXISTS feat_care_home;

CREATE TABLE feat_care_home
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    excluded_pre_window_eventdate
        AS care_home_excluded_pre_window_eventdate,
    excluded_pre_window_description
        AS care_home_excluded_pre_window_description,
    pre_3y_1y_eventdate AS care_home_pre_3y_1y_eventdate,
    pre_3y_1y_description AS care_home_pre_3y_1y_description,
    pre_1y_0y_eventdate AS care_home_pre_1y_0y_eventdate,
    pre_1y_0y_description AS care_home_pre_1y_0y_description,
    post_dem_eventdate AS care_home_post_dem_eventdate,
    post_dem_description AS care_home_post_dem_description
FROM preproc_outcome_features_long
WHERE outcome_prefix = 'care_home';

ALTER TABLE feat_care_home
    ADD UNIQUE INDEX idx_feat_care_home_patid (patid);

DROP TABLE IF EXISTS feat_depression_anxiety;

CREATE TABLE feat_depression_anxiety
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    excluded_pre_window_eventdate
        AS depression_anxiety_excluded_pre_window_eventdate,
    excluded_pre_window_description
        AS depression_anxiety_excluded_pre_window_description,
    pre_3y_1y_eventdate AS depression_anxiety_pre_3y_1y_eventdate,
    pre_3y_1y_description AS depression_anxiety_pre_3y_1y_description,
    pre_1y_0y_eventdate AS depression_anxiety_pre_1y_0y_eventdate,
    pre_1y_0y_description AS depression_anxiety_pre_1y_0y_description,
    post_dem_eventdate AS depression_anxiety_post_dem_eventdate,
    post_dem_description AS depression_anxiety_post_dem_description
FROM preproc_outcome_features_long
WHERE outcome_prefix = 'depression_anxiety';

ALTER TABLE feat_depression_anxiety
    ADD UNIQUE INDEX idx_feat_depression_anxiety_patid (patid);

DROP TABLE IF EXISTS feat_drug_related_psychiatric;

CREATE TABLE feat_drug_related_psychiatric
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    excluded_pre_window_eventdate
        AS drug_related_psychiatric_excluded_pre_window_eventdate,
    excluded_pre_window_description
        AS drug_related_psychiatric_excluded_pre_window_description,
    pre_3y_1y_eventdate
        AS drug_related_psychiatric_pre_3y_1y_eventdate,
    pre_3y_1y_description
        AS drug_related_psychiatric_pre_3y_1y_description,
    pre_1y_0y_eventdate
        AS drug_related_psychiatric_pre_1y_0y_eventdate,
    pre_1y_0y_description
        AS drug_related_psychiatric_pre_1y_0y_description,
    post_dem_eventdate
        AS drug_related_psychiatric_post_dem_eventdate,
    post_dem_description
        AS drug_related_psychiatric_post_dem_description
FROM preproc_outcome_features_long
WHERE outcome_prefix = 'drug_related_psychiatric';

ALTER TABLE feat_drug_related_psychiatric
    ADD UNIQUE INDEX idx_feat_drug_related_psychiatric_patid (patid);

/* -------------------------------------------------------------------------
   7. R-compatible medication and neuropsychiatric feature tables
   ------------------------------------------------------------------------- */

DROP TABLE IF EXISTS feat_medication;

CREATE TABLE feat_medication
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN excluded_pre_window_eventdate END)
        AS antipsychotics_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN excluded_pre_window_description END)
        AS antipsychotics_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN pre_3y_1y_eventdate END)
        AS antipsychotics_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN pre_3y_1y_description END)
        AS antipsychotics_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN pre_1y_0y_eventdate END)
        AS antipsychotics_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN pre_1y_0y_description END)
        AS antipsychotics_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN post_dem_eventdate END)
        AS antipsychotics_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics'
        THEN post_dem_description END)
        AS antipsychotics_post_dem_description,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN excluded_pre_window_eventdate END)
        AS antidepressants_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN excluded_pre_window_description END)
        AS antidepressants_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN pre_3y_1y_eventdate END)
        AS antidepressants_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN pre_3y_1y_description END)
        AS antidepressants_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN pre_1y_0y_eventdate END)
        AS antidepressants_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN pre_1y_0y_description END)
        AS antidepressants_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN post_dem_eventdate END)
        AS antidepressants_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antidepressants'
        THEN post_dem_description END)
        AS antidepressants_post_dem_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN excluded_pre_window_eventdate END)
        AS antipsychotics_antidepressants_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN excluded_pre_window_description END)
        AS antipsychotics_antidepressants_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN pre_3y_1y_eventdate END)
        AS antipsychotics_antidepressants_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN pre_3y_1y_description END)
        AS antipsychotics_antidepressants_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN pre_1y_0y_eventdate END)
        AS antipsychotics_antidepressants_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN pre_1y_0y_description END)
        AS antipsychotics_antidepressants_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN post_dem_eventdate END)
        AS antipsychotics_antidepressants_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'antipsychotics_antidepressants'
        THEN post_dem_description END)
        AS antipsychotics_antidepressants_post_dem_description,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN excluded_pre_window_eventdate END)
        AS anxiety_and_hypnotics_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN excluded_pre_window_description END)
        AS anxiety_and_hypnotics_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN pre_3y_1y_eventdate END)
        AS anxiety_and_hypnotics_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN pre_3y_1y_description END)
        AS anxiety_and_hypnotics_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN pre_1y_0y_eventdate END)
        AS anxiety_and_hypnotics_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN pre_1y_0y_description END)
        AS anxiety_and_hypnotics_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN post_dem_eventdate END)
        AS anxiety_and_hypnotics_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'anxiety_and_hypnotics'
        THEN post_dem_description END)
        AS anxiety_and_hypnotics_post_dem_description
FROM preproc_outcome_features_long
WHERE feature = 'medication'
GROUP BY
    patid,
    dementia_eventdate;

ALTER TABLE feat_medication
    ADD UNIQUE INDEX idx_feat_medication_patid (patid);

DROP TABLE IF EXISTS feat_neuropsychiatric;

CREATE TABLE feat_neuropsychiatric
ENGINE=InnoDB
AS
SELECT
    patid,
    dementia_eventdate,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN excluded_pre_window_eventdate END)
        AS psychosis_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN excluded_pre_window_description END)
        AS psychosis_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN pre_3y_1y_eventdate END)
        AS psychosis_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN pre_3y_1y_description END)
        AS psychosis_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN pre_1y_0y_eventdate END)
        AS psychosis_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN pre_1y_0y_description END)
        AS psychosis_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN post_dem_eventdate END)
        AS psychosis_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'psychosis'
        THEN post_dem_description END)
        AS psychosis_post_dem_description,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN excluded_pre_window_eventdate END)
        AS delirium_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN excluded_pre_window_description END)
        AS delirium_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN pre_3y_1y_eventdate END)
        AS delirium_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN pre_3y_1y_description END)
        AS delirium_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN pre_1y_0y_eventdate END)
        AS delirium_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN pre_1y_0y_description END)
        AS delirium_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN post_dem_eventdate END)
        AS delirium_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'delirium'
        THEN post_dem_description END)
        AS delirium_post_dem_description,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN excluded_pre_window_eventdate END)
        AS affective_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN excluded_pre_window_description END)
        AS affective_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN pre_3y_1y_eventdate END)
        AS affective_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN pre_3y_1y_description END)
        AS affective_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN pre_1y_0y_eventdate END)
        AS affective_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN pre_1y_0y_description END)
        AS affective_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN post_dem_eventdate END)
        AS affective_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'affective'
        THEN post_dem_description END)
        AS affective_post_dem_description,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN excluded_pre_window_eventdate END)
        AS challenging_excluded_pre_window_eventdate,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN excluded_pre_window_description END)
        AS challenging_excluded_pre_window_description,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN pre_3y_1y_eventdate END)
        AS challenging_pre_3y_1y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN pre_3y_1y_description END)
        AS challenging_pre_3y_1y_description,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN pre_1y_0y_eventdate END)
        AS challenging_pre_1y_0y_eventdate,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN pre_1y_0y_description END)
        AS challenging_pre_1y_0y_description,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN post_dem_eventdate END)
        AS challenging_post_dem_eventdate,
    MAX(CASE WHEN outcome_prefix = 'challenging'
        THEN post_dem_description END)
        AS challenging_post_dem_description
FROM preproc_outcome_features_long
WHERE feature = 'neuropsychiatric'
GROUP BY
    patid,
    dementia_eventdate;

ALTER TABLE feat_neuropsychiatric
    ADD UNIQUE INDEX idx_feat_neuropsychiatric_patid (patid);

/* -------------------------------------------------------------------------
   8. QC summaries
   ------------------------------------------------------------------------- */

DROP VIEW IF EXISTS v_qc_post_dementia_outcome_counts;

CREATE VIEW v_qc_post_dementia_outcome_counts AS
SELECT
    feature,
    outcome_prefix,
    source_table,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM preproc_outcome_events
GROUP BY
    feature,
    outcome_prefix,
    source_table;

DROP VIEW IF EXISTS v_qc_post_dementia_eligibility_counts;

CREATE VIEW v_qc_post_dementia_eligibility_counts AS
SELECT
    feature,
    outcome_prefix,
    eligible,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT patid) AS n_patients
FROM outcome_eligibility_log
GROUP BY
    feature,
    outcome_prefix,
    eligible;

DROP VIEW IF EXISTS v_qc_post_dementia_window_counts;

CREATE VIEW v_qc_post_dementia_window_counts AS
SELECT
    feature,
    outcome_prefix,
    SUM(excluded_pre_window_eventdate IS NOT NULL) AS n_excluded_pre_window,
    SUM(pre_3y_1y_eventdate IS NOT NULL) AS n_pre_3y_1y,
    SUM(pre_1y_0y_eventdate IS NOT NULL) AS n_pre_1y_0y,
    SUM(post_dem_eventdate IS NOT NULL) AS n_post_dem
FROM preproc_outcome_features_long
GROUP BY
    feature,
    outcome_prefix;

/* -------------------------------------------------------------------------
   9. Explicit cleanup; these would also disappear at session end
   ------------------------------------------------------------------------- */

DROP TEMPORARY TABLE IF EXISTS tmp_outcome_group_eligibility;
DROP TEMPORARY TABLE IF EXISTS tmp_outcome_prefixes;
DROP TEMPORARY TABLE IF EXISTS tmp_post_dementia_codes;
