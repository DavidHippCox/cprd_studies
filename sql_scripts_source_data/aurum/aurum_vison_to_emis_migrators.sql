-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
USE aurum_test;

CREATE TABLE IF NOT EXISTS vision_to_emis_migrators (
  gold_pracid MEDIUMINT,
  gold_lcddate DATE,
  emis_pracid MEDIUMINT,
  emis_joindate DATE,
  emis_fdcdate DATE
) ENGINE = InnoDB CHARSET = utf8mb4;

LOAD DATA INFILE '{{DATA_ROOT}}/AURUM_SEP2024_linked/Aurum_1/Migrators lookup/visiontoemismigrators.txt' IGNORE INTO TABLE vision_to_emis_migrators FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\r\n' IGNORE 1 LINES (gold_pracid, @gold_lcddate, emis_pracid, @emis_joindate, @emis_fdcdate)
SET
  gold_lcddate = STR_TO_DATE(NULLIF(@gold_lcddate, ''), '%d/%m/%Y'),
  emis_joindate = STR_TO_DATE(NULLIF(@emis_joindate, ''), '%d/%m/%Y'),
  emis_fdcdate = STR_TO_DATE(NULLIF(@emis_fdcdate, ''), '%d/%m/%Y');
