-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
\W
USE gold;


CREATE INDEX idx_patid ON consultation_001 (patid);
CREATE INDEX idx_patid ON consultation_002 (patid);
CREATE INDEX idx_patid ON consultation_003 (patid);
CREATE INDEX idx_patid ON consultation_004 (patid);
