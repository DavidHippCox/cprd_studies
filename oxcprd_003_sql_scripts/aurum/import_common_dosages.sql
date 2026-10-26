-- Authored by David Hippisley-Cox
-- project: aurum_oxcprd_003
-- analysis plan version: NA
USE aurum_oxcprd_003;

CREATE TABLE common_dosages (
    dosageid          VARCHAR(990),
    dosage_text       VARCHAR(999),
    daily_dose        VARCHAR(999),
    dose_number       VARCHAR(999),
    dose_unit         VARCHAR(999),
    dose_frequency    VARCHAR(999),
    dose_interval     VARCHAR(999),
    choice_of_dose    VARCHAR(999),
    dose_max_average  VARCHAR(999),
    change_dose       VARCHAR(999),
    dose_duration     VARCHAR(999)
);

LOAD DATA INFILE
    '{{DATA_ROOT}}/Aurum_SEP2024/202409_Lookups_CPRDAurum/common_dosages.txt'
INTO TABLE common_dosages
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @dosageid,
    @dosage_text,
    @daily_dose,
    @dose_number,
    @dose_unit,
    @dose_frequency,
    @dose_interval,
    @choice_of_dose,
    @dose_max_average,
    @change_dose,
    @dose_duration
)
SET
    dosageid = NULLIF(@dosageid, ''),
    dosage_text = NULLIF(@dosage_text, ''),
    daily_dose = NULLIF(@daily_dose, ''),
    dose_number = NULLIF(@dose_number, ''),
    dose_unit = NULLIF(@dose_unit, ''),
    dose_frequency = NULLIF(@dose_frequency, ''),
    dose_interval = NULLIF(@dose_interval, ''),
    choice_of_dose = NULLIF(@choice_of_dose, ''),
    dose_max_average = NULLIF(@dose_max_average, ''),
    change_dose = NULLIF(@change_dose, ''),
    dose_duration = NULLIF(@dose_duration, '');

ALTER TABLE common_dosages ADD PRIMARY KEY (dosageid);