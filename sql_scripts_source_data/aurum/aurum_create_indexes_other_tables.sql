-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
\W
USE aurum_test;

CREATE INDEX idx_patid ON patient (patid);

CREATE INDEX idx_pracid ON practice (pracid);