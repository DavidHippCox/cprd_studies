USE aurum_oxcprd_001b;

CREATE TABLE smoking_observation (
  patid BIGINT UNSIGNED NOT NULL,
  eventdate DATE NOT NULL,
  medcodeid BIGINT UNSIGNED NULL,
  value DECIMAL(19, 3),
  numunitid BIGINT UNSIGNED
) ENGINE = InnoDB;

/* CPRD observations */
INSERT INTO
  smoking_observation (patid, eventdate, medcodeid, value, numunitid)
SELECT
  o.patid,
  o.obsdate,
  o.medcodeid,
  o.value,
  o.numunitid
FROM
  observation AS o
  INNER JOIN v0_smoking_codes_AURUM AS c ON c.medcodeid = o.medcodeid
  INNER JOIN preproc_patient_candidates AS p ON p.patid = o.patid -- update for patient_analysis
WHERE
  o.obsdate IS NOT NULL
  AND o.obsdate >= DATE_ADD(p.yob_date, INTERVAL 18 YEAR) -- observations after 18 years old
  -- no family history
  AND o.obstypeid <> 4;