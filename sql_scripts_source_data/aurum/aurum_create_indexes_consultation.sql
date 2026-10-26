-- Authored by David Hippisley-Cox
-- project: sql_scripts_source_data
-- analysis plan version: NA
\W
USE aurum_test;


CREATE INDEX idx_pracid ON consultation_001 (pracid);
CREATE INDEX idx_pracid ON consultation_002 (pracid);
CREATE INDEX idx_pracid ON consultation_003 (pracid);
CREATE INDEX idx_pracid ON consultation_004 (pracid);
CREATE INDEX idx_pracid ON consultation_005 (pracid);
CREATE INDEX idx_pracid ON consultation_006 (pracid);
CREATE INDEX idx_pracid ON consultation_007 (pracid);
