-- once performing inner join of patids to create alcohol_units_observation_classified table and copying the lookups from aurum_alcohol 
-- we do these table creations (easiest considering size of data)
-- use MSc's aurum_arld;
USE aurum_arld;

CREATE TABLE `alcohol_unit_aurum` (
  `medcodeid` BIGINT(20) UNSIGNED NOT NULL,
  `observations` VARCHAR(500) NOT NULL,
  `term` VARCHAR(500) NOT NULL,
  `term_has_unit` TINYINT(1) NOT NULL,
  `term_period` VARCHAR(10) DEFAULT NULL,
  `zero_allowed` TINYINT(1) NOT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_uca1400_ai_ci;

LOAD DATA INFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_unit_aurum.csv' INTO TABLE alcohol_unit_aurum FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

CREATE TABLE `alcohol_unit_numunitid_aurum` (
  `numunitid` BIGINT(20) UNSIGNED NOT NULL,
  `description` VARCHAR(500) NOT NULL,
  `amount_type` VARCHAR(10) NOT NULL,
  `amount_low` DECIMAL(19, 3) DEFAULT NULL,
  `amount_high` DECIMAL(19, 3) DEFAULT NULL,
  `numunit_has_unit` TINYINT(1) NOT NULL,
  `numunit_period` VARCHAR(10) DEFAULT NULL,
  `weekly_multiplier` DECIMAL(20, 15) DEFAULT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_uca1400_ai_ci;

LOAD DATA INFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_unit_numunitid_aurum.csv' INTO TABLE alcohol_unit_numunitid_aurum FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

CREATE TABLE `alcohol_units_observation_classified` (
  `patid` BIGINT(20) UNSIGNED DEFAULT NULL,
  `obsdate` date DEFAULT NULL,
  `medcodeid` BIGINT(20) DEFAULT NULL,
  `value` DECIMAL(19, 3) DEFAULT NULL,
  `numunitid` BIGINT(20) DEFAULT NULL,
  `obstypeid` MEDIUMINT(9) DEFAULT NULL,
  `term` VARCHAR(500) NOT NULL,
  `numunit_description` VARCHAR(500),
  `status` VARCHAR(6) DEFAULT NULL,
  `reason_code` VARCHAR(27) DEFAULT NULL,
  `weekly_units_low` DECIMAL(39, 18) DEFAULT NULL,
  `weekly_units_high` DECIMAL(39, 18) DEFAULT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_uca1400_ai_ci;

LOAD DATA INFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_units_observation_classified.csv' INTO TABLE alcohol_units_observation_classified FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;