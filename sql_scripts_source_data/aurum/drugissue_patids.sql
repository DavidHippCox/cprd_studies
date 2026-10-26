-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_001;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_002;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_003;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_004;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_005;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_006;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_007;

INSERT IGNORE INTO
  drugissue_patids (patid)
SELECT
  patid
FROM
  drugissue_008;
