-- once performing inner join of patids to create alcohol_units_observation_classified table and copying the lookups from aurum_alcohol 
-- we do these table creations (easiest considering size of data)

-- use sarah's aurum_arld;
USE aurum_arld;

CREATE TABLE `alcohol_unit_aurum` (
  `medcodeid` bigint(20) unsigned NOT NULL,
  `observations` varchar(500) NOT NULL,
  `term` varchar(500) NOT NULL,
  `term_has_unit` tinyint(1) NOT NULL,
  `term_period` varchar(10) DEFAULT NULL,
  `zero_allowed` tinyint(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci; 

LOAD DATA INFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_unit_aurum.csv'
INTO TABLE alcohol_unit_aurum
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CREATE TABLE `alcohol_unit_numunitid_aurum` (
  `numunitid` bigint(20) unsigned NOT NULL,
  `description` varchar(500) NOT NULL,
  `amount_type` varchar(10) NOT NULL,
  `amount_low` decimal(19,3) DEFAULT NULL,
  `amount_high` decimal(19,3) DEFAULT NULL,
  `numunit_has_unit` tinyint(1) NOT NULL,
  `numunit_period` varchar(10) DEFAULT NULL,
  `weekly_multiplier` decimal(20,15) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


LOAD DATA INFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_unit_numunitid_aurum.csv'
INTO TABLE alcohol_unit_numunitid_aurum
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CREATE TABLE `alcohol_units_observation_classified` (
  `patid` bigint(20) unsigned DEFAULT NULL,
  `obsdate` date DEFAULT NULL,
  `medcodeid` bigint(20) DEFAULT NULL,
  `value` decimal(19,3) DEFAULT NULL,
  `numunitid` bigint(20) DEFAULT NULL,
  `obstypeid` mediumint(9) DEFAULT NULL,
  `term` varchar(500) NOT NULL,
  `numunit_description` varchar(500),
  `status` varchar(6) DEFAULT NULL,
  `reason_code` varchar(27) DEFAULT NULL,
  `weekly_units_low` decimal(39,18) DEFAULT NULL,
  `weekly_units_high` decimal(39,18) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

LOAD DATA INFILE '{{STUDY_002_AURUM_ROOT}}/rawdata/alcohol_units_observation_classified.csv'
INTO TABLE alcohol_units_observation_classified
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;